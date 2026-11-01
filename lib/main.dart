import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import 'features/admin/admin_console.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/cards/card_table_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/game/game_specs.dart';
import 'features/game/round_bets.dart';
import 'features/game/round_history.dart';

const emulator = bool.fromEnvironment('EMULATORS', defaultValue: kDebugMode);
const configuredHost = String.fromEnvironment('EMULATOR_HOST');
final host = configuredHost.isNotEmpty
    ? configuredHost
    : defaultTargetPlatform == TargetPlatform.android
    ? '10.0.2.2'
    : '127.0.0.1';
final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (!emulator &&
        const String.fromEnvironment(
              'FIREBASE_PROJECT_ID',
              defaultValue: 'demo-tai-xiu',
            ) ==
            'demo-tai-xiu') {
      throw StateError('Chưa cấu hình Firebase project thật cho bản release.');
    }
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: String.fromEnvironment(
          'FIREBASE_API_KEY',
          defaultValue: 'AIzaSyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        ),
        appId: String.fromEnvironment(
          'FIREBASE_APP_ID',
          defaultValue: '1:123456789:web:demo',
        ),
        messagingSenderId: String.fromEnvironment(
          'FIREBASE_SENDER_ID',
          defaultValue: '123456789',
        ),
        projectId: String.fromEnvironment(
          'FIREBASE_PROJECT_ID',
          defaultValue: 'demo-tai-xiu',
        ),
        authDomain: String.fromEnvironment(
          'FIREBASE_AUTH_DOMAIN',
          defaultValue: 'demo-tai-xiu.firebaseapp.com',
        ),
      ),
    );
    if (emulator) {
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      functions.useFunctionsEmulator(host, 5001);
    }
    runApp(const GameApp());
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Không kết nối được Firebase: $error')),
        ),
      ),
    );
  }
}

class GameApp extends StatelessWidget {
  const GameApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Phòng trò chơi • Xu ảo',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff277767),
        surface: const Color(0xfff8f5ee),
      ),
      scaffoldBackgroundColor: const Color(0xfff8f5ee),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xfff8f5ee)),
      cardTheme: CardThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    home: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Lỗi đăng nhập: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        return user == null
            ? const SignInScreen()
            : Lobby(key: ValueKey(user.uid), user: user);
      },
    ),
  );
}

String readableError(Object error) => error is FirebaseFunctionsException
    ? (error.message ??
          'Máy chủ không thực hiện được thao tác (${error.code}).')
    : error is FirebaseAuthException
    ? (error.message ?? 'Đăng nhập thất bại (${error.code}).')
    : 'Không thể kết nối. Kiểm tra mạng rồi thử lại: $error';

class Lobby extends StatefulWidget {
  final User user;
  const Lobby({super.key, required this.user});
  @override
  State<Lobby> createState() => _LobbyState();
}

class _LobbyState extends State<Lobby> {
  late Future<bool> profile = _loadProfile();
  Future<bool> _loadProfile() async {
    final token = await widget.user.getIdTokenResult(true);
    await functions.httpsCallable('ensureProfile').call();
    return token.claims?['admin'] == true;
  }

  void _showLeaderboard() {
    final ranking = functions.httpsCallable('getLeaderboard').call();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bảng xếp hạng xu ảo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chỉ là điểm mô phỏng, không có thưởng hay quy đổi.',
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: FutureBuilder<HttpsCallableResult<dynamic>>(
                    future: ranking,
                    builder: (context, result) {
                      if (result.hasError) {
                        return Text(
                          'Không tải được: ${readableError(result.error!)}',
                        );
                      }
                      if (!result.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final rows = result.data!.data;
                      if (rows is! List || rows.isEmpty) {
                        return const Text('Chưa có người chơi.');
                      }
                      return ListView(
                        shrinkWrap: true,
                        children: [
                          for (final row in rows.whereType<Map>())
                            ListTile(
                              leading: Text('#${row['rank'] ?? '—'}'),
                              title: Text('${row['nickname'] ?? 'Người chơi'}'),
                              trailing: Text('${row['balance'] ?? '—'} xu'),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('PHÒNG TRÒ CHƠI'),
      actions: [
        IconButton(
          tooltip: 'Đăng xuất',
          icon: const Icon(Icons.logout),
          onPressed: () => FirebaseAuth.instance.signOut(),
        ),
      ],
    ),
    body: FutureBuilder<bool>(
      future: profile,
      builder: (context, state) {
        if (state.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Không tải được tài khoản: ${readableError(state.error!)}',
                  ),
                  TextButton(
                    onPressed: () => setState(() => profile = _loadProfile()),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!state.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final isAdmin = state.data!;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'CHỌN PHÒNG',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  'Năm trò chơi, chỉ dùng điểm ảo.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'CHỈ XU ẢO • Không có tiền thật, nạp/rút hay giải thưởng. '
                      'Chế độ ADMIN cho phép quản trị viên chọn kết quả sau khi khóa cược; '
                      'RANDOM do máy chủ quyết định.',
                    ),
                  ),
                ),
                if (emulator) const Text('Đang dùng Firebase Emulator'),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .doc('users/${widget.user.uid}')
                      .snapshots(),
                  builder: (context, user) {
                    if (user.hasError) {
                      return Text('Không tải được số xu: ${user.error}');
                    }
                    if (!user.hasData) return const LinearProgressIndicator();
                    final data = user.data!.data();
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xff277767),
                          foregroundColor: Colors.white,
                          child: Icon(Icons.account_balance_wallet_outlined),
                        ),
                        title: Text(
                          '${data?['balance'] ?? '—'} xu ảo',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Text(
                          data?['blocked'] == true
                              ? 'Tài khoản bị khóa: ${data?['blockReason'] ?? 'Liên hệ quản trị'}'
                              : '${widget.user.email ?? widget.user.uid} • ${isAdmin ? 'Admin' : 'Hội viên'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProfileScreen(
                              user: widget.user,
                              isAdmin: isAdmin,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showLeaderboard,
                        icon: const Icon(Icons.leaderboard_outlined),
                        label: const Text('Bảng xếp hạng'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProfileScreen(
                              user: widget.user,
                              isAdmin: isAdmin,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.person_outline),
                        label: const Text('Hồ sơ & Ví'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...games.map(
                  (game) => Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      leading: CircleAvatar(child: Icon(game.icon)),
                      title: Text(
                        game.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      subtitle: Text(game.detail),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 17),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RoundScreen(
                            game: game,
                            uid: widget.user.uid,
                            isAdmin: isAdmin,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                for (final entry in const [
                  ('poker', 'Poker'),
                  ('ba_cay', 'Ba Cây'),
                ])
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.style_outlined),
                      title: Text(entry.$2),
                      subtitle: Text(
                        entry.$1 == 'poker'
                            ? 'Bàn 2–6 ghế • Texas Hold’em ante/cược giới hạn'
                            : 'Bàn 2–6 ghế • ba lá, góp ante rồi so điểm',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 17),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CardTableScreen(
                            uid: widget.user.uid,
                            isAdmin: isAdmin,
                            game: entry.$1,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Hoạt động xu ảo của bạn',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users/${widget.user.uid}/operations')
                      .orderBy('at', descending: true)
                      .limit(20)
                      .snapshots(),
                  builder: (context, ops) {
                    if (ops.hasError) {
                      return Text('Không tải được hoạt động: ${ops.error}');
                    }
                    if (!ops.hasData) return const LinearProgressIndicator();
                    if (ops.data!.docs.isEmpty) {
                      return const Text('Chưa có hoạt động.');
                    }
                    return Column(
                      children: ops.data!.docs.map((doc) {
                        final op = doc.data();
                        return ListTile(
                          title: Text(
                            '${op['kind'] ?? 'Hoạt động'} • ${op['delta'] ?? 0} xu',
                          ),
                          subtitle: Text(
                            'Số dư sau: ${op['balance'] ?? '—'} • ${op['roundId'] ?? ''}',
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                if (isAdmin)
                  AdminConsole(
                    uid: widget.user.uid,
                    invoke: (name, data) async {
                      await functions.httpsCallable(name).call(data);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class RoundScreen extends StatefulWidget {
  final GameSpec game;
  final String uid;
  final bool isAdmin;
  const RoundScreen({
    super.key,
    required this.game,
    required this.uid,
    required this.isAdmin,
  });
  @override
  State<RoundScreen> createState() => _RoundScreenState();
}

class _RoundScreenState extends State<RoundScreen> {
  final amount = TextEditingController(text: '1000');
  final result = TextEditingController();
  final reason = TextEditingController();
  final now = ValueNotifier(DateTime.now());
  Timer? timer;
  String mode = 'random';
  bool busy = false;
  String? message;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => now.value = DateTime.now(),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    now.dispose();
    amount.dispose();
    result.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> call(String name, Map<String, dynamic> data) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await functions.httpsCallable(name).call(data);
      if (mounted) setState(() => message = 'Thao tác đã hoàn tất.');
    } catch (e) {
      if (mounted) setState(() => message = readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void settle(String id) {
    final parsed = parseRoundResult(widget.game, result.text);
    if (parsed == null) {
      setState(
        () => message = 'Kết quả không hợp lệ. ${widget.game.resultHint}.',
      );
      return;
    }
    if (reason.text.trim().length < 5 || reason.text.length > 300) {
      setState(() => message = 'Nhập lý do từ 5 đến 300 ký tự.');
      return;
    }
    call('settleRound', {
      'roundId': id,
      'result': parsed,
      'reason': reason.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.game.title)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Icon(
                  widget.game.icon,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.game.symbol,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        widget.game.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(widget.game.detail),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Xu ảo, không tiền thật và không giải thưởng. Kết quả/số dư do máy chủ xác nhận.',
            ),
            if (busy) const LinearProgressIndicator(),
            if (message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  message!,
                  style: TextStyle(
                    color: message!.startsWith('Thao tác')
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            if (widget.isAdmin)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Điều hành phòng',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      DropdownButton<String>(
                        value: mode,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'random',
                            child: Text('RANDOM — máy chủ chọn'),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('ADMIN — quản trị chọn sau khóa cược'),
                          ),
                        ],
                        onChanged: busy
                            ? null
                            : (v) => setState(() => mode = v!),
                      ),
                      FilledButton.tonal(
                        onPressed: busy
                            ? null
                            : () => call('startRound', {
                                'game': widget.game.id,
                                'mode': mode,
                              }),
                        child: const Text('Mở phiên mới'),
                      ),
                    ],
                  ),
                ),
              ),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .doc('rooms/${widget.game.id}')
                  .snapshots(includeMetadataChanges: true),
              builder: (context, room) {
                if (room.hasError) {
                  return Text('Không tải được phòng: ${room.error}');
                }
                if (!room.hasData) return const LinearProgressIndicator();
                final id = room.data!.data()?['roundId'] as String?;
                if (id == null) {
                  return const Card(
                    child: ListTile(
                      title: Text('Chưa có phiên'),
                      subtitle: Text('Vui lòng đợi Admin mở phiên.'),
                    ),
                  );
                }
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  key: ValueKey(id),
                  stream: FirebaseFirestore.instance
                      .doc('rounds/$id')
                      .snapshots(includeMetadataChanges: true),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text('Không tải được phiên: ${snapshot.error}');
                    }
                    if (!snapshot.hasData) {
                      return const LinearProgressIndicator();
                    }
                    final round = snapshot.data!.data();
                    if (round == null) {
                      return const Text('Phiên không tồn tại hoặc đã bị xóa.');
                    }
                    if (round['game'] != widget.game.id) {
                      return const Text('Dữ liệu phòng không khớp trò chơi.');
                    }
                    final offline =
                        room.data!.metadata.isFromCache ||
                        snapshot.data!.metadata.isFromCache;
                    final status = round['status']?.toString() ?? 'không rõ';
                    final adminMode = round['mode'] == 'admin';
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (offline)
                              const Text(
                                'Đang xem dữ liệu lưu tạm; cần kết nối mạng để thao tác.',
                              ),
                            Text(
                              'PHIÊN $id',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            Text(
                              adminMode
                                  ? 'ADMIN • Quản trị có thể chọn kết quả'
                                  : 'RANDOM • Máy chủ chọn kết quả',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            ValueListenableBuilder<DateTime>(
                              valueListenable: now,
                              builder: (context, time, _) {
                                final closesAt = round['closesAt'];
                                final seconds = closesAt is Timestamp
                                    ? (closesAt
                                                  .toDate()
                                                  .difference(time)
                                                  .inMilliseconds /
                                              1000)
                                          .ceil()
                                    : null;
                                return Text(
                                  'Trạng thái: $status • ${seconds == null ? 'Không có hạn cược' : '${seconds < 0 ? 0 : seconds}s'} '
                                  '• ${round['betCount'] ?? 0} cược',
                                );
                              },
                            ),
                            if (round['result'] != null)
                              Text(
                                'Kết quả: ${(round['result'] as List).join(', ')}',
                              ),
                            if (round['outcome'] is Map)
                              Text(
                                'Diễn giải: ${formatOutcome(widget.game, round['outcome'] as Map)}',
                              ),
                            if (status == 'cancelled')
                              const Text(
                                'Phiên đã hủy; cược được hoàn theo máy chủ.',
                              ),
                            RoundHistory(game: widget.game),
                            const SizedBox(height: 12),
                            TextField(
                              controller: amount,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Số xu cược',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ValueListenableBuilder<DateTime>(
                              valueListenable: now,
                              builder: (context, time, _) => Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: widget.game.sides
                                    .map(
                                      (side) => FilledButton.tonal(
                                        onPressed:
                                            busy ||
                                                offline ||
                                                status != 'open' ||
                                                (round['closesAt']
                                                        is Timestamp &&
                                                    !(round['closesAt']
                                                            as Timestamp)
                                                        .toDate()
                                                        .isAfter(time))
                                            ? null
                                            : () {
                                                final value = int.tryParse(
                                                  amount.text.trim(),
                                                );
                                                if (value == null ||
                                                    value <= 0) {
                                                  setState(
                                                    () => message =
                                                        'Cược tối thiểu 1000 xu; bội số 100. Xóc Xóc: 1000/10000/50000/100000/1000000.',
                                                  );
                                                  return;
                                                }
                                                call('placeBet', {
                                                  'roundId': id,
                                                  'side': side.$1,
                                                  'amount': value,
                                                  'requestId': FirebaseFirestore
                                                      .instance
                                                      .collection('requestIds')
                                                      .doc()
                                                      .id,
                                                });
                                              },
                                        child: Text('Cược ${side.$2}'),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              key: ValueKey('bet_$id'),
                              stream: FirebaseFirestore.instance
                                  .doc('rounds/$id/bets/${widget.uid}')
                                  .snapshots(),
                              builder: (context, bet) {
                                if (bet.hasError) {
                                  return Text(
                                    'Không tải được cược của bạn: ${bet.error}',
                                  );
                                }
                                if (!bet.hasData) {
                                  return const Text('Đang tải cược của bạn…');
                                }
                                final data = bet.data!.data();
                                return Text(
                                  data == null
                                      ? 'Bạn chưa cược phiên này.'
                                      : 'Cược của bạn: ${data['stakes']} • ${data['amount']} xu '
                                            '• Ghi có: ${data['credit'] ?? 'chờ kết quả'}',
                                );
                              },
                            ),
                            if (widget.isAdmin) ...[
                              const Divider(),
                              TextField(
                                controller: reason,
                                maxLength: 300,
                                decoration: const InputDecoration(
                                  labelText: 'Lý do (5–300 ký tự)',
                                ),
                              ),
                              if (status == 'open')
                                ValueListenableBuilder<DateTime>(
                                  valueListenable: now,
                                  builder: (context, time, _) {
                                    final deadline = round['closesAt'];
                                    return OutlinedButton(
                                      onPressed:
                                          busy ||
                                              offline ||
                                              deadline is! Timestamp ||
                                              deadline.toDate().isAfter(time)
                                          ? null
                                          : () => call('lockRound', {
                                              'roundId': id,
                                            }),
                                      child: const Text('Khóa cược (sau hạn)'),
                                    );
                                  },
                                ),
                              if (adminMode && status == 'locked') ...[
                                TextField(
                                  controller: result,
                                  decoration: InputDecoration(
                                    labelText: widget.game.resultHint,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                FilledButton(
                                  onPressed: busy || offline
                                      ? null
                                      : () => settle(id),
                                  child: const Text('Chốt kết quả'),
                                ),
                              ],
                              if (!adminMode && status == 'locked')
                                FilledButton(
                                  onPressed: busy || offline
                                      ? null
                                      : () => call('settleRound', {
                                          'roundId': id,
                                        }),
                                  child: const Text(
                                    'Chốt ngẫu nhiên trên máy chủ',
                                  ),
                                ),
                              if (status == 'open' || status == 'locked')
                                OutlinedButton(
                                  onPressed: busy || offline
                                      ? null
                                      : () {
                                          if (reason.text.trim().length < 5 ||
                                              reason.text.length > 300) {
                                            setState(
                                              () => message =
                                                  'Nhập lý do từ 5 đến 300 ký tự.',
                                            );
                                          } else {
                                            call('cancelRound', {
                                              'roundId': id,
                                              'reason': reason.text.trim(),
                                            });
                                          }
                                        },
                                  child: const Text('Hủy phiên'),
                                ),
                              RoundBets(roundId: id),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
