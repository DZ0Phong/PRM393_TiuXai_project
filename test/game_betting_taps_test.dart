import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tai_xiu_realtime/features/game/presentation/widgets/bau_cua_betting_table.dart';
import 'package:tai_xiu_realtime/features/game/presentation/widgets/xoc_xoc/xoc_xoc_betting_table.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Future<void> showTable(
    WidgetTester tester, {
    required String roundId,
    required Future<void> Function(String, int) place,
    Future<void> Function()? refund,
    bool xocXoc = false,
    int? balance = 50000,
    bool enabled = true,
    bool offline = false,
    int secondsLeft = 30,
    Map<String, int> confirmed = const {},
  }) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: xocXoc
                ? XocXocBettingTable(
                    mode: 'quick',
                    roundId: roundId,
                    status: 'open',
                    secondsLeft: secondsLeft,
                    balance: balance,
                    enabled: enabled,
                    offline: offline,
                    result: null,
                    confirmedBets: confirmed,
                    onPlaceBet: place,
                  )
                : BauCuaBettingTable(
                    roundId: roundId,
                    status: 'open',
                    secondsLeft: secondsLeft,
                    balance: balance ?? 0,
                    enabled: enabled,
                    confirmedBets: confirmed,
                    onPlaceBet: place,
                    onRefundBet: refund ?? () async {},
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> tapLabel(WidgetTester tester, String label) async {
    if (find.byType(BauCuaBettingTable).evaluate().isNotEmpty &&
        ['HƯƠU', 'BẦU', 'GÀ'].contains(label)) {
      await tester.ensureVisible(find.text('10K'));
      await tester.tap(find.text('10K'));
      await tester.pump();
    }
    await tester.ensureVisible(find.text(label).first);
    await tester.tap(find.text(label).first);
    await tester.pump();
  }

  testWidgets('Bầu Cua rapid confirm sends once, then clears accepted draft', (
    tester,
  ) async {
    final pending = Completer<void>();
    final calls = <String>[];
    await showTable(
      tester,
      roundId: 'one',
      place: (side, amount) {
        calls.add('$side:$amount');
        return pending.future;
      },
    );
    await tapLabel(tester, 'HƯƠU');
    final confirm = find.text('XÁC NHẬN');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.tap(confirm);
    expect(calls, ['nai:10000']);
    pending.complete();
    await tester.pump();
    await tester.tap(confirm);
    expect(calls, ['nai:10000']);
  });

  testWidgets('Bầu Cua rapid refund cannot clear a new round draft', (
    tester,
  ) async {
    final pending = Completer<void>();
    var refunds = 0;
    Future<void> refund() {
      refunds++;
      return pending.future;
    }

    Future<void> place(String side, int amount) async {}
    await showTable(
      tester,
      roundId: 'one',
      place: place,
      confirmed: {'nai': 10000},
      refund: refund,
    );
    await tapLabel(tester, 'CƯỢC LẠI');
    await tester.tap(find.text('CƯỢC LẠI'));
    expect(refunds, 1);
    await showTable(tester, roundId: 'two', place: place, refund: refund);
    await tapLabel(tester, 'BẦU');
    pending.complete();
    await tester.pump();
    expect(find.textContaining('Cược: 10.000'), findsOneWidget);
  });

  testWidgets(
    'Bầu Cua old completion cannot erase next round draft or submit old gates',
    (tester) async {
      final pending = Completer<void>();
      final calls = <String>[];
      Future<void> place(String side, int amount) {
        calls.add('$side:$amount');
        return calls.length == 1 ? pending.future : Future.value();
      }

      await showTable(tester, roundId: 'one', place: place);
      await tapLabel(tester, 'HƯƠU');
      await tapLabel(tester, 'BẦU');
      await tapLabel(tester, 'XÁC NHẬN');
      await showTable(tester, roundId: 'two', place: place);
      await tapLabel(tester, 'GÀ');
      pending.complete();
      await tester.pump();
      await tapLabel(tester, 'XÁC NHẬN');
      expect(calls, ['nai:10000', 'ga:10000']);
    },
  );

  testWidgets(
    'Bầu Cua refuses stale balance and cap; uncertain attempt is not replayed',
    (tester) async {
      var calls = 0;
      Future<void> place(String side, int amount) async {
        calls++;
        throw StateError('network uncertain');
      }

      await showTable(tester, roundId: 'one', place: place);
      await tapLabel(tester, 'HƯƠU');
      await showTable(tester, roundId: 'one', place: place, balance: 500);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'XÁC NHẬN'))
            .onPressed,
        isNull,
      );
      await showTable(tester, roundId: 'one', place: place);
      await tapLabel(tester, 'XÁC NHẬN');
      await tester.pump();
      await tapLabel(tester, 'XÁC NHẬN');
      expect(calls, 1);
    },
  );

  testWidgets('Xóc Xóc invalid draft can be cleared after balance changes', (
    tester,
  ) async {
    var calls = 0;
    Future<void> place(String side, int amount) async {
      calls++;
    }

    await showTable(tester, roundId: 'one', place: place, xocXoc: true);
    await tapLabel(tester, 'CHẴN');
    await showTable(
      tester,
      roundId: 'one',
      place: place,
      xocXoc: true,
      balance: 500,
    );
    await tapLabel(tester, 'Xóa cược chưa gửi');
    expect(calls, 0);
    expect(find.text('Xóa cược chưa gửi'), findsNothing);
  });

  testWidgets('Bầu Cua requires chip selection again in a new round', (
    tester,
  ) async {
    final calls = <String>[];
    Future<void> place(String side, int amount) async {
      calls.add('$side:$amount');
    }

    await showTable(tester, roundId: 'one', place: place);
    expect(find.byType(TextField), findsNothing);
    await tapLabel(tester, '50K');
    await tester.pump();
    await showTable(tester, roundId: 'two', place: place);
    await tester.ensureVisible(find.text('HƯƠU').first);
    await tester.tap(find.text('HƯƠU').first);
    await tester.pump();
    expect(find.text('Hãy chọn mệnh giá trước khi đặt cược.'), findsOneWidget);
    expect(calls, isEmpty);
    await tapLabel(tester, 'HƯƠU');
    await tapLabel(tester, 'XÁC NHẬN');
    await tester.pump();
    expect(calls, ['nai:10000']);
  });

  testWidgets('Xóc Xóc does not show a fabricated zero while wallet loads', (
    tester,
  ) async {
    var calls = 0;
    await showTable(
      tester,
      roundId: 'one',
      place: (_, _) async => calls++,
      xocXoc: true,
      balance: null,
    );
    expect(find.text('Đang tải số dư'), findsWidgets);
    expect(find.text('0 VNĐ'), findsNothing);
    await tapLabel(tester, 'CHẴN');
    expect(calls, 0);
  });

  testWidgets(
    'Xóc Xóc sends four gates despite its own transient busy rebuild',
    (tester) async {
      final first = Completer<void>();
      final calls = <String>[];
      Future<void> place(String side, int amount) {
        calls.add('$side:$amount');
        return calls.length == 1 ? first.future : Future.value();
      }

      await showTable(tester, roundId: 'one', place: place, xocXoc: true);
      for (final side in ['CHẴN', 'LẺ', '3 ĐỎ 1 TRẮNG', '3 TRẮNG 1 ĐỎ']) {
        await tapLabel(tester, side);
      }
      await tapLabel(tester, 'XÁC NHẬN CƯỢC • 40.000 VNĐ');
      expect(calls, ['chan:10000']);

      // RoundScreen briefly disables inputs and lacks a wallet snapshot while
      // the first callable is pending; this is not a rejection of other gates.
      await showTable(
        tester,
        roundId: 'one',
        place: place,
        xocXoc: true,
        balance: null,
        enabled: false,
      );
      first.complete();
      await tester.pump();
      expect(calls, ['chan:10000', 'le:10000', 'red3:10000', 'white3:10000']);
      expect(find.textContaining('Đã cược: 10.000 VNĐ'), findsNWidgets(4));
      expect(find.textContaining('Chưa gửi: 10.000 VNĐ'), findsNothing);
      expect(find.text('50.000 VNĐ'), findsOneWidget);

      // A delayed Firestore snapshot must not drop or double-count receipts.
      await showTable(
        tester,
        roundId: 'one',
        place: place,
        xocXoc: true,
        balance: 10000,
        confirmed: const {'chan': 10000},
      );
      expect(find.textContaining('Đã cược: 10.000 VNĐ'), findsNWidgets(4));
      expect(find.textContaining('Đã cược: 20.000 VNĐ'), findsNothing);
    },
  );

  testWidgets(
    'Xóc Xóc rejects a later gate without claiming four were charged',
    (tester) async {
      final calls = <String>[];
      await showTable(
        tester,
        roundId: 'one',
        xocXoc: true,
        place: (side, amount) async {
          calls.add('$side:$amount');
          if (side == 'le')
            throw FirebaseFunctionsException(
              code: 'failed-precondition',
              message: 'Đã khóa cược',
            );
        },
      );
      for (final side in ['CHẴN', 'LẺ', '3 ĐỎ 1 TRẮNG', '3 TRẮNG 1 ĐỎ']) {
        await tapLabel(tester, side);
      }
      await tapLabel(tester, 'XÁC NHẬN CƯỢC • 40.000 VNĐ');
      await tester.pump();
      expect(calls, ['chan:10000', 'le:10000']);
      expect(find.text('Đã cược: 10.000 VNĐ'), findsOneWidget);
      expect(find.text('Chưa gửi: 10.000 VNĐ'), findsNWidgets(2));
      expect(
        find.text('Đã khóa cược. Cược đã nhận vẫn được giữ.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Xóc Xóc deadline rejection is concise and stops other gates', (
    tester,
  ) async {
    final calls = <String>[];
    await showTable(
      tester,
      roundId: 'one',
      place: (side, amount) async {
        calls.add('$side:$amount');
        throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Đã khóa cược',
        );
      },
      xocXoc: true,
    );
    await tapLabel(tester, 'CHẴN');
    await tapLabel(tester, 'LẺ');
    await tapLabel(tester, 'XÁC NHẬN CƯỢC • 20.000 VNĐ');
    await tester.pump();
    expect(calls, ['chan:10000']);
    expect(
      find.text('Đã khóa cược. Cược đã nhận vẫn được giữ.'),
      findsOneWidget,
    );
    expect(find.textContaining('firebase_functions/'), findsNothing);
  });

  testWidgets('Bầu Cua deadline rejection shows no exception stack', (
    tester,
  ) async {
    final calls = <String>[];
    await showTable(
      tester,
      roundId: 'one',
      place: (side, amount) async {
        calls.add('$side:$amount');
        throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Đã khóa cược',
        );
      },
    );
    await tapLabel(tester, 'HƯƠU');
    await tapLabel(tester, 'BẦU');
    await tapLabel(tester, 'XÁC NHẬN');
    await tester.pump();
    expect(calls, ['nai:10000']);
    expect(
      find.text('Đã khóa cược. Cược đã nhận vẫn được giữ.'),
      findsOneWidget,
    );
    expect(find.textContaining('firebase_functions/'), findsNothing);
  });

  testWidgets('Xóc Xóc deadline stops remaining multi-gate batch', (
    tester,
  ) async {
    final first = Completer<void>();
    final calls = <String>[];
    Future<void> place(String side, int amount) {
      calls.add('$side:$amount');
      return first.future;
    }

    await showTable(tester, roundId: 'one', place: place, xocXoc: true);
    await tapLabel(tester, 'CHẴN');
    await tapLabel(tester, 'LẺ');
    await tapLabel(tester, 'XÁC NHẬN CƯỢC • 20.000 VNĐ');
    expect(calls, ['chan:10000']);
    await showTable(
      tester,
      roundId: 'one',
      place: place,
      xocXoc: true,
      secondsLeft: 0,
      enabled: false,
    );
    first.complete();
    await tester.pump();
    expect(calls, ['chan:10000']);
  });

  testWidgets('Xóc Xóc reconnect stops batch and retains unsent gate', (
    tester,
  ) async {
    final pending = Completer<void>();
    final calls = <String>[];
    Future<void> place(String side, int amount) {
      calls.add('$side:$amount');
      return calls.length == 1 ? pending.future : Future.value();
    }

    await showTable(tester, roundId: 'one', place: place, xocXoc: true);
    await tapLabel(tester, 'CHẴN');
    await tapLabel(tester, 'LẺ');
    await tapLabel(tester, 'XÁC NHẬN CƯỢC • 20.000 VNĐ');
    await showTable(
      tester,
      roundId: 'one',
      place: place,
      xocXoc: true,
      enabled: false,
      offline: true,
    );
    pending.complete();
    await tester.pump();
    expect(calls, ['chan:10000']);
    await showTable(tester, roundId: 'one', place: place, xocXoc: true);
    await tapLabel(tester, 'XÁC NHẬN CƯỢC • 10.000 VNĐ');
    await tester.pump();
    expect(calls, ['chan:10000', 'le:10000']);
  });

  testWidgets(
    'Xóc Xóc rapid confirm and stale round stop old multi-gate batch',
    (tester) async {
      final pending = Completer<void>();
      final calls = <String>[];
      Future<void> place(String side, int amount) {
        calls.add('$side:$amount');
        return calls.length == 1 ? pending.future : Future.value();
      }

      await showTable(tester, roundId: 'one', place: place, xocXoc: true);
      await tapLabel(tester, 'CHẴN');
      await tapLabel(tester, 'LẺ');
      final confirm = find.textContaining('XÁC NHẬN CƯỢC');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.tap(confirm);
      expect(calls, ['chan:10000']);
      await showTable(tester, roundId: 'two', place: place, xocXoc: true);
      pending.complete();
      await tester.pump();
      expect(calls, ['chan:10000']);
    },
  );
}
