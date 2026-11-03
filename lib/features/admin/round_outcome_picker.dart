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
