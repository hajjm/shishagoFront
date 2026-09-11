import 'package:shishago/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens on sign in and links to a separate sign-up page', (
    tester,
  ) async {
    await tester.pumpWidget(const ShishaGoApp(skipRestore: true));
    await tester.pumpAndSettle();

    expect(find.text('Shisha Go'), findsOneWidget);
    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.text('Send code with WhatsApp'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Full name'), findsNothing);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your\naccount.'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Written delivery address'), findsOneWidget);
    expect(find.text('Use my current location'), findsOneWidget);
  });

  testWidgets('desktop login blends the logo into the hero panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ShishaGoApp(skipRestore: true));
    await tester.pumpAndSettle();

    expect(find.byType(ColorFiltered), findsOneWidget);
  });
}
