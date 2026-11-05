import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PointActivityScreen extends StatefulWidget {
  final String userId;

  const PointActivityScreen({super.key, required this.userId});

  @override
  State<PointActivityScreen> createState() => _PointActivityScreenState();
}

class _PointActivityScreenState extends State<PointActivityScreen> {
  static const _gold = Color(0xffffc174);
  static const _surface = Color(0xff1d2026);
  String _filter = 'all';
  String _search = '';
  late final Timestamp _since24h;

  static const _filters = <({String id, String label, IconData icon})>[
    (id: 'all', label: 'Tất cả', icon: Icons.receipt_long),
    (id: 'bet', label: 'Cược / vào bàn', icon: Icons.casino),
    (id: 'return', label: 'Thưởng / hoàn', icon: Icons.savings),
    (id: 'welcome', label: 'Điểm khởi tạo', icon: Icons.card_giftcard),
    (id: 'admin', label: 'Admin điều chỉnh', icon: Icons.admin_panel_settings),
  ];

  CollectionReference<Map<String, dynamic>> get _operations => FirebaseFirestore
      .instance
      .collection('users/${widget.userId}/operations');

  @override
  void initState() {
    super.initState();
    _since24h = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 24)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff10131a),
      appBar: AppBar(
        backgroundColor: const Color(0xff10131a),
        foregroundColor: const Color(0xffe1e2eb),
        title: const Text('Hoạt động điểm của tôi'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .doc('users/${widget.userId}')
            .snapshots(),
        builder: (context, userSnapshot) {
          final balance =
              (userSnapshot.data?.data()?['balance'] as num?)?.toInt() ?? 0;
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _operations
                .where('at', isGreaterThanOrEqualTo: _since24h)
                .orderBy('at', descending: true)
                .snapshots(),
            builder: (context, daySnapshot) =>
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _operations
                      .orderBy('at', descending: true)
                      .limit(20)
                      .snapshots(),
                  builder: (context, recentSnapshot) {
                    if (recentSnapshot.hasError) {
                      return _message(
                        'Không tải được hoạt động điểm: ${recentSnapshot.error}',
                      );
                    }
                    if (!recentSnapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: _gold),
                      );
                    }

                    final recent = recentSnapshot.data!.docs
                        .map((doc) => _PointOperation.fromDocument(doc))
                        .toList();
                    final recent24h =
                        daySnapshot.data?.docs
                            .map((doc) => _PointOperation.fromDocument(doc))
                            .toList() ??
                        const <_PointOperation>[];
                    final spent = recent24h.fold<int>(
                      0,
                      (subtotal, operation) => operation.delta < 0
                          ? subtotal - operation.delta
                          : subtotal,
                    );
                    final credited = recent24h.fold<int>(
                      0,
                      (subtotal, operation) => operation.delta > 0
                          ? subtotal + operation.delta
                          : subtotal,
                    );
                    final net = recent24h.fold<int>(
                      0,
                      (subtotal, operation) => subtotal + operation.delta,
                    );
                    final filtered = recent.where(_matches).toList();

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      children: [
                        _balanceCard(balance),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _totalCard(
                                'ĐIỂM ĐÃ DÙNG • 24H',
                                spent,
                                const Color(0xffff9292),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _totalCard(
                                'TỔNG GHI CÓ • 24H',
                                credited,
                                const Color(0xff73dfb0),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Biến động ròng trong 24 giờ',
                                  style: TextStyle(
                                    color: Color(0xffd8c3ad),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Text(
                                '${net >= 0 ? '+' : ''}${_formatPoints(net)} TX',
                                style: TextStyle(
                                  color: net >= 0
                                      ? const Color(0xff73dfb0)
                                      : const Color(0xffff9292),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'LỊCH SỬ ĐIỂM',
                          style: TextStyle(
                            color: _gold,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tối đa 20 hoạt động gần nhất đã được máy chủ ghi nhận.',
                          style: TextStyle(
                            color: Color(0xffa5a6ae),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          onChanged: (value) => setState(
                            () => _search = value.trim().toLowerCase(),
                          ),
                          style: const TextStyle(color: Color(0xffe1e2eb)),
                          decoration: InputDecoration(
                            hintText: 'Tìm loại giao dịch, mã phiên, lý do…',
                            hintStyle: const TextStyle(
                              color: Color(0xff83858e),
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Color(0xffa5a6ae),
                            ),
                            filled: true,
                            fillColor: _surface,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final filter in _filters)
                                Padding(
                                  padding: const EdgeInsets.only(right: 7),
                                  child: ChoiceChip(
                                    avatar: Icon(filter.icon, size: 16),
                                    label: Text(filter.label),
                                    selected: _filter == filter.id,
                                    onSelected: (_) =>
                                        setState(() => _filter = filter.id),
                                    selectedColor: _gold,
                                    backgroundColor: _surface,
                                    labelStyle: TextStyle(
                                      color: _filter == filter.id
                                          ? Colors.black
                                          : const Color(0xffe1e2eb),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    avatarBorder: const CircleBorder(),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (daySnapshot.hasError)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Không tải được thống kê 24 giờ: ${daySnapshot.error}',
                              style: const TextStyle(
                                color: Color(0xffffb4ab),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        if (filtered.isEmpty)
                          _emptyState()
                        else
                          for (final operation in filtered)
                            _operationTile(operation),
                        const SizedBox(height: 8),
                        const Text(
                          'Dữ liệu lấy từ sổ điểm cá nhân và chỉ gồm các giao dịch backend đã ghi nhận. Nhật ký thao tác quản trị hệ thống là màn riêng dành cho admin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xff898b94),
                            fontSize: 11,
                            height: 1.45,
                          ),
                        ),
                      ],
                    );
                  },
                ),
          );
        },
      ),
    );
  }

  bool _matches(_PointOperation operation) {
    final matchesFilter = switch (_filter) {
      'bet' => operation.kind == 'bet' || operation.kind == 'table_join',
      'return' => const {
        'payout',
        'refund',
        'bet_refund',
        'table_refund',
        'table_result',
      }.contains(operation.kind),
      'welcome' => operation.kind == 'welcome',
      'admin' => operation.kind == 'admin_adjust',
      _ => true,
    };
    if (!matchesFilter) return false;
    if (_search.isEmpty) return true;
    return <String>[
      operation.title,
      operation.kind,
      operation.gameLabel,
      operation.roundId,
      operation.tableId,
      operation.reason,
      operation.side,
    ].join(' ').toLowerCase().contains(_search);
  }

  Widget _balanceCard(int balance) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(
        colors: [Color(0xff3a2d19), Color(0xff1d2026)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: _gold.withValues(alpha: .32)),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 23,
          backgroundColor: Color(0x22ffc174),
          child: Icon(Icons.account_balance_wallet, color: _gold),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SỐ DƯ HIỆN TẠI',
                style: TextStyle(
                  color: Color(0xffc8b394),
                  fontSize: 11,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${_formatPoints(balance)} TX',
                style: const TextStyle(
                  color: _gold,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.verified_user, color: Color(0xff73dfb0), size: 18),
      ],
    ),
  );

  Widget _totalCard(String title, int amount, Color color) => Container(
    height: 88,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: .2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: .35,
          ),
        ),
        Text(
          '${_formatPoints(amount)} TX',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  Widget _operationTile(_PointOperation operation) {
    final positive = operation.delta > 0;
    final zero = operation.delta == 0;
    final color = zero
        ? const Color(0xffb7b9c2)
        : positive
        ? const Color(0xff73dfb0)
        : const Color(0xffff9292);
    final contextLine = <String>[
      if (operation.gameLabel.isNotEmpty) operation.gameLabel,
      if (operation.roundId.isNotEmpty) 'Phiên ${operation.roundId}',
      if (operation.tableId.isNotEmpty) 'Bàn ${operation.tableId}',
      if (operation.side.isNotEmpty) 'Cửa ${_sideLabel(operation.side)}',
      if (operation.stake != null && operation.stake! > 0)
        'Mức cược ${_formatPoints(operation.stake!)}',
      if (operation.reason.isNotEmpty) operation.reason,
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1affffff)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: .13),
            child: Icon(operation.icon, color: color, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  operation.title,
                  style: const TextStyle(
                    color: Color(0xffe1e2eb),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (contextLine.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    contextLine,
                    style: const TextStyle(
                      color: Color(0xffa5a6ae),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
                if (operation.at != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    _formatDate(operation.at!),
                    style: const TextStyle(
                      color: Color(0xff858791),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${positive ? '+' : ''}${_formatPoints(operation.delta)} TX',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (operation.balance != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Dư: ${_formatPoints(operation.balance!)}',
                  style: const TextStyle(
                    color: Color(0xff858791),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Container(
    margin: const EdgeInsets.symmetric(vertical: 14),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        const Icon(Icons.manage_search, color: Color(0xffa08e7a), size: 38),
        const SizedBox(height: 8),
        const Text(
          'Không có biến động điểm phù hợp',
          style: TextStyle(
            color: Color(0xffe1e2eb),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Thử đổi nhóm giao dịch hoặc từ khóa tìm kiếm.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xffa5a6ae), fontSize: 12),
        ),
        TextButton(
          onPressed: () => setState(() {
            _filter = 'all';
            _search = '';
          }),
          child: const Text('Xóa bộ lọc'),
        ),
      ],
    ),
  );

  Widget _message(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xffffb4ab)),
      ),
    ),
  );
}

class _PointOperation {
  final String kind;
  final int delta;
  final int? balance;
  final int? stake;
  final String gameLabel;
  final String roundId;
  final String tableId;
  final String side;
  final String reason;
  final DateTime? at;

  const _PointOperation({
    required this.kind,
    required this.delta,
    required this.balance,
    required this.stake,
    required this.gameLabel,
    required this.roundId,
    required this.tableId,
    required this.side,
    required this.reason,
    required this.at,
  });

  factory _PointOperation.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final timestamp = data['at'];
    final rawGame = data['game']?.toString() ?? '';
    return _PointOperation(
      kind: data['kind']?.toString() ?? 'unknown',
      delta: (data['delta'] as num?)?.toInt() ?? 0,
      balance: (data['balance'] as num?)?.toInt(),
      stake: ((data['stake'] ?? data['buyIn']) as num?)?.toInt(),
      gameLabel: _gameLabel(rawGame),
      roundId: data['roundId']?.toString() ?? '',
      tableId: data['tableId']?.toString() ?? '',
      side: data['side']?.toString() ?? '',
      reason: data['reason']?.toString() ?? '',
      at: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }

  String get title => switch (kind) {
    'welcome' => 'Điểm khởi tạo tài khoản',
    'bet' => 'Đặt cược',
    'payout' => delta > 0 ? 'Nhận thưởng cược' : 'Kết quả cược',
    'refund' || 'bet_refund' => 'Hoàn cược',
    'bet_balance_refund' => 'Hoàn cân cửa Tài/Xỉu',
    'admin_adjust' => 'Admin điều chỉnh điểm',
    'table_join' => 'Vào bàn bài',
    'table_refund' => 'Hoàn điểm rời bàn',
    'table_result' => 'Kết quả bàn bài',
    _ => 'Giao dịch điểm',
  };

  IconData get icon => switch (kind) {
    'welcome' => Icons.card_giftcard,
    'bet' || 'table_join' => Icons.casino,
    'payout' || 'table_result' => Icons.emoji_events,
    'refund' || 'bet_refund' || 'bet_balance_refund' || 'table_refund' =>
      Icons.replay,
    'admin_adjust' => Icons.admin_panel_settings,
    _ => Icons.swap_horiz,
  };
}

String _gameLabel(String game) => switch (game) {
  'tai_xiu' => 'Tài/Xỉu',
  'bau_cua' => 'Bầu Cua',
  'xoc_xoc' => 'Xóc Xóc',
  'poker' => 'Poker',
  'ba_cay' => 'Ba Cây',
  _ => game,
};

String _sideLabel(String side) => switch (side) {
  'tai' => 'Tài',
  'xiu' => 'Xỉu',
  'chan' => 'Chẵn',
  'le' => 'Lẻ',
  'red3' => '3 đỏ',
  'red4' => '4 đỏ',
  'white3' => '3 trắng',
  'white4' => '4 trắng',
  _ => side,
};

String _formatPoints(int amount) {
  final isNegative = amount < 0;
  final digits = amount.abs().toString();
  final out = StringBuffer(isNegative ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

String _formatDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.hour)}:${two(date.minute)}:${two(date.second)} · ${two(date.day)}/${two(date.month)}/${date.year}';
}
