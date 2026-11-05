import 'package:flutter/material.dart';

import 'game_win_effect.dart';

class BauCuaBettingTable extends StatefulWidget {
  final String roundId;
  final String status;
  final int secondsLeft;
  final int balance;
  final List<dynamic>? result;
  final int? confirmedCredit;
  final bool enabled;
  final Map<String, int> confirmedBets;
  final Future<void> Function(String side, int amount) onPlaceBet;
  final Future<void> Function() onRefundBet;

  const BauCuaBettingTable({
    super.key,
    required this.roundId,
    required this.status,
    required this.secondsLeft,
    required this.balance,
    this.result,
    this.confirmedCredit,
    required this.enabled,
    this.confirmedBets = const {},
    required this.onPlaceBet,
    required this.onRefundBet,
  });

  @override
  State<BauCuaBettingTable> createState() => _BauCuaBettingTableState();
}

class _BauCuaBettingTableState extends State<BauCuaBettingTable> {
  static const gold = Color(0xffffc174);
  static const surface = Color(0xff191c22);
  static const symbols = [
    ('nai', 'HƯƠU', '🦌', Icons.cruelty_free),
    ('bau', 'BẦU', '🍈', Icons.egg_alt),
    ('ga', 'GÀ', '🐓', Icons.flutter_dash),
    ('ca', 'CÁ', '🐟', Icons.set_meal),
    ('cua', 'CUA', '🦀', Icons.pest_control),
    ('tom', 'TÔM', '🦐', Icons.waves),
  ];
  static const chips = [1000, 10000, 50000, 100000, 500000, 1000000];
  final Map<String, int> bets = {for (final item in symbols) item.$1: 0};
  int chip = 10000;
  bool allInSelected = false;
  bool sending = false;
  bool invalidCustomAmount = false;
  final TextEditingController customAmount = TextEditingController(
    text: '10000',
  );

  @override
  void dispose() {
    customAmount.dispose();
    super.dispose();
  }

  int get total => bets.values.fold(0, (sum, value) => sum + value);
  int get confirmedTotal =>
      widget.confirmedBets.values.fold(0, (sum, value) => sum + value);

  int get allInAmount {
    final available = (widget.balance - total).clamp(0, 1000000);
    final limit = 1000000 - confirmedTotal - total;
    final amount = available < limit ? available : limit;
    final valid = amount - amount % 100;
    return valid >= 1000 ? valid : 0;
  }

  @override
  void didUpdateWidget(covariant BauCuaBettingTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roundId != widget.roundId) {
      bets.updateAll((_, _) => 0);
      allInSelected = false;
      invalidCustomAmount = false;
      customAmount.text = '$chip';
      sending = false;
    }
  }

  bool get canBet =>
      widget.enabled &&
      widget.status == 'open' &&
      widget.secondsLeft > 0 &&
      !sending;
  bool get canSubmit =>
      canBet &&
      total > 0 &&
      total <= widget.balance &&
      total + confirmedTotal <= 1000000;

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _addBet(String side) {
    if (!canBet) return;
    if ((!allInSelected && invalidCustomAmount) ||
        (!allInSelected &&
            (chip < 1000 || chip > 1000000 || chip % 100 != 0))) {
      _notice('Mức cược tối thiểu 1.000 điểm và phải là bội số 100.');
      return;
    }
    final amount = allInSelected ? allInAmount : chip;
    if (amount <= 0 ||
        total + confirmedTotal + amount > 1000000 ||
        total + amount > widget.balance) {
      _notice('Tổng cược mỗi phiên tối đa 1.000.000 điểm và không vượt số dư.');
      return;
    }
    setState(() {
      bets[side] = bets[side]! + amount;
      allInSelected = false;
    });
  }

  String fmt(int value) => value.toString().replaceAllMapped(
    RegExp(r'(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );

  @override
  Widget build(BuildContext context) {
    final resultFaces = widget.result
        ?.map((face) => symbols.where((item) => item.$1 == face).toList())
        .where((matches) => matches.isNotEmpty)
        .map((matches) => matches.first)
        .toList();
    return GameWinEffect(
      roundId: widget.roundId,
      status: widget.status,
      betAmount: confirmedTotal,
      credit: widget.confirmedCredit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xff0b0e14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xff534434)),
            ),
            child: Row(
              children: [
                const Icon(Icons.casino, color: gold),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'BẦU CUA • BÀN XU ẢO',
                    style: TextStyle(
                      color: gold,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff272a31),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 104,
                        child: Text(
                          '#${widget.roundId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      Text(
                        '${widget.secondsLeft.clamp(0, 999)}s',
                        style: const TextStyle(
                          color: gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 116,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const RadialGradient(
                colors: [
                  Color(0xff453017),
                  Color(0xff17120d),
                  Color(0xff0b0e14),
                ],
              ),
              border: Border.all(color: const Color(0xff8c6b32)),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 14),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xff8e682d), Color(0xff1a1208)],
                    ),
                    border: Border.all(color: gold, width: 2),
                  ),
                  child: Center(
                    child: widget.status == 'settled' && resultFaces != null
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final face in resultFaces)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: Text(
                                      face.$3,
                                      style: const TextStyle(fontSize: 26),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : const Text('🥣', style: TextStyle(fontSize: 46)),
                  ),
                ),
                Positioned(
                  left: 24,
                  top: 18,
                  child: Text(
                    widget.status == 'settled' ? '✨' : '🎲',
                    style: TextStyle(
                      fontSize: 28,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 8),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 25,
                  bottom: 15,
                  child: Text(
                    widget.status == 'settled' ? '🎉' : '🪙',
                    style: TextStyle(
                      fontSize: 27,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 8),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 12,
                  child: Text(
                    widget.status == 'settled'
                        ? 'KẾT QUẢ'
                        : canBet
                        ? 'ĐANG MỞ CƯỢC'
                        : 'ĐÃ KHÓA',
                    style: TextStyle(
                      color: canBet
                          ? const Color(0xff56e5a9)
                          : const Color(0xffffb3ad),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: symbols.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: .94,
            ),
            itemBuilder: (context, index) {
              final item = symbols[index];
              final amount =
                  bets[item.$1]! + (widget.confirmedBets[item.$1] ?? 0);
              return Material(
                color: amount > 0
                    ? const Color(0xff272a31)
                    : const Color(0xff0b0e14),
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  onTap: canBet ? () => _addBet(item.$1) : null,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: amount > 0 ? gold : const Color(0xff32353c),
                        width: amount > 0 ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.$4, size: 20, color: gold),
                        Text(
                          item.$2,
                          style: const TextStyle(
                            color: Color(0xffe1e2eb),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '1 : 1.98',
                          style: const TextStyle(
                            color: Color(0xffd8c3ad),
                            fontSize: 9,
                          ),
                        ),
                        Text(
                          'Cược: ${fmt(amount)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: amount > 0 ? gold : const Color(0xffa08e7a),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          if (widget.status == 'settled' && resultFaces != null) ...[
            const SizedBox(height: 8),
            Text(
              'Kết quả: ${resultFaces.map((face) => face.$2).join(' • ')}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: gold, fontWeight: FontWeight.bold),
            ),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xff534434)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: gold,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Số dư xu ảo: ${fmt(widget.balance)}',
                        style: const TextStyle(
                          color: gold,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      'Tổng cược: ${fmt(total + confirmedTotal)}',
                      style: const TextStyle(
                        color: Color(0xffe1e2eb),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'CHỌN MỆNH GIÁ',
                  style: TextStyle(
                    color: Color(0xffd8c3ad),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final value in chips)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              value >= 1000000
                                  ? '${value ~/ 1000000}M'
                                  : '${value ~/ 1000}K',
                            ),
                            selected: chip == value,
                            onSelected: canBet
                                ? (_) => setState(() {
                                    chip = value;
                                    allInSelected = false;
                                    customAmount.text = '$value';
                                    invalidCustomAmount = false;
                                  })
                                : null,
                            selectedColor: gold,
                            backgroundColor: const Color(0xff32353c),
                            labelStyle: TextStyle(
                              color: chip == value
                                  ? const Color(0xff2a1700)
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text('ALL IN • ${fmt(allInAmount)}'),
                          selected: allInSelected,
                          onSelected: canBet && allInAmount > 0
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
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: customAmount,
                  enabled: canBet,
                  keyboardType: TextInputType.number,
                  onChanged: (text) {
                    final value = int.tryParse(text);
                    final valid =
                        value != null &&
                        value >= 1000 &&
                        value <= 1000000 &&
                        value % 100 == 0;
                    setState(() {
                      invalidCustomAmount = !valid;
                      allInSelected = false;
                      if (valid) chip = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText:
                        'Mệnh giá tùy chỉnh (tối thiểu 1.000, bội số 100)',
                    errorText: invalidCustomAmount
                        ? 'Số tiền cược không hợp lệ'
                        : null,
                    prefixIcon: Icon(Icons.tune, color: gold),
                    isDense: true,
                    filled: true,
                    fillColor: Color(0xff0b0e14),
                    border: OutlineInputBorder(),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: canBet ? _refundAndReset : null,
                        icon: const Icon(Icons.replay, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('CƯỢC LẠI', maxLines: 1, softWrap: false),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xffe1e2eb),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: canSubmit ? _submit : null,
                        icon: const Icon(Icons.how_to_reg, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('XÁC NHẬN', maxLines: 1, softWrap: false),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: const Color(0xff2a1700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Đang cược bằng điểm mô phỏng • Không nạp hoặc rút tiền thật',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .55),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!canSubmit) return;
    final roundId = widget.roundId;
    final selected = bets.entries.where((entry) => entry.value > 0).toList();
    final placeBet = widget.onPlaceBet;
    String? attemptedSide;
    setState(() => sending = true);
    try {
      for (final entry in selected) {
        if (!mounted ||
            widget.roundId != roundId ||
            widget.status != 'open' ||
            widget.secondsLeft <= 0 ||
            entry.value > widget.balance ||
            entry.value + confirmedTotal > 1000000) {
          break;
        }
        attemptedSide = entry.key;
        await placeBet(entry.key, entry.value);
        if (!mounted || widget.roundId != roundId) break;
        setState(() => bets[entry.key] = 0);
        attemptedSide = null;
      }
    } catch (error) {
      if (mounted && widget.roundId == roundId) {
        // A network failure can mean the server accepted the bet; never replay its draft.
        if (attemptedSide != null) {
          setState(() => bets[attemptedSide!] = 0);
        }
        _notice(
          'Chưa xác nhận được cửa vừa gửi; kiểm tra cược trên máy chủ trước khi chọn lại: $error',
        );
      }
    } finally {
      if (mounted && widget.roundId == roundId) {
        setState(() => sending = false);
      }
    }
  }

  Future<void> _refundAndReset() async {
    if (!canBet) return;
    final roundId = widget.roundId;
    final refundBet = widget.onRefundBet;
    setState(() => sending = true);
    try {
      final hadConfirmedBet = confirmedTotal > 0;
      if (hadConfirmedBet) await refundBet();
      if (!mounted || widget.roundId != roundId) return;
      setState(() {
        bets.updateAll((_, _) => 0);
        allInSelected = false;
      });
      _notice(
        hadConfirmedBet
            ? 'Đã hoàn cược Bầu Cua về số dư.'
            : 'Đã xóa lựa chọn cược chưa xác nhận.',
      );
    } catch (error) {
      if (mounted && widget.roundId == roundId) {
        _notice('Chưa hoàn được cược: $error');
      }
    } finally {
      if (mounted && widget.roundId == roundId) {
        setState(() => sending = false);
      }
    }
  }
}
