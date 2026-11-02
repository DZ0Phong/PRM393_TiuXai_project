import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'game_specs.dart';

/// A historical description, never a prediction or an input to settlement.
List<List<String>> roadColumns(
  List<String> oldestFirst,
  int height,
  int width,
) {
  final columns = <List<String>>[];
  for (final side in oldestFirst) {
    if (columns.isEmpty ||
        columns.last.last != side ||
        columns.last.length == height) {
      columns.add([side]);
    } else {
      columns.last.add(side);
    }
  }
  return columns.length <= width
      ? columns
      : columns.sublist(columns.length - width);
}

class RoundHistory extends StatelessWidget {
  final GameSpec game;
  const RoundHistory({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final limit = game.id == 'tai_xiu'
        ? 125
        : game.id == 'xoc_xoc'
        ? 48
        : 15;
    return ExpansionTile(
      title: const Text('Lịch sử và cầu (chỉ mô tả, không dự đoán)'),
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('rounds')
              .where('game', isEqualTo: game.id)
              .where('status', isEqualTo: 'settled')
              .orderBy('settledAt', descending: true)
              .limit(limit)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ListTile(
                title: Text('Không tải được lịch sử: ${snapshot.error}'),
              );
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final rows = snapshot.data!.docs.map((doc) => doc.data()).toList();
            if (rows.isEmpty) {
              return const ListTile(title: Text('Chưa có phiên đã chốt.'));
            }
            if (game.id == 'bau_cua') {
              final recent = rows.take(15).toList();
              final counts = <String, int>{
                for (final side in game.sides) side.$1: 0,
              };
              for (final row in recent) {
                for (final face in (row['result'] as List? ?? [])) {
                  if (counts.containsKey(face)) {
                    counts[face] = counts[face]! + 1;
                  }
                }
              }
              return Column(
                children: [
                  Text(
                    'Số mặt trong ${recent.length} phiên gần nhất (không phải tổng từ đầu)',
                  ),
                  Text(
                    counts.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join(' • '),
                  ),
                  ...recent.map(
                    (row) => ListTile(
                      dense: true,
                      title: Text((row['result'] as List? ?? []).join(' • ')),
                    ),
                  ),
                ],
              );
            }
            final selected = game.id == 'tai_xiu' ? rows.take(120) : rows;
            final sides = selected
                .toList()
                .reversed
                .map(
                  (row) =>
                      game.id == 'tai_xiu' &&
                          (row['outcome'] as Map?)?['triple'] == true
                      ? 'triple'
                      : (row['outcome'] as Map?)?['side']?.toString() ?? '?',
                )
                .toList();
            final height = game.id == 'tai_xiu' ? 5 : 4;
            final columns = roadColumns(
              sides,
              height,
              game.id == 'tai_xiu' ? 20 : 12,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '${game.id == 'tai_xiu' ? 'Tài/Xỉu' : 'Chẵn/Lẻ'}: ${selected.length} phiên, tối đa ${columns.length} cột × $height ô. Lịch sử không bảo đảm kết quả tiếp theo.',
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final column in columns)
                          Padding(
                            padding: const EdgeInsets.only(right: 3),
                            child: Column(
                              children: [
                                for (final side in column)
                                  Container(
                                    width: 30,
                                    height: 30,
                                    margin: const EdgeInsets.only(bottom: 3),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: side == 'triple'
                                          ? Colors.amber.shade100
                                          : side == 'tai' || side == 'chan'
                                          ? Colors.red.shade100
                                          : Colors.blue.shade100,
                                    ),
                                    child: Text(
                                      side == 'tai'
                                          ? 'T'
                                          : side == 'xiu'
                                          ? 'X'
                                          : side == 'chan'
                                          ? 'C'
                                          : side == 'le'
                                          ? 'L'
                                          : side == 'triple'
                                          ? 'B'
                                          : '?',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (game.id == 'tai_xiu')
                  _DiceChart(rows.take(19).toList().reversed.toList()),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Gần nhất: ${rows.take(8).map((r) => (r['result'] as List? ?? []).join(',')).join('  |  ')}',
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DiceChart extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _DiceChart(this.rows);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '19 phiên gần nhất • đường tổng (đỏ) và từng xúc xắc',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        SizedBox(
          height: 130,
          width: double.infinity,
          child: CustomPaint(painter: _DicePainter(rows)),
        ),
      ],
    ),
  );
}

class _DicePainter extends CustomPainter {
  final List<Map<String, dynamic>> rows;
  _DicePainter(this.rows);
  @override
  void paint(Canvas canvas, Size size) {
    if (rows.length < 2) return;
    final colors = [Colors.red, Colors.blue, Colors.green, Colors.orange];
    for (var series = 0; series < 4; series++) {
      final path = Path();
      for (var i = 0; i < rows.length; i++) {
        final dice = (rows[i]['result'] as List).cast<num>();
        final value = series == 0
            ? dice.reduce((a, b) => a + b).toDouble()
            : dice[series - 1].toDouble();
        final x = i * size.width / (rows.length - 1);
        final y = size.height * (1 - value / 18);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colors[series]
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DicePainter oldDelegate) =>
      oldDelegate.rows != rows;
}
