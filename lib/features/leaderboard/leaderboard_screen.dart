import 'package:tai_xiu_realtime/core/backend_functions.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../core/currency_format.dart';

class LeaderboardScreen extends StatefulWidget {
  final FirebaseFunctions functions;

  const LeaderboardScreen({super.key, required this.functions});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const _background = Color(0xff111318);
  static const _gold = Color(0xffffc174);
  late Future<List<_LeaderboardEntry>> _ranking;

  @override
  void initState() {
    super.initState();
    _ranking = _loadRanking();
  }

  Future<List<_LeaderboardEntry>> _loadRanking() async {
    final result = await widget.functions.gameCallable('getLeaderboard').call();
    final data = result.data;
    if (data is! List) {
      throw const FormatException('Dữ liệu bảng xếp hạng không hợp lệ.');
    }
    return data.whereType<Map>().map(_LeaderboardEntry.fromMap).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
  }

  void _refresh() => setState(() => _ranking = _loadRanking());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: const Color(0xffe1e2eb),
        title: const Text('Bảng xếp hạng'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<_LeaderboardEntry>>(
          future: _ranking,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _gold));
            }
            if (snapshot.hasError) {
              return _MessageState(
                icon: Icons.cloud_off_outlined,
                message: 'Không tải được bảng xếp hạng.',
                action: TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              );
            }
            final rows = snapshot.data ?? const <_LeaderboardEntry>[];
            if (rows.isEmpty) {
              return const _MessageState(
                icon: Icons.emoji_events_outlined,
                message: 'Chưa có dữ liệu người chơi để xếp hạng.',
              );
            }
            final podium = rows.where((entry) => entry.rank <= 3).toList();
            final challengers = rows.where((entry) => entry.rank > 3).toList();
            return RefreshIndicator(
              color: _gold,
              onRefresh: () async {
                _refresh();
                try {
                  await _ranking;
                } catch (_) {
                  // FutureBuilder renders the retry state for failed requests.
                }
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _introCard(rows.length),
                  const SizedBox(height: 22),
                  if (podium.isNotEmpty) ...[
                    const _SectionTitle(
                      icon: Icons.military_tech,
                      title: 'Top vinh danh',
                    ),
                    const SizedBox(height: 12),
                    _Podium(entries: podium),
                    const SizedBox(height: 24),
                  ],
                  if (challengers.isNotEmpty) ...[
                    _SectionTitle(
                      icon: Icons.trending_up,
                      title: 'Thứ hạng ${challengers.first.rank}–${challengers.last.rank}',
                    ),
                    const SizedBox(height: 10),
                    for (final entry in challengers)
                      _RankingTile(entry: entry),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'Thứ hạng được sắp theo số dư VNĐ mô phỏng. Danh sách hiển thị tối đa 20 người chơi và được tải lại khi bạn làm mới.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xff9b9ca5), fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _introCard(int count) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(
        colors: [Color(0xff352b1d), Color(0xff211f1d)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: _gold.withValues(alpha: .32)),
    ),
    child: Row(
      children: [
        const Icon(Icons.workspace_premium, color: _gold, size: 38),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HALL OF FAME · VNĐ MÔ PHỎNG',
                style: TextStyle(color: _gold, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 5),
              Text(
                '$count người chơi trong bảng hiện tại',
                style: const TextStyle(color: Color(0xffe1e2eb)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Điểm mô phỏng giải trí · Không có giá trị quy đổi tiền mặt',
                style: TextStyle(color: Color(0xffb9a78f), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LeaderboardEntry {
  final int rank;
  final String nickname;
  final num balance;

  const _LeaderboardEntry({required this.rank, required this.nickname, required this.balance});

  factory _LeaderboardEntry.fromMap(Map row) {
    final rawRank = row['rank'];
    final rawBalance = row['balance'];
    return _LeaderboardEntry(
      rank: rawRank is num ? rawRank.toInt() : int.tryParse('$rawRank') ?? 0,
      nickname: row['nickname']?.toString() ?? 'Người chơi',
      balance: rawBalance is num ? rawBalance : num.tryParse('$rawBalance') ?? 0,
    );
  }
}

class _Podium extends StatelessWidget {
  final List<_LeaderboardEntry> entries;
  const _Podium({required this.entries});

  @override
  Widget build(BuildContext context) {
    final byRank = {for (final entry in entries) entry.rank: entry};
    const order = [2, 1, 3];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final rank in order)
          Expanded(
            child: byRank[rank] == null
                ? const SizedBox(height: 118)
                : _PodiumPlace(entry: byRank[rank]!, height: rank == 1 ? 166 : 132),
          ),
      ],
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  final _LeaderboardEntry entry;
  final double height;
  const _PodiumPlace({required this.entry, required this.height});

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.rank) {
      1 => const Color(0xffffc174),
      2 => const Color(0xffc5cad5),
      _ => const Color(0xffc98b5a),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(entry.rank == 1 ? Icons.workspace_premium : Icons.shield, color: color, size: 28),
          const SizedBox(height: 6),
          Text('#${entry.rank}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(entry.nickname, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xffe1e2eb), fontSize: 12)),
          const SizedBox(height: 4),
          Text('${_formatBalance(entry.balance)} VNĐ', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            height: height - 82,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(color: color.withValues(alpha: .45)),
            ),
            child: Text('${entry.rank}', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  final _LeaderboardEntry entry;
  const _RankingTile({required this.entry});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      color: const Color(0xff1d2026),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0x1affffff)),
    ),
    child: Row(
      children: [
        SizedBox(width: 34, child: Text(entry.rank.toString().padLeft(2, '0'),
            style: const TextStyle(color: Color(0xffa8a9b1), fontWeight: FontWeight.bold))),
        const CircleAvatar(radius: 17, backgroundColor: Color(0xff30333a),
          child: Icon(Icons.person, color: Color(0xffc6c7ce), size: 19)),
        const SizedBox(width: 12),
        Expanded(child: Text(entry.nickname, style: const TextStyle(color: Color(0xffe1e2eb), fontWeight: FontWeight.w600))),
        Text('${_formatBalance(entry.balance)} VNĐ',
            style: const TextStyle(color: Color(0xffffc174), fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(
    children: [Icon(icon, color: const Color(0xffffc174)), const SizedBox(width: 8),
      Text(title, style: const TextStyle(color: Color(0xffe1e2eb), fontSize: 16, fontWeight: FontWeight.bold))],
  );
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;
  const _MessageState({required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: const Color(0xffa08e7a), size: 46),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xffe1e2eb))),
        ?action,
      ]),
    ),
  );
}

String _formatBalance(num value) {
  return formatCurrencyAmount(value.round());
}
