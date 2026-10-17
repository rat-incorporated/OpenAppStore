import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/store_state.dart';

/// Static information about how the store works.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<StoreState>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 56,
                    height: 56,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('OpenAppStore', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      const Text(
                        'A bring-your-own-repository Android app store. It ships with no '
                        'sources, exactly like F-Droid: you add the JSON indexes you trust.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _InfoTile(
          icon: Icons.description_outlined,
          title: 'Repository format',
          subtitle: 'A JSON object with a "apps" array. Each app lists one or more '
              'releases with a version code and an APK URL. Format version 1.',
        ),
        _InfoTile(
          icon: Icons.download_outlined,
          title: 'Installing',
          subtitle: 'APKs download to the app cache, are optionally checksum-verified '
              'against the index SHA-256, then handed to the Android package installer.',
        ),
        _InfoTile(
          icon: Icons.verified_user_outlined,
          title: 'Permissions',
          subtitle: 'Internet access and permission to request package installs. '
              'Nothing else is collected or sent anywhere.',
        ),
        const SizedBox(height: 20),
        Text('Data', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Clear all data?'),
                content: const Text('Removes every repository and the installed-app list.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await state.clearEverything();
            }
          },
          icon: const Icon(Icons.delete_outline),
          label: const Text('Clear repositories and history'),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'Version 1.0.0 · repository format v1',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      isThreeLine: true,
    );
  }
}
