import 'package:flutter_test/flutter_test.dart';
import 'package:tai_xiu_realtime/features/game/round_history.dart';

void main() {
  test(
    'Cầu theo thứ tự thời gian: cắt cột tại chiều cao và giới hạn hiển thị',
    () {
      expect(roadColumns(['tai', 'tai', 'tai', 'xiu', 'xiu', 'tai'], 2, 3), [
        ['tai'],
        ['xiu', 'xiu'],
        ['tai'],
      ]);
      expect(roadColumns(['chan', 'le', 'chan', 'le'], 4, 2), [
        ['chan'],
        ['le'],
      ]);
      expect(roadColumns([], 5, 20), isEmpty);
    },
  );
}
