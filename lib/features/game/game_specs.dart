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
    'Ba biểu tượng • chọn một linh vật',
    '3 mặt: bau,cua,tom,ca,ga,nai',
    Icons.grid_view_rounded,
    [
      ('bau', 'Bầu'),
      ('cua', 'Cua'),
      ('tom', 'Tôm'),
      ('ca', 'Cá'),
      ('ga', 'Gà'),
      ('nai', 'Nai'),
    ],
  ),
  GameSpec(
    'xoc_xoc',
    'Xóc Xóc',
    '03',
    'Bốn đồng xu • chọn Chẵn hoặc Lẻ',
    '4 đồng xu 0/1, ví dụ: 0,1,0,1',
    Icons.toll_outlined,
    [('chan', 'Chẵn'), ('le', 'Lẻ')],
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
  final side = outcome['side'];
  final label = game.sides.where((option) => option.$1 == side);
  final name = label.isEmpty ? side?.toString() ?? '—' : label.first.$2;
  return game.id == 'tai_xiu'
      ? '$name • tổng ${outcome['total'] ?? '—'}'
      : '$name • ${outcome['ones'] ?? '—'} mặt 1';
}
