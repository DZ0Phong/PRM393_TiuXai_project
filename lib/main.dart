import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart' hide Text;

import 'core/backend_functions.dart';
import 'core/pending_mutation.dart';
import 'core/app_preferences.dart';
import 'core/app_text.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/admin/admin_console.dart';
import 'features/admin/round_outcome_picker.dart';
import 'features/lobby/lobby_screen.dart';
import 'features/onboarding/presentation/screens/authenticated_entry_screen.dart';
import 'features/game/game_specs.dart';
import 'features/game/round_bets.dart';
import 'features/game/round_history.dart';
import 'features/game/presentation/widgets/tai_xiu_betting_table.dart';
import 'features/game/presentation/widgets/bau_cua_betting_table.dart';
import 'features/game/presentation/widgets/xoc_xoc/xoc_xoc_betting_table.dart';

// Debug stays on local emulators; live Firebase requires explicit opt-in.
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
              defaultValue: emulator ? 'demo-tai-xiu' : 'ad2-8abfa540',
            ) ==
            'demo-tai-xiu') {
      throw StateError('Chưa cấu hình Firebase project thật cho bản release.');
    }
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: String.fromEnvironment(
          'FIREBASE_API_KEY',
          defaultValue: emulator
              ? 'AIzaSyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
              : 'AIzaSyBJsBK1UBIpYdzH-UgfTbNS9b_Ygqr6FV8',
        ),
        appId: String.fromEnvironment(
          'FIREBASE_APP_ID',
          defaultValue: emulator
              ? '1:123456789:web:demo'
              : '1:429747586374:android:0456200127afbe16b1d147',
        ),
        messagingSenderId: String.fromEnvironment(
          'FIREBASE_SENDER_ID',
          defaultValue: emulator ? '123456789' : '429747586374',
        ),
        projectId: String.fromEnvironment(
          'FIREBASE_PROJECT_ID',
          defaultValue: emulator ? 'demo-tai-xiu' : 'ad2-8abfa540',
        ),
        authDomain: String.fromEnvironment(
          'FIREBASE_AUTH_DOMAIN',
          defaultValue: emulator
              ? 'demo-tai-xiu.firebaseapp.com'
              : 'ad2-8abfa540.firebaseapp.com',
        ),
      ),
    );
    final backendError = backendConfigurationError(emulator, backendUrl);
    if (backendError != null) throw StateError(backendError);
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
            ? const SignInScreen(showDemoAdmin: emulator)
            : AuthenticatedEntryScreen(
                key: ValueKey(user.uid),
                user: user,
                adminBuilder: (_) => AdminConsole(
                  uid: user.uid,
                  initiallyExpanded: true,
                  invoke: (name, data) async {
                    await functions.gameCallable(name).call(data);
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
  final reason = TextEditingController(
    text: 'Điều hành phiên mô phỏng trong lớp',
  );
  final now = ValueNotifier(DateTime.now());
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _roomStream =
      FirebaseFirestore.instance
          .doc('rooms/${widget.game.id}')
          .snapshots(includeMetadataChanges: true);
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream =
      FirebaseFirestore.instance.doc('users/${widget.uid}').snapshots();
  String? _observedRoundId;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _betStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _planStream;

  void _observeRound(String id) {
    if (_observedRoundId == id) return;
    _observedRoundId = id;
    _betStream = FirebaseFirestore.instance
        .doc('rounds/$id/bets/${widget.uid}')
        .snapshots();
    _planStream = FirebaseFirestore.instance.doc('roundPlans/$id').snapshots();
  }

  Timer? timer;
  int gameNavIndex = 1;
  bool busy = false;
  String? message;
  final Set<String> _advancingRounds = {};
  final Set<String> _advancedRounds = {};
  final Map<String, DateTime> _lastAdvanceAttempt = {};
  final _mutationStore = PendingMutationStore();
  Map<String, dynamic>? _pendingMutation;
  bool _pendingLoaded = false;
  String get _mutationKey => '${widget.uid}_${widget.game.id}';
  bool _touchingRoom = false;
  DateTime? _lastRoomTouch;
  @override
  void initState() {
    super.initState();
    _touchRoom();
    _loadPendingMutation();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      now.value = DateTime.now();
      if (_lastRoomTouch == null ||
          now.value.difference(_lastRoomTouch!).inSeconds >= 60) {
        _touchRoom();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    unawaited(_leaveRoom());
    now.dispose();
    amount.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> _leaveRoom() async {
    try {
      await FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).gameCallable('leaveGameRoom').call({'game': widget.game.id});
    } catch (_) {
      /* Presence expires after 150 seconds. */
    }
  }

  Future<void> _touchRoom() async {
    if (_touchingRoom) return;
    _touchingRoom = true;
    _lastRoomTouch = DateTime.now();
    try {
      await FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).gameCallable('touchGameRoom').call({'game': widget.game.id});
    } catch (_) {
      // Presence is best effort; it must not block betting.
    } finally {
      _touchingRoom = false;
    }
  }

  Future<void> _loadPendingMutation() async {
    try {
      final pending = await _mutationStore.load(_mutationKey);
      if (mounted) setState(() => _pendingMutation = pending);
    } catch (error) {
      if (mounted) {
        setState(() => message = 'Không đọc được cược đang chờ: $error');
      }
    } finally {
      if (mounted) setState(() => _pendingLoaded = true);
    }
  }

  Future<void> _beginRoundMutation(
    String name,
    Map<String, dynamic> data,
  ) async {
    if (!_pendingLoaded || _pendingMutation != null) {
      throw StateError('Có cược chưa xác nhận; hãy thử lại yêu cầu cũ trước.');
    }
    final operation = <String, dynamic>{
      'name': name,
      'data': {
        ...data,
        'requestId': FirebaseFirestore.instance
            .collection('requestIds')
            .doc()
            .id,
      },
    };
    try {
      await _mutationStore.save(_mutationKey, operation);
      if (mounted) setState(() => _pendingMutation = operation);
      await _sendPendingMutation();
    } catch (error) {
      if (mounted) setState(() => message = 'Chưa xác nhận thao tác: $error');
      rethrow;
    }
  }

  Future<void> _sendPendingMutation() async {
    final operation = _pendingMutation;
    if (operation == null) return;
    try {
      await call(
        operation['name'] as String,
        Map<String, dynamic>.from(operation['data'] as Map),
        rethrowOnError: true,
      );
      await _mutationStore.clear(_mutationKey);
      if (mounted) setState(() => _pendingMutation = null);
    } on FirebaseFunctionsException catch (error) {
      // A definitive rejection did not charge points; uncertain network results keep the same requestId.
      if (const {
        'invalid-argument',
        'failed-precondition',
        'permission-denied',
        'unauthenticated',
        'already-exists',
        'not-found',
      }.contains(error.code)) {
        await _mutationStore.clear(_mutationKey);
        if (mounted) setState(() => _pendingMutation = null);
      }
      rethrow;
    }
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
      await functions.gameCallable(name).call(data);
      if (name == 'cancelRound') {
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
    await Future<void>.delayed(const Duration(seconds: 7));
    if (!mounted) return;
    try {
      await functions.gameCallable('ensureGameRounds').call({
        'game': widget.game.id,
      });
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
      final response = await functions.gameCallable('advanceRandomRound').call({
        'roundId': roundId,
      });
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

  void settle(String id, List<dynamic> selected) {
    if (reason.text.trim().length < 5 || reason.text.length > 300) {
      setState(() => message = 'Nhập lý do từ 5 đến 300 ký tự.');
      return;
    }
    call('setRoundOutcome', {
      'roundId': id,
      'result': selected,
      'reason': reason.text.trim(),
    });
  }

  DateTime? _roundDeadline(Map<String, dynamic> round) {
    final closesAt = round['closesAt'];
    if (closesAt is Timestamp) return closesAt.toDate();
    final createdAt = round['createdAt'];
    if (createdAt is Timestamp) {
      return createdAt.toDate().add(const Duration(seconds: 30));
    }
    return null;
  }

  String _countdownText(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    return '${(safe ~/ 60).toString().padLeft(2, '0')}:${(safe % 60).toString().padLeft(2, '0')}';
  }

  Widget _adminRoundControls({
    required String roundId,
    required Map<String, dynamic> round,
    required String status,
    required bool offline,
  }) => Card(
    color: const Color(0xff191c22),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Color(0xffffc174)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ĐIỀU HÀNH PHIÊN • ADMIN',
                  style: TextStyle(
                    color: Color(0xffffc174),
                    fontWeight: FontWeight.bold,
                    letterSpacing: .6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'Có thể chọn kết quả một lần trước khi hết giờ cược; nếu không, server sinh ngẫu nhiên.',
            style: TextStyle(
              color: Color(0xffd8c3ad),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (status == 'open' || status == 'locked') ...[
            const SizedBox(height: 10),
            ValueListenableBuilder<DateTime>(
              valueListenable: now,
              builder: (context, time, _) {
                final deadline = _roundDeadline(round);
                final secondsLeft = deadline?.difference(time).inSeconds;
                final value = secondsLeft == null
                    ? '--:--'
                    : _countdownText(secondsLeft);
                final open = status == 'open';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff0b0e14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          (open
                                  ? const Color(0xffffb3ad)
                                  : const Color(0xff56e5a9))
                              .withValues(alpha: .3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        open ? Icons.hourglass_top : Icons.lock_clock,
                        color: open
                            ? const Color(0xffffb3ad)
                            : const Color(0xff56e5a9),
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          open ? 'ĐẾM NGƯỢC ĐẶT CƯỢC' : 'PHIÊN ĐÃ KHÓA',
                          style: const TextStyle(
                            color: Color(0xffd8c3ad),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                      Text(
                        value,
                        style: TextStyle(
                          color: open
                              ? const Color(0xffffb3ad)
                              : const Color(0xff56e5a9),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          if (status == 'settled') ...[
            const SizedBox(height: 10),
            const Text(
              'Phiên đã chốt. Backend không cho sửa lại kết quả hoặc thanh toán đã hoàn tất.',
              style: TextStyle(color: Color(0xffa5a6ae), fontSize: 12),
            ),
          ],
          if (status == 'open' || status == 'locked') ...[
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              maxLength: 300,
              style: const TextStyle(color: Color(0xffe1e2eb)),
              decoration: const InputDecoration(
                labelText: 'Lý do thao tác (5–300 ký tự)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _planStream,
            builder: (context, plan) {
              if (plan.hasError) {
                return Text('Không tải được lựa chọn: ${plan.error}');
              }
              if (!plan.hasData) return const LinearProgressIndicator();
              if (plan.data!.exists) {
                return const Text(
                  'Kết quả đã chọn, không thể sửa; server chốt sau hạn cược.',
                );
              }
              if (status != 'open') return const SizedBox.shrink();
              return ValueListenableBuilder<DateTime>(
                valueListenable: now,
                builder: (context, time, _) => RoundOutcomePicker(
                  game: widget.game,
                  round: round,
                  enabled:
                      !busy &&
                      !offline &&
                      (_roundDeadline(round)?.isAfter(time) ?? false),
                  onSelected: (choice) => settle(roundId, choice.result),
                ),
              );
            },
          ),
          if (status == 'open' || status == 'locked')
            TextButton.icon(
              onPressed: busy || offline
                  ? null
                  : () {
                      if (reason.text.trim().length < 5 ||
                          reason.text.length > 300) {
                        setState(
                          () => message = 'Nhập lý do từ 5 đến 300 ký tự.',
                        );
                      } else {
                        call('cancelRound', {
                          'roundId': roundId,
                          'reason': reason.text.trim(),
                        });
                      }
                    },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Hủy phiên và hoàn cược'),
            ),
          if (status == 'open' || status == 'locked')
            ValueListenableBuilder<DateTime>(
              valueListenable: now,
              builder: (context, time, _) =>
                  RoundBets(roundId: roundId, game: widget.game, now: time),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor:
        widget.game.id == 'tai_xiu' ||
            widget.game.id == 'bau_cua' ||
            widget.game.id == 'xoc_xoc'
        ? const Color(0xff10131a)
        : null,
    appBar:
        !widget.isAdmin &&
            (widget.game.id == 'tai_xiu' || widget.game.id == 'xoc_xoc')
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
              widget.isAdmin
                  ? 'ADMIN • ${widget.game.title}'
                  : widget.game.id == 'tai_xiu'
                  ? 'TÀI XỈU • XU ẢO'
                  : widget.game.title,
            ),
            actions:
                !widget.isAdmin &&
                    (widget.game.id == 'tai_xiu' ||
                        widget.game.id == 'bau_cua' ||
                        widget.game.id == 'xoc_xoc')
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
        !widget.isAdmin &&
            (widget.game.id == 'tai_xiu' || widget.game.id == 'xoc_xoc')
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
            if (!widget.isAdmin && _pendingMutation != null)
              ListTile(
                title: const Text('Cược/hoàn cược chưa xác nhận'),
                subtitle: const Text(
                  'Mạng có thể đã ngắt sau khi server ghi. Thử lại cùng requestId để không trừ điểm hai lần.',
                ),
                trailing: TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          try {
                            await _sendPendingMutation();
                          } catch (_) {
                            /* Message shown by call. */
                          }
                        },
                  child: const Text('Thử lại'),
                ),
              ),
            if (widget.isAdmin)
              const Card(
                color: Color(0xff191c22),
                child: ListTile(
                  leading: Icon(Icons.autorenew, color: Color(0xffffc174)),
                  title: Text('Phiên tự chạy'),
                  subtitle: Text(
                    'Phiên mở khi có người trong phòng, tự chốt theo kết quả đã chọn hoặc ngẫu nhiên và chuyển sang phiên kế tiếp.',
                  ),
                ),
              ),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _roomStream,
              builder: (context, room) {
                if (room.hasError) {
                  return Text('Không tải được phòng: ${room.error}');
                }
                if (!room.hasData) return const LinearProgressIndicator();
                final id = room.data!.data()?['roundId'] as String?;
                if (id != null) _observeRound(id);
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
                                'Phiên do máy chủ xử lý',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                            ValueListenableBuilder<DateTime>(
                              valueListenable: now,
                              builder: (context, time, _) {
                                final deadline = _roundDeadline(round);
                                final seconds = deadline == null
                                    ? null
                                    : (deadline
                                                  .difference(time)
                                                  .inMilliseconds /
                                              1000)
                                          .ceil();
                                final playerCanAdvance =
                                    status == 'open' || status == 'locked';
                                if (!widget.isAdmin &&
                                    playerCanAdvance &&
                                    deadline != null &&
                                    !deadline.isAfter(time)) {
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
                            if ((widget.game.id != 'xoc_xoc' ||
                                    widget.isAdmin) &&
                                round['result'] != null)
                              Text(
                                'Kết quả: ${(round['result'] as List).join(', ')}',
                              ),
                            if ((widget.game.id != 'xoc_xoc' ||
                                    widget.isAdmin) &&
                                round['outcome'] is Map)
                              Text(
                                'Diễn giải: ${formatOutcome(widget.game, round['outcome'] as Map)}',
                              ),
                            if (status == 'cancelled')
                              const Text(
                                'Phiên đã hủy; cược được hoàn theo máy chủ.',
                              ),
                            if (widget.isAdmin)
                              _adminRoundControls(
                                roundId: id,
                                round: round,
                                status: status,
                                offline: offline,
                              ),
                            if (!widget.isAdmin && widget.game.id == 'tai_xiu')
                              StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>
                              >(
                                stream: _userStream,
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
                                          stream: _betStream,
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
                                                  currentBet.hasData &&
                                                  _pendingLoaded &&
                                                  _pendingMutation == null,
                                              onPlaceBet: (side, value) =>
                                                  _beginRoundMutation(
                                                    'placeBet',
                                                    {
                                                      'roundId': id,
                                                      'side': side,
                                                      'amount': value,
                                                    },
                                                  ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                              )
                            else if (!widget.isAdmin &&
                                widget.game.id == 'bau_cua')
                              StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>
                              >(
                                stream: _userStream,
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
                                          stream: _betStream,
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
                                                  currentBet.hasData &&
                                                  _pendingLoaded &&
                                                  _pendingMutation == null,
                                              onPlaceBet: (side, amount) async {
                                                await _beginRoundMutation(
                                                  'placeBet',
                                                  {
                                                    'roundId': id,
                                                    'side': side,
                                                    'amount': amount,
                                                  },
                                                );
                                              },
                                              onRefundBet: () =>
                                                  _beginRoundMutation(
                                                    'refundMyBet',
                                                    {'roundId': id},
                                                  ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                              )
                            else if (!widget.isAdmin &&
                                widget.game.id == 'xoc_xoc')
                              StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>
                              >(
                                stream: _userStream,
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
                                          stream: _betStream,
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
                                                  currentBet.hasData &&
                                                  _pendingLoaded &&
                                                  _pendingMutation == null,
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
                                                await _beginRoundMutation(
                                                  'placeBet',
                                                  {
                                                    'roundId': id,
                                                    'side': side,
                                                    'amount': amount,
                                                  },
                                                );
                                              },
                                            );
                                          },
                                        );
                                      },
                                    ),
                              )
                            else if (!widget.isAdmin) ...[
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
                                                  _beginRoundMutation(
                                                    'placeBet',
                                                    {
                                                      'roundId': id,
                                                      'side': side.$1,
                                                      'amount': value,
                                                    },
                                                  ).catchError((_) {});
                                                },
                                          child: Text('Cược ${side.$2}'),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ],
                            if (!widget.isAdmin &&
                                (widget.game.id == 'bau_cua' ||
                                    widget.game.id == 'tai_xiu'))
                              RoundHistory(game: widget.game),
                            if (!widget.isAdmin)
                              StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>
                              >(
                                key: ValueKey('bet_$id'),
                                stream: _betStream,
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
