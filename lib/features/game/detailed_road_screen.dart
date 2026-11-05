import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DetailedRoadScreen extends StatefulWidget {
  const DetailedRoadScreen({super.key});

  @override
  State<DetailedRoadScreen> createState() => _DetailedRoadScreenState();
}

class _DetailedRoadScreenState extends State<DetailedRoadScreen> {
  static const _gold = Color(0xffffc174);
  static const _red = Color(0xffff8585);
  static const _blue = Color(0xff71b8ff);
  static const _purple = Color(0xffc7a3ff);
  int _limit = 100;
  int _view = 0;

  @override
  Widget build(BuildContext context) {
    final rounds = FirebaseFirestore.instance
        .collection('rounds')
        .where('game', isEqualTo: 'tai_xiu')
        .where('status', isEqualTo: 'settled')
        .orderBy('settledAt', descending: true)
        .limit(_limit)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xff111318),
      appBar: AppBar(
        backgroundColor: const Color(0xff111318),
        foregroundColor: const Color(0xffe1e2eb),
        title: const Text('Soi cầu chi tiết'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: rounds,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Message(
              icon: Icons.cloud_off_outlined,
              text: 'Không tải được lịch sử phiên: ${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _gold));
          }
          final newestFirst = snapshot.data!.docs
              .map(_RoadRound.fromDocument)
              .toList();
          if (newestFirst.isEmpty) {
            return const _Message(
              icon: Icons.casino_outlined,
              text: 'Chưa có phiên Tài/Xỉu nào được chốt.',
            );
          }
          final oldestFirst = newestFirst.reversed.toList();
          final counts = <_Side, int>{for (final side in _Side.values) side: 0};
          for (final round in newestFirst) {
            counts[round.side] = counts[round.side]! + 1;
          }
          final road = _makeRoad(
            oldestFirst.where((r) => r.side != _Side.storm).toList(),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _intro(newestFirst.length),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Số phiên gần nhất',
                      style: TextStyle(
                        color: Color(0xffe1e2eb),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final count in [50, 100, 200])
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text('$count'),
                        selected: _limit == count,
                        onSelected: (_) => setState(() => _limit = count),
                        selectedColor: _gold,
                        backgroundColor: const Color(0xff24272e),
                        labelStyle: TextStyle(
                          color: _limit == count
                              ? Colors.black
                              : const Color(0xffe1e2eb),
                          fontWeight: FontWeight.bold,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _countCard(
                      'TÀI',
                      counts[_Side.tai]!,
                      newestFirst.length,
                      _red,
                      'T',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _countCard(
                      'XỈU',
                      counts[_Side.xiu]!,
                      newestFirst.length,
                      _blue,
                      'X',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _countCard(
                      'BÃO',
                      counts[_Side.storm]!,
                      newestFirst.length,
                      _purple,
                      'B',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _viewChip(0, 'Giọt nước'),
                  _viewChip(1, 'Big Road'),
                  _viewChip(2, 'Nhịp cầu'),
                ],
              ),
              const SizedBox(height: 12),
              if (_view == 0)
                _beadPlate(newestFirst)
              else if (_view == 1)
                _bigRoad(road)
              else
                _streaks(oldestFirst),
              const SizedBox(height: 18),
              const Text(
                'Đây là thống kê các kết quả đã chốt từ máy chủ. Tài/Xỉu được xác định theo tổng 3 xúc xắc; bộ ba được tính là Bão và thua cả hai cửa. Lịch sử không dự đoán hay bảo đảm kết quả kế tiếp.',
                style: TextStyle(
                  color: Color(0xffa5a6ae),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _intro(int count) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _gold.withValues(alpha: .3)),
      gradient: const LinearGradient(
        colors: [Color(0xff332a1e), Color(0xff1d2026)],
      ),
    ),
    child: Row(
      children: [
        const Icon(Icons.analytics_outlined, color: _gold, size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'KẾT QUẢ ĐÃ CHỐT',
                style: TextStyle(
                  color: _gold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count phiên gần nhất · dữ liệu trực tiếp',
                style: const TextStyle(color: Color(0xffe1e2eb)),
              ),
              const SizedBox(height: 3),
              const Text(
                'VNĐ mô phỏng · Không phải tiền thật, không quy đổi',
                style: TextStyle(color: Color(0xffb9a78f), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _countCard(
    String title,
    int count,
    int total,
    Color color,
    String mark,
  ) {
    final percent = total == 0 ? 0 : count * 100 / total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xff1d2026),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: color.withValues(alpha: .16),
                child: Text(
                  mark,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: const TextStyle(
              color: Color(0xfff1f1f4),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${percent.toStringAsFixed(1)}%',
            style: const TextStyle(color: Color(0xffa5a6ae), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _viewChip(int id, String title) => ChoiceChip(
    label: Text(title),
    selected: _view == id,
    onSelected: (_) => setState(() => _view = id),
    selectedColor: const Color(0xff493817),
    backgroundColor: const Color(0xff1d2026),
    side: BorderSide(color: _view == id ? _gold : const Color(0xff363942)),
    labelStyle: TextStyle(
      color: _view == id ? _gold : const Color(0xffd1d2d8),
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _beadPlate(List<_RoadRound> newestFirst) => _panel(
    title: 'Bảng Giọt Nước',
    subtitle: 'Mỗi ô là một phiên; mới nhất nằm trước.',
    child: Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [for (final round in newestFirst) _roundCell(round, 48)],
    ),
  );

  Widget _bigRoad(List<List<_RoadRound>> columns) => _panel(
    title: 'Đường Lớn · Big Road',
    subtitle:
        'Gom kết quả cùng cửa thành chuỗi; Bão được thống kê riêng và không nối vào đường Tài/Xỉu.',
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final column in columns)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Column(
                children: [
                  for (final round in column)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: _roundCell(round, 38),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );

  Widget _streaks(List<_RoadRound> oldestFirst) {
    final runs = <(_Side, int)>[];
    for (final round in oldestFirst) {
      if (round.side == _Side.storm) continue;
      if (runs.isEmpty || runs.last.$1 != round.side) {
        runs.add((round.side, 1));
      } else {
        runs[runs.length - 1] = (runs.last.$1, runs.last.$2 + 1);
      }
    }
    final longest = runs.fold<int>(
      0,
      (best, run) => run.$2 > best ? run.$2 : best,
    );
    final switches = runs.length > 1 ? runs.length - 1 : 0;
    return _panel(
      title: 'Nhịp cầu trong mẫu đã chọn',
      subtitle:
          'Tóm tắt chuỗi liên tiếp và lần đổi cửa giữa các kết quả đã chốt.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _metric('Chuỗi liên tiếp', '${runs.length}')),
              const SizedBox(width: 8),
              Expanded(child: _metric('Lần đổi cửa', '$switches')),
              const SizedBox(width: 8),
              Expanded(child: _metric('Chuỗi dài nhất', '$longest')),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Các chuỗi từ cũ đến mới',
            style: TextStyle(
              color: Color(0xffe1e2eb),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final run in runs)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _sideColor(run.$1).withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _sideColor(run.$1).withValues(alpha: .4),
                    ),
                  ),
                  child: Text(
                    '${_sideName(run.$1)} × ${run.$2}',
                    style: TextStyle(
                      color: _sideColor(run.$1),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xff262930),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: _gold,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: Color(0xffa5a6ae), fontSize: 10),
        ),
      ],
    ),
  );

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xff1a1d23),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xff343740)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _gold,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xffa5a6ae),
            fontSize: 11,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );

  Widget _roundCell(_RoadRound round, double size) {
    final color = _sideColor(round.side);
    return Tooltip(
      message:
          'Phiên ${round.id}\n${round.dice.join(' + ')} = ${round.total} · ${_sideName(round.side)}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: .12),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _sideLetter(round.side),
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '${round.total}',
              style: const TextStyle(color: Color(0xffdedfe5), fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Side { tai, xiu, storm }

class _RoadRound {
  final String id;
  final List<int> dice;
  final int total;
  final _Side side;

  const _RoadRound({
    required this.id,
    required this.dice,
    required this.total,
    required this.side,
  });

  factory _RoadRound.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final dice = (data['result'] as List? ?? const [])
        .whereType<num>()
        .map((n) => n.toInt())
        .toList();
    final total = dice.fold<int>(0, (subtotal, die) => subtotal + die);
    final triple = dice.length == 3 && dice[0] == dice[1] && dice[1] == dice[2];
    return _RoadRound(
      id: doc.id,
      dice: dice,
      total: total,
      side: triple
          ? _Side.storm
          : total > 10
          ? _Side.tai
          : _Side.xiu,
    );
  }
}

List<List<_RoadRound>> _makeRoad(List<_RoadRound> rounds) {
  final columns = <List<_RoadRound>>[];
  for (final round in rounds) {
    if (columns.isEmpty ||
        columns.last.last.side != round.side ||
        columns.last.length >= 6) {
      columns.add([round]);
    } else {
      columns.last.add(round);
    }
  }
  return columns;
}

Color _sideColor(_Side side) => switch (side) {
  _Side.tai => const Color(0xffff8585),
  _Side.xiu => const Color(0xff71b8ff),
  _Side.storm => const Color(0xffc7a3ff),
};

String _sideName(_Side side) => switch (side) {
  _Side.tai => 'Tài',
  _Side.xiu => 'Xỉu',
  _Side.storm => 'Bão',
};

String _sideLetter(_Side side) => switch (side) {
  _Side.tai => 'T',
  _Side.xiu => 'X',
  _Side.storm => 'B',
};

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xffa08e7a), size: 44),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xffe1e2eb)),
          ),
        ],
      ),
    ),
  );
}
