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

  test('Giọt Nước maps three dice to Tài, Xỉu, Bão and skips bad results', () {
    expect(
      taiXiuBeadResult({
        'result': [4, 4, 5],
      }),
      (mark: 'T', total: 13),
    );
    expect(
      taiXiuBeadResult({
        'result': [1, 2, 3],
      }),
      (mark: 'X', total: 6),
    );
    expect(
      taiXiuBeadResult({
        'result': [6, 6, 6],
      }),
      (mark: 'B', total: 18),
    );
    expect(
      taiXiuBeadResult({
        'result': [0, 4, 5],
      }),
      isNull,
    );
    expect(
      taiXiuBeadResult({
        'result': [2, 3],
      }),
      isNull,
    );
    expect(
      taiXiuBeadResult({
        'result': [double.nan, 2, 3],
      }),
      isNull,
    );
  });
}
