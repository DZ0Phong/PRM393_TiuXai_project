import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../../core/bet_failure_notice.dart';
import '../../../../../core/currency_format.dart';
import '../game_win_effect.dart';

/// Xóc Xóc play screen. Bets and outcomes remain server-authoritative.
class XocXocBettingTable extends StatefulWidget {
  final String roundId;
  final String mode;
  final String status;
  final int secondsLeft;
  final int? balance;
  final bool enabled;
  final bool offline;
  final List<dynamic>? result;
  final int? confirmedCredit;
  final Map<String, int> confirmedBets;
  final Future<void> Function(Map<String, int> stakes) onPlaceBets;

  const XocXocBettingTable({
    super.key,
    required this.roundId,
    required this.mode,
    required this.status,
    required this.secondsLeft,
    required this.balance,
    required this.enabled,
    this.offline = false,
    required this.result,
    this.confirmedCredit,
    this.confirmedBets = const {},
    required this.onPlaceBets,
  });

  @override
  State<XocXocBettingTable> createState() => _XocXocBettingTableState();
}

class _XocXocBettingTableState extends State<XocXocBettingTable> {
  static const gold = Color(0xffffc174);
  static const chips = [1000, 10000, 50000, 100000, 1000000];
  static const gates = <(String, String, String, String)>[
    ('chan', 'CHẴN', '4 Đỏ / 4 Trắng / 2-2', '1.98x'),
    ('le', 'LẺ', '3 Đỏ 1 Trắng / 3 Trắng 1 Đỏ', '1.98x'),
    ('red3', '3 ĐỎ 1 TRẮNG', 'Đúng 3 mặt đỏ', '3.94x'),
    ('white3', '3 TRẮNG 1 ĐỎ', 'Đúng 3 mặt trắng', '3.94x'),
    ('red4', '4 ĐỎ', 'Cả 4 mặt đỏ', '14.7x'),
    ('white4', '4 TRẮNG', 'Cả 4 mặt trắng', '14.7x'),
  ];

  final bets = <String, int>{for (final gate in gates) gate.$1: 0};
  final acknowledgedBets = <String, int>{};
  Map<String, int>? awaitingBets;
  Map<String, int>? awaitingBaseline;
  int? lastKnownBalance;
  int? optimisticBalance;
  int selectedChip = 10000;
  bool allInSelected = false;
  bool sending = false;
  bool revealed = false;
  bool rulesOpen = false;

  int get total =>
      bets.values.fold(0, (accumulated, value) => accumulated + value);
  int confirmed(String side) {
    final server = widget.confirmedBets[side] ?? 0;
    final acknowledged = acknowledgedBets[side] ?? 0;
    return server > acknowledged ? server : acknowledged;
  }

  int get confirmedTotal => gates.fold(
    0,
    (totalConfirmed, gate) => totalConfirmed + confirmed(gate.$1),
  );
  int? get displayBalance {
    final known = widget.balance ?? lastKnownBalance;
    if (known == null) return optimisticBalance;
    if (optimisticBalance == null) return known;
    return known < optimisticBalance! ? known : optimisticBalance;
  }

  int get allInAmount {
    final balance = displayBalance;
    if (balance == null) return 0;
    final available = (balance - total).clamp(0, 1000000);
    final limit = 1000000 - confirmedTotal - total;
    final amount = available < limit ? available : limit;
    final valid = amount - amount % 1000;
    return valid >= 1000 ? valid : 0;
  }

  bool get canBet =>
      widget.enabled &&
      displayBalance != null &&
      widget.status == 'open' &&
      widget.secondsLeft > 0 &&
      !sending;

  @override
  void initState() {
    super.initState();
    revealed = widget.status == 'settled';
    lastKnownBalance = widget.balance;
  }

  String format(int value) => formatCurrencyAmount(value);

  @override
  void didUpdateWidget(covariant XocXocBettingTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.balance != null) lastKnownBalance = widget.balance;
    if (oldWidget.roundId != widget.roundId) {
      optimisticBalance = null;
      acknowledgedBets.clear();
      awaitingBets = null;
      awaitingBaseline = null;
      bets.updateAll((_, _) => 0);
      revealed = false;
      allInSelected = false;
      sending = false;
    } else if (awaitingBets != null &&
        !sending &&
        awaitingBets!.entries.every(
          (entry) =>
              (widget.confirmedBets[entry.key] ?? 0) >=
              (awaitingBaseline![entry.key] ?? 0) + entry.value,
        )) {
      for (final entry in awaitingBets!.entries) {
        bets[entry.key] = (bets[entry.key]! - entry.value).clamp(0, 1000000);
      }
      awaitingBets = null;
      awaitingBaseline = null;
    }
    if (widget.balance != null &&
        optimisticBalance != null &&
        (widget.balance! <= optimisticBalance! ||
            (widget.status == 'settled' &&
                (widget.confirmedCredit ?? 0) > 0 &&
                widget.balance! >=
                    optimisticBalance! + widget.confirmedCredit!))) {
      optimisticBalance = null;
    }
    if (oldWidget.status != 'settled' && widget.status == 'settled') {
      revealed = true;
    }
  }

  void _add(String side) {
    if (!canBet) return;
    final balance = displayBalance!;
    final amount = allInSelected ? allInAmount : selectedChip;
    final next = total + amount;
    if (amount <= 0) {
      _notice('Số dư khả dụng không đủ để đặt cược.');
      return;
    }
    if (next > balance || next + confirmedTotal > 1000000) {
      _notice(
        next > balance
            ? 'Số dư không đủ cho mức cược này.'
            : 'Tổng cược tối đa mỗi phiên là 1.000.000 VNĐ.',
      );
      return;
    }
    setState(() {
      bets[side] = bets[side]! + amount;
      allInSelected = false;
    });
  }

  Future<void> _submit() async {
    if (!canBet || total == 0) return;
    if (total > displayBalance! || total + confirmedTotal > 1000000) {
      _notice('Số dư hoặc hạn mức cược đã thay đổi; hãy xóa cược chưa gửi.');
      return;
    }
    final roundId = widget.roundId;
    final selected = <String, int>{
      for (final entry in bets.entries)
        if (entry.value > 0) entry.key: entry.value,
    };
    final before = {for (final side in selected.keys) side: confirmed(side)};
    final balanceAfter = displayBalance! - total;
    setState(() {
      sending = true;
      awaitingBets = selected;
      awaitingBaseline = before;
      optimisticBalance = balanceAfter;
    });
    try {
      // One server transaction: all selected gates are accepted or none are.
      await widget.onPlaceBets(selected);
      if (!mounted || widget.roundId != roundId) return;
      setState(() {
        for (final entry in selected.entries) {
          acknowledgedBets[entry.key] = before[entry.key]! + entry.value;
          bets[entry.key] = 0;
        }
        awaitingBets = null;
        awaitingBaseline = null;
      });
    } catch (error) {
      if (mounted && widget.roundId == roundId) {
        // An uncertain response keeps its requestId in PendingMutationStore;
        // a later server snapshot clears the draft without sending it twice.
        if (error is! FirebaseFunctionsException ||
            const {
              'invalid-argument',
              'failed-precondition',
              'permission-denied',
              'unauthenticated',
              'already-exists',
              'not-found',
            }.contains(error.code)) {
          setState(() {
            awaitingBets = null;
            awaitingBaseline = null;
            optimisticBalance = null;
          });
        }
        _notice(betFailureNotice(error));
      }
    } finally {
      if (mounted && widget.roundId == roundId) {
        setState(() => sending = false);
      }
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final open = widget.status == 'open' && widget.secondsLeft > 0;
    final result = widget.result;
    return GameWinEffect(
      roundId: widget.roundId,
      status: widget.status,
      betAmount: confirmedTotal,
      credit: widget.confirmedCredit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 8),
          _sessionBar(),
          const SizedBox(height: 8),
          _walletAndBowl(open, result),
          const SizedBox(height: 8),
          _betGates(),
          const SizedBox(height: 8),
          _chipSelector(),
          const SizedBox(height: 8),
          _confirmButton(),
          if (total > 0)
            TextButton(
              onPressed: sending
                  ? null
                  : () => setState(() => bets.updateAll((_, _) => 0)),
              child: const Text('Xóa cược chưa gửi'),
            ),
          const SizedBox(height: 8),
          _road(),
          const SizedBox(height: 8),
          _rules(),
          const SizedBox(height: 8),
          const Text(
            'Điểm mô phỏng • Không nạp/rút tiền thật • Lịch sử chỉ thống kê, không dự đoán.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xffa08e7a), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _header() => Container(
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
          displayBalance == null
              ? 'Đang tải số dư'
              : '${format(displayBalance!)} VNĐ',
          style: const TextStyle(
            color: Color(0xffffddb8),
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 7),
        const CircleAvatar(
          radius: 15,
          backgroundColor: gold,
          child: Icon(Icons.person, color: Color(0xff472a00), size: 17),
        ),
      ],
    ),
  );

  Widget _sessionBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: _panel(),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PHIÊN:',
                style: TextStyle(
                  color: Color(0xffa08e7a),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '#${widget.roundId}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xff32353c),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.status == 'open'
                ? widget.mode.toUpperCase()
                : '${widget.mode.toUpperCase()} • ${widget.status.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xffe1e2eb),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.timer, color: Color(0xffffb3ad), size: 17),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'ĐẾM NGƯỢC',
              style: TextStyle(color: Color(0xffa08e7a), fontSize: 8),
            ),
            Text(
              '${widget.secondsLeft.clamp(0, 999)}s',
              style: const TextStyle(
                color: Color(0xffffb3ad),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _walletAndBowl(bool open, List<dynamic>? result) => Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: _panel(),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet, color: gold, size: 18),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'Số dư VNĐ:',
                style: TextStyle(color: Color(0xffd8c3ad), fontSize: 11),
              ),
            ),
            Text(
              displayBalance == null
                  ? 'Đang tải số dư'
                  : format(displayBalance!),
              style: const TextStyle(
                color: Color(0xffffddb8),
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'VNĐ',
              style: TextStyle(
                color: gold,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const RadialGradient(
            colors: [Color(0xff342512), Color(0xff191c22), Color(0xff0b0e14)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xff8d6b31)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14)],
        ),
        child: Column(
          children: [
            const Text(
              'BÁT ĐĨA HOÀNG GIA',
              style: TextStyle(
                color: gold,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 142,
              height: 82,
              decoration: BoxDecoration(
                color: revealed
                    ? const Color(0xff191c22)
                    : const Color(0xff6f4e20),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(72),
                  bottom: Radius.circular(revealed ? 18 : 45),
                ),
                border: Border.all(color: gold, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 10),
                ],
              ),
              child: Center(
                child: revealed && result != null && result.length == 4
                    ? Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 5,
                        runSpacing: 4,
                        children: [for (final bit in result) _coin(bit == 1)],
                      )
                    : const Icon(
                        Icons.blur_on,
                        color: Color(0xffffddb8),
                        size: 42,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              revealed
                  ? (result == null
                        ? 'Chưa có kết quả từ máy chủ.'
                        : 'KẾT QUẢ • ${result.where((bit) => bit == 1).length} ĐỎ / ${result.where((bit) => bit == 0).length} TRẮNG')
                  : open
                  ? 'Bát đang úp • Đặt cửa tự do'
                  : 'ĐANG LẮC • Cược đã khóa',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xffd8c3ad),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 5),
            OutlinedButton.icon(
              onPressed: widget.status == 'settled' && result != null
                  ? () => setState(() => revealed = !revealed)
                  : null,
              icon: Icon(
                revealed ? Icons.visibility_off : Icons.visibility,
                size: 16,
              ),
              label: Text(revealed ? 'Úp lại' : 'Hé mở'),
              style: OutlinedButton.styleFrom(
                foregroundColor: gold,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _coin(bool red) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: red ? const Color(0xffb4232d) : const Color(0xfff1e8d2),
      border: Border.all(color: gold, width: 2),
      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
    ),
    child: Center(
      child: Icon(
        Icons.circle,
        size: 10,
        color: red ? const Color(0xffffc174) : const Color(0xff88785e),
      ),
    ),
  );

  Widget _betGates() => Container(
    padding: const EdgeInsets.all(10),
    decoration: _panel(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CỬA CƯỢC CHÍNH',
          style: TextStyle(
            color: gold,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            fontSize: 12,
          ),
        ),
        const Text(
          'CHỌN NHIỀU CỬA',
          style: TextStyle(color: Color(0xffa08e7a), fontSize: 9),
        ),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.32,
          children: [for (final gate in gates) _gate(gate)],
        ),
      ],
    ),
  );

  Widget _gate((String, String, String, String) gate) {
    final accepted = confirmed(gate.$1);
    final draft = bets[gate.$1]!;
    final selected = accepted + draft > 0;
    final color = gate.$1 == 'chan' || gate.$1 == 'red3' || gate.$1 == 'red4'
        ? const Color(0xffb4232d)
        : const Color(0xff32353c);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canBet ? () => _add(gate.$1) : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xff342512) : const Color(0xff191c22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? gold : const Color(0xff534434),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      gate.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? gold : const Color(0xffe1e2eb),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      gate.$4,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                gate.$3,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xffd8c3ad), fontSize: 9),
              ),
              const SizedBox(height: 3),
              Text(
                'Đã cược: ${format(accepted)} VNĐ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              if (draft > 0)
                Text(
                  'Chưa gửi: ${format(draft)} VNĐ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xffd8c3ad), fontSize: 9),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipSelector() => Container(
    padding: const EdgeInsets.all(10),
    decoration: _panel(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.toll, color: gold, size: 17),
            const SizedBox(width: 5),
            const Expanded(
              child: Text(
                'CHỌN MỆNH GIÁ CHIP',
                style: TextStyle(
                  color: gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            Text(
              '${format(selectedChip)} VNĐ',
              style: const TextStyle(
                color: Color(0xffffddb8),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 5,
          children: [
            for (final chip in chips)
              ChoiceChip(
                label: Text(_short(chip)),
                selected: chip == selectedChip,
                onSelected: canBet
                    ? (_) => setState(() {
                        selectedChip = chip;
                        allInSelected = false;
                      })
                    : null,
                selectedColor: gold,
                backgroundColor: const Color(0xff32353c),
                labelStyle: TextStyle(
                  color: chip == selectedChip
                      ? const Color(0xff2a1700)
                      : const Color(0xffe1e2eb),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        ChoiceChip(
          label: Text('ALL IN • ${format(allInAmount)} VNĐ'),
          selected: allInSelected,
          onSelected: canBet && allInAmount > 0
              ? (_) => setState(() => allInSelected = true)
              : null,
          selectedColor: const Color(0xfff59e0b),
          backgroundColor: const Color(0xff32353c),
          labelStyle: TextStyle(
            color: allInSelected ? const Color(0xff2a1700) : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 10,
          ),
        ),
      ],
    ),
  );

  String _short(int value) => switch (value) {
    1000 => '1K',
    10000 => '10K',
    50000 => '50K',
    100000 => '100K',
    _ => '1M',
  };

  Widget _confirmButton() => FilledButton.icon(
    onPressed:
        canBet &&
            total > 0 &&
            total <= displayBalance! &&
            total + confirmedTotal <= 1000000
        ? _submit
        : null,
    icon: const Icon(Icons.verified_outlined),
    label: Text(
      sending ? 'ĐANG GỬI...' : 'XÁC NHẬN CƯỢC • ${format(total)} VNĐ',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    style: FilledButton.styleFrom(
      backgroundColor: gold,
      foregroundColor: const Color(0xff2a1700),
      padding: const EdgeInsets.symmetric(vertical: 13),
    ),
  );

  Widget _road() => const _XocXocRoad();

  Widget _rules() => Container(
    decoration: _panel(),
    child: Column(
      children: [
        Material(
          color: Colors.transparent,
          child: ListTile(
            leading: const Icon(Icons.verified_user, color: gold),
            title: const Text(
              'QUY TẮC PHÒNG CHƠI OBSIDIAN VIP',
              style: TextStyle(
                color: Color(0xffe1e2eb),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Icon(
              rulesOpen ? Icons.expand_less : Icons.expand_more,
              color: gold,
            ),
            onTap: () => setState(() => rulesOpen = !rulesOpen),
          ),
        ),
        if (rulesOpen)
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text(
              '• Bốn đồng xu: Chẵn/Lẻ trả 1.98x; 3 mặt đỏ/trắng trả 3.94x; 4 mặt đỏ/trắng trả 14.7x.\n• Mỗi phiên đặt tối đa 1.000.000 VNĐ; chip theo mệnh giá có sẵn.\n• Tỷ lệ theo luật backend; kết quả ngẫu nhiên do máy chủ chốt sau khi khóa cược.\n• Bảng soi cầu chỉ hiển thị dữ liệu lịch sử, không dự đoán kết quả.',
              style: TextStyle(
                color: Color(0xffd8c3ad),
                height: 1.45,
                fontSize: 11,
              ),
            ),
          ),
      ],
    ),
  );

  BoxDecoration _panel() => BoxDecoration(
    color: const Color(0xff191c22),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: const Color(0xff534434)),
  );
}

class _XocXocRoad extends StatelessWidget {
  const _XocXocRoad();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xff191c22),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xff534434)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.troubleshoot, color: Color(0xffffc174), size: 18),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'BẢNG SOI CẦU (19 PHIÊN GẦN NHẤT)',
                style: TextStyle(
                  color: Color(0xffe1e2eb),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('rounds')
              .where('game', isEqualTo: 'xoc_xoc')
              .where('status', isEqualTo: 'settled')
              .orderBy('settledAt', descending: true)
              .limit(19)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                'Không tải được lịch sử: ${snapshot.error}',
                style: const TextStyle(color: Color(0xffffb3ad), fontSize: 10),
              );
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final rows = snapshot.data!.docs;
            final ordered = rows.reversed.toList();
            final counts = {'chan': 0, 'le': 0};
            for (final row in rows) {
              final side = (row.data()['outcome'] as Map?)?['side'];
              if (counts.containsKey(side)) counts[side] = counts[side]! + 1;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'C: ${counts['chan']}  |  L: ${counts['le']}',
                  style: const TextStyle(
                    color: Color(0xffd8c3ad),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (var index = 0; index < ordered.length; index++)
                      _roadCell(ordered[index], index == ordered.length - 1),
                  ],
                ),
                if (ordered.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Text(
                      'MỚI',
                      style: TextStyle(
                        color: Color(0xff56e5a9),
                        fontWeight: FontWeight.bold,
                        fontSize: 8,
                      ),
                    ),
                  ),
                const SizedBox(height: 5),
                const Text(
                  'Không dự đoán kết quả - Dữ liệu thống kê mô phỏng.',
                  style: TextStyle(color: Color(0xffa08e7a), fontSize: 9),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );

  Widget _roadCell(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool newest,
  ) {
    final row = doc.data();
    final side = (row['outcome'] as Map?)?['side']?.toString();
    return Tooltip(
      message: '#${doc.id}',
      child: SizedBox(
        width: 42,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 31,
              height: 31,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: side == 'chan'
                    ? const Color(0xffb4232d)
                    : const Color(0xff32353c),
                border: Border.all(
                  color: newest
                      ? const Color(0xff56e5a9)
                      : const Color(0xffa08e7a),
                  width: newest ? 2 : 1,
                ),
              ),
              child: Text(
                side == 'chan'
                    ? 'C'
                    : side == 'le'
                    ? 'L'
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            Text(
              '#${doc.id.substring(0, doc.id.length < 4 ? doc.id.length : 4)}',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(color: Color(0xffa08e7a), fontSize: 7),
            ),
          ],
        ),
      ),
    );
  }
}
