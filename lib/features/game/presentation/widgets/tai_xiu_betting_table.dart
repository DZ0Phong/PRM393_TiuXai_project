import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/currency_format.dart';
import '../../detailed_road_screen.dart';
import 'game_win_effect.dart';
import 'tai_xiu_dice.dart';

int validAllInStake(int balance, int remainingLimit) {
  final capped = balance < remainingLimit ? balance : remainingLimit;
  return capped < 1000 ? 0 : (capped ~/ 100) * 100;
}

/// Gold table UI for Tai Xiu. Chip selection and quick controls only prepare
/// a stake locally; the server remains the authority for accepting bets.
class TaiXiuBettingTable extends StatefulWidget {
  final String roundId;
  final String status;
  final int secondsLeft;
  final int balance;
  final bool enabled;
  final int confirmedAmount;
  final int confirmedRefund;
  final int? confirmedCredit;
  final String? confirmedSide;
  final Map<String, int> totalBySide;
  final Map<String, int> playerCountsBySide;
  final List<dynamic>? dice;
  final Map<String, dynamic>? outcome;
  final Future<void> Function(String side, int amount) onPlaceBet;

  const TaiXiuBettingTable({
    super.key,
    required this.roundId,
    required this.status,
    required this.secondsLeft,
    required this.balance,
    required this.enabled,
    this.confirmedAmount = 0,
    this.confirmedRefund = 0,
    this.confirmedCredit,
    this.confirmedSide,
    this.totalBySide = const {},
    this.playerCountsBySide = const {},
    this.dice,
    this.outcome,
    required this.onPlaceBet,
  });

  @override
  State<TaiXiuBettingTable> createState() => _TaiXiuBettingTableState();
}

class _TaiXiuBettingTableState extends State<TaiXiuBettingTable> {
  static const gold = Color(0xffd4af37);
  static const chips = [
    1000,
    10000,
    50000,
    100000,
    500000,
    1000000,
    5000000,
    10000000,
  ];
  int? selectedChip;
  bool allInSelected = false;
  int tai = 0;
  int xiu = 0;
  bool sending = false;
  bool shakeDice = false;
  bool manualPeek = false;
  bool lidOpen = false;
  bool draggingLid = false;
  Offset lidDragStart = Offset.zero;
  Offset lidDragOffset = Offset.zero;
  Offset lidOpenOffset = const Offset(0, -210);
  int previousTai = 0;
  int previousXiu = 0;
  final chatInput = TextEditingController();
  final chatLines = <(String, String)>[
    ('sihdhdhdid', 'húp tài'),
    ('hoangg20j', 'thun10 taybthong'),
    ('da03456', 'Quyết tâm'),
    ('xinadlen3tr', 'xỉu mà'),
    ('hungbesbonn', 'Xxxxx'),
    ('6_ben_6', 'S24 hô nét'),
  ];

  @override
  void initState() {
    super.initState();
    lidOpen = widget.status == 'settled';
  }

  @override
  void dispose() {
    chatInput.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TaiXiuBettingTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roundId != widget.roundId) {
      tai = 0;
      xiu = 0;
      previousTai = 0;
      previousXiu = 0;
      allInSelected = false;
      selectedChip = null;
      lidOpen = false;
      manualPeek = false;
      draggingLid = false;
      lidDragStart = Offset.zero;
      lidDragOffset = Offset.zero;
      lidOpenOffset = const Offset(0, -210);
    }
    if (oldWidget.status == 'open' && widget.status != 'open') {
      selectedChip = null;
      allInSelected = false;
    }
    if (oldWidget.status != 'settled' && widget.status == 'settled') {
      // In manual mode, keep the bowl closed after settlement until the
      // player drags it away. Automatic mode reveals the dice immediately.
      lidOpen = !manualPeek;
      lidOpenOffset = const Offset(0, -210);
      lidDragOffset = lidOpen ? lidOpenOffset : Offset.zero;
    }
    if (oldWidget.status == 'settled' && widget.status != 'settled') {
      lidOpen = false;
      lidDragOffset = Offset.zero;
    }
  }

  String format(int value) => formatCurrencyAmount(value);

  int get _draftTotal => tai + xiu;
  int get _remainingRoundLimit =>
      (1000000 - widget.confirmedAmount - _draftTotal).clamp(0, 1000000);
  int get _allInAmount => validAllInStake(
    (widget.balance - _draftTotal).clamp(0, 1000000),
    _remainingRoundLimit,
  );

  String? get _activeSide => widget.confirmedAmount > 0
      ? widget.confirmedSide
      : tai > 0
      ? 'tai'
      : xiu > 0
      ? 'xiu'
      : null;

  void _add(String side) {
    if (_activeSide != null && _activeSide != side) {
      _info('Tài Xỉu chỉ cho phép đặt một cửa trong mỗi phiên.');
      return;
    }
    final amount = allInSelected ? _allInAmount : (selectedChip ?? 0);
    if (amount == 0) {
      _info('Hãy chọn mệnh giá chip trước khi đặt cược.');
      return;
    }
    if (amount < 1000 ||
        amount % 100 != 0 ||
        amount > widget.balance - _draftTotal ||
        amount > _remainingRoundLimit) {
      _info('Mỗi phiên tối đa 1.000.000 VNĐ và không vượt số dư.');
      return;
    }
    setState(() {
      if (side == 'tai') {
        tai += amount;
      } else {
        xiu += amount;
      }
      allInSelected = false;
    });
  }

  void _repeatDraft() {
    final side = widget.confirmedAmount > 0
        ? widget.confirmedSide
        : previousTai > 0
        ? 'tai'
        : previousXiu > 0
        ? 'xiu'
        : null;
    if (side == null) return;
    if (_activeSide != null && _activeSide != side) {
      _info('Không thể đổi cửa sau khi đã đặt cược trong phiên này.');
      return;
    }
    final amount = side == 'tai' ? previousTai : previousXiu;
    final safeAmount = amount.clamp(
      0,
      widget.balance < _remainingRoundLimit
          ? widget.balance
          : _remainingRoundLimit,
    );
    setState(() {
      allInSelected = false;
      if (side == 'tai') {
        tai = safeAmount;
        xiu = 0;
      } else {
        xiu = safeAmount;
        tai = 0;
      }
    });
  }

  void _doubleDraft() {
    final side = _activeSide;
    if (side == null) return;
    final current = side == 'tai' ? tai : xiu;
    final doubled = current * 2;
    if (doubled > widget.balance ||
        doubled > 1000000 - widget.confirmedAmount) {
      _info('Gấp đôi sẽ vượt số dư hoặc giới hạn 1.000.000 VNĐ/phiên.');
      return;
    }
    setState(() {
      allInSelected = false;
      if (side == 'tai') {
        tai = doubled;
      } else {
        xiu = doubled;
      }
    });
  }

  String get _resultSummary {
    final dice = widget.dice;
    if (widget.status != 'settled' || dice == null || dice.length != 3) {
      return 'Kết quả sẽ hiện khi máy chủ chốt phiên.';
    }
    final total =
        widget.outcome?['total'] ??
        dice.fold<int>(
          0,
          (sum, value) => sum + (value is num ? value.toInt() : 0),
        );
    final side = widget.outcome?['triple'] == true
        ? 'BỘ BA • THUA CẢ TÀI VÀ XỈU'
        : widget.outcome?['side']?.toString().toUpperCase() ??
              (total > 10 ? 'TÀI' : 'XỈU');
    return 'Kết quả phiên #${widget.roundId}: ${dice.join(' + ')} = $total • $side';
  }

  Future<void> _place(String side, int amount) async {
    if (!widget.enabled || sending || amount <= 0) return;
    if (amount < 1000 || amount % 100 != 0) {
      _info('Cược tối thiểu 1.000 VNĐ và phải là bội số 100.');
      return;
    }
    if ((_activeSide != null && _activeSide != side) ||
        amount > widget.balance ||
        amount + widget.confirmedAmount > 1000000) {
      _info('Cửa cược hoặc tổng tiền không còn hợp lệ với số dư phiên này.');
      return;
    }
    setState(() => sending = true);
    try {
      await widget.onPlaceBet(side, amount);
      if (!mounted) return;
      setState(() {
        if (side == 'tai') {
          previousTai = tai;
          tai = 0;
        }
        if (side == 'xiu') {
          previousXiu = xiu;
          xiu = 0;
        }
      });
    } catch (error) {
      if (mounted) {
        _info(
          error is FirebaseFunctionsException
              ? (error.message ?? 'Máy chủ không nhận cược.')
              : 'Chưa xác nhận cược; xem thông báo phía trên.',
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !sending;
    return GameWinEffect(
      roundId: widget.roundId,
      status: widget.status,
      betAmount: widget.confirmedAmount,
      credit: widget.confirmedCredit,
      revealAllowed: !manualPeek || lidOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _roundAction(
                Icons.arrow_back_ios_new,
                'Thoát bàn',
                () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 3),
              _roundAction(
                Icons.volume_up,
                'Âm thanh',
                () => _info('Âm thanh chưa được tích hợp.'),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'PHIÊN CƯỢC',
                    style: TextStyle(
                      color: Color(0xffa08e7a),
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Text(
                      '#${widget.roundId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: gold,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 5),
              SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: (widget.secondsLeft.clamp(0, 30) / 30).toDouble(),
                      strokeWidth: 2,
                      backgroundColor: const Color(0xff32353c),
                      color: gold,
                    ),
                    Text(
                      '${widget.secondsLeft.clamp(0, 999)}s',
                      style: const TextStyle(
                        color: gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'LIVE',
                style: TextStyle(
                  color: Color(0xffffb3ad),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _roundAction(
                Icons.menu,
                'Tùy chọn',
                () => _info('Bàn cược điểm mô phỏng.'),
              ),
            ],
          ),
          _dealerStream(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff10131a),
              border: Border.all(color: const Color(0xff534434)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
              child: Column(
                children: [
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    // Leave enough vertical room for the amount and the
                    // per-side submit button on narrow phone screens.
                    childAspectRatio: 0.82,
                    children: [
                      _betSide(
                        title: 'XỈU',
                        range: '4 – 10 • trừ bộ ba',
                        amount:
                            xiu +
                            (widget.confirmedSide == 'xiu'
                                ? widget.confirmedAmount
                                : 0),
                        tint: const Color(0xff27d39a),
                        totalBet: widget.totalBySide['xiu'] ?? 0,
                        refunded: widget.confirmedSide == 'xiu'
                            ? widget.confirmedRefund
                            : 0,
                        players: widget.playerCountsBySide['xiu'] ?? 0,
                        canSubmit: xiu > 0,
                        onAdd: () => _add('xiu'),
                        onSubmit: () => _place('xiu', xiu),
                      ),
                      _betSide(
                        title: 'TÀI',
                        range: '11 – 17 • trừ bộ ba',
                        amount:
                            tai +
                            (widget.confirmedSide == 'tai'
                                ? widget.confirmedAmount
                                : 0),
                        tint: const Color(0xffff737d),
                        totalBet: widget.totalBySide['tai'] ?? 0,
                        refunded: widget.confirmedSide == 'tai'
                            ? widget.confirmedRefund
                            : 0,
                        players: widget.playerCountsBySide['tai'] ?? 0,
                        canSubmit: tai > 0,
                        onAdd: () => _add('tai'),
                        onSubmit: () => _place('tai', tai),
                      ),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xff191c22),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0xff534434)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: Color(0xffffb95f),
                        ),
                        const SizedBox(width: 7),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BÃO BẤT KỲ',
                                style: TextStyle(
                                  color: Color(0xffffc174),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                'Ba mặt xúc xắc đồng chất • chỉ hiển thị',
                                style: TextStyle(
                                  color: Color(0xffd8c3ad),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          '1 : 30',
                          style: TextStyle(
                            color: Color(0xffffddb8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        color: gold,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Số dư: ${format(widget.balance)} VNĐ',
                          style: const TextStyle(
                            color: Color(0xffffc174),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        active ? 'ĐANG MỞ CƯỢC' : 'ĐÃ KHÓA',
                        style: TextStyle(
                          color: active
                              ? const Color(0xff56e5a9)
                              : const Color(0xffffb3ad),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: 8, left: 3),
                      child: Text(
                        'CHỌN CHIP',
                        style: TextStyle(
                          color: Color(0xffd8c3ad),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final chip in chips)
                          Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: ChoiceChip(
                              label: Text(_chipLabel(chip)),
                              selected: selectedChip == chip,
                              onSelected:
                                  active &&
                                      chip <= _remainingRoundLimit &&
                                      chip <= widget.balance - _draftTotal
                                  ? (_) => setState(() {
                                      selectedChip = chip;
                                      allInSelected = false;
                                    })
                                  : null,
                              selectedColor: gold,
                              backgroundColor: const Color(0xff32353c),
                              labelStyle: TextStyle(
                                color: selectedChip == chip
                                    ? const Color(0xff2a1700)
                                    : chip > _remainingRoundLimit ||
                                          chip > widget.balance - _draftTotal
                                    ? const Color(0xff777777)
                                    : const Color(0xffe1e2eb),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ChoiceChip(
                    label: Text('ALL IN • ${format(_allInAmount)} VNĐ'),
                    selected: allInSelected,
                    onSelected: active && _allInAmount > 0
                        ? (_) => setState(() => allInSelected = true)
                        : null,
                    selectedColor: const Color(0xfff59e0b),
                    backgroundColor: const Color(0xff32353c),
                    labelStyle: TextStyle(
                      color: allInSelected
                          ? const Color(0xff2a1700)
                          : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _quickButton(
                          'HỦY CƯỢC',
                          Icons.close,
                          () => setState(() {
                            tai = 0;
                            xiu = 0;
                            allInSelected = false;
                          }),
                          active,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _quickButton(
                          'CƯỢC LẠI',
                          Icons.history,
                          _repeatDraft,
                          active,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _quickButton(
                          '+2 GẤP ĐÔI',
                          Icons.exposure_plus_2,
                          _doubleDraft,
                          active,
                          gold: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff1b171c), Color(0xff0f0c10)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xff83632f)),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.chat, color: gold, size: 17),
                    SizedBox(width: 6),
                    Text(
                      'CHAT BÀN (MÔ PHỎNG)',
                      style: TextStyle(
                        color: gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                for (final line in chatLines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      children: [
                        Text(
                          '${line.$1}: ',
                          style: const TextStyle(
                            color: Color(0xffffb95f),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            line.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xffe1e2eb),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(color: Color(0xff3e2e16), height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: chatInput,
                        style: const TextStyle(
                          color: Color(0xffe1e2eb),
                          fontSize: 12,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Nhập nội dung chat',
                          isDense: true,
                          filled: true,
                          fillColor: Color(0xff0d0a0e),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      onPressed: () {
                        final text = chatInput.text.trim();
                        if (text.isEmpty) return;
                        setState(() {
                          chatLines.add(('Bạn', text));
                          if (chatLines.length > 8) chatLines.removeAt(0);
                          chatInput.clear();
                        });
                      },
                      icon: const Icon(Icons.send, size: 16),
                      style: IconButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: const Color(0xff2a1700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DetailedRoadScreen(),
              ),
            ),
            icon: const Icon(Icons.analytics, size: 16),
            label: const Text('Soi cầu chi tiết · Giọt Nước & Big Road'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xffd8c3ad),
              side: const BorderSide(color: Color(0xff534434)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dealerStream() => Container(
    height: 280,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xff534434)),
      image: const DecorationImage(
        image: NetworkImage(
          'https://lh3.googleusercontent.com/aida-public/AB6AXuB2n4Qkr5PVh6Ew4LvYU6D4rBgmlwrZFjEVItJqj0S9XOzrMvtYsv-6JJ3Nds64wR_85s488qA4K3bagYwpijiw9QiHRjgfToBYuvZo9Z5lhAVlcPnVXEs8_DDT8gdBxTYao5eiO4zUDNpBAKe_5VNBVBive1iId3RHgjLXj7Nsys-ZUS7JBiu8vE0nvFAvVoSo8J68k_DuNHUWM2xx3ERA-U9np7D3XOfBBp1XVfw',
        ),
        fit: BoxFit.cover,
        colorFilter: ColorFilter.mode(Color(0xb3000000), BlendMode.darken),
      ),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Row(
                children: [
                  Icon(Icons.person, color: Color(0xff56e5a9), size: 17),
                  SizedBox(width: 5),
                  Text(
                    'Dealer bàn cược',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xff0b0e14).withValues(alpha: .85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  _modeButton(
                    'Mở Tự Động',
                    !manualPeek,
                    () => setState(() {
                      manualPeek = false;
                      lidOpen = widget.status == 'settled';
                      lidOpenOffset = const Offset(0, -210);
                      lidDragOffset = lidOpen ? lidOpenOffset : Offset.zero;
                    }),
                  ),
                  _modeButton(
                    'Nặn 3D',
                    manualPeek,
                    () => setState(() {
                      manualPeek = true;
                      lidOpen = false;
                      lidDragOffset = Offset.zero;
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Spacer(),
        Stack(
          alignment: Alignment.center,
          children: [
            AnimatedScale(
              scale: shakeDice ? 1.06 : 1,
              duration: const Duration(milliseconds: 180),
              child: Container(
                width: 162,
                height: 162,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xfff59e0b),
                      Color(0xff32353c),
                      Color(0xff0b0e14),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border.all(color: const Color(0xffffc174), width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black87, blurRadius: 20),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xee0b0e14),
                      border: Border.all(color: const Color(0xff534434)),
                    ),
                    child: Center(
                      child:
                          widget.status == 'settled' &&
                              widget.dice != null &&
                              widget.dice!.length == 3
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [TaiXiuDice(values: widget.dice!)],
                            )
                          : const Text(
                              '⚄   ⚄   ⚄',
                              style: TextStyle(
                                color: Color(0xffa08e7a),
                                fontSize: 22,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedSlide(
              offset: Offset(lidDragOffset.dx / 162, lidDragOffset.dy / 162),
              duration: draggingLid
                  ? Duration.zero
                  : const Duration(milliseconds: 350),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: manualPeek && widget.status == 'settled' && !lidOpen
                    ? (_) => setState(() {
                        draggingLid = true;
                        lidDragStart = Offset.zero;
                        lidDragOffset = lidDragStart;
                      })
                    : null,
                onPanUpdate:
                    manualPeek && widget.status == 'settled' && !lidOpen
                    ? (details) => setState(() {
                        final next = lidDragOffset + details.delta;
                        final distance = next.distance;
                        lidDragOffset = distance > 210
                            ? Offset(
                                next.dx / distance * 210,
                                next.dy / distance * 210,
                              )
                            : next;
                      })
                    : null,
                onPanEnd: manualPeek && widget.status == 'settled' && !lidOpen
                    ? (_) {
                        final movement = lidDragOffset - lidDragStart;
                        final distance = movement.distance;
                        setState(() {
                          draggingLid = false;
                          if (distance >= 150) {
                            lidOpen = true;
                            lidOpenOffset = Offset(
                              movement.dx / distance * 210,
                              movement.dy / distance * 210,
                            );
                            lidDragOffset = lidOpenOffset;
                          } else {
                            lidDragOffset = Offset.zero;
                          }
                        });
                      }
                    : null,
                onPanCancel:
                    manualPeek && widget.status == 'settled' && !lidOpen
                    ? () => setState(() {
                        draggingLid = false;
                        lidDragOffset = Offset.zero;
                      })
                    : null,
                child: Container(
                  width: 162,
                  height: 162,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xffffddb8),
                        Color(0xfff59e0b),
                        Color(0xff653e00),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: const Color(0xffffc174),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black87, blurRadius: 14),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        size: 38,
                        color: Color(0xff472a00),
                      ),
                      const Text(
                        'RỒNG VÀNG',
                        style: TextStyle(
                          color: Color(0xff472a00),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        manualPeek ? 'Kéo bát ra để mở' : 'Mở tự động',
                        style: const TextStyle(
                          color: Color(0xff472a00),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        if (!manualPeek || lidOpen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xee272a31),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              _resultSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.status == 'settled'
                    ? const Color(0xffffb3ad)
                    : const Color(0xffd8c3ad),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _modeButton(String label, bool selected, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 30),
            padding: const EdgeInsets.symmetric(horizontal: 9),
            backgroundColor: selected ? gold : Colors.transparent,
            foregroundColor: selected
                ? const Color(0xff472a00)
                : const Color(0xffd8c3ad),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ),
      );

  String _chipLabel(int value) =>
      value >= 1000000 ? '${value ~/ 1000000}M' : '${value ~/ 1000}K';

  Widget _betSide({
    required String title,
    required String range,
    required int amount,
    required int refunded,
    required Color tint,
    required int totalBet,
    required int players,
    required bool canSubmit,
    required VoidCallback onAdd,
    required VoidCallback onSubmit,
  }) => Column(
    children: [
      Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: widget.enabled && !sending ? onAdd : null,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            width: double.infinity,
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.alphaBlend(
                    tint.withValues(alpha: .22),
                    const Color(0xff1c2028),
                  ),
                  const Color(0xff0d1016),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border.all(
                color: amount > 0 ? tint : tint.withValues(alpha: .78),
                width: amount > 0 ? 2.5 : 2,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 8),
              ],
            ),
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    color: tint,
                    shadows: const [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                Text(
                  range,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xffffc174), fontSize: 9),
                ),
                const SizedBox(height: 3),
                Text(
                  'Bạn cược: ${format(amount)} VNĐ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tint,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (refunded > 0)
                  Text(
                    'Hoàn cân cửa: ${format(refunded)} xu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xff27d39a),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                Text(
                  'Tổng: ${format(totalBet)} VNĐ • $players người',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xffe1e2eb),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      SizedBox(
        width: double.infinity,
        height: 32,
        child: FilledButton(
          onPressed: canSubmit && widget.enabled && !sending ? onSubmit : null,
          style: FilledButton.styleFrom(
            backgroundColor: tint,
            foregroundColor: const Color(0xff10131a),
            disabledBackgroundColor: tint.withValues(alpha: .3),
            disabledForegroundColor: const Color(0xffe1e2eb),
            padding: EdgeInsets.zero,
            textStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          child: const Text('ĐẶT CƯỢC', maxLines: 1, softWrap: false),
        ),
      ),
    ],
  );

  Widget _roundAction(IconData icon, String label, VoidCallback action) =>
      IconButton(
        tooltip: label,
        onPressed: action,
        icon: Icon(icon, color: const Color(0xffffd777), size: 18),
        style: IconButton.styleFrom(
          minimumSize: const Size(38, 38),
          fixedSize: const Size(38, 38),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          backgroundColor: const Color(0xff2a1a0c),
          side: const BorderSide(color: Color(0xffd4af37)),
        ),
      );

  Widget _quickButton(
    String label,
    IconData icon,
    VoidCallback onTap,
    bool active, {
    bool gold = false,
  }) => OutlinedButton.icon(
    onPressed: active ? onTap : null,
    icon: Icon(icon, size: 14),
    label: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
      ),
    ),
    style: OutlinedButton.styleFrom(
      backgroundColor: gold ? const Color(0xfff59e0b) : const Color(0xff272a31),
      foregroundColor: gold ? const Color(0xff2a1700) : const Color(0xffe1e2eb),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      side: const BorderSide(color: Color(0xff534434)),
    ),
  );

  void _info(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
