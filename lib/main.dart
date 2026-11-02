import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart' hide Text;

import 'core/app_preferences.dart';
import 'core/app_text.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/admin/admin_console.dart';
import 'features/lobby/lobby_screen.dart';
import 'features/onboarding/presentation/screens/authenticated_entry_screen.dart';
import 'features/game/game_specs.dart';
import 'features/game/round_bets.dart';
import 'features/game/round_history.dart';
import 'features/game/presentation/widgets/tai_xiu_betting_table.dart';
import 'features/game/presentation/widgets/bau_cua_betting_table.dart';
import 'features/game/presentation/widgets/xoc_xoc/xoc_xoc_betting_table.dart';

const emulator = bool.fromEnvironment('EMULATORS', defaultValue: kDebugMode);
const configuredHost = String.fromEnvironment('EMULATOR_HOST');
final host = configuredHost.isNotEmpty
    ? configuredHost
    : defaultTargetPlatform == TargetPlatform.android
    ? '10.0.2.2'
    : '127.0.0.1';
final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');

Map<String, int> _intMap(Object? value) => value is Map
    ? {
        for (final entry in value.entries)
          if (entry.key is String && entry.value is num)
            entry.key as String: (entry.value as num).toInt(),
      }
    : const {};

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
    await AppPreferences.loadLanguage();
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
            : AuthenticatedEntryScreen(
                key: ValueKey(user.uid),
                user: user,
                adminBuilder: (_) => AdminConsole(
                  uid: user.uid,
                  initiallyExpanded: true,
                  invoke: (name, data) async {
                    await functions.httpsCallable(name).call(data);
                  },
                  roundBuilder: (game) =>
                      RoundScreen(game: game, uid: user.uid, isAdmin: true),
                ),
                lobbyBuilder: (_) => LobbyScreen(
                  key: ValueKey('lobby_${user.uid}'),
                  user: user,
                  functions: functions,
                  emulator: emulator,
                  readableError: readableError,
                  roundBuilder: (game, uid, isAdmin) =>
                      RoundScreen(game: game, uid: uid, isAdmin: isAdmin),
                ),
              );
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
  int gameNavIndex = 1;
  bool busy = false;
  String? message;
  final Set<String> _advancingRounds = {};
  final Set<String> _advancedRounds = {};
  final Map<String, DateTime> _lastAdvanceAttempt = {};
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

  Future<void> call(
    String name,
    Map<String, dynamic> data, {
    bool rethrowOnError = false,
  }) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await functions.httpsCallable(name).call(data);
      if (name == 'settleRound' || name == 'cancelRound') {
        unawaited(_ensureNextSessions());
      }
      if (mounted) setState(() => message = 'Thao tác đã hoàn tất.');
    } catch (e) {
      if (mounted) setState(() => message = readableError(e));
      if (rethrowOnError) rethrow;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _ensureNextSessions() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    try {
      await functions.httpsCallable('ensureGameRounds').call();
    } catch (error) {
      if (mounted) setState(() => message = readableError(error));
    }
  }

  Future<void> _advanceExpiredRandomRound(String roundId) async {
    if (_advancingRounds.contains(roundId) ||
        _advancedRounds.contains(roundId)) {
      return;
    }
    final nowAt = DateTime.now();
    final last = _lastAdvanceAttempt[roundId];
    if (last != null && nowAt.difference(last).inSeconds < 5) return;
    _lastAdvanceAttempt[roundId] = nowAt;
    _advancingRounds.add(roundId);
    try {
      final response = await functions.httpsCallable('advanceRandomRound').call(
        {'roundId': roundId},
      );
      final data = response.data;
      if (data is Map && data['notDue'] == true) return;
      if (data is Map && data['waiting'] == true) return;
      _advancedRounds.add(roundId);
      await _ensureNextSessions();
    } catch (error) {
      if (mounted) setState(() => message = readableError(error));
    } finally {
      _advancingRounds.remove(roundId);
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

  void intervene(String id) {
    if (reason.text.trim().length < 5 || reason.text.length > 300) {
      setState(() => message = 'Nhập lý do can thiệp từ 5 đến 300 ký tự.');
      return;
    }
    call('interveneRound', {'roundId': id, 'reason': reason.text.trim()});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor:
        widget.game.id == 'tai_xiu' ||
            widget.game.id == 'bau_cua' ||
            widget.game.id == 'xoc_xoc'
        ? const Color(0xff10131a)
        : null,
    appBar: widget.game.id == 'tai_xiu' || widget.game.id == 'xoc_xoc'
        ? null
        : AppBar(
            backgroundColor:
                widget.game.id == 'tai_xiu' ||
                    widget.game.id == 'bau_cua' ||
                    widget.game.id == 'xoc_xoc'
                ? const Color(0xff0b0e14)
                : null,
            foregroundColor:
                widget.game.id == 'tai_xiu' ||
                    widget.game.id == 'bau_cua' ||
                    widget.game.id == 'xoc_xoc'
                ? const Color(0xffe1e2eb)
                : null,
            title: Text(
              widget.game.id == 'tai_xiu'
                  ? 'TÀI XỈU • XU ẢO'
                  : widget.game.title,
            ),
            actions:
                widget.game.id == 'tai_xiu' ||
                    widget.game.id == 'bau_cua' ||
                    widget.game.id == 'xoc_xoc'
                ? [
                    IconButton(
                      tooltip: 'Âm thanh',
                      onPressed: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Âm thanh chưa được tích hợp.'),
                            ),
                          ),
                      icon: const Icon(Icons.volume_up),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 18,
                      ),
                      child: Text(
                        'LIVE',
                        style: TextStyle(
                          color: Color(0xffffb3ad),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ]
                : null,
          ),
    bottomNavigationBar:
        widget.game.id == 'tai_xiu' || widget.game.id == 'xoc_xoc'
        ? NavigationBar(
            backgroundColor: const Color(0xff0b0e14),
            indicatorColor: const Color(0x33ffc174),
            selectedIndex: gameNavIndex,
            onDestinationSelected: (index) {
              if (index == 0) {
                Navigator.of(context).maybePop();
                return;
              }
              setState(() => gameNavIndex = index);
              if (index != 1) {
                final labels = ['', '', 'Cầu Road', 'VIP Vault', 'Rank'];
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      index == 2
                          ? 'Lịch sử phiên nằm bên dưới bàn chơi.'
                          : '${labels[index]} đang ở chế độ giao diện.',
                    ),
                  ),
                );
              }
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.casino), label: 'Lobby'),
              NavigationDestination(
                icon: Icon(Icons.play_circle),
                label: 'Arena',
              ),
              NavigationDestination(
                icon: Icon(Icons.analytics),
                label: 'Cầu Road',
              ),
              NavigationDestination(
                icon: Icon(Icons.military_tech),
                label: 'VIP Vault',
              ),
              NavigationDestination(
                icon: Icon(Icons.admin_panel_settings),
                label: 'Rank',
              ),
            ],
          )
        : null,
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.game.id != 'tai_xiu' &&
                widget.game.id != 'bau_cua' &&
                widget.game.id != 'xoc_xoc')
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
            if (widget.game.id != 'tai_xiu' &&
                widget.game.id != 'bau_cua' &&
                widget.game.id != 'xoc_xoc')
              const SizedBox(height: 18),
            if (widget.game.id != 'tai_xiu' &&
                widget.game.id != 'bau_cua' &&
                widget.game.id != 'xoc_xoc')
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
              const Card(
                color: Color(0xff191c22),
                child: ListTile(
                  leading: Icon(Icons.autorenew, color: Color(0xffffc174)),
                  title: Text('Phiên tự chạy'),
                  subtitle: Text(
                    'Các phiên tự mở, chốt ngẫu nhiên và chuyển sang phiên kế tiếp. Can thiệp từng phiên ở phần quản trị bên dưới.',
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
                  return Card(
                    color:
                        widget.game.id == 'tai_xiu' ||
                            widget.game.id == 'bau_cua' ||
                            widget.game.id == 'xoc_xoc'
                        ? const Color(0xff191c22)
                        : null,
                    child: ListTile(
                      title: Text('Chưa có phiên'),
                      subtitle: Text('Đang tự động khởi tạo phiên chơi.'),
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
                      color:
                          widget.game.id == 'tai_xiu' ||
                              widget.game.id == 'bau_cua' ||
                              widget.game.id == 'xoc_xoc'
                          ? const Color(0xff191c22)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (offline)
                              const Text(
                                'Đang xem dữ liệu lưu tạm; cần kết nối mạng để thao tác.',
                              ),
                            if (widget.game.id != 'tai_xiu' &&
                                widget.game.id != 'xoc_xoc') ...[
                              Text(
                                'PHIÊN $id',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              Text(
                                adminMode
                                    ? 'ADMIN • Quản trị có thể chọn kết quả'
                                    : 'RANDOM • Máy chủ chọn kết quả',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
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
                                if (!adminMode &&
                                    status != 'settled' &&
                                    status != 'cancelled' &&
                                    closesAt is Timestamp &&
                                    !closesAt.toDate().isAfter(time)) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    _advanceExpiredRandomRound(id);
                                  });
                                }
                                return Text(
                                  'Trạng thái: $status • ${seconds == null ? 'Không có hạn cược' : '${seconds < 0 ? 0 : seconds}s'} '
                                  '• ${round['betCount'] ?? 0} cược',
                                );
                              },
                            ),
                            if (widget.game.id != 'xoc_xoc' &&
                                round['result'] != null)
                              Text(
                                'Kết quả: ${(round['result'] as List).join(', ')}',
                              ),
                            if (widget.game.id != 'xoc_xoc' &&
                                round['outcome'] is Map)
                              Text(
                                'Diễn giải: ${formatOutcome(widget.game, round['outcome'] as Map)}',
                              ),
                            if (status == 'cancelled')
                              const Text(
                                'Phiên đã hủy; cược được hoàn theo máy chủ.',
                              ),
                            if (widget.game.id == 'tai_xiu')
                              StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>
                              >(
                                stream: FirebaseFirestore.instance
                                    .doc('users/${widget.uid}')
                                    .snapshots(),
                                builder: (context, userSnapshot) =>
                                    ValueListenableBuilder<DateTime>(
                                      valueListenable: now,
                                      builder: (context, time, _) {
                                        final closesAt = round['closesAt'];
                                        final secondsLeft =
                                            closesAt is Timestamp
                                            ? closesAt
                                                  .toDate()
                                                  .difference(time)
                                                  .inSeconds
                                            : 0;
                                        final balance = userSnapshot.data
                                            ?.data()?['balance'];
                                        return StreamBuilder<
                                          DocumentSnapshot<Map<String, dynamic>>
                                        >(
                                          stream: FirebaseFirestore.instance
                                              .doc(
                                                'rounds/$id/bets/${widget.uid}',
                                              )
                                              .snapshots(),
                                          builder: (context, currentBet) {
                                            final data = currentBet.data
                                                ?.data();
                                            final stakes = data?['stakes'];
                                            String? confirmedSide;
                                            if (stakes is Map) {
                                              for (final entry
                                                  in stakes.entries) {
                                                if (entry.value is num &&
                                                    (entry.value as num) > 0) {
                                                  confirmedSide =
                                                      '${entry.key}';
                                                }
                                              }
                                            }
                                            final confirmedAmount =
                                                data?['amount'];
                                            final result = round['result'];
                                            final outcome = round['outcome'];
                                            return TaiXiuBettingTable(
                                              key: ValueKey('tai_xiu_$id'),
                                              roundId: id,
                                              mode:
                                                  '${round['mode'] ?? 'random'}',
                                              status: status,
                                              secondsLeft: secondsLeft,
                                              balance: balance is int
                                                  ? balance
                                                  : 0,
                                              confirmedAmount:
                                                  confirmedAmount is int
                                                  ? confirmedAmount
                                                  : 0,
                                              confirmedCredit:
                                                  data?['credit'] is num
                                                  ? (data!['credit'] as num)
                                                        .toInt()
                                                  : null,
                                              confirmedSide: confirmedSide,
                                              totalBySide: _intMap(
                                                round['totals'],
                                              ),
                                              playerCountsBySide: _intMap(
                                                round['playerCounts'],
                                              ),
                                              dice: result is List
                                                  ? result
                                                  : null,
                                              outcome:
                                                  outcome
                                                      is Map<String, dynamic>
                                                  ? outcome
                                                  : null,
                                              enabled:
                                                  !busy &&
                                                  !offline &&
                                                  status == 'open' &&
                                                  secondsLeft > 0 &&
                                                  currentBet.hasData,
                                              onPlaceBet: (side, value) => call(
                                                'placeBet',
                                                {
                                                  'roundId': id,
                                                  'side': side,
                                                  'amount': value,
                                                  'requestId': FirebaseFirestore
                                                      .instance
                                                      .collection('requestIds')
                                                      .doc()
                                                      .id,
                                                },
                                                rethrowOnError: true,
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                              )
                            else if (widget.game.id == 'bau_cua')
                              StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>
                              >(
                                stream: FirebaseFirestore.instance
                                    .doc('users/${widget.uid}')
                                    .snapshots(),
                                builder: (context, userSnapshot) =>
                                    ValueListenableBuilder<DateTime>(
                                      valueListenable: now,
                                      builder: (context, time, _) {
                                        final closesAt = round['closesAt'];
                                        final secondsLeft =
                                            closesAt is Timestamp
                                            ? closesAt
                                                  .toDate()
                                                  .difference(time)
                                                  .inSeconds
                                            : 0;
                                        final balance = userSnapshot.data
                                            ?.data()?['balance'];
                                        return StreamBuilder<
                                          DocumentSnapshot<Map<String, dynamic>>
                                        >(
                                          stream: FirebaseFirestore.instance
                                              .doc(
                                                'rounds/$id/bets/${widget.uid}',
                                              )
                                              .snapshots(),
                                          builder: (context, currentBet) {
                                            final betData = currentBet.data
                                                ?.data();
                                            final rawStakes =
                                                betData?['stakes'];
                                            final confirmedBets =
                                                <String, int>{};
                                            if (rawStakes is Map) {
                                              for (final entry
                                                  in rawStakes.entries) {
                                                if (entry.value is num) {
                                                  confirmedBets['${entry.key}'] =
                                                      (entry.value as num)
                                                          .toInt();
                                                }
                                              }
                                            }
                                            return BauCuaBettingTable(
                                              key: ValueKey('bau_cua_$id'),
                                              roundId: id,
                                              status: status,
                                              secondsLeft: secondsLeft,
                                              balance: balance is int
                                                  ? balance
                                                  : 0,
                                              result: round['result'] is List
                                                  ? round['result'] as List
                                                  : null,
                                              confirmedCredit:
                                                  betData?['credit'] is num
                                                  ? (betData!['credit'] as num)
                                                        .toInt()
                                                  : null,
                                              confirmedBets: confirmedBets,
                                              enabled:
                                                  !busy &&
                                                  !offline &&
                                                  status == 'open' &&
                                                  secondsLeft > 0 &&
                                                  currentBet.hasData,
                                              onPlaceBet: (side, amount) async {
                                                await call('placeBet', {
                                                  'roundId': id,
                                                  'side': side,
                                                  'amount': amount,
                                                  'requestId': FirebaseFirestore
                                                      .instance
                                                      .collection('requestIds')
                                                      .doc()
                                                      .id,
                                                }, rethrowOnError: true);
                                              },
                                              onRefundBet: () => call(
                                                'refundMyBet',
                                                {
                                                  'roundId': id,
                                                  'requestId': FirebaseFirestore
                                                      .instance
                                                      .collection('requestIds')
                                                      .doc()
                                                      .id,
                                                },
                                                rethrowOnError: true,
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                              )
                            else if (widget.game.id == 'xoc_xoc')
                              StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>
                              >(
                                stream: FirebaseFirestore.instance
                                    .doc('users/${widget.uid}')
                                    .snapshots(),
                                builder: (context, userSnapshot) =>
                                    ValueListenableBuilder<DateTime>(
                                      valueListenable: now,
                                      builder: (context, time, _) {
                                        final closesAt = round['closesAt'];
                                        final secondsLeft =
                                            closesAt is Timestamp
                                            ? (closesAt
                                                          .toDate()
                                                          .difference(time)
                                                          .inMilliseconds /
                                                      1000)
                                                  .ceil()
                                            : 0;
                                        final balance = userSnapshot.data
                                            ?.data()?['balance'];
                                        return StreamBuilder<
                                          DocumentSnapshot<Map<String, dynamic>>
                                        >(
                                          stream: FirebaseFirestore.instance
                                              .doc(
                                                'rounds/$id/bets/${widget.uid}',
                                              )
                                              .snapshots(),
                                          builder: (context, currentBet) {
                                            final betData = currentBet.data
                                                ?.data();
                                            final rawStakes =
                                                betData?['stakes'];
                                            final confirmedBets =
                                                <String, int>{};
                                            if (rawStakes is Map) {
                                              for (final entry
                                                  in rawStakes.entries) {
                                                if (entry.value is num) {
                                                  confirmedBets['${entry.key}'] =
                                                      (entry.value as num)
                                                          .toInt();
                                                }
                                              }
                                            }
                                            return XocXocBettingTable(
                                              roundId: id,
                                              mode:
                                                  '${round['mode'] ?? 'random'}',
                                              status: status,
                                              secondsLeft: secondsLeft,
                                              balance: balance is int
                                                  ? balance
                                                  : 0,
                                              enabled:
                                                  !busy &&
                                                  !offline &&
                                                  status == 'open' &&
                                                  secondsLeft > 0 &&
                                                  currentBet.hasData,
                                              result: round['result'] is List
                                                  ? round['result'] as List
                                                  : null,
                                              confirmedCredit:
                                                  betData?['credit'] is num
                                                  ? (betData!['credit'] as num)
                                                        .toInt()
                                                  : null,
                                              confirmedBets: confirmedBets,
                                              onPlaceBet: (side, amount) async {
                                                await call('placeBet', {
                                                  'roundId': id,
                                                  'side': side,
                                                  'amount': amount,
                                                  'requestId': FirebaseFirestore
                                                      .instance
                                                      .collection('requestIds')
                                                      .doc()
                                                      .id,
                                                }, rethrowOnError: true);
                                              },
                                            );
                                          },
                                        );
                                      },
                                    ),
                              )
                            else ...[
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
                                                    'requestId':
                                                        FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                              'requestIds',
                                                            )
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
                            ],
                            if (widget.game.id == 'bau_cua' ||
                                widget.game.id == 'tai_xiu')
                              RoundHistory(game: widget.game),
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
                              if (!adminMode && status == 'locked')
                                OutlinedButton.icon(
                                  onPressed: busy || offline
                                      ? null
                                      : () => intervene(id),
                                  icon: const Icon(Icons.tune),
                                  label: const Text(
                                    'Chọn kết quả admin cho phiên đã khóa',
                                  ),
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
