import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart';
import 'package:kiosk_satellite/ui/celestial_settings.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Each Celestial location source reveals its own row on the device, as on
/// the remote (settings.js, updateCelestialLocationRow): a status line for
/// the GPS and the home zone, the entity picker with a status line for an
/// entity, and the coordinates field for Manual.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppContainer> open(WidgetTester tester, String source) async {
    SharedPreferences.setMockInitialValues({
      'ks.screensaver.enabled': true,
      'ks.screensaver.mode': 'celestial',
      'ks.screensaver.celestial_location': source,
    });
    final container = AppContainer();
    await container.settings.init();
    tester.view.physicalSize = const Size(500, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(container: container)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    for (final title in ['Screensaver', 'Celestial screensaver']) {
      await tester.tap(find.text(title).first);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    }
    return container;
  }

  testWidgets('the home zone shows its status under the select', (
    tester,
  ) async {
    await open(tester, 'ha_home');
    expect(find.text('Location'), findsOneWidget);
    expect(find.byType(CelestialLocationStatusRow), findsOneWidget);
    expect(find.text('Current location'), findsOneWidget);
    expect(find.text('Home Assistant is not connected.'), findsOneWidget);
    expect(find.byType(CelestialEntityRow), findsNothing);
    expect(find.text('Coordinates'), findsNothing);
  });

  testWidgets('an entity source shows the picker and its status', (
    tester,
  ) async {
    await open(tester, 'ha_entity');
    expect(find.byType(CelestialEntityRow), findsOneWidget);
    expect(find.text('Pick an entity with a location.'), findsOneWidget);
  });

  testWidgets('Manual shows the coordinates field and no status', (
    tester,
  ) async {
    // A receiver with no fix to give.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('kiosk_satellite/location'),
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('kiosk_satellite/location'),
        null,
      ),
    );
    final c = await open(tester, 'manual');
    expect(find.text('Coordinates'), findsOneWidget);
    expect(find.byType(CelestialLocationStatusRow), findsNothing);
    // Point at the sky needs a compass, not a GPS.
    expect(find.text('Point at the sky'), findsOneWidget);
    // Switching the source swaps the rows in place.
    await c.settings.set(screensaverCelestialLocation, 'gps');
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.text('Coordinates'), findsNothing);
    expect(find.text('No GPS fix yet.'), findsOneWidget);
    expect(find.text('Point at the sky'), findsOneWidget);
    // Opt in: a wall kiosk with a compass keeps its touch view.
    expect(c.settings.get(screensaverCelestialFollowDevice), isFalse);
  });
}
