import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tai_xiu_realtime/features/admin/round_outcome_choices.dart';
import 'package:tai_xiu_realtime/features/admin/round_outcome_picker.dart';
import 'package:tai_xiu_realtime/features/game/game_specs.dart';

void main() {
  test(
    'Tài/Xỉu has two non-triple choices and accounts for imbalance refund',
    () {
      final choices = roundOutcomeChoices(games[0], {'tai': 6000, 'xiu': 2000});
      expect(choices.map((c) => c.label), ['Tài thắng', 'Xỉu thắng']);
      expect(choices.map((c) => c.estimatedCredit), [7960, 7960]);
      expect(choices.map((c) => c.result), [
        [4, 4, 3],
        [2, 3, 4],
      ]);
      expect(
        roundOutcomeChoices(games[0], {
          'tai': 1000,
          'xiu': 0,
        }).map((c) => c.estimatedCredit),
        [1980, 0],
      );
    },
  );

  test(
    'Bầu Cua lists six valid triple-face results; lowest stake has lowest credit',
    () {
      final choices = roundOutcomeChoices(games[1], {'nai': 1000, 'bau': 5000});
      expect(choices.length, 6);
      expect(choices[0].result, ['nai', 'nai', 'nai']);
      expect(choices[0].estimatedCredit, 3940);
      expect(choices[1].estimatedCredit, 19700);
      expect(choices[2].estimatedCredit, 0);
    },
  );

  test('Xóc Xóc lists five red counts and both overlapping winning sides', () {
    final choices = roundOutcomeChoices(games[2], {
      'chan': 1000,
      'le': 2000,
      'red3': 1000,
    });
    expect(choices.length, 5);
    expect(choices.map((c) => c.result), [
      [0, 0, 0, 0],
      [1, 0, 0, 0],
      [1, 1, 0, 0],
      [1, 1, 1, 0],
      [1, 1, 1, 1],
    ]);
    expect(choices[3].winningSides, ['le', 'red3']);
    expect(choices.map((c) => c.estimatedCredit), [
      1980,
      3960,
      1980,
      7900,
      1980,
    ]);
  });

  testWidgets('expired round does not allow selecting a result', (
    tester,
  ) async {
    RoundOutcomeChoice? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RoundOutcomePicker(
              game: games[1],
              round: {
                'totals': {'nai': 1000},
                'playerCounts': {'nai': 1},
              },
              enabled: false,
              onSelected: (value) => chosen = value,
            ),
          ),
        ),
      ),
    );
    expect(find.text('3 mặt Hươu'), findsOneWidget);
    await tester.tap(find.text('3 mặt Hươu'));
    expect(chosen, isNull);
  });

  testWidgets(
    'one tap submits the selected legal result; buttons show stake and count',
    (tester) async {
      RoundOutcomeChoice? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RoundOutcomePicker(
                game: games[0],
                round: {
                  'totals': {'tai': 3000, 'xiu': 1000},
                  'playerCounts': {'tai': 2, 'xiu': 1},
                },
                enabled: true,
                onSelected: (value) => chosen = value,
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Tài: 2 người · 3000 điểm'), findsOneWidget);
      await tester.tap(find.text('Xỉu thắng'));
      expect(chosen?.result, [2, 3, 4]);
    },
  );
}
