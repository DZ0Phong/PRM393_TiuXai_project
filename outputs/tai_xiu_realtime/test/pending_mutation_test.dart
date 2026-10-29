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
  test('Không ghi đè requestId chưa xác nhận khi mở lại store', () async {
    final store = PendingMutationStore();
    final first = <String, dynamic>{
      'name': 'wallet',
      'data': {
        'requestId': 'first-request-123',
        'kind': 'deposit',
        'amount': 100,
      },
    };
    await store.save('alice', first);
    await expectLater(
      PendingMutationStore().save('alice', {
        'name': 'wallet',
        'data': {
          'requestId': 'second-request-123',
          'kind': 'deposit',
          'amount': 100,
        },
      }),
      throwsStateError,
    );
    expect(await store.load('alice'), first);
  });
}
