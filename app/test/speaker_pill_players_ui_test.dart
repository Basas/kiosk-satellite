import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart';
import 'package:kiosk_satellite/ui/entity_picker.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Now Playing page's Filter the speaker selection pill row (issue
/// #974): the picks of the menu's source by name, All speakers with none,
/// no row for a source without a menu, and a pick that keeps the other
/// source's ids. Mirrored on the remote (rows.js).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppContainer> open(
    WidgetTester tester, {
    String source = '',
    List<String> picks = const [],
  }) async {
    SharedPreferences.setMockInitialValues({
      'ks.sendspin.enabled': true,
      'ks.sendspin.player_active': true,
      'ks.sendspin.fullscreen': true,
      'ks.sendspin.player_source': source,
      'ks.sendspin.player': '',
      'ks.sendspin.speaker_pill_players': jsonEncode(picks),
    });
    PickCatalog.reset();
    final container = AppContainer();
    await container.settings.init();
    if (!container.commands.all.any((c) => c.name == 'mediaPlayers')) {
      container.commands.register(
        Command(
          name: 'mediaPlayers',
          description: 'fake',
          handler: (p) async => const CommandResult.ok({
            'players': [
              {'id': 'ma:kitchen', 'name': 'Kitchen', 'group': 'ma'},
              {'id': 'ma:office', 'name': 'Office', 'group': 'ma'},
            ],
            'notes': {},
          }),
        ),
      );
    }
    tester.view.physicalSize = const Size(500, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(container: container)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    for (final title in ['Media Player', 'Now Playing']) {
      await tester.tap(find.text(title).first);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    }
    return container;
  }

  testWidgets('no picks offer every speaker', (tester) async {
    await open(tester);
    expect(find.text('Filter the speaker selection pill'), findsOneWidget);
    expect(find.text('All speakers'), findsOneWidget);
  });

  testWidgets('the picks of the menu source show by name', (tester) async {
    await open(tester, picks: ['ma:kitchen', 'sonos:RINCON_A']);
    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.textContaining('RINCON_A'), findsNothing);
  });

  testWidgets('a Home Assistant player has no menu, so no row', (tester) async {
    await open(tester, source: 'ha');
    expect(find.text('Show speaker selection pill'), findsOneWidget);
    expect(find.text('Filter the speaker selection pill'), findsNothing);
  });

  testWidgets('a pick keeps the other source picks', (tester) async {
    final container = await open(
      tester,
      picks: ['sonos:RINCON_A', 'ma:kitchen'],
    );
    await tester.tap(find.text('Kitchen'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.tap(find.text('Office').last);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.text('Done'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(
      decodeSpeakerPillPlayers(
        container.settings.get(sendspinSpeakerPillPlayers),
      ),
      ['sonos:RINCON_A', 'ma:kitchen', 'ma:office'],
    );
    expect(find.text('Kitchen, Office'), findsOneWidget);
  });
}
