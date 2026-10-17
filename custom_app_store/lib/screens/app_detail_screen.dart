import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_release.dart';
import '../models/store_app.dart';
import '../state/store_state.dart';
import '../util/json_utils.dart';
import '../util/links.dart';
import '../widgets/app_icon.dart';

/// Detail page for a single app: description, screenshots, links, versions and
/// the install/update action.
class AppDetailScreen extends StatelessWidget {
  const AppDetailScreen({super.key, required this.app});

  final StoreApp app;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StoreState>();
    final theme = Theme.of(context);
    final latest = app.latest;

    return Scaffold(
      appBar: AppBar(title: Text(app.name)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _Header(app: app),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _InstallBar(app: app, state: state),
          ),
          if (state.installErrorFor(app) != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.installErrorFor(app)!,
                          style: TextStyle(color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (latest != null && latest.size > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'APK size: ${formatBytes(latest.size)}'
                '${latest.channel != 'stable' ? ' · ${latest.channel}' : ''}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (app.screenshots.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: app.screenshots.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    app.screenshots[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 120,
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (app.description.isNotEmpty) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('About this app', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(app.description, style: theme.textTheme.bodyMedium),
            ),
          ],
          const SizedBox(height: 20),
          _LinksSection(app: app),
          if (app.releases.length > 1) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Versions', style: theme.textTheme.titleMedium),
            ),
            for (final release in app.releases)
              _ReleaseTile(
                release: release,
                isLatest: identical(release, app.releases.first),
              ),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'From ${app.sourceName.isEmpty ? 'an unknown repository' : app.sourceName} · ${app.id}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.app});
  final StoreApp app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = [...app.categories, ...app.tags].take(6).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(app: app, size: 72, radius: 16),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.name, style: theme.textTheme.headlineSmall),
                if (app.summary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(app.summary, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: 6),
                Text(
                  [
                    if (app.developer.isNotEmpty) app.developer,
                    if (app.latestVersionName.isNotEmpty) 'v${app.latestVersionName}',
                    if (app.license.isNotEmpty) app.license,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in tags)
                        Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallBar extends StatelessWidget {
  const _InstallBar({required this.app, required this.state});
  final StoreApp app;
  final StoreState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = state.progressFor(app);
    final installing = state.isInstalling(app);
    final installed = state.isInstalled(app);
    final update = state.updateAvailable(app);

    if (installing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.downloading),
            label: Text(
              progress == null ? 'Downloading…' : 'Downloading ${(progress * 100).round()}%',
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress),
        ],
      );
    }

    final label = update
        ? 'Update to v${app.latestVersionName}'
        : installed
            ? 'Reinstall v${app.latestVersionName}'
            : 'Install${app.latestVersionName.isEmpty ? '' : ' v${app.latestVersionName}'}';

    final icon = update
        ? Icons.arrow_circle_up
        : installed
            ? Icons.refresh
            : Icons.download;

    return FilledButton.icon(
      onPressed: app.latest == null ? null : () => state.install(app),
      icon: Icon(icon),
      style: FilledButton.styleFrom(
        backgroundColor: update ? theme.colorScheme.tertiary : null,
        minimumSize: const Size.fromHeight(48),
      ),
      label: Text(app.latest == null ? 'No download available' : label),
    );
  }
}

class _LinksSection extends StatelessWidget {
  const _LinksSection({required this.app});
  final StoreApp app;

  @override
  Widget build(BuildContext context) {
    final links = <(IconData, String, String)>[
      if (app.homepage.isNotEmpty) (Icons.language, 'Website', app.homepage),
      if (app.sourceCode.isNotEmpty) (Icons.code, 'Source', app.sourceCode),
      if (app.issueTracker.isNotEmpty) (Icons.bug_report_outlined, 'Issues', app.issueTracker),
      if (app.donate.isNotEmpty) (Icons.favorite_outline, 'Donate', app.donate),
    ];
    if (links.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (icon, label, url) in links)
            OutlinedButton.icon(
              onPressed: () => openExternal(context, url),
              icon: Icon(icon, size: 18),
              label: Text(label),
            ),
        ],
      ),
    );
  }
}

class _ReleaseTile extends StatelessWidget {
  const _ReleaseTile({required this.release, required this.isLatest});
  final AppRelease release;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bits = <String>[
      if (release.versionCode > 0) 'code ${release.versionCode}',
      if (release.size > 0) formatBytes(release.size),
      if (release.added.isNotEmpty) release.added,
    ];
    return ListTile(
      leading: Icon(isLatest ? Icons.star : Icons.history, color: isLatest ? Colors.amber : null),
      title: Text('v${release.versionName}'
          '${release.channel != 'stable' ? ' (${release.channel})' : ''}'),
      subtitle: Text(
        release.changelog.isNotEmpty ? '${bits.join(' · ')}\n${release.changelog}' : bits.join(' · '),
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
