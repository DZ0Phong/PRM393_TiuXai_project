import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/pending_mutation.dart';
import '../cards/presentation/screens/card_table_screen.dart';
import '../game/game_specs.dart';

bool definitiveAdjustError(String code) => const {
  'invalid-argument',
  'failed-precondition',
  'permission-denied',
  'unauthenticated',
  'already-exists',
  'not-found',
}.contains(code);

class AdminConsole extends StatefulWidget {
  final String uid;
  final Future<void> Function(String, Map<String, dynamic>) invoke;
  final Widget Function(GameSpec) roundBuilder;
  final bool initiallyExpanded;
  const AdminConsole({
    super.key,
    required this.uid,
    required this.invoke,
    required this.roundBuilder,
    this.initiallyExpanded = false,
  });

  @override
  State<AdminConsole> createState() => _AdminConsoleState();
}

class _AdminConsoleState extends State<AdminConsole> {
  final target = TextEditingController();
  final delta = TextEditingController();
  final reason = TextEditingController();
  final store = PendingMutationStore();
  late final Future<void> profileReady = _ensureProfileAndRounds();
  Map<String, dynamic>? pending;
  bool loaded = false, busy = false;
  String? message;

  Future<void> _ensureProfileAndRounds() async {
    await widget.invoke('ensureProfile', {});
    await widget.invoke('ensureGameRounds', {});
  }

  @override
  void initState() {
    super.initState();
    loadPending();
  }

  @override
  void dispose() {
    target.dispose();
    delta.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> loadPending() async {
    setState(() {
      loaded = false;
      message = null;
    });
    try {
      final saved = await store.load(widget.uid);
      if (mounted) {
        setState(() {
          pending = saved;
          loaded = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => message = 'Không đọc được thao tác chờ: $error');
      }
    }
  }

  Future<void> adjust() async {
    if (busy || !loaded || pending != null) return;
    final value = int.tryParse(delta.text.trim());
    if (target.text.trim().isEmpty ||
        value == null ||
        value == 0 ||
        value.abs() > 100000 ||
        reason.text.trim().length < 5 ||
        reason.text.length > 300) {
      setState(
        () => message = 'Nhập UID, điều chỉnh ±1–100000 và lý do 5–300 ký tự.',
      );
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    final operation = <String, dynamic>{
      'name': 'adjustBalance',
      'data': {
        'uid': target.text.trim(),
        'delta': value,
        'reason': reason.text.trim(),
        'requestId':
            'adjust_${widget.uid}_${DateTime.now().microsecondsSinceEpoch}',
      },
    };
    try {
      await store.save(widget.uid, operation);
      pending = operation;
      if (mounted) setState(() {});
      await sendPending();
    } catch (error) {
      // A failed write may still leave an older intent; reload before allowing a new one.
      try {
        final saved = await store.load(widget.uid);
        if (mounted) setState(() => pending = saved);
      } catch (_) {
        if (mounted) setState(() => loaded = false);
      }
      if (mounted) {
        setState(() => message = 'Không thể lưu/gửi điều chỉnh: $error');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> retry() async {
    if (busy || pending == null || pending!['name'] != 'adjustBalance') return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await sendPending();
    } catch (error) {
      if (mounted) {
        setState(() => message = 'Không thể xác nhận điều chỉnh: $error');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> setBlocked(bool blocked) async {
    if (busy || !loaded || pending != null) return;
    if (target.text.trim().isEmpty ||
        reason.text.trim().length < 5 ||
        reason.text.length > 300) {
      setState(() => message = 'Nhập UID và lý do 5–300 ký tự.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await widget.invoke('setPlayerBlocked', {
        'uid': target.text.trim(),
        'blocked': blocked,
        'reason': reason.text.trim(),
      });
      if (mounted) {
        setState(
          () => message = blocked
              ? 'Đã khóa truy cập game.'
              : 'Đã mở khóa truy cập game.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => message = 'Không thể thay đổi trạng thái: $error');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> sendPending() async {
    final operation = pending!;
    try {
      await widget.invoke(
        'adjustBalance',
        Map<String, dynamic>.from(operation['data'] as Map),
      );
      await store.clear(widget.uid);
      if (mounted) {
        setState(() {
          pending = null;
          message = 'Điều chỉnh đã xác nhận.';
        });
      }
    } on FirebaseFunctionsException catch (error) {
      if (definitiveAdjustError(error.code)) {
        await store.clear(widget.uid);
        if (mounted) setState(() => pending = null);
      }
      rethrow;
    }
  }

  Widget _accountManagementPanel() => ExpansionTile(
    initiallyExpanded: widget.initiallyExpanded,
    leading: const Icon(Icons.admin_panel_settings_outlined),
    title: const Text('Quản trị'),
    subtitle: const Text('Điều chỉnh xu ảo và nhật ký chỉ dành cho Admin'),
    children: [
      if (!loaded) ...[
        if (message == null) const LinearProgressIndicator(),
        if (message != null) ListTile(title: Text(message!)),
        TextButton(
          onPressed: busy ? null : loadPending,
          child: const Text('Tải lại thao tác chờ'),
        ),
      ] else ...[
        if (pending != null) ...[
          ListTile(
            title: const Text(
              'Thao tác chưa xác nhận — không tạo điều chỉnh mới',
            ),
            subtitle: Text('${pending!['name']} • ${pending!['data']}'),
          ),
          if (pending!['name'] == 'adjustBalance')
            FilledButton.tonal(
              onPressed: busy ? null : retry,
              child: const Text('Thử lại cùng requestId'),
            ),
        ],
        if (message != null) ListTile(title: Text(message!)),
        TextField(
          controller: target,
          enabled: !busy && pending == null,
          decoration: const InputDecoration(labelText: 'UID người chơi'),
        ),
        TextField(
          controller: delta,
          enabled: !busy && pending == null,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: const InputDecoration(
            labelText: 'Thay đổi xu (±1–100000)',
          ),
        ),
        TextField(
          controller: reason,
          enabled: !busy && pending == null,
          maxLength: 300,
          decoration: const InputDecoration(labelText: 'Lý do (5–300 ký tự)'),
        ),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: busy || pending != null ? null : adjust,
              child: const Text('Điều chỉnh xu ảo'),
            ),
            OutlinedButton(
              onPressed: busy || pending != null
                  ? null
                  : () => setBlocked(true),
              child: const Text('Khóa truy cập game'),
            ),
            OutlinedButton(
              onPressed: busy || pending != null
                  ? null
                  : () => setBlocked(false),
              child: const Text('Mở khóa'),
            ),
          ],
        ),
      ],
      const Divider(),
      const ListTile(title: Text('50 tài khoản mới nhất • chạm để chọn UID')),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ListTile(
              title: Text('Không tải được tài khoản: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) return const LinearProgressIndicator();
          if (snapshot.data!.docs.isEmpty) {
            return const ListTile(title: Text('Chưa có tài khoản.'));
          }
          return Column(
            children: snapshot.data!.docs
                .map(
                  (doc) => ListTile(
                    title: Text(doc.id),
                    subtitle: Text(
                      '${doc.data()['balance'] ?? '—'} xu • ${doc.data()['blocked'] == true ? 'ĐÃ KHÓA' : 'Hoạt động'}',
                    ),
                    onTap: busy || pending != null
                        ? null
                        : () => setState(() => target.text = doc.id),
                  ),
                )
                .toList(),
          );
        },
      ),
      const Divider(),
      const ListTile(title: Text('Nhật ký quản trị')),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('auditLogs')
            .orderBy('at', descending: true)
            .limit(20)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ListTile(
              title: Text('Không tải được nhật ký: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            );
          }
          if (snapshot.data!.docs.isEmpty) {
            return const ListTile(title: Text('Chưa có thao tác quản trị.'));
          }
          return Column(
            children: snapshot.data!.docs.map((doc) {
              final log = doc.data();
              return ListTile(
                title: Text(
                  '${log['action'] ?? 'Thao tác'} • ${log['actor'] ?? ''}',
                ),
                subtitle: Text('${log['details'] ?? ''}'),
              );
            }).toList(),
          );
        },
      ),
    ],
  );

  Widget _gameLink({
    required String title,
    required String subtitle,
    required IconData icon,
    required WidgetBuilder builder,
  }) => Card(
    color: const Color(0xff191c22),
    child: ListTile(
      leading: Icon(icon, color: const Color(0xffffc174)),
      title: Text(title, style: const TextStyle(color: Color(0xffe1e2eb))),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Color(0xffd8c3ad)),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xffffc174)),
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute<void>(builder: builder)),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff10131a),
    appBar: AppBar(
      backgroundColor: const Color(0xff0b0e14),
      foregroundColor: const Color(0xffe1e2eb),
      title: const Text('ADMIN CONSOLE'),
      actions: [
        IconButton(
          tooltip: 'Đăng xuất',
          onPressed: () => FirebaseAuth.instance.signOut(),
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: FutureBuilder<void>(
      future: profileReady,
      builder: (context, profile) {
        if (profile.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Không tải được hồ sơ quản trị: ${profile.error}'),
            ),
          );
        }
        if (profile.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xffffc174)),
          );
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff392714), Color(0xff191c22)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xff8d6b31)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: Color(0xffffc174),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Quản lý phiên game, tài khoản, điểm ảo và nhật ký.',
                          style: TextStyle(color: Color(0xffe1e2eb)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'QUẢN LÝ PHIÊN GAME',
                  style: TextStyle(
                    color: Color(0xffffc174),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                for (final game in games)
                  _gameLink(
                    title: game.title,
                    subtitle: 'Mở bàn quản trị phiên ${game.title}',
                    icon: game.icon,
                    builder: (_) => widget.roundBuilder(game),
                  ),
                _gameLink(
                  title: 'Poker',
                  subtitle: 'Quản lý bàn Poker, lượt và thao tác bài',
                  icon: Icons.style,
                  builder: (_) => CardTableScreen(
                    uid: widget.uid,
                    isAdmin: true,
                    game: 'poker',
                  ),
                ),
                _gameLink(
                  title: 'Ba Cây',
                  subtitle: 'Quản lý bàn Ba Cây và kết quả ván',
                  icon: Icons.style_outlined,
                  builder: (_) => CardTableScreen(
                    uid: widget.uid,
                    isAdmin: true,
                    game: 'ba_cay',
                  ),
                ),
                const SizedBox(height: 16),
                _accountManagementPanel(),
              ],
            ),
          ),
        );
      },
    ),
  );
}
