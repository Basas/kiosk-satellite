import 'dart:async';

import 'package:flutter/material.dart';

import '../app_container.dart';
import '../core/events.dart';
import '../l10n/messages.dart';
import '../managers/browser/url_blacklist.dart';
import '../managers/settings/definitions.dart';
import 'kit.dart';
import 'settings_search.dart';

/// Settings > Web Browsing > URL Blacklist: the addresses the dashboard and
/// external pages cannot open, each rule with its name, pattern and where
/// it applies. Tapping a rule edits it, Add rule opens the same dialog
/// empty. The page follows changes made in the remote admin while it is
/// open.
class UrlBlacklistCard extends StatefulWidget {
  const UrlBlacklistCard({super.key, required this.container});

  final AppContainer container;

  @override
  State<UrlBlacklistCard> createState() => _UrlBlacklistCardState();
}

class _UrlBlacklistCardState extends State<UrlBlacklistCard> {
  AppContainer get c => widget.container;
  StreamSubscription<SettingChanged>? _echo;

  @override
  void initState() {
    super.initState();
    _echo = c.bus.on<SettingChanged>().listen((e) {
      if (e.key == browserUrlBlacklist.key && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _echo?.cancel();
    super.dispose();
  }

  Future<void> _edit([int? index]) async {
    await showUrlBlacklistRuleDialog(context, c, index: index);
    if (mounted) setState(() {});
  }

  Future<void> _remove(int index) async {
    await c.commands.execute('removeUrlBlacklistRule', {'index': index});
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final scheme = Theme.of(context).colorScheme;
    final rules = c.browser.urlBlacklist;
    return SearchLandingTarget(
      id: 'x:url_blacklist',
      child: SettingsCard(
        children: [
          if (rules.isEmpty) HintRow(strings.urlBlacklistEmpty),
          for (final (index, rule) in rules.indexed)
            SettingsRow(
              leading: Icon(Icons.block, color: scheme.primary),
              title: Text(rule.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.pattern,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    [
                      urlBlacklistScopeLabel(context, rule.scope),
                      if (rule.isRegex) strings.urlBlacklistTypeRegex,
                    ].join(' · '),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: strings.commonRemove,
                onPressed: () => _remove(index),
              ),
              onTap: () => _edit(index),
            ),
          ListTile(
            leading: Icon(Icons.add_circle_outline, color: scheme.primary),
            title: Text(
              strings.urlBlacklistAdd,
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => _edit(),
          ),
        ],
      ),
    );
  }
}

/// The Applies to choice of a rule, in the kiosk's language.
String urlBlacklistScopeLabel(BuildContext context, String scope) =>
    switch (scope) {
      urlBlacklistDashboard => l10n(context).urlBlacklistScopeDashboard,
      urlBlacklistExternal => l10n(context).urlBlacklistScopeExternal,
      _ => l10n(context).urlBlacklistScopeAll,
    };

/// Why Save refused, in the kiosk's language (see the
/// saveUrlBlacklistRule command for the codes).
String urlBlacklistError(BuildContext context, String code) => switch (code) {
  'name' => l10n(context).urlBlacklistErrorName,
  'pattern' => l10n(context).urlBlacklistErrorPattern,
  'regex' => l10n(context).urlBlacklistErrorRegex,
  _ => l10n(context).commonSaveFailed,
};

/// Add a rule, or change the one at [index]. Save checks the rule on the
/// device: a usable one saves and closes, anything else shows why and keeps
/// the dialog open. Answers true when it saved.
Future<bool> showUrlBlacklistRuleDialog(
  BuildContext context,
  AppContainer container, {
  int? index,
}) async {
  final rules = container.browser.urlBlacklist;
  final rule = index != null && index < rules.length ? rules[index] : null;
  final name = TextEditingController(text: rule?.name ?? '');
  final pattern = TextEditingController(text: rule?.pattern ?? '');
  var type = rule?.type ?? urlBlacklistWildcard;
  var scope = rule?.scope ?? urlBlacklistAll;
  var saving = false;
  String? error;

  final route = DialogRoute<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final strings = l10n(ctx);
        final scheme = Theme.of(ctx).colorScheme;
        Future<void> save() async {
          setDialogState(() {
            saving = true;
            error = null;
          });
          final result = await container.commands
              .execute('saveUrlBlacklistRule', {
                'name': name.text,
                'pattern': pattern.text,
                'type': type,
                'scope': scope,
                if (rule != null) 'index': index,
              });
          if (!ctx.mounted) return;
          if (result.ok) {
            Navigator.pop(ctx, true);
            return;
          }
          setDialogState(() {
            saving = false;
            error = urlBlacklistError(ctx, result.error ?? '');
          });
        }

        return AlertDialog(
          title: Text(
            rule == null
                ? strings.urlBlacklistAddTitle
                : strings.urlBlacklistEditTitle,
          ),
          content: SizedBox(
            width: 480,
            child: EdgeFade(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    LabeledField(
                      label: strings.urlBlacklistName,
                      child: TextField(
                        controller: name,
                        enabled: !saving,
                        autofocus: rule == null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(),
                      ),
                    ),
                    LabeledField(
                      label: strings.urlBlacklistType,
                      child: KsDropdown<String>(
                        value: type,
                        expand: true,
                        items: [
                          DropdownMenuItem(
                            value: urlBlacklistWildcard,
                            child: Text(strings.urlBlacklistTypeWildcard),
                          ),
                          DropdownMenuItem(
                            value: urlBlacklistRegex,
                            child: Text(strings.urlBlacklistTypeRegex),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (v) => setDialogState(() => type = v ?? type),
                      ),
                    ),
                    LabeledField(
                      label: strings.urlBlacklistPattern,
                      helper: type == urlBlacklistRegex
                          ? strings.urlBlacklistPatternRegexHint
                          : strings.urlBlacklistPatternWildcardHint,
                      child: TextField(
                        controller: pattern,
                        enabled: !saving,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: const TextStyle(fontFamily: 'monospace'),
                        onSubmitted: (_) => saving ? null : save(),
                        decoration: const InputDecoration(),
                      ),
                    ),
                    LabeledField(
                      label: strings.urlBlacklistScope,
                      helper: strings.urlBlacklistScopeHint,
                      child: KsDropdown<String>(
                        value: scope,
                        expand: true,
                        items: [
                          for (final s in urlBlacklistScopes)
                            DropdownMenuItem(
                              value: s,
                              child: Text(urlBlacklistScopeLabel(ctx, s)),
                            ),
                        ],
                        onChanged: saving
                            ? null
                            : (v) => setDialogState(() => scope = v ?? scope),
                      ),
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: Theme.of(
                          ctx,
                        ).textTheme.bodyMedium?.copyWith(color: scheme.error),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: Text(strings.commonCancel),
            ),
            FilledButton(
              onPressed: saving ? null : save,
              child: Text(strings.commonSave),
            ),
          ],
        );
      },
    ),
  );
  final saved = await Navigator.of(context, rootNavigator: true).push(route);
  await route.completed;
  name.dispose();
  pattern.dispose();
  return saved ?? false;
}
