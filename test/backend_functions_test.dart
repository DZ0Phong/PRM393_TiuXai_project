import 'package:flutter_test/flutter_test.dart';
import 'package:tai_xiu_realtime/core/backend_functions.dart';

void main() {
  test('local emulator rejects a private backend URL', () {
    expect(backendConfigurationError(true, ''), isNull);
    expect(
      backendConfigurationError(true, 'https://host.tailnet.ts.net'),
      isNotNull,
    );
  });

  test('live Functions needs no private backend URL', () {
    expect(backendConfigurationError(false, ''), isNull);
  });

  test('private backend still requires a secure Tailscale origin', () {
    expect(
      backendConfigurationError(false, 'https://host.tailnet.ts.net'),
      isNull,
    );
    for (final url in [
      'http://host.tailnet.ts.net',
      'https://host.tailnet.ts.net:8765',
      'https://host.tailnet.ts.net/path',
      'https://host.tailnet.ts.net?token=secret',
      'https://other.example.com',
    ]) {
      expect(backendConfigurationError(false, url), isNotNull, reason: url);
    }
  });
}
