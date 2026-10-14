import 'dart:convert';

// URL Blacklist: addresses the kiosk's web views do not navigate to, so a
// guest cannot leave a locked-down dashboard for Home Assistant's history,
// logbook or settings pages (issue #989), or an external page for the rest
// of the web.
//
// Only navigations made from a page are blocked: a link, a script moving the
// page, Home Assistant's own routing. What the kiosk itself loads (the start
// URL, the dashboard pickers, rotation, gesture and Home Assistant actions)
// is the owner's choice and always opens.
//
// A rule is a wildcard pattern or a regular expression. Wildcards match the
// whole address, case-insensitively, with `*` standing for anything:
//
// - "/history*" starts with a slash, so it matches the path on any server.
// - "www.youtube.com/*" has no scheme, so any scheme matches.
// - "https://ha.lan:8123/config/*" matches exactly that.
//
// The query and the fragment are left out of the match unless the pattern
// has a "?" or a "#" of its own, so "*/history" also catches
// "/history?entity_id=light.den". A regular expression is searched for
// anywhere in the full address, case-insensitively.
//
// Rules compile to one form both sides read (see [UrlBlacklistRule.compiled]):
// Dart checks full page loads in shouldOverrideUrlLoading, and the page
// script ([urlBlacklistJs]) checks history.pushState and replaceState, which
// is how Home Assistant moves between its pages without loading anything.

/// Where a rule applies. [urlBlacklistDashboard] covers the dashboard web
/// view, custom pages included; [urlBlacklistExternal] covers external
/// pages, the overlay that shows dashboard links and rotation pages.
const urlBlacklistAll = 'all';
const urlBlacklistDashboard = 'dashboard';
const urlBlacklistExternal = 'external';
const urlBlacklistScopes = [
  urlBlacklistAll,
  urlBlacklistDashboard,
  urlBlacklistExternal,
];

/// How a rule's pattern reads.
const urlBlacklistWildcard = 'wildcard';
const urlBlacklistRegex = 'regex';
const urlBlacklistTypes = [urlBlacklistWildcard, urlBlacklistRegex];

/// One rule the person added.
class UrlBlacklistRule {
  UrlBlacklistRule({
    required this.name,
    required this.pattern,
    this.type = urlBlacklistWildcard,
    this.scope = urlBlacklistAll,
  });

  final String name;
  final String pattern;

  /// [urlBlacklistWildcard] or [urlBlacklistRegex].
  final String type;

  /// [urlBlacklistAll], [urlBlacklistDashboard] or [urlBlacklistExternal].
  final String scope;

  bool get isRegex => type == urlBlacklistRegex;

  /// Whether the rule covers a navigation that touches any of [surfaces].
  bool appliesTo(Set<String> surfaces) =>
      scope == urlBlacklistAll || surfaces.contains(scope);

  /// The rule as the page script reads it: a regular expression [s], tested
  /// case-insensitively against the address with only the path when [p], and
  /// with the query and the fragment only when [q] and [f]. [n] is the name
  /// the blocked notice shows.
  late final Map<String, Object> compiled = _compile();

  late final RegExp? _regExp = () {
    try {
      return RegExp(compiled['s']! as String, caseSensitive: false);
    } catch (_) {
      return null;
    }
  }();

  Map<String, Object> _compile() {
    if (isRegex) {
      return {'s': pattern, 'p': false, 'q': true, 'f': true, 'n': name};
    }
    var p = pattern.trim();
    final pathOnly = p.startsWith('/');
    if (!pathOnly && !p.contains('://') && !p.startsWith('*')) p = '*://$p';
    final source = '^${p.split('*').map(RegExp.escape).join('.*')}\$';
    return {
      's': source,
      'p': pathOnly,
      'q': p.contains('?'),
      'f': p.contains('#'),
      'n': name,
    };
  }

  /// Whether [url] is one this rule blocks.
  bool matches(String url) {
    final re = _regExp;
    if (re == null) return false;
    return re.hasMatch(
      urlBlacklistSubject(
        url,
        pathOnly: compiled['p']! as bool,
        query: compiled['q']! as bool,
        fragment: compiled['f']! as bool,
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'pattern': pattern,
    'type': type,
    'scope': scope,
  };
}

/// The part of [url] a rule is tested against, the same cut the page script
/// makes: the fragment and the query dropped unless kept, then everything
/// before the path dropped when only the path counts.
String urlBlacklistSubject(
  String url, {
  required bool pathOnly,
  required bool query,
  required bool fragment,
}) {
  var s = url;
  if (!fragment) {
    final i = s.indexOf('#');
    if (i >= 0) s = s.substring(0, i);
  }
  if (!query) {
    final i = s.indexOf('?');
    if (i >= 0) {
      final hash = s.indexOf('#', i);
      s = s.substring(0, i) + (hash >= 0 ? s.substring(hash) : '');
    }
  }
  if (pathOnly) {
    final origin = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://[^/?#]*').firstMatch(s);
    if (origin != null) {
      s = s.substring(origin.end);
      if (s.isEmpty || !s.startsWith('/')) s = '/$s';
    }
  }
  return s;
}

/// The rules stored in the `browser.url_blacklist` setting, in their order.
/// Anything malformed is skipped rather than failing the whole list.
List<UrlBlacklistRule> parseUrlBlacklist(String raw) {
  try {
    final list = jsonDecode(raw);
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map &&
            '${e['name'] ?? ''}'.trim().isNotEmpty &&
            '${e['pattern'] ?? ''}'.trim().isNotEmpty)
          UrlBlacklistRule(
            name: '${e['name']}'.trim(),
            pattern: '${e['pattern']}'.trim(),
            type: urlBlacklistTypes.contains(e['type'])
                ? e['type'] as String
                : urlBlacklistWildcard,
            scope: urlBlacklistScopes.contains(e['scope'])
                ? e['scope'] as String
                : urlBlacklistAll,
          ),
    ];
  } catch (_) {
    return const [];
  }
}

String encodeUrlBlacklist(List<UrlBlacklistRule> rules) =>
    jsonEncode([for (final r in rules) r.toJson()]);

/// Why a rule cannot be saved, or null when it can: 'name' or 'pattern' when
/// one is empty, 'regex' when the regular expression does not compile.
String? urlBlacklistRuleError(UrlBlacklistRule rule) {
  if (rule.name.trim().isEmpty) return 'name';
  if (rule.pattern.trim().isEmpty) return 'pattern';
  if (rule.isRegex) {
    try {
      RegExp(rule.pattern);
    } catch (_) {
      return 'regex';
    }
  }
  return null;
}

/// The first of [rules] that blocks [url] on any of [surfaces], or null.
UrlBlacklistRule? urlBlacklistMatch(
  List<UrlBlacklistRule> rules,
  String url,
  Set<String> surfaces,
) {
  for (final rule in rules) {
    if (rule.appliesTo(surfaces) && rule.matches(url)) return rule;
  }
  return null;
}

/// Page script that hands the page [rules] and, the first time there are
/// any, wraps history.pushState and replaceState so a blocked address is
/// never pushed. Home Assistant reads the location after it pushes, so the
/// page simply stays where it was. The blocked address and the rule's name
/// go to the `ksUrlBlocked` handler for the notice.
///
/// Run at document start for every page and again on the page on screen
/// when the rules change: an empty list leaves an existing wrap passing
/// everything through. The kiosk's own navigation scripts push through
/// `history.__ksPushState`, the unwrapped original, so they are never
/// blocked.
String urlBlacklistJs(List<UrlBlacklistRule> rules) {
  final compiled = jsonEncode([for (final r in rules) r.compiled]);
  return '''
(function (rules) {
  var list = [];
  for (var i = 0; i < rules.length; i++) {
    try {
      var r = rules[i];
      list.push({ re: new RegExp(r.s, 'i'), p: r.p, q: r.q, f: r.f, n: r.n });
    } catch (e) {}
  }
  window.__ksUrlBlacklist = list;
  if (window.__ksUrlBlacklistGuard || !list.length) return;
  window.__ksUrlBlacklistGuard = true;
  function subject(url, r) {
    var s = url, i;
    if (!r.f) { i = s.indexOf('#'); if (i >= 0) s = s.slice(0, i); }
    if (!r.q) {
      i = s.indexOf('?');
      if (i >= 0) {
        var h = s.indexOf('#', i);
        s = s.slice(0, i) + (h >= 0 ? s.slice(h) : '');
      }
    }
    if (r.p) {
      var m = /^[a-zA-Z][a-zA-Z0-9+.\\-]*:\\/\\/[^\\/?#]*/.exec(s);
      if (m) {
        s = s.slice(m[0].length);
        if (s.charAt(0) !== '/') s = '/' + s;
      }
    }
    return s;
  }
  function blocked(url) {
    var all = window.__ksUrlBlacklist || [];
    for (var i = 0; i < all.length; i++) {
      if (all[i].re.test(subject(url, all[i]))) return all[i];
    }
    return null;
  }
  function wrap(name) {
    var original = history[name];
    if (typeof original !== 'function') return;
    // The kiosk's own moves (rotation, the carousel, Home Assistant
    // actions) are the owner's choice and go around the check.
    if (name === 'pushState') history.__ksPushState = original;
    history[name] = function (state, title, url) {
      if (url !== undefined && url !== null && url !== '') {
        var target = null;
        try { target = new URL(String(url), location.href).href; } catch (e) {}
        if (target && target !== location.href) {
          var rule = blocked(target);
          if (rule) {
            try {
              window.flutter_inappwebview.callHandler('ksUrlBlocked', target, rule.n);
            } catch (e) {}
            return;
          }
        }
      }
      return original.apply(this, arguments);
    };
  }
  wrap('pushState');
  wrap('replaceState');
})($compiled);
''';
}
