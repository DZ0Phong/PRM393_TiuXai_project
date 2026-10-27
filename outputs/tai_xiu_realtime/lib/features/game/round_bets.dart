import 'package:flutter/material.dart';
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
        builder: (context, s) {
          if (s.hasError) return Text('Lỗi tải cược: ${s.error}');
          final bets = s.data?.docs;
          if (bets == null) return const LinearProgressIndicator();
          final tai = bets
              .where((b) => b.data()['side'] == 'tai')
              .fold<int>(0, (total, b) => total + (b.data()['amount'] as int));
          final xiu = bets
              .where((b) => b.data()['side'] == 'xiu')
              .fold<int>(0, (total, b) => total + (b.data()['amount'] as int));
          return Column(
            children: [
              Text('Tổng Tài: $tai xu • Xỉu: $xiu xu'),
              ...bets.map(
                (b) => ListTile(
                  title: Text(b.id),
                  subtitle: Text(
                    '${b.data()['side']} • ${b.data()['amount']} xu • Ghi có: ${b.data()['credit'] ?? "Chờ kết quả"}',
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
