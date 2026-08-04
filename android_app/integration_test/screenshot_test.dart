import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:almed_ahu_android/main.dart' as app;

Future<void> _pause(WidgetTester tester, [int seconds = 3]) async {
  await tester.pump(Duration(seconds: seconds));
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  int maxSeconds = 45,
}) async {
  for (var i = 0; i < maxSeconds; i++) {
    await tester.pump(const Duration(seconds: 1));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

Future<void> _waitForAppReady(WidgetTester tester) async {
  for (var i = 0; i < 90; i++) {
    await tester.pump(const Duration(seconds: 1));
    if (find.byType(TextFormField).evaluate().isNotEmpty) return;
    if (find.text('Sign Up').evaluate().isNotEmpty) return;
    if (find.text('Email or Username').evaluate().isNotEmpty) return;
    if (find.byIcon(Icons.logout_rounded).evaluate().isNotEmpty) return;
    if (find.byIcon(Icons.dashboard_rounded).evaluate().isNotEmpty) return;
    if (find.textContaining('AHUs Online').evaluate().isNotEmpty) return;
  }
  fail('App did not reach login or dashboard');
}

Future<void> _screenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  await binding.convertFlutterSurfaceToImage();
  await binding.takeScreenshot(name);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture iPhone App Store screenshots', (tester) async {
    app.main();
    await _waitForAppReady(tester);

    final onDashboard = find.byIcon(Icons.logout_rounded);
    if (onDashboard.evaluate().isEmpty) {
      if (find.text('Sign Up').evaluate().isNotEmpty) {
        await tester.tap(find.widgetWithText(OutlinedButton, 'Login'));
        await _pause(tester, 2);
      }

      final fields = find.byType(TextFormField);
      expect(fields, findsAtLeastNWidgets(2));

      await tester.enterText(fields.at(0), 'test2@gmail.com');
      await tester.enterText(fields.at(1), 'testing2');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await _waitFor(tester, find.byIcon(Icons.logout_rounded));
    }

    await _pause(tester, 5);
    await _screenshot(binding, '01-dashboard-home');

    await tester.tap(find.byIcon(Icons.air_rounded).last);
    await _waitFor(tester, find.text('My AHU Units'));
    await _pause(tester, 2);
    await _screenshot(binding, '02-ahu-list');

    final ahuTitle = find.textContaining('AHU_');
    if (ahuTitle.evaluate().isNotEmpty) {
      await tester.tap(ahuTitle.first);
      await _pause(tester, 5);
      await _screenshot(binding, '03-ahu-control');
      final backButton = find.byIcon(Icons.arrow_back_rounded);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton.first);
      } else {
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
      }
      await _pause(tester, 2);
    }

    await tester.tap(find.byIcon(Icons.support_agent_rounded));
    await _waitFor(tester, find.text('New Report'));
    await _pause(tester, 2);
    await _screenshot(binding, '04-support-report');
  });
}
