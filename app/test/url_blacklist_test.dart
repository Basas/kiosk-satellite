import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/browser/url_blacklist.dart';

UrlBlacklistRule wildcard(String pattern, {String scope = urlBlacklistAll}) =>
    UrlBlacklistRule(name: pattern, pattern: pattern, scope: scope);

UrlBlacklistRule regex(String pattern) =>
    UrlBlacklistRule(name: pattern, pattern: pattern, type: urlBlacklistRegex);

const ha = 'http://ha.lan:8123';

// Addresses and whether each rule should block them, shared by the Dart
// matcher and the page script so the two never disagree.
final cases = <(UrlBlacklistRule, String, bool)>[
  (wildcard('/history*'), '$ha/history', true),
  (wildcard('/history*'), '$ha/history?entity_id=light.den', true),
  (wildcard('/history*'), '$ha/lovelace/history', false),
  (wildcard('*/history'), '$ha/history?entity_id=light.den', true),
  (wildcard('*/history'), '$ha/history#top', true),
  (wildcard('*/history'), '$ha/history/extra', false),
  (wildcard('/config/*'), '$ha/config/areas', true),
  (wildcard('/config/*'), '$ha/configuration', false),
  (wildcard('/LOGBOOK'), '$ha/logbook', true),
  (wildcard('www.youtube.com/*'), 'https://www.youtube.com/watch?v=1', true),
  (wildcard('www.youtube.com/*'), 'https://m.youtube.com/watch', false),
  (wildcard('*youtube.com*'), 'https://m.youtube.com/watch', true),
  (wildcard('https://ha.lan:8123/profile'), '$ha/profile', false),
  (wildcard('http://ha.lan:8123/profile'), '$ha/profile', true),
  (wildcard('/history?entity_id=*'), '$ha/history', false),
  (wildcard('/history?entity_id=*'), '$ha/history?entity_id=x', true),
  (wildcard('/a.b'), '$ha/axb', false),
  (regex(r'/(history|logbook)'), '$ha/logbook?x=1', true),
  (regex(r'/(history|logbook)'), '$ha/lovelace/0', false),
  (regex(r'^https://'), '$ha/lovelace/0', false),
  (regex(r'ENERGY'), '$ha/energy', true),
];

void main() {
  test('wildcards and regular expressions match the documented way', () {
    for (final (rule, url, blocked) in cases) {
      expect(rule.matches(url), blocked, reason: '${rule.pattern} on $url');
    }
  });

  test('a rule covers only the surfaces it names', () {
    final dashboard = wildcard('/history*', scope: urlBlacklistDashboard);
    final external = wildcard('*youtube*', scope: urlBlacklistExternal);
    final rules = [dashboard, external];
    expect(
      urlBlacklistMatch(rules, '$ha/history', {urlBlacklistDashboard}),
      dashboard,
    );
    expect(
      urlBlacklistMatch(rules, '$ha/history', {urlBlacklistExternal}),
      isNull,
    );
    expect(
      urlBlacklistMatch(rules, 'https://youtube.com', {urlBlacklistDashboard}),
      isNull,
    );
    // A dashboard link leaving for an external page answers to both.
    expect(
      urlBlacklistMatch(rules, 'https://youtube.com', {
        urlBlacklistDashboard,
        urlBlacklistExternal,
      }),
      external,
    );
  });

  test('the stored list round-trips and skips what is malformed', () {
    final rules = [
      wildcard('/history*', scope: urlBlacklistDashboard),
      regex('logbook'),
    ];
    final parsed = parseUrlBlacklist(encodeUrlBlacklist(rules));
    expect(
      [for (final r in parsed) r.toJson()],
      [for (final r in rules) r.toJson()],
    );
    expect(
      parseUrlBlacklist(
        jsonEncode([
          {'name': '', 'pattern': '/x'},
          {'name': 'x', 'pattern': ' '},
          'junk',
          {'name': 'ok', 'pattern': '/ok', 'type': 'bogus', 'scope': 'bogus'},
        ]),
      ).map((r) => r.toJson()),
      [
        {'name': 'ok', 'pattern': '/ok', 'type': 'wildcard', 'scope': 'all'},
      ],
    );
    expect(parseUrlBlacklist('not json'), isEmpty);
  });

  test('a rule that cannot be used says why', () {
    expect(urlBlacklistRuleError(wildcard('/x')), isNull);
    expect(
      urlBlacklistRuleError(UrlBlacklistRule(name: ' ', pattern: '/x')),
      'name',
    );
    expect(
      urlBlacklistRuleError(UrlBlacklistRule(name: 'x', pattern: '')),
      'pattern',
    );
    expect(urlBlacklistRuleError(regex('(unclosed')), 'regex');
    expect(urlBlacklistRuleError(wildcard('(unclosed')), isNull);
  });

  test('the page script blocks exactly what the matcher blocks', () async {
    final dir = await Directory.systemTemp.createTemp('url_blacklist');
    addTearDown(() => dir.delete(recursive: true));
    final checks = [
      for (final (rule, url, blocked) in cases)
        {
          'script': urlBlacklistJs([rule]),
          'url': url,
          'blocked': blocked,
        },
    ];
    final harness = File('${dir.path}/harness.mjs');
    await harness.writeAsString('''
import { runInNewContext } from 'node:vm';
const checks = ${jsonEncode(checks)};
const failures = [];
for (const c of checks) {
  const pushed = [];
  const sent = [];
  const location = { href: 'http://ha.lan:8123/lovelace/0' };
  const history = {
    pushState(state, title, url) { pushed.push(url); },
    replaceState(state, title, url) { pushed.push(url); },
  };
  const window = {
    flutter_inappwebview: { callHandler: (...args) => sent.push(args) },
  };
  runInNewContext(c.script, { window, history, location, URL });
  history.pushState(null, '', c.url);
  const blocked = pushed.length === 0;
  if (blocked !== c.blocked) failures.push(c.url + ' expected ' + c.blocked);
  if (blocked && (sent.length !== 1 || sent[0][0] !== 'ksUrlBlocked')) {
    failures.push(c.url + ' did not report');
  }
}
// The page on screen hears new rules: an empty list lets everything by.
{
  const pushed = [];
  const location = { href: 'http://ha.lan:8123/lovelace/0' };
  const history = { pushState(s, t, url) { pushed.push(url); } };
  const window = { flutter_inappwebview: { callHandler() {} } };
  const context = { window, history, location, URL };
  runInNewContext(checks[0].script, context);
  history.pushState(null, '', '/history');
  runInNewContext(${jsonEncode(urlBlacklistJs(const []))}, context);
  history.pushState(null, '', '/history');
  if (pushed.length !== 1) failures.push('cleared rules still block');
}
// The kiosk's own navigation goes around the check.
{
  const pushed = [];
  const location = { href: 'http://ha.lan:8123/lovelace/0' };
  const history = { pushState(s, t, url) { pushed.push(url); } };
  const window = { flutter_inappwebview: { callHandler() {} } };
  runInNewContext(checks[0].script, { window, history, location, URL });
  history.__ksPushState.call(history, null, '', '/history');
  if (pushed.length !== 1) failures.push('the kiosk push was blocked');
}
console.log(JSON.stringify(failures));
''');
    final result = await Process.run('node', [harness.path]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(jsonDecode((result.stdout as String).trim()), isEmpty);
  });
}
