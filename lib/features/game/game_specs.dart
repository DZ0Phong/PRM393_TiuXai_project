import 'package:flutter/material.dart';

class GameSpec {
  final String id, title, symbol, detail, resultHint;
  final IconData icon;
  final List<(String, String)> sides;
  const GameSpec(
    this.id,
    this.title,
    this.symbol,
    this.detail,
    this.resultHint,
    this.icon,
    this.sides,
  );
}

const games = [
  GameSpec(
    'tai_xiu',
    'Tài Xỉu',
    '01',
    'Ba xúc xắc • chọn Tài hoặc Xỉu',
    '3 xúc xắc 1–6, ví dụ: 2,3,6',
    Icons.casino_outlined,
    [('tai', 'Tài'), ('xiu', 'Xỉu')],
  ),
  GameSpec(
    'bau_cua',
    'Bầu Cua',
    '02',
    'Ba biểu tượng • đặt nhiều cửa, thắng theo số mặt',
    '3 mặt: nai,bau,ga,ca,cua,tom',
    Icons.grid_view_rounded,
    [
      ('nai', 'Hươu'),
      ('bau', 'Bầu'),
      ('ga', 'Gà'),
      ('ca', 'Cá'),
      ('cua', 'Cua'),
      ('tom', 'Tôm'),
    ],
  ),
  GameSpec(
    'xoc_xoc',
    'Xóc Xóc',
    '03',
    'Bốn đồng xu • sáu cửa, có thể đặt nhiều cửa',
    '4 đồng xu 0/1, ví dụ: 0,1,0,1',
    Icons.toll_outlined,
    [
      ('chan', 'Chẵn'),
      ('le', 'Lẻ'),
      ('red3', '3 đỏ'),
      ('red4', '4 đỏ'),
      ('white3', '3 trắng'),
      ('white4', '4 trắng'),
    ],
  ),
];

/// The callable accepts a typed result, not the raw text from an admin field.
List<dynamic>? parseRoundResult(GameSpec game, String input) {
  final parts = input.split(',').map((s) => s.trim().toLowerCase()).toList();
  if (parts.any((s) => s.isEmpty)) return null;
  if (game.id == 'bau_cua') {
    return parts.length == 3 &&
            parts.every((s) => game.sides.any((side) => side.$1 == s))
        ? parts
        : null;
  }
  final expected = game.id == 'xoc_xoc' ? 4 : 3;
  final values = parts.map(int.tryParse).toList();
  final low = game.id == 'xoc_xoc' ? 0 : 1;
  final high = game.id == 'xoc_xoc' ? 1 : 6;
  return values.length == expected &&
          values.every((n) => n != null && n >= low && n <= high)
      ? values.cast<int>()
      : null;
}

String formatOutcome(GameSpec game, Map outcome) {
  if (game.id == 'bau_cua') {
    final counts = outcome['counts'];
    if (counts is Map) {
      return game.sides
          .map((side) => '${side.$2}: ${counts[side.$1] ?? 0}')
          .join(' • ');
    }
  }
  if (game.id == 'tai_xiu' && outcome['triple'] == true) {
    return 'Bộ ba • cả Tài và Xỉu đều thua • tổng ${outcome['total'] ?? '—'}';
  }
  final side = outcome['side'];
  final label = game.sides.where((option) => option.$1 == side);
  final name = label.isEmpty ? side?.toString() ?? '—' : label.first.$2;
  return game.id == 'tai_xiu'
      ? '$name • tổng ${outcome['total'] ?? '—'}'
      : '$name • ${outcome['ones'] ?? '—'} mặt đỏ • thắng: ${(outcome['winningSides'] as List?)?.join(', ') ?? '—'}';
}
