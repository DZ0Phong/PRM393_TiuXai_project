import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide Text;

import '../../core/app_preferences.dart';
import '../../core/app_text.dart';
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
      key: ValueKey('round_history_${game.id}'),
      initiallyExpanded: game.id == 'bau_cua',
      leading: Icon(
        game.id == 'bau_cua' ? Icons.history_rounded : Icons.query_stats,
        color: const Color(0xffffc174),
      ),
      title: Text(
        game.id == 'bau_cua' ? 'Lịch sử Bầu Cua' : 'Lịch sử và cầu',
        style: const TextStyle(
          color: Color(0xffffc174),
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
      subtitle: game.id == 'bau_cua'
          ? const Text(
              'Kết quả các phiên đã chốt',
              style: TextStyle(color: Color(0xffb7a995), fontSize: 11),
            )
          : null,
      iconColor: const Color(0xffffc174),
      collapsedIconColor: const Color(0xffffc174),
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
              return game.id == 'bau_cua'
                  ? _BauCuaHistoryEmpty()
                  : const ListTile(title: Text('Chưa có phiên đã chốt.'));
            }
            if (game.id == 'bau_cua') {
              final recent = rows.take(15).toList();
              final faceNames = {
                for (final side in game.sides) side.$1: side.$2,
              };
              const faceEmojis = {
                'nai': '🦌',
                'bau': '🍈',
                'ga': '🐓',
                'ca': '🐟',
                'cua': '🦀',
                'tom': '🦐',
              };
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
              return Container(
                margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xff101319),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xff59462d)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xffffc174),
                          size: 17,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'THỐNG KÊ ${recent.length} PHIÊN GẦN NHẤT',
                            style: const TextStyle(
                              color: Color(0xffffc174),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .45,
                            ),
                          ),
                        ),
                        Text(
                          '${recent.length} phiên',
                          style: const TextStyle(
                            color: Color(0xffb7a995),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Số lần xuất hiện của mỗi mặt trong các kết quả đã chốt',
                      style: TextStyle(color: Color(0xffa99b89), fontSize: 10),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final side in game.sides)
                          Container(
                            width: 88,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xff1b1e24),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: const Color(0xff39332b),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  faceEmojis[side.$1] ?? '🎲',
                                  style: const TextStyle(fontSize: 15),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        side.$2,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xffd8c3ad),
                                          fontSize: 9,
                                        ),
                                      ),
                                      Text(
                                        '${counts[side.$1]} lần',
                                        style: const TextStyle(
                                          color: Color(0xffffc174),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 15, bottom: 8),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: Color(0xff39332b))),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'KẾT QUẢ GẦN ĐÂY',
                              style: TextStyle(
                                color: Color(0xffb7a995),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .5,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Color(0xff39332b))),
                        ],
                      ),
                    ),
                    ...recent.asMap().entries.map((entry) {
                      final result = entry.value['result'] as List? ?? [];
                      final settledAt = entry.value['settledAt'];
                      final timeLabel = settledAt is Timestamp
                          ? _historyTime(settledAt.toDate())
                          : null;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xff1a1d23),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: entry.key == 0
                                ? const Color(0xff8c6b32)
                                : const Color(0xff34312b),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 25,
                              height: 25,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: entry.key == 0
                                    ? const Color(0xff3c2b15)
                                    : const Color(0xff292b31),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${entry.key + 1}',
                                style: TextStyle(
                                  color: entry.key == 0
                                      ? const Color(0xffffc174)
                                      : const Color(0xffb7a995),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          entry.key == 0
                                              ? 'Phiên mới nhất'
                                              : 'Phiên ${entry.key + 1}',
                                          style: const TextStyle(
                                            color: Color(0xffe1e2eb),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (timeLabel != null)
                                        Text(
                                          timeLabel,
                                          style: const TextStyle(
                                            color: Color(0xff8f8b84),
                                            fontSize: 9,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Wrap(
                                    spacing: 5,
                                    runSpacing: 4,
                                    children: [
                                      for (final face in result)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xff30271b),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            '${faceEmojis['$face'] ?? '🎲'} ${faceNames['$face'] ?? face}',
                                            style: const TextStyle(
                                              color: Color(0xffffddb8),
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 2),
                    const Text(
                      'Lịch sử chỉ mô tả các kết quả trước đó, không dự đoán phiên tiếp theo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xff8f8b84), fontSize: 9),
                    ),
                  ],
                ),
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
            return FutureBuilder<String>(
              future: AppPreferences.roadStyle(),
              builder: (context, styleSnapshot) {
                final roadStyle = styleSnapshot.data ?? 'Cầu Bàn Cờ';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '${game.id == 'tai_xiu' ? 'Tài/Xỉu' : 'Chẵn/Lẻ'}: ${selected.length} phiên, tối đa ${columns.length} cột × $height ô. Lịch sử không bảo đảm kết quả tiếp theo.',
                      ),
                    ),
                    if (roadStyle == 'Cầu Tóm Tắt')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: [
                            for (final side in sides.take(30).toList().reversed)
                              _RoadMark(side: side, style: roadStyle),
                          ],
                        ),
                      )
                    else
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
                                        _RoadMark(side: side, style: roadStyle),
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
            );
          },
        ),
      ],
    );
  }
}

String _historyTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month • $hour:$minute';
}

class _BauCuaHistoryEmpty extends StatelessWidget {
  const _BauCuaHistoryEmpty();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xff101319),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xff59462d)),
    ),
    child: const Column(
      children: [
        Icon(Icons.history_rounded, color: Color(0xffffc174), size: 28),
        SizedBox(height: 8),
        Text(
          'Chưa có phiên Bầu Cua đã chốt',
          style: TextStyle(
            color: Color(0xffffddb8),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 3),
        Text(
          'Kết quả sẽ xuất hiện ở đây sau khi phiên đầu tiên kết thúc.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xffa99b89), fontSize: 10),
        ),
      ],
    ),
  );
}

class _RoadMark extends StatelessWidget {
  final String side;
  final String style;

  const _RoadMark({required this.side, required this.style});

  @override
  Widget build(BuildContext context) {
    final text = switch (side) {
      'tai' => 'T',
      'xiu' => 'X',
      'chan' => 'C',
      'le' => 'L',
      'triple' => 'B',
      _ => '?',
    };
    final color = side == 'triple'
        ? Colors.amber.shade100
        : side == 'tai' || side == 'chan'
        ? Colors.red.shade100
        : Colors.blue.shade100;
    return Container(
      width: 30,
      height: style == 'Cầu Tóm Tắt' ? 26 : 30,
      margin: const EdgeInsets.only(bottom: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: style == 'Cầu Bàn Cờ' ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: style == 'Cầu Giọt Nước'
            ? const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(3),
              )
            : style == 'Cầu Tóm Tắt'
            ? BorderRadius.circular(6)
            : null,
      ),
      child: Text(text),
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
