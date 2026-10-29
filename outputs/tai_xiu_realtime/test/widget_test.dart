import 'package:flutter_test/flutter_test.dart';
import 'package:tai_xiu_realtime/main.dart';

void main() {
  test('Debug mặc định dùng emulator', () {
    expect(emulator, isTrue);
    expect(host, '127.0.0.1');
  });
}
