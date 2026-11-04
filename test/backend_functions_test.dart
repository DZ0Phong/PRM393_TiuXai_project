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

  test('live Spark requires the VPS backend URL', () {
    expect(backendConfigurationError(false, ''), isNotNull);
  });

  test('live backend requires a secure origin without port or path', () {
    expect(
      backendConfigurationError(false, 'https://host.tailnet.ts.net'),
      isNull,
    );
    expect(backendConfigurationError(false, 'https://203.0.113.10'), isNull);
    expect(backendConfigurationError(false, 'https://backend.example.com'), isNull);
    for (final url in [
      'http://host.tailnet.ts.net',
      'https://host.tailnet.ts.net:8765',
      'https://host.tailnet.ts.net/path',
      'https://host.tailnet.ts.net?token=secret',
      'https://localhost',
      'https://127.0.0.1',
      'https://user:pass@backend.example.com',
    ]) {
      expect(backendConfigurationError(false, url), isNotNull, reason: url);
    }
  });
}
