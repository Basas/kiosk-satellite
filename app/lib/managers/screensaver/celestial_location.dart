import '../../core/command_registry.dart';
import '../../core/manager.dart';
import '../home_assistant/home_assistant_manager.dart';
import '../location/location_manager.dart';
import '../settings/definitions.dart' as defs;
import '../settings/settings_manager.dart';

/// Where the Celestial sky is seen from, for one location source, or why
/// that source has no position. [message] is English settings wording,
/// translated where it is shown.
class CelestialLocationStatus {
  const CelestialLocationStatus(
    this.source, {
    this.latitude,
    this.longitude,
    this.message,
  });

  final String source;
  final double? latitude, longitude;
  final String? message;

  bool get available => latitude != null && longitude != null;

  Map<String, Object?> toJson() => {
    'source': source,
    'available': available,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (message != null) 'message': message,
  };
}

/// Resolves the Celestial screensaver's Location setting into coordinates:
/// the GPS, Home Assistant's home zone, a Home Assistant entity with a
/// latitude and longitude, or typed coordinates. The screensaver and both
/// settings pages ask the same question here, so the status row shows
/// exactly what the sky uses.
class CelestialLocator extends Manager {
  CelestialLocator(
    super.bus,
    super.commands,
    super.log,
    this._settings,
    this._location,
    this._homeAssistant,
  );

  final SettingsManager _settings;
  final LocationManager _location;
  final HomeAssistantManager _homeAssistant;

  @override
  String get name => 'celestial';

  @override
  Future<void> init() async {
    commands.register(
      Command(
        name: 'getCelestialLocation',
        description:
            "Where the Celestial screensaver's sky is seen from, for the "
            "chosen location source or the one given as source",
        handler: (args) async {
          final source = args['source'];
          return CommandResult.ok(
            (await resolve(source is String ? source : null)).toJson(),
          );
        },
      ),
    );
  }

  /// The position from [source], the Location setting by default.
  Future<CelestialLocationStatus> resolve([String? requested]) async {
    final String source =
        requested ?? _settings.get(defs.screensaverCelestialLocation);
    switch (source) {
      case 'gps':
        final (:fix, :error) = await _location.currentFix();
        if (fix != null) {
          return CelestialLocationStatus(
            source,
            latitude: fix.latitude,
            longitude: fix.longitude,
          );
        }
        return CelestialLocationStatus(
          source,
          message: switch (error) {
            'absent' => 'This device has no GPS receiver.',
            'denied' => 'Location permission not granted.',
            _ => 'No GPS fix yet.',
          },
        );
      case 'ha_home':
        return _entity(source, 'zone.home', 'Home Assistant has no home zone.');
      case 'ha_entity':
        final entity = _settings.get(defs.screensaverCelestialEntity).trim();
        if (entity.isEmpty) {
          return CelestialLocationStatus(
            source,
            message: 'Pick an entity with a location.',
          );
        }
        return _entity(source, entity, 'This entity has no location.');
      default:
        final typed = defs.parseCoordinates(
          _settings.get(defs.screensaverCelestialCoordinates),
        );
        if (typed == null) {
          return const CelestialLocationStatus(
            'manual',
            message: 'Enter a latitude and longitude, like 40.71, -74.01',
          );
        }
        return CelestialLocationStatus(
          'manual',
          latitude: typed.latitude,
          longitude: typed.longitude,
        );
    }
  }

  Future<CelestialLocationStatus> _entity(
    String source,
    String entity,
    String missing,
  ) async {
    if (!_homeAssistant.configured) {
      return CelestialLocationStatus(
        source,
        message: 'Home Assistant is not connected.',
      );
    }
    final attributes = await _homeAssistant.fetchEntityAttributes(entity);
    if (attributes == null) {
      return CelestialLocationStatus(
        source,
        message: 'Home Assistant is not connected.',
      );
    }
    final lat = attributes['latitude'], lon = attributes['longitude'];
    if (lat is num && lon is num && lat.abs() <= 90 && lon.abs() <= 180) {
      return CelestialLocationStatus(
        source,
        latitude: lat.toDouble(),
        longitude: lon.toDouble(),
      );
    }
    return CelestialLocationStatus(source, message: missing);
  }
}

/// Coordinates as the status row shows them.
String formatCelestialPlace(double latitude, double longitude) =>
    '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
