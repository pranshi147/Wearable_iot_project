
import 'package:flutter_test/flutter_test.dart';
import 'package:wearable_iot_project/main.dart';

void main() {
  testWidgets('SafeWear dashboard loads', (WidgetTester tester) async {
    await tester.pumpWidget(const SafetyApp());

    expect(find.text('SafeWear'), findsOneWidget);
    expect(find.text('Your Safety Dashboard'), findsOneWidget);
    expect(find.text('Emergency SOS'), findsOneWidget);
  });
}
