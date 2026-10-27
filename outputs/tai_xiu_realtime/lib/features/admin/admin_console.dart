import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminConsole extends StatefulWidget {
  final bool busy;
  final Future<void> Function(String, Map<String, dynamic>) execute;
  const AdminConsole({super.key, required this.busy, required this.execute});
  @override
  State<AdminConsole> createState() => _AdminConsoleState();
}

class _AdminConsoleState extends State<AdminConsole> {
  final target = TextEditingController();
  final delta = TextEditingController(text: '100');
  final reason = TextEditingController();
  @override
  void dispose() {
    target.dispose();
    delta.dispose();
    reason.dispose();
    super.dispose();
  }

  Widget button(
    String label,
    String api,
    Map<String, dynamic> Function() data,
  ) => Padding(
    padding: const EdgeInsets.all(4),
    child: OutlinedButton(
      onPressed: widget.busy ? null : () => widget.execute(api, data()),
      child: Text(label),
    ),
  );
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Quản lý tài khoản & ví xu'),
    subtitle: const Text(
      'Mọi thay đổi phải có lý do và được ghi audit công khai',
    ),
    children: [
      TextField(
        controller: target,
        decoration: const InputDecoration(
          labelText: 'UID người chơi (chọn trong danh sách bên dưới)',
        ),
      ),
      TextField(
        controller: delta,
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        decoration: const InputDecoration(
          labelText: 'Số xu điều chỉnh: dương để cộng, âm để trừ',
        ),
      ),
      TextField(
        controller: reason,
        maxLength: 300,
        decoration: const InputDecoration(labelText: 'Lý do 5–300 ký tự'),
      ),
      Wrap(
        children: [
          button(
            'Điều chỉnh ví',
            'adjustBalance',
            () => {
              'uid': target.text.trim(),
              'delta': int.tryParse(delta.text),
              'reason': reason.text.trim(),
              'requestId': 'adjust_${DateTime.now().microsecondsSinceEpoch}',
            },
          ),
          button(
            'Khóa truy cập game',
            'setPlayerBlocked',
            () => {
              'uid': target.text.trim(),
              'blocked': true,
              'reason': reason.text.trim(),
            },
          ),
          button(
            'Mở khóa',
            'setPlayerBlocked',
            () => {
              'uid': target.text.trim(),
              'blocked': false,
              'reason': reason.text.trim(),
            },
          ),
        ],
      ),
      const Text('50 tài khoản mới nhất • nhấn để chọn; có thể nhập UID khác'),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, s) {
          if (s.hasError) return Text('Không tải được tài khoản: ${s.error}');
          return Column(
            children:
                s.data?.docs
                    .map(
                      (d) => ListTile(
                        title: Text(d.id),
                        subtitle: Text(
                          '${d.data()['balance']} xu • ${d.data()['blocked'] == true ? "ĐÃ KHÓA" : "Hoạt động"}',
                        ),
                        onTap: widget.busy
                            ? null
                            : () => setState(() => target.text = d.id),
                      ),
                    )
                    .toList() ??
                [const LinearProgressIndicator()],
          );
        },
      ),
    ],
  );
}
