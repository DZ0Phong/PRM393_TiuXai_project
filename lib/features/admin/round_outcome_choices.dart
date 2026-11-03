import '../game/game_specs.dart';

/// A small set of legal, representative results. Backend remains authoritative.
class RoundOutcomeChoice {
  final String label;
  final List<dynamic> result;
  final List<String> winningSides;
  final int estimatedCredit;

  const RoundOutcomeChoice(
    this.label,
    this.result,
    this.winningSides,
    this.estimatedCredit,
  );
}

List<RoundOutcomeChoice> roundOutcomeChoices(
  GameSpec game,
  Map<String, dynamic> totals,
) {
  int stake(String side) =>
      (totals[side] is num) ? (totals[side] as num).toInt() : 0;
  if (game.id == 'tai_xiu') {
    final tai = stake('tai'), xiu = stake('xiu');
    final both = tai > 0 && xiu > 0;
    final refund = both ? (tai - xiu).abs() : 0;
    int credit(String side) =>
        refund + (both ? (tai < xiu ? tai : xiu) : stake(side)) * 198 ~/ 100;
    return [
      RoundOutcomeChoice('Tài thắng', [4, 4, 3], ['tai'], credit('tai')),
      RoundOutcomeChoice('Xỉu thắng', [2, 3, 4], ['xiu'], credit('xiu')),
    ];
  }
  if (game.id == 'bau_cua') {
    return [
      for (final face in game.sides)
        RoundOutcomeChoice(
          '3 mặt ${face.$2}',
          [face.$1, face.$1, face.$1],
          [face.$1],
          stake(face.$1) * 394 ~/ 100,
        ),
    ];
  }
  // 4 coins have five distinct outcomes by red count. Parity and color
  // specials overlap, so six independent side buttons would be misleading.
  const winning = [
    ['chan', 'white4'],
    ['le', 'white3'],
    ['chan'],
    ['le', 'red3'],
    ['chan', 'red4'],
  ];
  const names = [
    '0 đỏ · 4 trắng',
    '1 đỏ · 3 trắng',
    '2 đỏ · 2 trắng',
    '3 đỏ · 1 trắng',
    '4 đỏ · 0 trắng',
  ];
  return [
    for (var red = 0; red <= 4; red++)
      RoundOutcomeChoice(
        names[red],
        [for (var i = 0; i < 4; i++) i < red ? 1 : 0],
        winning[red],
        winning[red].fold<int>(
          0,
          (sum, side) =>
              sum +
              stake(side) *
                  (side == 'chan' || side == 'le'
                      ? 198
                      : side == 'red3' || side == 'white3'
                      ? 394
                      : 1470) ~/
                  100,
        ),
      ),
  ];
}
