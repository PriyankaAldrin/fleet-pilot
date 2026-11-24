import 'package:fleet_pilot/features/auth/login_screen.dart';
import 'package:fleet_pilot/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _app(Locale locale) => ProviderScope(
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        home: const LoginScreen(),
      ),
    );

void main() {
  testWidgets('login validates empty fields', (tester) async {
    await tester.pumpWidget(_app(const Locale('en')));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Required'), findsNWidgets(2));
  });

  testWidgets('login is right to left in Arabic', (tester) async {
    await tester.pumpWidget(_app(const Locale('ar')));
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.byType(LoginScreen)));
    expect(dir, TextDirection.rtl);
  });
}
