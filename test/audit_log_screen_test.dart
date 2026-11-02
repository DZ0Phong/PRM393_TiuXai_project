import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tai_xiu_realtime/features/admin/audit_log_repository.dart';
import 'package:tai_xiu_realtime/features/admin/audit_log_screen.dart';

class _FakeAuditLogRepository implements AuditLogRepository {
  final controller = StreamController<List<AuditLogEntry>>.broadcast();
  final pages = <List<AuditLogEntry>>[];
  int fetchCount = 0;

  @override
  Stream<List<AuditLogEntry>> watchLatest(int limit) => controller.stream;

  @override
  Future<List<AuditLogEntry>> fetchAfter(
    AuditLogEntry cursor,
    int limit,
  ) async {
    fetchCount++;
    return pages.isEmpty ? [] : pages.removeAt(0);
  }

  Future<void> dispose() => controller.close();
}

AuditLogEntry _entry({
  required String id,
  required String action,
  String actor = 'admin-1',
  Map<String, dynamic> details = const {},
}) => AuditLogEntry(
  id: id,
  data: {
    'action': action,
    'actor': actor,
    'details': details,
    'at': Timestamp.fromDate(DateTime(2026, 11, 2, 14, 30)),
  },
);

List<AuditLogEntry> _firstPage() => [
  _entry(
    id: 'adjust-log',
    action: 'ADJUST_BALANCE',
    details: {'uid': 'player-01', 'reason': 'Điều chỉnh do lỗi kết nối'},
  ),
  _entry(id: 'bet-log', action: 'BET', details: {'uid': 'player-02'}),
  ...List.generate(
    18,
    (index) => _entry(id: 'log-$index', action: 'TABLE_ACTION'),
  ),
];

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeAuditLogRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(home: AuditLogScreen(repository: repository)),
  );
  repository.controller.add(_firstPage());
  await tester.pump();
}

void main() {
  testWidgets('shows live records and filters by backend event category', (
    tester,
  ) async {
    final repository = _FakeAuditLogRepository();
    await _pumpScreen(tester, repository);
    expect(find.text('Nhật Ký Quản Trị Hệ Thống'), findsOneWidget);
    expect(find.text('20 bản ghi đang hiển thị • 20 đã tải'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Điểm & ví'));
    await tester.pump();
    expect(find.text('1 bản ghi đang hiển thị • 20 đã tải'), findsOneWidget);
    expect(find.text('Điều chỉnh điểm'), findsOneWidget);
    expect(find.text('Đặt cược'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tất cả'));
    await tester.pump();

    repository.controller.add([
      _entry(
        id: 'new-settle',
        action: 'SETTLE',
        details: {'roundId': 'round-9'},
      ),
      ..._firstPage().take(19),
    ]);
    await tester.pump();
    expect(find.text('Chốt kết quả phiên'), findsOneWidget);
    await repository.dispose();
  });

  testWidgets('searches record details and offers reset for an empty result', (
    tester,
  ) async {
    final repository = _FakeAuditLogRepository();
    await _pumpScreen(tester, repository);
    await tester.enterText(find.byType(TextField), 'player-01');
    await tester.pump();
    expect(find.text('1 bản ghi đang hiển thị • 20 đã tải'), findsOneWidget);
    expect(find.text('Điều chỉnh điểm'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'no-match');
    await tester.pump();
    expect(find.text('Không tìm thấy nhật ký phù hợp.'), findsOneWidget);
    await tester.tap(find.text('Đặt lại bộ lọc'));
    await tester.pump();
    expect(find.text('20 bản ghi đang hiển thị • 20 đã tải'), findsOneWidget);
    await repository.dispose();
  });

  testWidgets('loads an older page and disables load-more at the end', (
    tester,
  ) async {
    final repository = _FakeAuditLogRepository()
      ..pages.add([_entry(id: 'older-log', action: 'TABLE_TIMEOUT')]);
    await _pumpScreen(tester, repository);
    final verticalScroll = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.text('Tải thêm 20 bản ghi trước'),
      300,
      scrollable: verticalScroll.first,
    );
    await tester.tap(find.text('Tải thêm 20 bản ghi trước'));
    await tester.pump();
    await tester.pump();

    expect(repository.fetchCount, 1);
    await tester.scrollUntilVisible(
      find.text('Tự động xử lý lượt hết giờ'),
      300,
      scrollable: verticalScroll.first,
    );
    expect(find.text('Tự động xử lý lượt hết giờ'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Tải thêm 20 bản ghi trước'),
      300,
      scrollable: verticalScroll.first,
    );
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Tải thêm 20 bản ghi trước'),
    );
    expect(button.onPressed, isNull);
    await repository.dispose();
  });

  testWidgets('shows Firestore query errors', (tester) async {
    final repository = _FakeAuditLogRepository();
    await tester.pumpWidget(
      MaterialApp(home: AuditLogScreen(repository: repository)),
    );
    repository.controller.addError(StateError('offline'));
    await tester.pump();
    expect(find.textContaining('Không tải được nhật ký:'), findsOneWidget);
    await repository.dispose();
  });
}
