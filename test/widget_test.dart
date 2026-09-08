import 'package:chichago/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the Chichago client sign-in experience', (tester) async {
    await tester.pumpWidget(const ChichagoApp(skipRestore: true));
    await tester.pumpAndSettle();

    expect(find.text('Your evening,\ndelivered.'), findsOneWidget);
    expect(find.text('Continue with WhatsApp'), findsOneWidget);
    expect(find.textContaining('Owners and drivers'), findsOneWidget);
  });
}
