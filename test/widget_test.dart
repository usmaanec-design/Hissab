import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hissab/data/database/platform/database_platform.dart';
import 'package:hissab/main.dart';

void main() {
  setUpAll(() async {
    await DatabasePlatform.initialize();
  });

  testWidgets('HissabApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const HissabApp());
    expect(find.byType(HissabApp), findsOneWidget);
  });
}
