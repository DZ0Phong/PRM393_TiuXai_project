import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'features/admin/admin_console.dart';
import 'features/game/round_bets.dart';
import 'core/pending_mutation.dart';

const emulator = bool.fromEnvironment('EMULATORS', defaultValue: true);
const host = String.fromEnvironment('EMULATOR_HOST', defaultValue: '127.0.0.1');
final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: String.fromEnvironment(
          'FIREBASE_API_KEY',
          defaultValue: 'demo-key',
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
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(body: Center(child: Text('Lỗi Firebase: $e'))),
      ),
    );
  }
}

class GameApp extends StatelessWidget {
  const GameApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Tài Xỉu • Xu giả lập',
    theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
    home: const Lobby(),
  );
}

class Lobby extends StatefulWidget {
  const Lobby({super.key});
  @override
  State<Lobby> createState() => _LobbyState();
}

class _LobbyState extends State<Lobby> {
  final email = TextEditingController(),
      password = TextEditingController(),
      amount = TextEditingController(text: '100'),
      dice = TextEditingController(text: '2,3,6'),
      reason = TextEditingController();
  bool busy = false, isAdmin = false;
  String mode = 'random', message = '';
  Timer? timer;
  final clock = ValueNotifier(DateTime.now());
  final pendingStore = PendingMutationStore();
  Map<String, dynamic>? pending;
  String? pendingLoadedUid;
  int authRevision = 0;
  StreamSubscription<User?>? auth;
  String get uid => FirebaseAuth.instance.currentUser!.uid;
  @override
  void initState() {
    super.initState();
    auth = FirebaseAuth.instance.authStateChanges().listen((user) async {
      final revision = ++authRevision;
      if (mounted) {
        setState(() {
          pendingLoadedUid = null;
          pending = null;
          isAdmin = false;
        });
      }
      if (user != null) {
        try {
          final token = await user.getIdTokenResult(true);
          await invoke('ensureProfile');
          final saved = await pendingStore.load(user.uid);
          if (mounted &&
              revision == authRevision &&
              FirebaseAuth.instance.currentUser?.uid == user.uid) {
            setState(() {
              isAdmin = token.claims?['admin'] == true;
              pending = saved;
              pendingLoadedUid = user.uid;
            });
          }
        } catch (e) {
          if (mounted && revision == authRevision) {
            setState(() => message = e.toString());
          }
        }
      }
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      clock.value = DateTime.now();
    });
  }

  @override
  void dispose() {
    auth?.cancel();
    timer?.cancel();
    clock.dispose();
    for (final c in [email, password, amount, dice, reason]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> perform(Future<void> Function() fn) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = '';
    });
    try {
      await fn();
      if (mounted) setState(() => message = 'Thao tác hoàn tất.');
    } catch (e) {
      if (mounted) {
        setState(
          () => message = e is FirebaseFunctionsException
              ? (e.message ?? 'Không thực hiện được thao tác')
              : e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> invoke(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (name == 'wallet' || name == 'adjustBalance') {
      if (pendingLoadedUid != uid) {
        throw StateError('Đang tải thao tác ví chờ xác nhận; vui lòng đợi');
      }
      if (pending != null) {
        throw StateError(
          'Có thao tác ví chưa được xác nhận. Dùng nút Thử lại thao tác chờ.',
        );
      }
      final value = <String, dynamic>{'name': name, 'data': data};
      await pendingStore.save(uid, value);
      if (mounted) setState(() => pending = value);
      return deliverPending();
    }
    await functions.httpsCallable(name).call(data);
  }

  Future<void> deliverPending() async {
    final operation = pending;
    if (operation == null) return;
    final owner = uid;
    try {
      await functions
          .httpsCallable(operation['name'] as String)
          .call(operation['data']);
      await pendingStore.clear(owner);
      if (mounted && FirebaseAuth.instance.currentUser?.uid == owner) {
        setState(() => pending = null);
      }
    } on FirebaseFunctionsException catch (e) {
      if ([
        'invalid-argument',
        'failed-precondition',
        'permission-denied',
        'unauthenticated',
        'already-exists',
        'not-found',
      ].contains(e.code)) {
        await pendingStore.clear(owner);
        if (mounted && FirebaseAuth.instance.currentUser?.uid == owner) {
          setState(() => pending = null);
        }
      }
      rethrow;
    }
  }

  Widget action(
    String text,
    Future<void> Function() fn, {
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.all(4),
    child: FilledButton(
      onPressed: busy || !enabled ? null : () => perform(fn),
      child: Text(text),
    ),
  );
  Widget field(TextEditingController c, String label, {bool secret = false}) =>
      TextField(
        controller: c,
        obscureText: secret,
        decoration: InputDecoration(labelText: label),
      );
  Widget feed(
    String collection,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection(collection)
        .orderBy(collection == 'rounds' ? 'createdAt' : 'at', descending: true)
        .limit(20)
        .snapshots(),
    builder: (context, s) {
      if (s.hasError) return Text('Lỗi: ${s.error}');
      return Column(
        children:
            s.data?.docs
                .map(
                  (d) => ListTile(
                    title: Text(
                      collection == 'rounds'
                          ? '${d.id} • ${d.data()['mode']} • ${d.data()['status']}'
                          : '${d.data()['action']} • ${d.data()['actor']}',
                    ),
                    subtitle: Text(
                      collection == 'rounds'
                          ? '${d.data()['dice'] ?? "Chưa chốt"} • ${d.data()['reason'] ?? ""}'
                          : '${d.data()['details']}',
                    ),
                  ),
                )
                .toList() ??
            [const Text('Đang tải…')],
      );
    },
  );
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Tài Xỉu • Xu giả lập')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'CHỈ XU GIẢ LẬP • Không thanh toán, không đổi tiền.\n3 xúc xắc: Xỉu 4–10, Tài 11–17. Bộ ba thua cả hai. Thắng nhận 2× cược gồm vốn. Một cược/người/phiên, 10–1000 xu.\nPhiên ADMIN công bố trước: admin chọn xúc xắc sau khóa cược, bắt buộc ghi lý do. RANDOM ngẫu nhiên tại server.',
                  ),
                ),
              ),
              if (emulator) const Text('Firebase Emulator'),
              if (busy) const LinearProgressIndicator(),
              if (message.isNotEmpty) Text(message),
              if (user == null) ...[
                field(email, 'Email'),
                field(password, 'Mật khẩu ít nhất 6 ký tự', secret: true),
                Wrap(
                  children: [
                    action('Đăng nhập', () async {
                      await FirebaseAuth.instance.signInWithEmailAndPassword(
                        email: email.text.trim(),
                        password: password.text,
                      );
                    }),
                    action('Đăng ký', () async {
                      await FirebaseAuth.instance
                          .createUserWithEmailAndPassword(
                            email: email.text.trim(),
                            password: password.text,
                          );
                    }),
                  ],
                ),
              ] else ...[
                Text(
                  '${user.email} • ${isAdmin ? "Admin" : "Player"} • UID: ${user.uid}',
                ),
                action('Đăng xuất', () async {
                  await FirebaseAuth.instance.signOut();
                }),
                if (pending != null) ...[
                  Text(
                    'Thao tác chờ xác nhận: ${pending!['name']} • ${pending!['data']}',
                  ),
                  action(
                    'Thử lại thao tác chờ (giữ nguyên requestId)',
                    deliverPending,
                  ),
                ],
                StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .doc('users/$uid')
                      .snapshots(),
                  builder: (context, s) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (s.hasError) Text('Không tải được ví: ${s.error}'),
                      Text('Số dư: ${s.data?.data()?['balance'] ?? "…"} xu'),
                      if (s.data?.data()?['blocked'] == true)
                        Text(
                          'Đã khóa truy cập game: ${s.data?.data()?['blockReason'] ?? "Liên hệ admin"}',
                        ),
                    ],
                  ),
                ),
                field(amount, 'Số xu cược / nạp / rút (10–1000)'),
                Wrap(
                  children: ['deposit', 'withdraw']
                      .map(
                        (kind) => action(
                          kind == 'deposit'
                              ? 'Nạp xu giả lập'
                              : 'Rút xu giả lập',
                          () => invoke('wallet', {
                            'kind': kind,
                            'amount': int.tryParse(amount.text),
                            'requestId':
                                '${uid}_${DateTime.now().microsecondsSinceEpoch}',
                          }),
                          enabled:
                              pendingLoadedUid == user.uid && pending == null,
                        ),
                      )
                      .toList(),
                ),
                if (isAdmin) ...[
                  AdminConsole(
                    busy: busy,
                    execute: (name, data) => perform(() => invoke(name, data)),
                  ),
                  DropdownButton<String>(
                    value: mode,
                    items: const [
                      DropdownMenuItem(
                        value: 'random',
                        child: Text('RANDOM — server ngẫu nhiên'),
                      ),
                      DropdownMenuItem(
                        value: 'admin',
                        child: Text('ADMIN — công khai can thiệp'),
                      ),
                    ],
                    onChanged: busy ? null : (v) => setState(() => mode = v!),
                  ),
                  action(
                    'Mở phiên 30 giây',
                    () => invoke('startRound', {'mode': mode}),
                  ),
                  field(dice, 'Xúc xắc ADMIN, ví dụ 2,3,6'),
                  field(reason, 'Lý do can thiệp công khai'),
                ],
                StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .doc('rooms/main')
                      .snapshots(),
                  builder: (context, s) {
                    if (s.hasError) {
                      return Text('Không truy cập được phòng: ${s.error}');
                    }
                    final id = s.data?.data()?['roundId'] as String?;
                    if (id == null) return const Text('Chờ Admin mở phiên');
                    return StreamBuilder(
                      stream: FirebaseFirestore.instance
                          .doc('rounds/$id')
                          .snapshots(),
                      builder: (context, s) {
                        if (s.hasError) {
                          return Text('Không tải được phiên: ${s.error}');
                        }
                        final r = s.data?.data();
                        if (r == null) return const Text('Đang tải…');
                        return ValueListenableBuilder<DateTime>(
                          valueListenable: clock,
                          builder: (context, now, child) {
                            final seconds =
                                ((r['closesAt'] as Timestamp)
                                            .toDate()
                                            .difference(now)
                                            .inMilliseconds /
                                        1000)
                                    .ceil();
                            final open = r['status'] == 'open' && seconds > 0;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Phiên $id • ${r['mode'] == 'admin' ? 'ADMIN: CÓ CAN THIỆP' : 'RANDOM'}',
                                    ),
                                    Text(
                                      '${r['status']} • ${seconds > 0 ? seconds : 0}s • ${r['betCount']}/100 người',
                                    ),
                                    if (r['dice'] != null)
                                      Text(
                                        '${r['dice']} • ${r['outcome']} • ${r['reason']}',
                                      ),
                                    if (r['status'] == 'cancelled')
                                      Text(
                                        'PHIÊN ĐÃ HỦY • Hoàn toàn bộ cược • ${r['reason']}',
                                      ),
                                    Wrap(
                                      children: ['tai', 'xiu']
                                          .map(
                                            (side) => action(
                                              side == 'tai'
                                                  ? 'Cược Tài'
                                                  : 'Cược Xỉu',
                                              () => invoke('placeBet', {
                                                'roundId': id,
                                                'side': side,
                                                'amount': int.tryParse(
                                                  amount.text,
                                                ),
                                              }),
                                              enabled: open,
                                            ),
                                          )
                                          .toList(),
                                    ),
                                    StreamBuilder(
                                      stream: FirebaseFirestore.instance
                                          .doc('rounds/$id/bets/$uid')
                                          .snapshots(),
                                      builder: (context, b) => Text(
                                        'Cược của bạn: ${b.data?.data() ?? "Chưa cược"}',
                                      ),
                                    ),
                                    if (isAdmin)
                                      action(
                                        'Chốt kết quả',
                                        () => invoke('settleRound', {
                                          'roundId': id,
                                          'dice': dice.text
                                              .split(',')
                                              .map(
                                                (x) => int.tryParse(x.trim()),
                                              )
                                              .toList(),
                                          'reason': reason.text.trim(),
                                        }),
                                        enabled: !open && r['status'] == 'open',
                                      ),
                                    if (isAdmin) ...[
                                      action(
                                        'Hủy phiên & hoàn xu',
                                        () => invoke('cancelRound', {
                                          'roundId': id,
                                          'reason': reason.text.trim(),
                                        }),
                                        enabled: r['status'] == 'open',
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
                    );
                  },
                ),
                const Divider(),
                const Text('Lịch sử ví — 30 giao dịch gần nhất'),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users/$uid/operations')
                      .orderBy('at', descending: true)
                      .limit(30)
                      .snapshots(),
                  builder: (context, s) {
                    if (s.hasError) return Text('Lỗi lịch sử ví: ${s.error}');
                    return Column(
                      children:
                          s.data?.docs
                              .map(
                                (d) => ListTile(
                                  title: Text(
                                    '${d.data()['kind']} • ${d.data()['delta'] ?? d.data()['amount']} xu',
                                  ),
                                  subtitle: Text(
                                    'Số dư sau: ${d.data()['balance']} • ${d.data()['reason'] ?? d.data()['roundId'] ?? ""}',
                                  ),
                                ),
                              )
                              .toList() ??
                          [],
                    );
                  },
                ),
                const Divider(),
                const Text('Lịch sử 20 phiên gần nhất'),
                feed('rounds'),
                const Divider(),
                const Text('Audit công khai — 20 thao tác gần nhất'),
                feed('auditLogs'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
