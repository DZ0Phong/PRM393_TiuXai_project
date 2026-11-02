import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tai_xiu_realtime/features/admin/player_management_repository.dart';
import 'package:tai_xiu_realtime/features/admin/player_management_screen.dart';

class _FakePlayerRepository implements PlayerManagementRepository {
  final controller = StreamController<List<PlayerRecord>>.broadcast();
  final records = <String, PlayerRecord>{};
  final pages = <List<PlayerRecord>>[];
  int lookupCount = 0;
  int pageCount = 0;

  @override
  Stream<List<PlayerRecord>> watchLatest(int limit) => controller.stream;

  @override
  Future<PlayerRecord?> getByUid(String uid) async {
    lookupCount++;
    return records[uid];
  }

  @override
  Future<List<PlayerRecord>> fetchAfter(PlayerRecord cursor, int limit) async {
    pageCount++;
    return pages.isEmpty ? [] : pages.removeAt(0);
  }

  Future<void> close() => controller.close();
}

PlayerRecord _player(
  String uid, {
  int balance = 20000,
  bool blocked = false,
  bool isBot = false,
}) => PlayerRecord(
  uid: uid,
  data: {
    'balance': balance,
    'blocked': blocked,
    'isBot': isBot,
    'createdAt': Timestamp.fromDate(DateTime(2026, 11, 2)),
  },
);

class _Harness {
  _Harness() {
    players = _FakePlayerRepository();
    players.records.addAll({
      'player-active-01': _player('player-active-01'),
      'player-locked-02': _player('player-locked-02', blocked: true),
      'admin-self-uid': _player('admin-self-uid'),
    });
    latest = players.records.values.toList();
  }

  late final _FakePlayerRepository players;
  late List<PlayerRecord> latest;
  final calls = <({String name, Map<String, dynamic> data})>[];
  bool failAdjustOnce = false;

  Future<void> invoke(String name, Map<String, dynamic> data) async {
    calls.add((name: name, data: Map<String, dynamic>.from(data)));
    final player = players.records[data['uid']];
    if (name == 'adjustBalance') {
      if (failAdjustOnce) {
        failAdjustOnce = false;
        throw FirebaseFunctionsException(
          code: 'unavailable',
          message: 'offline',
        );
      }
      if (player != null) {
        final balance =
            (player.data['balance'] as int) + (data['delta'] as int);
        final updated = _player(
          player.uid,
          balance: balance,
          blocked: player.data['blocked'] == true,
        );
        players.records[player.uid] = updated;
        players.controller.add(
          latest.map((item) => players.records[item.uid]!).toList(),
        );
      }
    } else if (name == 'setPlayerBlocked' && player != null) {
      players.records[player.uid] = _player(
        player.uid,
        balance: player.data['balance'] as int,
        blocked: data['blocked'] as bool,
      );
      players.controller.add(
        latest.map((item) => players.records[item.uid]!).toList(),
      );
    }
  }
}

Future<void> _pump(WidgetTester tester, _Harness harness) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    MaterialApp(
      home: PlayerManagementScreen(
        adminUid: 'admin-self-uid',
        invoke: harness.invoke,
        repository: harness.players,
      ),
    ),
  );
  harness.players.controller.add(harness.latest);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
}

Future<void> _select(WidgetTester tester, String uid) async {
  await tester.tap(find.text(uid));
  await tester.pump();
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  final listView = find.byType(ListView);
  expect(listView, findsOneWidget);
  final scrollable = find.descendant(
    of: listView,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    ),
  ).first;
  await tester.scrollUntilVisible(target, 250, scrollable: scrollable);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('lists players, filters status and looks up exact UID', (
    tester,
  ) async {
    final harness = _Harness();
    await _pump(tester, harness);
    expect(find.text('Quản lý người chơi'), findsWidgets);
    expect(find.text('player-active-01'), findsOneWidget);
    expect(find.text('player-locked-02'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Đã khóa'));
    await tester.pump();
    expect(find.text('player-locked-02'), findsOneWidget);
    expect(find.text('player-active-01'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Tất cả'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'player-active-01');
    await tester.tap(find.byTooltip('Tra cứu UID chính xác'));
    await tester.pump();
    await tester.pump();
    expect(harness.players.lookupCount, 1);
    expect(find.text('Đã tìm thấy người chơi.'), findsOneWidget);
    expect(find.text('20000 xu'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'missing-player');
    await tester.tap(find.byTooltip('Tra cứu UID chính xác'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Không tìm thấy người chơi với UID này.'), findsOneWidget);
    await harness.players.close();
  });

  testWidgets('loads an older player page and reports end of collection', (
    tester,
  ) async {
    final harness = _Harness();
    for (var index = 0; index < 50; index++) {
      final player = _player('page-player-${index.toString().padLeft(2, '0')}');
      harness.players.records[player.uid] = player;
    }
    harness.latest = harness.players.records.values.take(50).toList();
    final older = _player('older-player-uid');
    harness.players.records[older.uid] = older;
    harness.players.pages.add([older]);
    await _pump(tester, harness);
    final loadMore = find.widgetWithText(
      OutlinedButton,
      'Tải thêm 50 tài khoản cũ hơn',
    );
    await _scrollTo(tester, loadMore);
    await tester.tap(loadMore);
    await tester.pumpAndSettle();
    expect(harness.players.pageCount, 1);
    expect(find.text('older-player-uid'), findsOneWidget);
    expect(find.text('Đã tải hết tài khoản'), findsOneWidget);
    await harness.players.close();
  });

  testWidgets(
    'confirms and submits a signed adjustment through backend callable',
    (tester) async {
      final harness = _Harness();
      await _pump(tester, harness);
      await _select(tester, 'player-active-01');
      await tester.enterText(find.byType(TextField).at(1), '5000');
      await tester.tap(find.text('Trừ điểm (−)'));
      await tester.enterText(find.byType(TextField).at(2), 'Sai lệch kiểm thử');
      final submit = find.byKey(const ValueKey('player-adjustment-submit'));
      await _scrollTo(tester, submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Hành động: -5000 xu'), findsOneWidget);
      expect(find.text('Số dư dự kiến: 15000 xu'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận').last);
      await tester.pumpAndSettle();

      expect(harness.calls, hasLength(1));
      expect(harness.calls.single.name, 'adjustBalance');
      expect(harness.calls.single.data['uid'], 'player-active-01');
      expect(harness.calls.single.data['delta'], -5000);
      expect(harness.calls.single.data['reason'], 'Sai lệch kiểm thử');
      expect(harness.calls.single.data['requestId'], isNotEmpty);
      expect(find.text('Đã điều chỉnh điểm.'), findsOneWidget);
      expect(find.textContaining('15000 xu'), findsWidgets);
      await harness.players.close();
    },
  );

  testWidgets(
    'canceling confirmation sends nothing; rejects invalid amount/reason',
    (tester) async {
      final harness = _Harness();
      await _pump(tester, harness);
      await _select(tester, 'player-active-01');
      await tester.enterText(find.byType(TextField).at(1), '1000');
      await tester.enterText(find.byType(TextField).at(2), 'Lý do hợp lệ');
      final submit = find.byKey(const ValueKey('player-adjustment-submit'));
      await _scrollTo(tester, submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();
      expect(harness.calls, isEmpty);

      await tester.enterText(find.byType(TextField).at(1), '100001');
      await tester.tap(submit);
      await tester.pump();
      expect(find.textContaining('±1–100000'), findsOneWidget);
      expect(harness.calls, isEmpty);
      await harness.players.close();
    },
  );

  testWidgets(
    'retains and retries the same request after a transient failure',
    (tester) async {
      final harness = _Harness()..failAdjustOnce = true;
      await _pump(tester, harness);
      await _select(tester, 'player-active-01');
      await tester.enterText(find.byType(TextField).at(1), '1000');
      await tester.enterText(find.byType(TextField).at(2), 'Thử lại request');
      final submit = find.byKey(const ValueKey('player-adjustment-submit'));
      await _scrollTo(tester, submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận').last);
      await tester.pumpAndSettle();
      expect(find.text('Thử lại điều chỉnh'), findsOneWidget);
      expect(find.textContaining('chưa được xác nhận'), findsOneWidget);
      final requestId = harness.calls.first.data['requestId'];

      await tester.tap(find.text('Thử lại điều chỉnh'));
      await tester.pumpAndSettle();
      expect(harness.calls, hasLength(2));
      expect(harness.calls.last.data['requestId'], requestId);
      expect(find.text('Đã điều chỉnh điểm.'), findsOneWidget);
      await harness.players.close();
    },
  );

  testWidgets('locks and unlocks with reason; disables self lock controls', (
    tester,
  ) async {
    final harness = _Harness();
    await _pump(tester, harness);
    await _select(tester, 'player-active-01');
    await tester.enterText(find.byType(TextField).at(2), 'Vi phạm quy định');
    final lockButton = find.widgetWithText(OutlinedButton, 'Khóa tài khoản');
    await _scrollTo(tester, lockButton);
    await tester.enterText(find.byType(TextField).at(2), 'x');
    await tester.tap(lockButton);
    await tester.pumpAndSettle();
    expect(find.textContaining('lý do 5–300 ký tự'), findsOneWidget);
    expect(harness.calls, isEmpty);
    await tester.enterText(find.byType(TextField).at(2), 'Vi phạm quy định');
    await tester.tap(lockButton);
    await tester.pumpAndSettle();
    expect(harness.calls.single.name, 'setPlayerBlocked');
    expect(harness.calls.single.data['blocked'], isTrue);
    expect(harness.calls.single.data['reason'], 'Vi phạm quy định');
    expect(find.text('Đã khóa tài khoản.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(2), 'Đã xử lý xong');
    final unlockButton = find.widgetWithText(OutlinedButton, 'Mở khóa');
    await _scrollTo(tester, unlockButton);
    await tester.tap(unlockButton);
    await tester.pumpAndSettle();
    expect(harness.calls.last.data['blocked'], isFalse);
    expect(find.text('Đã mở khóa tài khoản.'), findsOneWidget);

    await _scrollTo(tester, find.text('admin-self-uid'));
    await _select(tester, 'admin-self-uid');
    final selfLock = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Khóa tài khoản'),
    );
    expect(selfLock.onPressed, isNull);
    await harness.players.close();
  });
}
