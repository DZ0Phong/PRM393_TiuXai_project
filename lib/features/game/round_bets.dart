import 'package:flutter/material.dart' hide Text;

import '../../core/app_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoundBets extends StatelessWidget {
  final String roundId;
  const RoundBets({super.key, required this.roundId});

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Cược toàn phòng (Admin)'),
    children: [
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('rounds/$roundId/bets')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ListTile(
              title: Text('Không tải được cược: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            );
          }
          final bets = snapshot.data!.docs;
          if (bets.isEmpty) return const ListTile(title: Text('Chưa có cược.'));
          final totals = <String, int>{};
          for (final bet in bets) {
            final stakes = bet.data()['stakes'] as Map? ?? {};
            for (final entry in stakes.entries) {
              totals.update(
                entry.key.toString(),
                (n) => n + (entry.value as num).toInt(),
                ifAbsent: () => (entry.value as num).toInt(),
              );
            }
          }
          return Column(
            children: [
              ListTile(
                title: Text(
                  totals.entries
                      .map((entry) => '${entry.key}: ${entry.value} xu')
                      .join(' • '),
                ),
              ),
              ...bets.map(
                (bet) => ListTile(
                  title: Text(bet.id),
                  subtitle: Text(
                    '${bet.data()['stakes']} • ${bet.data()['amount']} xu • '
                    'Ghi có: ${bet.data()['credit'] ?? 'Chờ kết quả'}',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}
