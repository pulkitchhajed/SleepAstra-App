import 'package:flutter_test/flutter_test.dart';
import 'package:snore_clinics/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SnoreClinicsApp());
    expect(find.byType(SnoreClinicsApp), findsOneWidget);
  });
}
