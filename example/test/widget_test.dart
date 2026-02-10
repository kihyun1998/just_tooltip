import 'package:flutter_test/flutter_test.dart';

import 'package:just_tooltip_example/main.dart';

void main() {
  testWidgets('Playground app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const PlaygroundApp());
    await tester.pumpAndSettle();

    expect(find.text('JustTooltip Playground'), findsOneWidget);
  });
}
