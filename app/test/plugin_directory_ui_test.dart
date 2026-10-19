import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/plugins/plugin_directory.dart';
import 'package:kiosk_satellite/managers/plugins/plugin_manager.dart';
import 'package:kiosk_satellite/ui/plugin_directory.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Browse plugins sits first on the Plugin Manager page and lists Community
/// Plugins. Mirrored on the remote (plugin_directory_remote_ui_test.py).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('Browse plugins opens from the Plugin Manager page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      PluginManager.channel,
      (call) async => {'enabled': true, 'plugins': <Object?>[]},
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(PluginManager.channel, null),
    );
    final container = AppContainer();
    await container.settings.init();
    container.plugins.enabled.value = true;
    tester.view.physicalSize = const Size(500, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(container: container)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Plugin Manager').first);
    await settle(tester);
    final browse = find.text('Browse plugins');
    expect(browse, findsOneWidget);
    expect(
      tester.getTopLeft(browse).dy,
      lessThan(tester.getTopLeft(find.text('Add plugin')).dy),
    );
    await tester.tap(browse);
    await settle(tester);
    expect(find.text('Search plugins'), findsOneWidget);
    expect(find.text('Submit your plugin'), findsOneWidget);
  });

  testWidgets('lists plugins by popularity and filters them', (tester) async {
    final body = jsonEncode({
      'schemaVersion': 1,
      'plugins': [
        for (final (id, name, installs) in [
          ('quiet', 'Quiet Clock', 2),
          ('weather', 'Weather Mood', 40),
        ])
          {
            'id': id,
            'name': name,
            'description': '$name for the kiosk.',
            'author': 'Alice',
            'version': '1.0.0',
            'repository': 'https://github.com/alice/$id',
            'stars': 1,
            'downloads': 1,
            'installs': installs,
            'status': 'ok',
          },
      ],
    });
    final plugins = PluginManager(
      EventBus(),
      CommandRegistry(Logger()),
      Logger(),
      directory: PluginDirectory(
        clientFactory: () => MockClient((_) async => http.Response(body, 200)),
        cacheFile: () async => null,
      ),
    );
    plugins.installed.value = [
      {
        'id': 'quiet',
        'name': 'Quiet Clock',
        'version': '1.0.0',
        'source': {'repository': 'https://github.com/alice/quiet'},
      },
    ];
    // The list arrives before the page opens, the way a second visit finds it.
    await tester.runAsync(() => plugins.directory.read());
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PluginDirectoryPanel(plugins: plugins, onOpen: (_) {}),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(
      tester.getTopLeft(find.text('Weather Mood')).dy,
      lessThan(tester.getTopLeft(find.text('Quiet Clock')).dy),
    );
    expect(find.text('Installed'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'weather');
    await settle(tester);
    expect(find.text('Quiet Clock'), findsNothing);
    expect(find.text('Weather Mood'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'nothing like this');
    await settle(tester);
    expect(find.text('No plugins match your search.'), findsOneWidget);
  });
}
