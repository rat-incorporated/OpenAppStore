import 'package:flutter/material.dart';

import '../models/store_app.dart';
import '../util/json_utils.dart';
import 'app_icon.dart';

/// A row in the app list.
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.app,
    this.installed = false,
    this.updateAvailable = false,
    this.badge,
    this.onTap,
  });

  final StoreApp app;
  final bool installed;
  final bool updateAvailable;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      if (app.developer.isNotEmpty) app.developer,
      if (app.latestVersionName.isNotEmpty) 'v${app.latestVersionName}',
      if (app.latest != null && app.latest!.size > 0) formatBytes(app.latest!.size),
    ];
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: AppIcon(app: app, size: 52),
      title: Row(
        children: [
          Expanded(
            child: Text(
              app.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (badge != null) _Badge(text: badge!),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (app.summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text(app.summary, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          Text(
            subtitleParts.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
      trailing: updateAvailable
          ? const Icon(Icons.arrow_circle_up, color: Colors.teal)
          : (installed ? const Icon(Icons.check_circle, color: Colors.green) : null),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: scheme.onSecondaryContainer),
      ),
    );
  }
}
