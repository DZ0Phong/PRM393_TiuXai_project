import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'audit_log_logic.dart';
import 'audit_log_repository.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key, this.repository, this.embedded = false});

  final AuditLogRepository? repository;
  final bool embedded;

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  static const _pageSize = 20;
  static const _background = Color(0xff10131a);
  static const _surface = Color(0xff191c22);
  static const _surfaceHigh = Color(0xff272a31);
  static const _gold = Color(0xffffc174);
  static const _muted = Color(0xffd8c3ad);

  final _search = TextEditingController();
  final _olderDocs = <AuditLogEntry>[];
  late final AuditLogRepository _repository;
  late final Stream<List<AuditLogEntry>> _latestStream;
  String _filter = 'all';
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _loadError;

  static const _filters = <({String id, String label, IconData icon})>[
    (id: 'all', label: 'Tất cả', icon: Icons.list_alt),
    (id: 'round_result', label: 'Kết quả phiên', icon: Icons.casino),
    (id: 'balance', label: 'Điểm & ví', icon: Icons.account_balance_wallet),
    (id: 'cancel', label: 'Hủy & hoàn', icon: Icons.cancel_outlined),
    (id: 'round', label: 'Điều hành phiên', icon: Icons.play_circle_outline),
    (id: 'account', label: 'Tài khoản', icon: Icons.manage_accounts),
    (id: 'bet', label: 'Cược', icon: Icons.savings_outlined),
    (id: 'table', label: 'Bàn bài', icon: Icons.style),
    (id: 'bot', label: 'Bot', icon: Icons.smart_toy_outlined),
    (id: 'system', label: 'Hệ thống', icon: Icons.settings_outlined),
  ];

  static const _actionLabels = <String, String>{
    'AUTO_MODE_MIGRATE': 'Chuyển phiên sang chế độ tự động',
    'AUTO_START': 'Tự động mở phiên',
    'WELCOME': 'Cấp điểm khởi tạo',
    'START': 'Mở phiên',
    'BET': 'Đặt cược',
    'BET_REFUND': 'Hoàn cược',
    'LOCK': 'Khóa phiên',
    'INTERVENE_ROUND': 'Can thiệp kết quả phiên',
    'SETTLE': 'Chốt kết quả phiên',
    'CANCEL': 'Hủy phiên và hoàn cược',
    'ADJUST_BALANCE': 'Điều chỉnh điểm',
    'BLOCK_PLAYER': 'Khóa tài khoản',
    'UNBLOCK_PLAYER': 'Mở khóa tài khoản',
    'TABLE_CREATE': 'Tạo bàn bài',
    'TABLE_JOIN': 'Vào bàn bài',
    'TABLE_LEAVE': 'Rời bàn bài',
    'TABLE_BOT_CONFIG': 'Cấu hình bot',
    'TABLE_START': 'Bắt đầu ván bài',
    'TABLE_ACTION': 'Thao tác trong ván bài',
    'TABLE_CANCEL': 'Hủy bàn và hoàn điểm',
    'TABLE_TIMEOUT': 'Tự động xử lý lượt hết giờ',
  };

  static const _detailLabels = <String, String>{
    'game': 'Trò chơi',
    'roundId': 'Mã phiên',
    'tableId': 'Mã bàn',
    'uid': 'UID người chơi',
    'requestId': 'Mã yêu cầu',
    'reason': 'Lý do',
    'amount': 'Số điểm',
    'delta': 'Thay đổi điểm',
    'mode': 'Chế độ',
    'result': 'Kết quả',
    'side': 'Cửa cược',
    'status': 'Trạng thái',
    'refundedPlayers': 'Số người được hoàn',
    'credits': 'Các khoản ghi có',
    'enabled': 'Đã bật bot',
    'maxBots': 'Số bot tối đa',
    'players': 'Người chơi',
    'type': 'Loại thao tác',
    'street': 'Vòng bài',
    'rake': 'Phí bàn',
    'stake': 'Mức cược',
    'buyIn': 'Điểm vào bàn',
    'blocked': 'Đã khóa',
  };

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseAuditLogRepository();
    _latestStream = _repository.watchLatest(_pageSize);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadMore(List<AuditLogEntry> current) async {
    if (_loadingMore || current.isEmpty) return;
    setState(() {
      _loadingMore = true;
      _loadError = null;
    });
    try {
      final cursor = _olderDocs.isNotEmpty ? _olderDocs.last : current.last;
      final page = await _repository.fetchAfter(cursor, _pageSize);
      if (mounted) {
        setState(() {
          _olderDocs.addAll(page);
          _hasMore = page.length == _pageSize;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _loadError = 'Không tải thêm được: $error');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<AuditLogEntry> _merge(List<AuditLogEntry> latest) {
    final byId = <String, AuditLogEntry>{};
    for (final doc in [...latest, ..._olderDocs]) {
      byId.putIfAbsent(doc.id, () => doc);
    }
    return byId.values.toList();
  }

  bool _matchesCategory(String action) {
    return auditMatchesCategory(action, _filter);
  }

  List<AuditLogEntry> _visible(List<AuditLogEntry> docs) {
    final query = _search.text.trim();
    return docs.where((doc) {
      final data = doc.data;
      final action = '${data['action'] ?? ''}';
      if (!_matchesCategory(action)) return false;
      return auditMatchesSearch(documentId: doc.id, data: data, query: query);
    }).toList();
  }

  String _timestamp(dynamic value) {
    if (value is! Timestamp) return 'Chưa có thời gian';
    final date = value.toDate().toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}  ${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }

  String _shortId(String value) => value.length > 18
      ? '${value.substring(0, 8)}…${value.substring(value.length - 6)}'
      : value;

  Color _actionColor(String category) => switch (category) {
    'round_result' => _gold,
    'balance' || 'bet' => const Color(0xff56e5a9),
    'cancel' || 'account' => const Color(0xffff8e88),
    'bot' => const Color(0xffc3a6ff),
    'system' => const Color(0xff8ecbff),
    _ => const Color(0xffd8c3ad),
  };

  String _formatValue(dynamic value) {
    if (value == null) return '—';
    if (value is Map || value is List) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }
    return value.toString();
  }

  Widget _detailRows(Map<String, dynamic> details) {
    if (details.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xff0b0e14).withValues(alpha: .8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: details.entries.map((entry) {
          final label = _detailLabels[entry.key] ?? entry.key;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: SelectableText.rich(
              TextSpan(
                style: const TextStyle(fontSize: 12, height: 1.4),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(color: _muted),
                  ),
                  TextSpan(
                    text: _formatValue(entry.value),
                    style: const TextStyle(color: Color(0xffe1e2eb)),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _logCard(AuditLogEntry doc) {
    final data = doc.data;
    final details = Map<String, dynamic>.from(
      data['details'] is Map ? data['details'] as Map : const {},
    );
    final action = '${data['action'] ?? 'UNKNOWN'}';
    final category = auditCategoryForAction(action);
    final color = _actionColor(category);
    final entityId = details['roundId'] ?? details['tableId'] ?? details['uid'];
    return Card(
      color: _surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _actionLabels[action] ?? action.replaceAll('_', ' '),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _timestamp(data['at']),
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 5,
              children: [
                _meta(Icons.shield_outlined, 'Actor: ${data['actor'] ?? '—'}'),
                if (entityId != null)
                  _meta(Icons.tag, _shortId(entityId.toString())),
                _meta(Icons.fingerprint, 'Log: ${_shortId(doc.id)}'),
              ],
            ),
            _detailRows(details),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: _muted),
      const SizedBox(width: 4),
      SelectableText(
        text,
        style: const TextStyle(color: Color(0xffe1e2eb), fontSize: 11),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: widget.embedded
        ? null
        : AppBar(
            backgroundColor: const Color(0xff0b0e14),
            foregroundColor: const Color(0xffe1e2eb),
            title: const Text(
              'Nhật ký quản trị',
              style: TextStyle(color: _gold),
            ),
          ),
    body: StreamBuilder<List<AuditLogEntry>>(
      stream: _latestStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Không tải được nhật ký: ${snapshot.error}',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _gold));
        }
        final latestDocs = snapshot.data!;
        final allDocs = _merge(latestDocs);
        final docs = _visible(allDocs);
        final canLoadMore = _olderDocs.isEmpty
            ? latestDocs.length == _pageSize
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
                        Icons.verified_user_outlined,
                        color: Color(0xff56e5a9),
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'ROLE: ADMIN • AUDIT TRAIL',
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
                    'Nhật Ký Quản Trị Hệ Thống',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Ghi nhận các sự kiện được backend lưu trong auditLogs. Hiển thị mới nhất trước, 20 bản ghi mỗi trang.',
                    style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Color(0xffe1e2eb)),
              decoration: InputDecoration(
                hintText: 'Tìm UID, mã phiên/bàn, Admin, lý do…',
                hintStyle: const TextStyle(color: _muted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: _muted),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xóa tìm kiếm',
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close, color: _muted),
                      ),
                filled: true,
                fillColor: const Color(0xff0b0e14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final item = _filters[index];
                  final selected = _filter == item.id;
                  return ChoiceChip(
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = item.id),
                    avatar: Icon(
                      item.icon,
                      size: 15,
                      color: selected ? const Color(0xff613b00) : _muted,
                    ),
                    label: Text(item.label),
                    labelStyle: TextStyle(
                      color: selected ? const Color(0xff613b00) : _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: _surfaceHigh,
                    selectedColor: const Color(0xfff59e0b),
                    side: BorderSide.none,
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${docs.length} bản ghi đang hiển thị • ${allDocs.length} đã tải',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
            const SizedBox(height: 8),
            if (docs.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.manage_search, color: _muted, size: 34),
                    const SizedBox(height: 8),
                    Text(
                      allDocs.isEmpty
                          ? 'Chưa có bản ghi nhật ký.'
                          : 'Không tìm thấy nhật ký phù hợp.',
                      style: const TextStyle(
                        color: Color(0xffe1e2eb),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (allDocs.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          _search.clear();
                          setState(() => _filter = 'all');
                        },
                        child: const Text('Đặt lại bộ lọc'),
                      ),
                  ],
                ),
              )
            else
              ...docs.map(_logCard),
            if (allDocs.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (_loadError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _loadError!,
                    style: const TextStyle(
                      color: Color(0xffff8e88),
                      fontSize: 12,
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _loadingMore || !canLoadMore
                    ? null
                    : () => _loadMore(allDocs),
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
                      : 'Tải thêm $_pageSize bản ghi trước',
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
                    'Quyền đọc được kiểm soát bởi Firestore Rules.',
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
