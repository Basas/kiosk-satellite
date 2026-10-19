import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/messages.dart';
import '../managers/plugins/plugin_directory.dart';
import '../managers/plugins/plugin_manager.dart';
import 'kit.dart';
import 'plugin_settings.dart';
import 'settings_search.dart';
import 'toast.dart';

const pluginSubmitUrl =
    'https://github.com/jxlarrea/kiosk-satellite-plugins#submit-your-plugin';

/// Browse plugins: Community Plugins, searchable, with each plugin's
/// stars, downloads and active installs. Picking one runs the same preview
/// and trust dialog as Add plugin. Mirrors the remote admin (plugins.js,
/// renderDirectory).
class PluginDirectoryPanel extends StatefulWidget {
  const PluginDirectoryPanel({
    super.key,
    required this.plugins,
    required this.onOpen,
  });
  final PluginManager plugins;
  final ValueChanged<String> onOpen;
  @override
  State<PluginDirectoryPanel> createState() => _PluginDirectoryPanelState();
}

class _PluginDirectoryPanelState extends State<PluginDirectoryPanel> {
  /// Rows per page, so a directory of thousands still builds a short page.
  static const pageSize = 20;
  final _query = TextEditingController();
  final _listTop = GlobalKey();
  int _page = 0;
  String _sort = 'installs';
  Map<String, Object?>? _data;
  Object? _error;
  bool _loading = true;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    // A new search starts at its first page.
    _query.addListener(() => setState(() => _page = 0));
    unawaited(_load());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() => _loading = true);
    try {
      final data = await widget.plugins.directory.read(refresh: refresh);
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _install(Map<String, Object?> entry, bool update) async {
    if (_busyId != null) return;
    setState(() => _busyId = entry['id'] as String);
    try {
      final preview = update
          ? await widget.plugins.checkUpdate(entry['id'] as String)
          : await widget.plugins.previewRepository(
              entry['repository'] as String,
            );
      if (!mounted) return;
      if (update && preview['updateAvailable'] != true) {
        showToast(
          context,
          title: '${entry['name']}',
          message: pluginText(context, 'No updates available.'),
        );
        return;
      }
      if (await showPluginPreview(context, preview)) {
        await widget.plugins.installRepository(
          preview['previewId'] as String,
          trusted: true,
        );
      }
    } catch (error) {
      if (mounted) {
        showToast(
          context,
          title: pluginText(context, 'Plugin Manager'),
          message: pluginError(context, '$error'),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// The orders Sort by offers, the same as kiosksatellite.com's.
  static const sorts = {
    'installs': 'Most installs',
    'stars': 'Most stars',
    'updated': 'Recently updated',
    'newest': 'Newest',
    'name': 'Name',
  };

  static int _byName(Map a, Map b) =>
      '${a['name']}'.toLowerCase().compareTo('${b['name']}'.toLowerCase());

  static int _count(Map a, Map b, String key) =>
      ((b[key] as int?) ?? -1).compareTo((a[key] as int?) ?? -1);

  static int _date(Map a, Map b, String key) =>
      '${b[key] ?? ''}'.compareTo('${a[key] ?? ''}');

  static int Function(Map, Map) comparator(String sort) => switch (sort) {
    'stars' => (a, b) => _count(a, b, 'stars').ifZero(() => _byName(a, b)),
    'updated' => (a, b) => _date(a, b, 'released').ifZero(() => _byName(a, b)),
    'newest' => (a, b) => _date(
      a,
      b,
      'added',
    ).ifZero(() => _date(a, b, 'released')).ifZero(() => _byName(a, b)),
    'name' => _byName,
    _ => (a, b) => _count(
      a,
      b,
      'installs',
    ).ifZero(() => _count(a, b, 'downloads')).ifZero(() => _byName(a, b)),
  };

  List<Map<String, Object?>> _shown() {
    final words = _query.text.toLowerCase().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    final plugins = [
      for (final p in (_data?['plugins'] as List? ?? const []))
        p as Map<String, Object?>,
    ];
    return plugins.where((p) {
      final text = '${p['name']} ${p['description']} ${p['author']} ${p['id']}'
          .toLowerCase();
      return words.every(text.contains);
    }).toList()..sort(comparator(_sort));
  }

  void _turn(int page) {
    setState(() => _page = page);
    // The new page starts at its first row, not where the last one ended.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final top = _listTop.currentContext;
      if (top != null && top.mounted) {
        Scrollable.ensureVisible(
          top,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = _data?['error'] ?? _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _query,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: pluginText(context, 'Search plugins'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: pluginText(context, 'Refresh'),
                    onPressed: _loading ? null : () => _load(refresh: true),
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            DropdownRow<String>(
              title: pluginText(context, 'Sort by'),
              description: null,
              value: _sort,
              options: [
                for (final entry in sorts.entries)
                  (entry.key, pluginText(context, entry.value)),
              ],
              // A new order starts at its first page.
              onChanged: (value) => setState(() {
                _sort = value ?? 'installs';
                _page = 0;
              }),
            ),
            if (error != null) WarnRow(pluginError(context, '$error')),
          ],
        ),
        if (_data != null)
          ValueListenableBuilder<List<Map<String, Object?>>>(
            valueListenable: widget.plugins.installed,
            builder: (context, installed, _) {
              final shown = _shown();
              final byId = {for (final p in installed) p['id']: p};
              final pages = (shown.length / pageSize).ceil();
              final page = _page.clamp(0, pages == 0 ? 0 : pages - 1);
              final rows = shown.skip(page * pageSize).take(pageSize);
              return SettingsCard(
                key: _listTop,
                children: [
                  if (shown.isEmpty)
                    HintRow(
                      pluginText(
                        context,
                        _query.text.trim().isEmpty
                            ? 'Community Plugins has no plugins yet.'
                            : 'No plugins match your search.',
                      ),
                    ),
                  for (final entry in rows)
                    _DirectoryRow(
                      entry: entry,
                      status: PluginDirectory.installStatus(
                        entry,
                        byId[entry['id']],
                      ),
                      busy: _busyId == entry['id'],
                      enabled: _busyId == null,
                      onInstall: (update) => _install(entry, update),
                      onOpen: () => widget.onOpen(entry['id'] as String),
                    ),
                  if (pages > 1)
                    _Pager(page: page, pages: pages, onTurn: _turn),
                ],
              );
            },
          ),
        SettingsCard(
          children: [
            SearchLandingTarget(
              id: 'x:plugins:submit',
              child: SettingsRow(
                title: Text(pluginText(context, 'Submit your plugin')),
                subtitle: Text(
                  pluginText(context, 'List your plugin in Community Plugins.'),
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => launchUrl(
                  Uri.parse(pluginSubmitUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A plugin's icon from Community Plugins, or the generic plugin icon.
class PluginIcon extends StatelessWidget {
  const PluginIcon({super.key, this.url, this.size = 40});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final generic = Container(
      width: size,
      height: size,
      color: theme.colorScheme.primary.withValues(alpha: 0.14),
      alignment: Alignment.center,
      child: Icon(
        Icons.extension_rounded,
        size: size * 0.55,
        color: theme.colorScheme.primary,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: url == null
          ? generic
          : Image.network(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => generic,
            ),
    );
  }
}

/// Previous and next page buttons around "Page 2 of 31".
class _Pager extends StatelessWidget {
  const _Pager({required this.page, required this.pages, required this.onTurn});
  final int page;
  final int pages;
  final ValueChanged<int> onTurn;

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: pluginText(context, 'Previous page'),
            onPressed: page > 0 ? () => onTurn(page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              l10n(context).pluginPageOfPages(
                number.format(page + 1),
                number.format(pages),
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(
            tooltip: pluginText(context, 'Next page'),
            onPressed: page < pages - 1 ? () => onTurn(page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _DirectoryRow extends StatelessWidget {
  const _DirectoryRow({
    required this.entry,
    required this.status,
    required this.busy,
    required this.enabled,
    required this.onInstall,
    required this.onOpen,
  });
  final Map<String, Object?> entry;
  final Map<String, Object?> status;
  final bool busy;
  final bool enabled;
  final ValueChanged<bool> onInstall;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final number = NumberFormat.compact(
      locale: Localizations.localeOf(context).toString(),
    );
    final installed = status['installed'] == true;
    final update = status['updateAvailable'] == true;
    final icon = entry['icon'] as String?;
    Widget stat(IconData icon, String label, int value) => Tooltip(
      message: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(number.format(value), style: muted),
        ],
      ),
    );
    final Widget trailing = busy
        ? const SizedBox(
            width: 24,
            height: 24,
            child: Padding(
              padding: EdgeInsets.all(3),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : update
        ? FilledButton.tonal(
            onPressed: enabled ? () => onInstall(true) : null,
            child: Text(pluginText(context, 'Update')),
          )
        : installed
        ? Text(
            pluginText(context, 'Installed'),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          )
        : IconButton(
            tooltip: pluginText(context, 'Install'),
            onPressed: enabled ? () => onInstall(false) : null,
            icon: const Icon(Icons.add_rounded),
          );
    return SettingsRow(
      leading: PluginIcon(url: icon),
      title: Text('${entry['name']}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${entry['author']} · ${entry['version']}', style: muted),
          if ('${entry['description']}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${entry['description']}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                stat(
                  Icons.star_outline_rounded,
                  pluginText(context, 'Stars'),
                  entry['stars'] as int? ?? 0,
                ),
                stat(
                  Icons.download_rounded,
                  pluginText(context, 'Downloads'),
                  entry['downloads'] as int? ?? 0,
                ),
                if (entry['installs'] is int)
                  stat(
                    Icons.devices_rounded,
                    pluginText(context, 'Active installs'),
                    entry['installs'] as int,
                  ),
              ],
            ),
          ),
        ],
      ),
      trailing: trailing,
      enabled: enabled,
      onTap: installed && !update ? onOpen : () => onInstall(update),
    );
  }
}

extension on int {
  /// This comparison, or [next] when it is a tie.
  int ifZero(int Function() next) => this == 0 ? next() : this;
}
