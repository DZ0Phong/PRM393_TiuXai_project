import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tai_xiu_realtime/features/game/presentation/widgets/xoc_xoc/xoc_xoc_betting_table.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Future<void> showTable(
    WidgetTester tester, {
    required Future<void> Function(String, int) onPlaceBet,
    String roundId = 'round-one',
    int? balance = 50000,
    String status = 'open',
    bool enabled = true,
    Map<String, int> confirmedBets = const {},
    int? confirmedCredit,
  }) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: XocXocBettingTable(
              roundId: roundId,
              mode: 'quick',
              status: status,
              secondsLeft: 30,
              balance: balance,
              enabled: enabled,
              result: null,
              confirmedBets: confirmedBets,
              confirmedCredit: confirmedCredit,
              onPlaceBet: onPlaceBet,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> tapGate(WidgetTester tester, String label) =>
      tap(tester, find.text(label).first);

  Future<void> confirm(WidgetTester tester) =>
      tap(tester, find.textContaining('XÁC NHẬN CƯỢC'));

  testWidgets(
    'one chip on one gate, then all-in on another uses only the remainder',
    (tester) async {
      final calls = <(String, int)>[];
      Future<void> place(String side, int amount) async =>
          calls.add((side, amount));
      await showTable(tester, onPlaceBet: place);

      await tapGate(tester, 'CHẴN');
      await tap(tester, find.text('ALL IN • 40.000 VNĐ'));
      await tapGate(tester, 'LẺ');
      expect(find.text('Chưa gửi: 10.000 VNĐ'), findsOneWidget);
      expect(find.text('Chưa gửi: 40.000 VNĐ'), findsOneWidget);
      await confirm(tester);

      expect(calls, [('chan', 10000), ('le', 40000)]);
      expect(find.text('Đã cược: 10.000 VNĐ'), findsOneWidget);
      expect(find.text('Đã cược: 40.000 VNĐ'), findsOneWidget);
      expect(find.textContaining('Chưa gửi:'), findsNothing);
    },
  );

  for (var count = 1; count <= 4; count++) {
    testWidgets('$count gate submission sends each gate once in order', (
      tester,
    ) async {
      final first = Completer<void>();
      final calls = <(String, int)>[];
      Future<void> place(String side, int amount) {
        calls.add((side, amount));
        return calls.length == 1 ? first.future : Future.value();
      }

      await showTable(tester, onPlaceBet: place);
      const labels = ['CHẴN', 'LẺ', '3 ĐỎ 1 TRẮNG', '3 TRẮNG 1 ĐỎ'];
      const sides = ['chan', 'le', 'red3', 'white3'];
      for (final label in labels.take(count)) {
        await tapGate(tester, label);
      }
      await confirm(tester);
      expect(calls, [('chan', 10000)]);
      expect(find.text('ĐANG GỬI...'), findsOneWidget);
      first.complete();
      await tester.pump();

      expect(calls, [for (final side in sides.take(count)) (side, 10000)]);
      expect(find.text('Đã cược: 10.000 VNĐ'), findsNWidgets(count));
      expect(find.textContaining('Chưa gửi:'), findsNothing);
      await confirm(tester); // No draft remains to replay.
      expect(calls.length, count);
    });
  }

  testWidgets(
    'second submission in the same round preserves the first receipt',
    (tester) async {
      final calls = <(String, int)>[];
      Future<void> place(String side, int amount) async =>
          calls.add((side, amount));
      await showTable(tester, onPlaceBet: place);
      await tapGate(tester, 'CHẴN');
      await confirm(tester);
      expect(calls, [('chan', 10000)]);

      // The wallet and confirmed-bet snapshots arrive after the first call.
      await showTable(
        tester,
        onPlaceBet: place,
        balance: 40000,
        confirmedBets: const {'chan': 10000},
      );
      expect(find.text('Đã cược: 10.000 VNĐ'), findsOneWidget);
      expect(find.text('Đã cược: 20.000 VNĐ'), findsNothing);
      await tapGate(tester, 'LẺ');
      await confirm(tester);
      expect(calls, [('chan', 10000), ('le', 10000)]);
      expect(find.text('Đã cược: 10.000 VNĐ'), findsNWidgets(2));
      expect(find.textContaining('Chưa gửi:'), findsNothing);
    },
  );

  testWidgets(
    'optimistic reserve survives stale wallet, catches up, and resets next round',
    (tester) async {
      final calls = <(String, int)>[];
      Future<void> place(String side, int amount) async =>
          calls.add((side, amount));
      await showTable(tester, onPlaceBet: place, balance: 50000);
      await tapGate(tester, 'CHẴN');
      await confirm(tester);
      expect(calls, [('chan', 10000)]);

      // Parent has not received the wallet snapshot yet: do not re-spend 50k.
      await showTable(tester, onPlaceBet: place, balance: 50000);
      expect(find.text('40.000 VNĐ'), findsOneWidget);
      expect(find.text('ALL IN • 40.000 VNĐ'), findsOneWidget);
      await tap(tester, find.text('ALL IN • 40.000 VNĐ'));
      await tapGate(tester, 'LẺ');
      await confirm(tester);
      expect(calls, [('chan', 10000), ('le', 40000)]);
      expect(find.text('0 VNĐ'), findsOneWidget);
      expect(find.text('ALL IN • 0 VNĐ'), findsOneWidget);
      expect(find.textContaining('Chưa gửi:'), findsNothing);

      // Matching server snapshots should not restore stale funds or double count.
      await showTable(
        tester,
        onPlaceBet: place,
        balance: 0,
        confirmedBets: const {'chan': 10000, 'le': 40000},
      );
      expect(find.text('0 VNĐ'), findsOneWidget);
      expect(find.text('Đã cược: 10.000 VNĐ'), findsOneWidget);
      expect(find.text('Đã cược: 40.000 VNĐ'), findsOneWidget);

      await showTable(tester, onPlaceBet: place, roundId: 'round-two');
      expect(find.text('50.000 VNĐ'), findsOneWidget);
      expect(find.text('ALL IN • 50.000 VNĐ'), findsOneWidget);
      expect(find.text('Đã cược: 10.000 VNĐ'), findsNothing);
      expect(find.text('Đã cược: 40.000 VNĐ'), findsNothing);
      expect(calls.length, 2);
    },
  );
  testWidgets('settlement wallet replaces the optimistic debit', (
    tester,
  ) async {
    Future<void> place(String side, int amount) async {}
    await showTable(tester, onPlaceBet: place);
    await tapGate(tester, 'CHẴN');
    await confirm(tester);
    expect(find.text('40.000 VNĐ'), findsOneWidget);

    await showTable(
      tester,
      onPlaceBet: place,
      status: 'settled',
      balance: 50000,
      confirmedBets: const {'chan': 10000},
      confirmedCredit: 10000,
    );
    expect(find.text('50.000 VNĐ'), findsOneWidget);
  });

  testWidgets(
    'null wallet and pending status pause input without losing draft',
    (tester) async {
      final calls = <(String, int)>[];
      Future<void> place(String side, int amount) async =>
          calls.add((side, amount));
      await showTable(tester, onPlaceBet: place);
      await tapGate(tester, 'CHẴN');

      await showTable(tester, onPlaceBet: place, balance: null, enabled: false);
      expect(find.text('50.000 VNĐ'), findsOneWidget); // Last known balance.
      expect(find.text('0 VNĐ'), findsNothing);
      expect(find.text('Chưa gửi: 10.000 VNĐ'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await showTable(tester, onPlaceBet: place, status: 'pending');
      expect(find.text('Chưa gửi: 10.000 VNĐ'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(calls, isEmpty);

      await showTable(tester, onPlaceBet: place);
      await confirm(tester);
      expect(calls, [('chan', 10000)]);
      expect(find.textContaining('Chưa gửi:'), findsNothing);
    },
  );
}
