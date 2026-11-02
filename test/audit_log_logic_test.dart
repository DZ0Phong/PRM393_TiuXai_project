import 'package:flutter_test/flutter_test.dart';
import 'package:tai_xiu_realtime/features/admin/audit_log_logic.dart';

void main() {
  group('audit event categories', () {
    test('maps every backend action to a visible filter', () {
      const actions = <String, String>{
        'INTERVENE_ROUND': 'round_result',
        'SETTLE': 'round_result',
        'ADJUST_BALANCE': 'balance',
        'CANCEL': 'cancel',
        'TABLE_CANCEL': 'cancel',
        'BET_REFUND': 'cancel',
        'BLOCK_PLAYER': 'account',
        'UNBLOCK_PLAYER': 'account',
        'BET': 'bet',
        'TABLE_BOT_CONFIG': 'bot',
        'TABLE_CREATE': 'table',
        'TABLE_JOIN': 'table',
        'TABLE_LEAVE': 'table',
        'TABLE_START': 'table',
        'TABLE_ACTION': 'table',
        'TABLE_TIMEOUT': 'table',
        'WELCOME': 'system',
        'AUTO_MODE_MIGRATE': 'round',
        'AUTO_START': 'round',
        'START': 'round',
        'LOCK': 'round',
      };

      for (final entry in actions.entries) {
        expect(
          auditCategoryForAction(entry.key),
          entry.value,
          reason: entry.key,
        );
        expect(auditMatchesCategory(entry.key, entry.value), isTrue);
        expect(auditMatchesCategory(entry.key, 'all'), isTrue);
      }
      expect(auditMatchesCategory('ADJUST_BALANCE', 'account'), isFalse);
    });
  });

  group('audit search', () {
    const record = <String, dynamic>{
      'actor': 'admin-123',
      'action': 'ADJUST_BALANCE',
      'details': {
        'uid': 'player-456',
        'reason': 'Điều chỉnh do lỗi kết nối phiên #TX-901',
      },
    };

    test('matches document, actor, UID, action, IDs, and detail text', () {
      for (final query in [
        'audit-document',
        'ADMIN-123',
        'player-456',
        'adjust_balance',
        'TX-901',
      ]) {
        expect(
          auditMatchesSearch(
            documentId: 'audit-document',
            data: record,
            query: query,
          ),
          isTrue,
          reason: query,
        );
      }
    });

    test('ignores Vietnamese accents and surrounding spaces', () {
      expect(
        auditMatchesSearch(
          documentId: 'audit-document',
          data: record,
          query: '  dieu chinh do loi ket noi  ',
        ),
        isTrue,
      );
    });

    test('an empty query matches and unrelated query does not', () {
      expect(
        auditMatchesSearch(
          documentId: 'audit-document',
          data: record,
          query: '  ',
        ),
        isTrue,
      );
      expect(
        auditMatchesSearch(
          documentId: 'audit-document',
          data: record,
          query: 'không có trong nhật ký',
        ),
        isFalse,
      );
    });
  });
}
