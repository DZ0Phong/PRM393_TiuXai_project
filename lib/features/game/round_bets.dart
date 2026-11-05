import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/currency_format.dart';
import 'game_specs.dart';

class RoundBets extends StatefulWidget {
  final String roundId;
  final GameSpec game;
  final DateTime now;
  const RoundBets({
    super.key,
    required this.roundId,
    required this.game,
    required this.now,
  });

  @override
  State<RoundBets> createState() => _RoundBetsState();
}

class _RoundBetsState extends State<RoundBets> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _members;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _bets;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(RoundBets oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roundId != widget.roundId ||
        oldWidget.game.id != widget.game.id) {
      _subscribe();
    }
  }

  void _subscribe() {
    _members = FirebaseFirestore.instance
        .collection('rooms/${widget.game.id}/members')
        .snapshots();
    _bets = FirebaseFirestore.instance
        .collection('rounds/${widget.roundId}/bets')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    initiallyExpanded: true,
    title: const Text('Người chơi & cược từng cửa (Admin)'),
    children: [
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _members,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ListTile(
              title: Text(
                'Không tải được người trong phòng: ${snapshot.error}',
              ),
            );
          }
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final members = snapshot.data!.docs.where((doc) {
            final seen = doc.data()['lastSeen'];
            return seen is Timestamp &&
                widget.now.difference(seen.toDate()).inSeconds < 150;
          }).toList();
          return Column(
            children: [
              ListTile(
                title: Text(
                  'Đang trong phòng (gần đúng): ${members.length} người',
                ),
              ),
              for (final member in members)
                ListTile(
                  dense: true,
                  title: Text(
                    member.data()['nickname']?.toString() ?? member.id,
                  ),
                  subtitle: Text('UID ${member.id}'),
                ),
              const Divider(),
            ],
          );
        },
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _bets,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ListTile(
              title: Text('Không tải được cược: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final bets = snapshot.data!.docs
              .where((doc) => (doc.data()['amount'] as num? ?? 0) > 0)
              .toList();
          final totals = {for (final side in widget.game.sides) side.$1: 0};
          final counts = {for (final side in widget.game.sides) side.$1: 0};
          for (final bet in bets) {
            final stakes = bet.data()['stakes'] as Map? ?? {};
            for (final side in widget.game.sides) {
              final stake = stakes[side.$1];
              if (stake is num && stake > 0) {
                totals[side.$1] = totals[side.$1]! + stake.toInt();
                counts[side.$1] = counts[side.$1]! + 1;
              }
            }
          }
          final amounts = totals.values.toList();
          final spread =
              amounts.reduce((a, b) => a > b ? a : b) -
              amounts.reduce((a, b) => a < b ? a : b);
          final leading = widget.game.sides.reduce(
            (a, b) => totals[a.$1]! >= totals[b.$1]! ? a : b,
          );
          final total = amounts.fold<int>(0, (a, b) => a + b);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: Text(
                  '${bets.length} người đang cược • Tổng ${formatCurrencyAmount(total)} VNĐ',
                ),
                subtitle: Text(
                  widget.game.id == 'tai_xiu'
                      ? 'Chênh Tài − Xỉu: ${formatCurrencyAmount(totals['tai']! - totals['xiu']!)} VNĐ'
                      : 'Cửa cao nhất: ${leading.$2} • Chênh cao nhất − thấp nhất: ${formatCurrencyAmount(spread)} VNĐ',
                ),
              ),
              for (final side in widget.game.sides)
                Builder(
                  builder: (context) {
                    final sideBets = bets.where((bet) {
                      final stakes = bet.data()['stakes'] as Map? ?? {};
                      final amount = stakes[side.$1];
                      return amount is num && amount > 0;
                    }).toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          dense: true,
                          title: Text('${side.$2} • ${counts[side.$1]} người'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${formatCurrencyAmount(totals[side.$1]!)} VNĐ'),
                              if (widget.game.id == 'bau_cua' &&
                                  sideBets.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 0,
                                  children: [
                                    for (final bet in sideBets)
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        label: Text(
                                          '${bet.data()['nickname']?.toString() ?? 'Bạn ${bet.id.substring(0, bet.id.length < 6 ? bet.id.length : 6)}'} · ${formatCurrencyAmount(((bet.data()['stakes'] as Map)[side.$1] as num).toInt())} VNĐ',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              const Divider(),
              if (bets.isEmpty) const ListTile(title: Text('Chưa có cược.')),
              for (final bet in bets)
                ListTile(
                  dense: true,
                  title: Text(
                    bet.data()['nickname']?.toString() ??
                        'Bạn ${bet.id.substring(0, bet.id.length < 6 ? bet.id.length : 6)}',
                  ),
                  subtitle: Text('UID ${bet.id} • ${bet.data()['stakes']}'),
                  trailing: Text('${formatCurrencyAmount((bet.data()['amount'] as num).toInt())} VNĐ'),
                ),
            ],
          );
        },
      ),
    ],
  );
}
