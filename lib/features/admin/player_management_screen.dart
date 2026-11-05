import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/currency_format.dart';
import '../../core/pending_mutation.dart';
import 'player_management_repository.dart';

class PlayerManagementScreen extends StatefulWidget {
  const PlayerManagementScreen({
    super.key,
    required this.adminUid,
    required this.invoke,
    this.repository,
    this.embedded = false,
  });

  final String adminUid;
  final Future<void> Function(String, Map<String, dynamic>) invoke;
  final PlayerManagementRepository? repository;
  final bool embedded;

  @override
  State<PlayerManagementScreen> createState() => _PlayerManagementScreenState();
}

class _PlayerManagementScreenState extends State<PlayerManagementScreen> {
  static const _pageSize = 50;
  static const _background = Color(0xff10131a);
  static const _surface = Color(0xff191c22);
  static const _gold = Color(0xffffc174);
  static const _muted = Color(0xffd8c3ad);

  final _search = TextEditingController();
  final _delta = TextEditingController();
  final _reason = TextEditingController();
  final _store = PendingMutationStore();
  final _olderUsers = <PlayerRecord>[];
  late final PlayerManagementRepository _repository;
  late final Stream<List<PlayerRecord>> _latestStream;
  String _statusFilter = 'all';
  int _adjustmentSign = 1;
  String? _selectedUid;
  Map<String, dynamic>? _selectedUser;
  Map<String, dynamic>? _pending;
  bool _loadingPending = true;
  bool _loadingMore = false;
  bool _lookingUp = false;
  bool _busy = false;
  bool _hasMore = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebasePlayerManagementRepository();
    _latestStream = _repository.watchLatest(_pageSize);
    _loadPending();
  }

  @override
  void dispose() {
    _search.dispose();
    _delta.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _loadPending() async {
    try {
      final pending = await _store.load(widget.adminUid);
      if (mounted) {
        setState(() {
          _pending = pending;
          _selectedUid = pending?['data']?['uid']?.toString();
        });
        if (_selectedUid != null) {
          final player = await _repository.getByUid(_selectedUid!);
          if (mounted && player != null) {
            setState(() => _selectedUser = player.data);
          }
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Không đọc được thao tác chờ: $error');
      }
    } finally {
      if (mounted) setState(() => _loadingPending = false);
    }
  }

  Future<void> _lookupUid() async {
    final uid = _search.text.trim();
    if (uid.isEmpty || _lookingUp) return;
    setState(() {
      _lookingUp = true;
      _message = null;
    });
    try {
      final player = await _repository.getByUid(uid);
      if (!mounted) return;
      if (player == null) {
        setState(() => _message = 'Không tìm thấy người chơi với UID này.');
      } else {
        setState(() {
          _selectedUid = player.uid;
          _selectedUser = player.data;
          _message = 'Đã tìm thấy người chơi.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Không tìm được người chơi: $error');
      }
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _loadMore(List<PlayerRecord> latest) async {
    if (_loadingMore || !_hasMore || latest.isEmpty) return;
    setState(() {
      _loadingMore = true;
      _message = null;
    });
    try {
      final cursor = _olderUsers.isNotEmpty ? _olderUsers.last : latest.last;
      final page = await _repository.fetchAfter(cursor, _pageSize);
      if (mounted) {
        setState(() {
          _olderUsers.addAll(page);
          _hasMore = page.length == _pageSize;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = 'Không tải thêm được: $error');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<PlayerRecord> _merge(List<PlayerRecord> latest) {
    final byId = <String, PlayerRecord>{};
    for (final doc in [...latest, ..._olderUsers]) {
      byId.putIfAbsent(doc.uid, () => doc);
    }
    return byId.values.toList();
  }

  List<PlayerRecord> _visible(List<PlayerRecord> users) {
    final query = _search.text.trim().toLowerCase();
    return users.where((doc) {
      final data = doc.data;
      final blocked = data['blocked'] == true;
      final isBot = data['isBot'] == true;
      final matchesStatus = switch (_statusFilter) {
        'active' => !blocked && !isBot,
        'blocked' => blocked,
        'bot' => isBot,
        _ => true,
      };
      return matchesStatus &&
          (query.isEmpty || doc.uid.toLowerCase().contains(query));
    }).toList();
  }

  void _select(String uid, Map<String, dynamic> data) {
    setState(() {
      _selectedUid = uid;
      _selectedUser = data;
      _message = null;
    });
  }

  Future<void> _refreshSelected() async {
    final uid = _selectedUid;
    if (uid == null) return;
    final player = await _repository.getByUid(uid);
    if (mounted && player != null) {
      setState(() => _selectedUser = player.data);
    }
  }

  Future<void> _adjustBalance() async {
    if (_busy || _pending != null || _selectedUid == null) return;
    final amount = int.tryParse(_delta.text.trim());
    final why = _reason.text.trim();
    final currentBalance = (_selectedUser?['balance'] as num?)?.toInt() ?? 0;
    final projectedBalance = currentBalance + (amount ?? 0) * _adjustmentSign;
    if (amount == null ||
        amount == 0 ||
        amount.abs() > 100000 ||
        projectedBalance < 0 ||
        projectedBalance > 1000000 ||
        why.length < 5 ||
        why.length > 300) {
      final invalidInput =
          amount == null ||
          amount == 0 ||
          amount.abs() > 100000 ||
          why.length < 5 ||
          why.length > 300;
      setState(
        () => _message = invalidInput
            ? 'Nhập thay đổi ±1–100000 điểm và lý do 5–300 ký tự.'
            : 'Số dư sau điều chỉnh phải từ 0 đến 1.000.000 điểm.',
      );
      return;
    }
    final signedAmount = amount * _adjustmentSign;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff272a31),
        title: const Text('Xác nhận điều chỉnh điểm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UID: $_selectedUid'),
            Text('Hành động: ${signedAmount > 0 ? '+' : ''}${formatCurrencyAmount(signedAmount)} VNĐ'),
            Text(
              'Số dư dự kiến: ${formatCurrencyAmount(((_selectedUser?['balance'] as num? ?? 0) + signedAmount).toInt())} VNĐ',
            ),
            const SizedBox(height: 10),
            Text('Lý do: $why'),
            const SizedBox(height: 10),
            const Text('Thao tác sẽ được gửi đến backend và ghi audit log.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    final operation = <String, dynamic>{
      'name': 'adjustBalance',
      'data': {
        'uid': _selectedUid,
        'delta': signedAmount,
        'reason': why,
        'requestId':
            'adjust_${widget.adminUid}_${DateTime.now().microsecondsSinceEpoch}',
      },
    };
    try {
      await _store.save(widget.adminUid, operation);
      if (mounted) setState(() => _pending = operation);
      await _sendPending();
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Không thể điều chỉnh điểm: $error');
      }
    }
  }

  Future<void> _sendPending() async {
    final operation = _pending;
    if (operation == null || operation['name'] != 'adjustBalance') return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.invoke(
        'adjustBalance',
        Map<String, dynamic>.from(operation['data'] as Map),
      );
      await _store.clear(widget.adminUid);
      if (mounted) {
        setState(() {
          _pending = null;
          _message = 'Đã điều chỉnh điểm.';
          _delta.clear();
          _reason.clear();
        });
      }
      try {
        await _refreshSelected();
      } catch (error) {
        if (mounted) {
          setState(
            () => _message =
                'Đã điều chỉnh điểm; không làm mới được số dư: $error',
          );
        }
      }
    } on FirebaseFunctionsException catch (error) {
      if (const {
        'invalid-argument',
        'failed-precondition',
        'permission-denied',
        'unauthenticated',
        'already-exists',
        'not-found',
      }.contains(error.code)) {
        await _store.clear(widget.adminUid);
        if (mounted) setState(() => _pending = null);
      }
      rethrow;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retryPending() async {
    try {
      await _sendPending();
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Không thể xác nhận thao tác: $error');
      }
    }
  }

  Future<void> _setBlocked(bool blocked) async {
    if (_busy || _pending != null || _selectedUid == null) return;
    final why = _reason.text.trim();
    if (why.length < 5 || why.length > 300) {
      setState(
        () => _message = 'Nhập lý do 5–300 ký tự trước khi khóa hoặc mở khóa.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.invoke('setPlayerBlocked', {
        'uid': _selectedUid,
        'blocked': blocked,
        'reason': why,
      });
      if (mounted) {
        setState(() {
          _message = blocked ? 'Đã khóa tài khoản.' : 'Đã mở khóa tài khoản.';
          _reason.clear();
        });
      }
      try {
        await _refreshSelected();
      } catch (error) {
        if (mounted) {
          setState(
            () => _message =
                '${blocked ? 'Đã khóa' : 'Đã mở khóa'} tài khoản; không làm mới được hồ sơ: $error',
          );
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Không thể đổi trạng thái tài khoản: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _shortUid(String uid) => uid.length > 18
      ? '${uid.substring(0, 8)}…${uid.substring(uid.length - 6)}'
      : uid;

  Widget _chip(String id, String label) {
    final selected = _statusFilter == id;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = id),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? const Color(0xff613b00) : _muted,
        fontSize: 12,
      ),
      selectedColor: const Color(0xfff59e0b),
      backgroundColor: const Color(0xff272a31),
      side: BorderSide.none,
      showCheckmark: false,
    );
  }

  Widget _selectedPanel() {
    final user = _selectedUser;
    if (_selectedUid == null || user == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Chọn người chơi trong danh sách hoặc tìm theo UID để xem và thao tác.',
          style: TextStyle(color: _muted),
        ),
      );
    }
    final blocked = user['blocked'] == true;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: blocked ? const Color(0xffff8e88) : const Color(0xff534434),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                blocked ? Icons.person_off : Icons.person,
                color: blocked ? const Color(0xffff8e88) : _gold,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _shortUid(_selectedUid!),
                  style: const TextStyle(
                    color: _gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${user['balance'] is num ? formatCurrencyAmount((user['balance'] as num).toInt()) : '—'} VNĐ',
                style: const TextStyle(
                  color: Color(0xff56e5a9),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          SelectableText(
            _selectedUid!,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          if (user['createdAt'] is Timestamp)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'Tạo lúc: ${(user['createdAt'] as Timestamp).toDate().toLocal()}',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ),
          if (user['isBot'] == true)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text(
                'Tài khoản bot hệ thống',
                style: TextStyle(color: Color(0xffc3a6ff), fontSize: 12),
              ),
            ),
          if (blocked) ...[
            const SizedBox(height: 5),
            Text(
              'Lý do khóa: ${user['blockReason'] ?? '—'}',
              style: const TextStyle(color: Color(0xffff8e88), fontSize: 12),
            ),
          ],
          const Divider(height: 22),
          TextField(
            controller: _delta,
            enabled: !_busy && _pending == null,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            style: const TextStyle(color: Color(0xffe1e2eb)),
            decoration: const InputDecoration(
              labelText: 'Số điểm điều chỉnh (1–100000)',
              helperText: 'Số dư sau điều chỉnh phải từ 0 đến 1.000.000',
            ),
          ),
          const SizedBox(height: 7),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 1,
                label: Text('Tặng VNĐ (+)'),
                icon: Icon(Icons.add_circle_outline),
              ),
              ButtonSegment(
                value: -1,
                label: Text('Trừ điểm (−)'),
                icon: Icon(Icons.remove_circle_outline),
              ),
            ],
            selected: {_adjustmentSign},
            onSelectionChanged: _busy || _pending != null
                ? null
                : (value) => setState(() => _adjustmentSign = value.first),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [1000, 5000, 10000, 50000, 100000]
                .map(
                  (amount) => ActionChip(
                    label: Text(
                      '${_adjustmentSign > 0 ? '+' : '−'}${amount >= 1000 ? '${amount ~/ 1000}K' : amount}',
                    ),
                    onPressed: _busy || _pending != null
                        ? null
                        : () => setState(() => _delta.text = '$amount'),
                    backgroundColor: const Color(0xff272a31),
                    labelStyle: const TextStyle(color: _muted, fontSize: 11),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reason,
            enabled: !_busy && _pending == null,
            maxLength: 300,
            style: const TextStyle(color: Color(0xffe1e2eb)),
            decoration: const InputDecoration(labelText: 'Lý do (5–300 ký tự)'),
          ),
          if (_pending != null) ...[
            const Text(
              'Điều chỉnh chưa được xác nhận. Hãy thử lại cùng requestId.',
              style: TextStyle(color: _gold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _busy ? null : _retryPending,
              child: const Text('Thử lại điều chỉnh'),
            ),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const ValueKey('player-adjustment-submit'),
                onPressed: _busy || _pending != null ? null : _adjustBalance,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: Text(
                  _adjustmentSign > 0
                      ? 'Tặng VNĐ cho người chơi'
                      : 'Xác nhận trừ điểm',
                ),
              ),
              if (!blocked)
                OutlinedButton.icon(
                  onPressed:
                      _busy ||
                          _pending != null ||
                          _selectedUid == widget.adminUid
                      ? null
                      : () => _setBlocked(true),
                  icon: const Icon(Icons.block),
                  label: const Text('Khóa tài khoản'),
                )
              else
                OutlinedButton.icon(
                  onPressed:
                      _busy ||
                          _pending != null ||
                          _selectedUid == widget.adminUid
                      ? null
                      : () => _setBlocked(false),
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Mở khóa'),
                ),
              if (_busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: widget.embedded
        ? null
        : AppBar(
            backgroundColor: const Color(0xff0b0e14),
            foregroundColor: const Color(0xffe1e2eb),
            title: const Text(
              'Quản lý người chơi',
              style: TextStyle(color: _gold),
            ),
            actions: [
              IconButton(
                tooltip: 'Đăng xuất',
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
    body: StreamBuilder<List<PlayerRecord>>(
      stream: _latestStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Không tải được danh sách người chơi: ${snapshot.error}',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _gold));
        }
        final latest = snapshot.data!;
        final allUsers = _merge(latest);
        final users = _visible(allUsers);
        final canLoadMore = _olderUsers.isEmpty
            ? latest.length == _pageSize
            : _hasMore;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xff534434)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings_outlined,
                        color: Color(0xff56e5a9),
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'ROLE: ADMIN • PLAYER MANAGEMENT',
                        style: TextStyle(
                          color: Color(0xff56e5a9),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Quản lý người chơi',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Xem tài khoản, điều chỉnh điểm ảo và khóa hoặc mở khóa truy cập game. Mọi thay đổi được ghi vào nhật ký quản trị.',
                    style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _lookupUid(),
                    style: const TextStyle(color: Color(0xffe1e2eb)),
                    decoration: InputDecoration(
                      hintText: 'Tìm UID người chơi…',
                      hintStyle: const TextStyle(color: _muted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: _muted),
                      filled: true,
                      fillColor: const Color(0xff0b0e14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Tra cứu UID chính xác',
                  onPressed: _lookingUp ? null : _lookupUid,
                  icon: _lookingUp
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_search),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('all', 'Tất cả'),
                  const SizedBox(width: 6),
                  _chip('active', 'Đang hoạt động'),
                  const SizedBox(width: 6),
                  _chip('blocked', 'Đã khóa'),
                  const SizedBox(width: 6),
                  _chip('bot', 'Bot'),
                ],
              ),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _message!.startsWith('Không')
                        ? const Color(0xffff8e88)
                        : const Color(0xff56e5a9),
                    fontSize: 12,
                  ),
                ),
              ),
            if (_loadingPending) const LinearProgressIndicator(minHeight: 2),
            if (_pending != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xff392714),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Có điều chỉnh điểm đang chờ xác nhận. Hoàn tất hoặc thử lại trước khi tạo thao tác mới.',
                  style: TextStyle(color: _gold, fontSize: 12),
                ),
              ),
            _selectedPanel(),
            const SizedBox(height: 14),
            Text(
              'TÀI KHOẢN ĐÃ TẢI • ${users.length} / ${allUsers.length}',
              style: const TextStyle(
                color: _gold,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            if (users.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  allUsers.isEmpty
                      ? 'Chưa có tài khoản.'
                      : 'Không có tài khoản phù hợp. Dùng nút tra cứu để tìm UID chính xác.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted),
                ),
              )
            else
              ...users.map((doc) {
                final data = doc.data;
                final blocked = data['blocked'] == true;
                final isBot = data['isBot'] == true;
                return Card(
                  color: _surface,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    selected: _selectedUid == doc.uid,
                    selectedTileColor: const Color(0xff392714),
                    leading: CircleAvatar(
                      backgroundColor: blocked
                          ? const Color(0xff93000a)
                          : (isBot
                                ? const Color(0xff493276)
                                : const Color(0xff392714)),
                      child: Icon(
                        blocked
                            ? Icons.person_off
                            : (isBot
                                  ? Icons.smart_toy_outlined
                                  : Icons.person_outline),
                        color: blocked ? const Color(0xffff8e88) : _gold,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      _shortUid(doc.uid),
                      style: const TextStyle(
                        color: Color(0xffe1e2eb),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${data['balance'] is num ? formatCurrencyAmount((data['balance'] as num).toInt()) : '—'} VNĐ • ${blocked ? 'ĐÃ KHÓA' : (isBot ? 'BOT' : 'Hoạt động')}',
                      style: TextStyle(
                        color: blocked ? const Color(0xffff8e88) : _muted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: _muted),
                    onTap: () => _select(doc.uid, data),
                  ),
                );
              }),
            if (allUsers.isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loadingMore || !canLoadMore
                    ? null
                    : () => _loadMore(latest),
                icon: _loadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.history),
                label: Text(
                  _loadingMore
                      ? 'Đang tải…'
                      : (canLoadMore
                            ? 'Tải thêm $_pageSize tài khoản cũ hơn'
                            : 'Đã tải hết tài khoản'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _gold,
                  side: const BorderSide(color: Color(0xff534434)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, color: _muted, size: 14),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Quyền xem tài khoản và thao tác được kiểm soát bởi backend và Firestore Rules.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 10),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
