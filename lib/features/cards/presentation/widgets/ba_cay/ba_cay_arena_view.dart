import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/currency_format.dart';
/// Presentation-only Ba Cây arena. Round status, seats, winners and private
/// cards come from the existing card-table backend stream.
class BaCayArenaView extends StatefulWidget {
  final String tableId;
  final Map<String, dynamic> table;
  final List<Map> seats;
  final String uid;
  final Object? privateCards;
  final int balance;
  final VoidCallback? onNewTable;
  final VoidCallback? onCreateTable;

  const BaCayArenaView({
    super.key,
    required this.tableId,
    required this.table,
    required this.seats,
    required this.uid,
    required this.privateCards,
    required this.balance,
    this.onNewTable,
    this.onCreateTable,
  });

  @override
  State<BaCayArenaView> createState() => _BaCayArenaViewState();
}

class _BaCayArenaViewState extends State<BaCayArenaView> {
  static const gold = Color(0xffffc174);
  bool rulesOpen = false;
  bool showCards = true;
  int seconds = 4;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => seconds = seconds > 1 ? seconds - 1 : 15);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  int? get points {
    final cards = widget.privateCards;
    if (cards is! List || cards.length != 3 || cards.any((c) => c is! String)) {
      return null;
    }
    final values = cards.cast<String>().map((card) {
      final rank = card.substring(0, card.length - 1);
      return rank == 'A' ? 1 : int.tryParse(rank) ?? 0;
    }).toList();
    final sum = values.fold<int>(0, (a, b) => a + b);
    return sum % 10 == 0 ? 10 : sum % 10;
  }

  String _name(Map seat) => seat['nickname'] ?? seat['uid'] ?? 'Người chơi';

  @override
  Widget build(BuildContext context) {
    final status = '${widget.table['status'] ?? 'waiting'}';
    final seats = widget.seats;
    final dealerUid = widget.table['dealerUid'];
    final me = seats.cast<Map?>().firstWhere(
      (seat) => seat?['uid'] == widget.uid,
      orElse: () => null,
    );
    final hand = widget.privateCards is List
        ? widget.privateCards as List
        : const [];
    final winners = widget.table['winners'];
    final winnerUids = winners is List
        ? winners
              .map((winner) => winner is Map ? winner['uid'] : winner)
              .toList()
        : const [];
    final isWinner = winnerUids.contains(widget.uid);
    final dealer = seats.cast<Map?>().firstWhere(
      (seat) => seat?['uid'] == dealerUid,
      orElse: () => null,
    );
    final winnerNames = winnerUids
        .map(
          (uid) => _name(
            seats.firstWhere(
              (seat) => seat['uid'] == uid,
              orElse: () => {'uid': uid},
            ),
          ),
        )
        .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: _panel(),
          child: Row(
            children: [
              const Icon(Icons.casino, color: gold),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE TABLE',
                      style: TextStyle(
                        color: Color(0xff56e5a9),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'Tiuxai Arena',
                      style: TextStyle(
                        color: gold,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.toll, color: gold, size: 18),
              const SizedBox(width: 4),
              Text(
                '${formatCurrencyAmount(widget.balance)} VNĐ',
                style: const TextStyle(
                  color: Color(0xffffddb8),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 15,
                backgroundColor: gold,
                child: Icon(Icons.person, color: Color(0xff472a00), size: 17),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: _panel(),
          child: Row(
            children: [
              const Icon(Icons.circle, size: 9, color: Color(0xff56e5a9)),
              const SizedBox(width: 5),
              Text(
                '#${widget.tableId} ${status.toUpperCase()}',
                style: const TextStyle(
                  color: Color(0xff56e5a9),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Ba Cây Hoàng Gia',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                '${me?['stack'] is num ? formatCurrencyAmount((me!['stack'] as num).toInt()) : '—'} VNĐ',
                style: const TextStyle(color: Color(0xffffddb8), fontSize: 10),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: widget.onCreateTable,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('TẠO BÀN'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: _panel(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat(
                'MỨC ANTE',
                '${widget.table['stake'] is num ? formatCurrencyAmount((widget.table['stake'] as num).toInt()) : '—'} VNĐ',
                Icons.account_balance_wallet,
              ),
              Row(
                children: [
                  const Icon(Icons.timer, color: Color(0xffffb3ad), size: 16),
                  const SizedBox(width: 3),
                  const Text(
                    'Hạ bài:',
                    style: TextStyle(fontSize: 10, color: Color(0xffd8c3ad)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${seconds.toString().padLeft(2, '0')}s',
                    style: const TextStyle(
                      color: Color(0xffffb3ad),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              _stat(
                'GÓP TẨY',
                '${widget.table['pot'] is num ? formatCurrencyAmount((widget.table['pot'] as num).toInt()) : '0'} VNĐ',
                Icons.savings,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const RadialGradient(
              colors: [Color(0xff342512), Color(0xff191c22), Color(0xff0b0e14)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xff8d6b31)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 15)],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events, color: gold),
                  const SizedBox(width: 6),
                  const Icon(Icons.workspace_premium, color: gold),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CHƯƠNG',
                          style: TextStyle(
                            color: gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          dealer == null
                              ? 'Chương chờ xác định'
                              : _name(dealer),
                          style: const TextStyle(
                            color: Color(0xffe1e2eb),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'ĐIỂM CHƯƠNG',
                        style: TextStyle(
                          color: Color(0xffffb3ad),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${dealer?['stack'] is num ? formatCurrencyAmount((dealer!['stack'] as num).toInt()) : '—'} VNĐ',
                        style: const TextStyle(
                          color: Color(0xffffddb8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _cardBack(),
                  const SizedBox(width: 5),
                  _cardBack(),
                  const SizedBox(width: 5),
                  _cardBack(),
                ],
              ),
              const SizedBox(height: 5),
              const Text(
                'Bài Chương được giữ riêng cho đến khi máy chủ công bố.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xffd8c3ad), fontSize: 9),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xaa0b0e14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      status == 'settled'
                          ? 'KẾT QUẢ BÀN ĐẤU'
                          : 'ĐANG CHỜ CHIA BÀI',
                      style: const TextStyle(
                        color: gold,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    if (status == 'settled' && points != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'BÀI CỦA BẠN • $points ĐIỂM',
                        style: TextStyle(
                          color: isWinner
                              ? const Color(0xff56e5a9)
                              : const Color(0xffffb3ad),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        isWinner
                            ? 'Bạn thắng ván • kết quả do máy chủ chốt'
                            : 'Kết quả đã được máy chủ chốt',
                        style: const TextStyle(
                          color: Color(0xffd8c3ad),
                          fontSize: 10,
                        ),
                      ),
                    ],
                    if (status == 'settled' && winnerUids.isNotEmpty)
                      Text(
                        'Người thắng: $winnerNames',
                        style: const TextStyle(
                          color: Color(0xffe1e2eb),
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final seat in seats.where((seat) => seat['uid'] != widget.uid))
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: _opponentSeat(
              seat,
              status,
              winnerUids.contains(seat['uid']),
            ),
          ),
        if (status == 'settled') _resultBanner(winnerNames, isWinner),
        if (status == 'settled') const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _panel(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, color: gold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      me == null ? 'BÀI RIÊNG' : '${_name(me)} (BẠN)',
                      style: const TextStyle(
                        color: gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    'Số dư ${me?['stack'] is num ? formatCurrencyAmount((me!['stack'] as num).toInt()) : '—'} VNĐ',
                    style: const TextStyle(
                      color: Color(0xffd8c3ad),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.visibility,
                    color: Color(0xff56e5a9),
                    size: 16,
                  ),
                  const Text(
                    'Lật Tự Động',
                    style: TextStyle(
                      color: Color(0xff56e5a9),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => showCards = !showCards),
                    icon: Icon(
                      showCards ? Icons.visibility : Icons.visibility_off,
                      color: gold,
                    ),
                  ),
                ],
              ),
              if (hand.length == 3) ...[
                AnimatedOpacity(
                  opacity: showCards ? 1 : .18,
                  duration: const Duration(milliseconds: 180),
                  child: Center(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final card in hand) _playingCard('$card'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Tổng: ${hand.map((c) => c.toString()).join(' + ')}  →  ${points ?? '—'} điểm',
                    style: const TextStyle(
                      color: Color(0xffe1e2eb),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xff0b0e14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CÔNG THỨC TÍNH: HÀNG ĐƠN VỊ TÍNH ĐIỂM',
                        style: TextStyle(
                          color: gold,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${hand.map((c) => c.toString()).join(' + ')} = ${_sum(hand)}  →  ${points ?? '—'} ĐIỂM',
                        style: const TextStyle(
                          color: Color(0xffe1e2eb),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                const Text(
                  'Bài riêng chỉ hiển thị sau khi máy chủ chia bài.',
                  style: TextStyle(color: Color(0xffd8c3ad), fontSize: 11),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 7) / 2;
            return Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                SizedBox(
                  width: width,
                  child: FilledButton.icon(
                    onPressed: widget.onNewTable,
                    icon: const Icon(Icons.replay),
                    label: const Text('VÁN MỚI', maxLines: 1, softWrap: false),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.workspace_premium),
                    label: const Text(
                      'CƯỚP CHƯƠNG',
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.local_fire_department),
                    label: const Text(
                      'GÓP TẨY x2',
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Container(
          decoration: _panel(),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.gavel, color: gold),
                title: const Text(
                  'Luật Ba Cây Chuẩn & Minh Bạch',
                  style: TextStyle(
                    color: Color(0xffe1e2eb),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                trailing: Icon(
                  rulesOpen ? Icons.expand_less : Icons.expand_more,
                  color: gold,
                ),
                onTap: () => setState(() => rulesOpen = !rulesOpen),
              ),
              if (rulesOpen)
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Text(
                    '• Bộ bài 36 lá: A đến 9.\n• Điểm bằng chữ số hàng đơn vị của tổng ba lá; 10 hoặc 20 tính 10 điểm.\n• Khi bằng điểm, so chất cao nhất: Rô, Cơ, Tép, Bích.\n• Mọi người so trực tiếp với Chương. Điểm chỉ dùng giải trí, không quy đổi tiền thật.',
                    style: TextStyle(
                      color: Color(0xffd8c3ad),
                      height: 1.45,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  BoxDecoration _panel() => BoxDecoration(
    color: const Color(0xff191c22),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xff534434)),
  );

  int _sum(List cards) => cards.fold<int>(0, (sum, card) {
    if (card is! String || card.isEmpty) return sum;
    final rank = card.substring(0, card.length - 1);
    return sum + (rank == 'A' ? 1 : int.tryParse(rank) ?? 0);
  });

  Widget _stat(String title, String value, IconData icon) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, color: gold, size: 14),
          const SizedBox(width: 3),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xffd8c3ad),
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      Text(
        value,
        style: const TextStyle(
          color: gold,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );

  Widget _cardBack() => Container(
    width: 42,
    height: 58,
    decoration: BoxDecoration(
      color: const Color(0xff272a31),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: gold),
    ),
    child: const Center(child: Icon(Icons.style, color: gold, size: 20)),
  );

  Widget _opponentSeat(Map seat, String status, bool isWinner) => Container(
    padding: const EdgeInsets.all(10),
    decoration: _panel(),
    child: Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xff272a31),
          child: Text(
            _name(seat).isEmpty ? '?' : _name(seat)[0].toUpperCase(),
            style: const TextStyle(color: gold, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _name(seat),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xffe1e2eb),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              Text(
                '${seat['stack'] is num ? formatCurrencyAmount((seat['stack'] as num).toInt()) : '—'} VNĐ • Bài được giữ riêng',
                style: const TextStyle(color: Color(0xffd8c3ad), fontSize: 9),
              ),
            ],
          ),
        ),
        if (status == 'settled')
          Text(
            isWinner ? 'THẮNG' : 'THUA',
            style: TextStyle(
              color: isWinner
                  ? const Color(0xff56e5a9)
                  : const Color(0xffffb3ad),
              fontWeight: FontWeight.bold,
              fontSize: 9,
            ),
          ),
        if (status != 'settled')
          const Text(
            'Bài ẩn',
            style: TextStyle(color: Color(0xffd8c3ad), fontSize: 9),
          ),
      ],
    ),
  );

  Widget _resultBanner(String winnerNames, bool isWinner) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: (isWinner ? const Color(0xff30c88f) : const Color(0xffa40217))
          .withValues(alpha: .2),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isWinner ? const Color(0xff56e5a9) : const Color(0xffffb3ad),
      ),
    ),
    child: Row(
      children: [
        Icon(
          isWinner ? Icons.emoji_events : Icons.info_outline,
          color: isWinner ? const Color(0xff56e5a9) : const Color(0xffffb3ad),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'KẾT QUẢ BÀN ĐẤU',
                style: TextStyle(
                  color: Color(0xff56e5a9),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                isWinner ? 'BẠN THẮNG CHƯƠNG' : 'VÁN ĐÃ KẾT THÚC',
                style: const TextStyle(
                  color: Color(0xffe1e2eb),
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Người thắng: $winnerNames',
                style: const TextStyle(color: Color(0xffd8c3ad), fontSize: 9),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _playingCard(String code) {
    final suitCode = code.isNotEmpty ? code.substring(code.length - 1) : 'S';
    final suit =
        const {'C': '♣', 'D': '♦', 'H': '♥', 'S': '♠'}[suitCode] ?? '♠';
    final suitName =
        const {'C': 'TÉP', 'D': 'RÔ', 'H': 'CƠ', 'S': 'BÍCH'}[suitCode] ??
        'BÍCH';
    final rank = code.length > 1 ? code.substring(0, code.length - 1) : '?';
    final red = suitCode == 'D' || suitCode == 'H';
    return Container(
      width: 88,
      height: 124,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xfff7f1e4),
        borderRadius: BorderRadius.circular(11),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                rank,
                style: TextStyle(
                  color: red
                      ? const Color(0xffb4232d)
                      : const Color(0xff181818),
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                ),
              ),
              Text(
                suit,
                style: TextStyle(
                  color: red
                      ? const Color(0xffb4232d)
                      : const Color(0xff181818),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: Text(
                suit,
                style: TextStyle(
                  color: red
                      ? const Color(0xffb4232d)
                      : const Color(0xff181818),
                  fontSize: 42,
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                suitName,
                style: TextStyle(
                  color: red
                      ? const Color(0xffb4232d)
                      : const Color(0xff181818),
                  fontWeight: FontWeight.bold,
                  fontSize: 8,
                ),
              ),
              Transform.rotate(
                angle: 3.14159,
                child: Text(
                  rank,
                  style: TextStyle(
                    color: red
                        ? const Color(0xffb4232d)
                        : const Color(0xff181818),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
