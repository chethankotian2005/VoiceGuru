import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:voiceguru_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VoiceGuru app renders the home shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const VoiceGuruApp());
    await tester.pumpAndSettle();

    expect(find.text('VoiceGuru'), findsOneWidget);
    expect(find.text('Tap and ask your doubt'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
  });
}
