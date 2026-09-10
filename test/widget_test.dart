import 'package:chichago/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens on sign in and links to a separate sign-up page', (
    tester,
  ) async {
    await tester.pumpWidget(const ChichagoApp(skipRestore: true));
    await tester.pumpAndSettle();

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
}
