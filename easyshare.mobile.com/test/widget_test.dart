import 'package:flutter_test/flutter_test.dart';
import 'package:easyshare/main.dart';

void main() {
  testWidgets('shows file-sharing actions on the home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Next Share'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Videos'), findsOneWidget);
    expect(find.byTooltip('Transfer history'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
  });
}
