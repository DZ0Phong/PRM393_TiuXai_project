import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:tai_xiu_realtime/features/game/game_specs.dart';
import 'package:tai_xiu_realtime/features/admin/admin_console.dart';
import 'package:tai_xiu_realtime/main.dart';
import 'package:tai_xiu_realtime/features/game/presentation/widgets/tai_xiu_betting_table.dart';

void main() {
  test('ALL IN làm tròn bội số 100 và không gửi cược dưới 1000', () {
    expect(validAllInStake(28580, 1000000), 28500);
    expect(validAllInStake(999, 1000000), 0);
    expect(validAllInStake(1030, 990), 0);
    expect(validAllInStake(1000000, 1000000), 1000000);
  });

  test('Chỉ lỗi server dứt khoát mới xóa điều chỉnh chờ', () {
    expect(definitiveAdjustError('invalid-argument'), isTrue);
    expect(definitiveAdjustError('permission-denied'), isTrue);
    expect(definitiveAdjustError('unavailable'), isFalse);
    expect(definitiveAdjustError('deadline-exceeded'), isFalse);
  });

  test('Debug mặc định dùng emulator, không tự ghi vào Firebase thật', () {
    expect(emulator, isTrue);
    expect(
      host,
      defaultTargetPlatform == TargetPlatform.android
          ? '10.0.2.2'
          : '127.0.0.1',
    );
  });

  test('Ba phòng chơi riêng, kết quả quản trị được kiểm tra theo game', () {
    expect(games.map((game) => game.id), ['tai_xiu', 'bau_cua', 'xoc_xoc']);
    expect(parseRoundResult(games[0], '2, 3, 6'), [2, 3, 6]);
    expect(parseRoundResult(games[0], '2,7,6'), isNull);
    expect(parseRoundResult(games[1], 'bau,cua,tom'), ['bau', 'cua', 'tom']);
    expect(parseRoundResult(games[1], 'bau,foo,tom'), isNull);
    expect(parseRoundResult(games[2], '0,1,0,1'), [0, 1, 0, 1]);
    expect(parseRoundResult(games[2], '0,1,2,1'), isNull);
  });
}
