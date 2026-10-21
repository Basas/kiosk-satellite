/// Amazon's wake word engine on the Echo Dot image.
///
/// The Kiosk Satellite Edition image for the Echo Dot runs Amazon's own
/// engine (Pryon), with the models the Dot shipped with, as a service:
/// biscuit-pryond, on a local socket. When an app connects, the service
/// first lists every model it has and the keywords each one spots. This
/// reads that list once at boot, so the wake word selects offer exactly what
/// the service has, and leaves the engine out on every other device.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/headless.dart';
import '../../../core/logging.dart';
import '../../settings/definitions.dart' as defs;
import 'pryon_isolate.dart';

/// One keyword the service spots: a wake word, or the stop word.
class PryonWord {
  const PryonWord({
    required this.id,
    required this.model,
    required this.keyword,
    this.stop = false,
    this.acceptThreshold,
  });

  /// The keyword in lower case, the id the wake word selects use: 'alexa'.
  final String id;

  /// The model that spots it, as the service names it: 'ALEXA'.
  final String model;

  /// The keyword as the service reports it: 'ALEXA'.
  final String keyword;

  final bool stop;

  /// The score the service accepts it at before a client property lowers
  /// it, or null when the service did not say.
  final double? acceptThreshold;

  /// Where the engine finds it, in place of a manifest URL.
  String get url => 'pryon:$model/$keyword';

  @override
  bool operator ==(Object other) =>
      other is PryonWord &&
      other.id == id &&
      other.model == model &&
      other.keyword == keyword &&
      other.stop == stop &&
      other.acceptThreshold == acceptThreshold;

  @override
  int get hashCode => Object.hash(id, model, keyword, stop, acceptThreshold);
}

abstract final class PryonCatalog {
  /// The service's socket. Tests point it at a fake one.
  static String socketPath = pryonSocketPath;

  static List<PryonWord> _words = const [];

  /// The word a config's manifest URL names, or null.
  static PryonWord? byUrl(String url) {
    for (final w in _words) {
      if (w.url == url) return w;
    }
    return null;
  }

  static List<PryonWord> get wakeWords => [
    for (final w in _words)
      if (!w.stop) w,
  ];

  static PryonWord? get stopWord {
    for (final w in _words) {
      if (w.stop) return w;
    }
    return null;
  }

  /// The service answered with at least one wake word.
  static bool get available => wakeWords.isNotEmpty;

  /// Read the service's list on the image, then hide the engine wherever
  /// there is nothing to listen with. Before the settings render: both
  /// settings UIs and the ESPHome select read the hidden options.
  static Future<void> init(Logger log) async {
    if (Headless.pryon) {
      try {
        _words = parseHello(await _hello());
        log.info(
          'pryon',
          'Amazon wake words: ${[for (final w in _words) w.id].join(', ')}',
        );
      } catch (e) {
        _words = const [];
        log.warn('pryon', 'the wake word service did not answer: $e');
      }
    }
    if (!available) {
      defs.deviceHiddenOptions[defs.voiceWakeWordEngine.key] = {'pryon'};
    }
  }

  static Future<String> _hello() async {
    final socket = await Socket.connect(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
      timeout: const Duration(seconds: 2),
    );
    try {
      return await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 3));
    } finally {
      socket.destroy();
    }
  }

  /// The words in the service's first line, wake words before stop words.
  /// A keyword two models spot is offered once, from the first.
  static List<PryonWord> parseHello(String line) {
    final hello = jsonDecode(line);
    if (hello is! Map || hello['event'] != 'hello') {
      throw const FormatException('not a hello');
    }
    final wake = <String, PryonWord>{};
    final stop = <String, PryonWord>{};
    for (final m in hello['models'] as List? ?? const []) {
      if (m is! Map) continue;
      final model = '${m['model'] ?? ''}';
      if (model.isEmpty) continue;
      final accept = m['accept_thresholds'];
      for (final (list, isStop, into) in [
        (m['wake_words'], false, wake),
        (m['stop_words'], true, stop),
      ]) {
        for (final k in list as List? ?? const []) {
          final keyword = '$k';
          if (keyword.isEmpty) continue;
          into.putIfAbsent(
            keyword.toLowerCase(),
            () => PryonWord(
              id: keyword.toLowerCase(),
              model: model,
              keyword: keyword,
              stop: isStop,
              acceptThreshold: accept is Map && accept[keyword] is num
                  ? (accept[keyword] as num).toDouble()
                  : null,
            ),
          );
        }
      }
    }
    return [...wake.values, ...stop.values];
  }

  /// Tests only.
  static set debugWords(List<PryonWord> words) => _words = words;
}
