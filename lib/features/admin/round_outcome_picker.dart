import 'package:flutter/material.dart';

import '../game/game_specs.dart';
import 'round_outcome_choices.dart';

class RoundOutcomePicker extends StatelessWidget {
  final GameSpec game;
  final Map<String, dynamic> round;
  final bool enabled;
  final ValueChanged<RoundOutcomeChoice> onSelected;

  const RoundOutcomePicker({
    super.key,
    required this.game,
    required this.round,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final totals = Map<String, dynamic>.from(round['totals'] as Map? ?? {});
    if (game.id == 'bau_cua') {
      return _BauCuaOutcomeSelector(
        game: game,
        totals: totals,
        enabled: enabled,
        onSelected: onSelected,
      );
    }
    final counts = Map<String, dynamic>.from(
      round['playerCounts'] as Map? ?? {},
    );
    final choices = roundOutcomeChoices(game, totals);
    final totalStake = totals.values.whereType<num>().fold<int>(
      0,
      (sum, n) => sum + n.toInt(),
    );
    final lowestCredit = choices
        .map((choice) => choice.estimatedCredit)
        .reduce((a, b) => a < b ? a : b);
    final names = {for (final side in game.sides) side.$1: side.$2};
    final highestStake = game.sides
        .map((side) => (totals[side.$1] as num? ?? 0).toInt())
        .reduce((a, b) => a > b ? a : b);
    final uniqueLowest =
        totalStake > 0 &&
        choices
                .where((choice) => choice.estimatedCredit == lowestCredit)
                .length ==
            1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Cược hiện tại theo từng cửa',
          style: TextStyle(
            color: Color(0xffffc174),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final side in game.sides)
              Chip(
                backgroundColor: const Color(0xff272a31),
                side: BorderSide(
                  color: highestStake > 0 && totals[side.$1] == highestStake
                      ? const Color(0xffffb3ad)
                      : const Color(0xff444852),
                ),
                label: Text(
                  '${side.$2}: ${counts[side.$1] ?? 0} người · ${totals[side.$1] ?? 0} điểm'
                  '${highestStake > 0 && totals[side.$1] == highestStake ? ' ↑' : ''}',
                  style: const TextStyle(
                    color: Color(0xffffddb8),
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Tổng cược: $totalStake điểm. Chạm một kết quả hợp lệ để lưu một lần trước hạn cược.',
          style: const TextStyle(color: Color(0xffd8c3ad), fontSize: 11),
        ),
        const SizedBox(height: 8),
        for (final choice in choices) ...[
          OutlinedButton(
            onPressed: enabled ? () => onSelected(choice) : null,
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              backgroundColor: const Color(0xff202329),
              foregroundColor: const Color(0xffffddb8),
              disabledForegroundColor: const Color(0xff777b81),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              side: BorderSide(
                color: uniqueLowest && choice.estimatedCredit == lowestCredit
                    ? const Color(0xff56e5a9)
                    : const Color(0xff976414),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  choice.label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Cửa thắng: ${choice.winningSides.map((side) => names[side]).join(' + ')}'
                  ' · Trả dự kiến: ${choice.estimatedCredit} · Chênh cược − trả: ${totalStake - choice.estimatedCredit}',
                  style: const TextStyle(fontSize: 10),
                ),
                if (uniqueLowest && choice.estimatedCredit == lowestCredit)
                  const Text(
                    'Ít điểm trả nhất trong các lựa chọn này',
                    style: TextStyle(color: Color(0xff56e5a9), fontSize: 9),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          game.id == 'tai_xiu'
              ? 'Tài/Xỉu hoàn phần cược dư khi hai bên đều có cược; chênh thu-chi có thể bằng nhau dù chọn bên nào.'
              : game.id == 'bau_cua'
              ? 'Mỗi nút ra ba mặt cùng loại. Nếu cả sáu cửa đều có cược, không có kết quả nào làm tất cả thua.'
              : 'Chẵn/Lẻ thắng cùng cửa màu tương ứng; không thể chọn sáu cửa độc lập.',
          style: const TextStyle(color: Color(0xffd8c3ad), fontSize: 9),
        ),
        const Text(
          'Ước tính thay đổi khi có cược/hoàn mới; thanh toán cuối cùng do backend tính.',
          style: TextStyle(color: Color(0xffd8c3ad), fontSize: 9),
        ),
      ],
    );
  }
}

class _BauCuaOutcomeSelector extends StatefulWidget {
  final GameSpec game;
  final Map<String, dynamic> totals;
  final bool enabled;
  final ValueChanged<RoundOutcomeChoice> onSelected;

  const _BauCuaOutcomeSelector({
    required this.game,
    required this.totals,
    required this.enabled,
    required this.onSelected,
  });

  @override
  State<_BauCuaOutcomeSelector> createState() => _BauCuaOutcomeSelectorState();
}

class _BauCuaOutcomeSelectorState extends State<_BauCuaOutcomeSelector> {
  final List<String?> _result = List<String?>.filled(3, null);

  @override
  Widget build(BuildContext context) {
    final faces = widget.game.sides;
    final faceNames = {for (final face in faces) face.$1: face.$2};
    final counts = <String, int>{for (final face in faces) face.$1: 0};
    for (final face in _result.whereType<String>()) {
      counts[face] = counts[face]! + 1;
    }
    final winningSides = faces
        .where((face) => counts[face.$1]! > 0)
        .map((face) => face.$1)
        .toList();
    final estimatedCredit = winningSides.fold<int>(0, (sum, side) {
      final stake = (widget.totals[side] as num? ?? 0).toInt();
      final matches = counts[side]!;
      return sum + stake * (100 + 98 * matches) ~/ 100;
    });
    final complete = _result.every((face) => face != null);
    final choice = RoundOutcomeChoice(
      _result.map((face) => face == null ? '—' : faceNames[face]!).join(' · '),
      _result.whereType<String>().toList(),
      winningSides,
      estimatedCredit,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Chọn độc lập từng mặt trong 3 lượt gieo. Mỗi lượt chọn một trong 6 con; có thể chọn trùng nhau.',
          style: TextStyle(color: Color(0xffd8c3ad), fontSize: 11),
        ),
        const SizedBox(height: 10),
        for (var die = 0; die < 3; die++) ...[
          Text(
            'Lượt ${die + 1}: ${_result[die] == null ? 'Chưa chọn' : faceNames[_result[die]]}',
            style: const TextStyle(
              color: Color(0xffffc174),
              fontWeight: FontWeight.bold,
            ),
          ),
          Wrap(
            spacing: 5,
            runSpacing: 2,
            children: [
              for (final face in faces)
                ChoiceChip(
                  label: Text(face.$2),
                  selected: _result[die] == face.$1,
                  onSelected: !widget.enabled
                      ? null
                      : (_) => setState(() => _result[die] = face.$1),
                  selectedColor: const Color(0xffffc174),
                  backgroundColor: const Color(0xff272a31),
                  labelStyle: TextStyle(
                    color: _result[die] == face.$1
                        ? const Color(0xff21180b)
                        : const Color(0xffffddb8),
                    fontSize: 11,
                  ),
                  side: const BorderSide(color: Color(0xff705123)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        Text(
          'Kết quả: ${choice.label}${complete ? ' · Cửa thắng: ${winningSides.map((side) => faceNames[side]).join(', ')} · Trả dự kiến: $estimatedCredit điểm' : ''}',
          style: const TextStyle(color: Color(0xffd8c3ad), fontSize: 10),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: widget.enabled && complete
              ? () => widget.onSelected(choice)
              : null,
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            backgroundColor: const Color(0xff202329),
            foregroundColor: const Color(0xffffddb8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            side: const BorderSide(color: Color(0xff976414)),
          ),
          child: Text('Lưu kết quả: ${choice.label}'),
        ),
      ],
    );
  }
}
