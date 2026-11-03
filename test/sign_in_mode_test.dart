import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tai_xiu_realtime/features/auth/sign_in_screen.dart';

void main() {
  testWidgets('Demo Admin is only offered for local emulator mode', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignInScreen()));
    expect(find.text('Demo Admin'), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: SignInScreen(showDemoAdmin: true)));
    expect(find.text('Demo Admin'), findsOneWidget);
  });

  testWidgets('Registration does not suggest a shared password', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignInScreen(initialRegisterTab: true)));
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.take(3).map((field) => field.controller?.text), everyElement(isEmpty));
    expect(find.text('EMAIL CỦA BẠN'), findsOneWidget);
    expect(find.text('TẶNG CODE 100K CHO TÂN THỦ'), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: SignInScreen(initialRegisterTab: true, showDemoAdmin: true)));
    expect(find.text('TÊN ĐĂNG NHẬP (NICKNAME)'), findsOneWidget);
  });
}
