import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tai_xiu_realtime/core/pending_mutation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Giữ requestId và payload khi tạo lại store; cách ly theo UID',
    () async {
      final first = PendingMutationStore();
      final intent = <String, dynamic>{
        'name': 'wallet',
        'data': {
          'requestId': 'same-request-123',
          'kind': 'deposit',
          'amount': 100,
        },
      };
      await first.save('alice', intent);
      final reopened = PendingMutationStore();
      expect(await reopened.load('alice'), intent);
      expect(await reopened.load('bob'), isNull);
      await reopened.save('bob', {
        'name': 'wallet',
        'data': {'requestId': 'bob-request-123'},
      });
      await reopened.clear('alice');
      expect(await first.load('alice'), isNull);
      expect(
        (await first.load('bob'))?['data']['requestId'],
        'bob-request-123',
      );
    },
  );
}
