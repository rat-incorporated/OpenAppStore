import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/source.dart';
import '../state/store_state.dart';
import '../widgets/add_source_dialog.dart';
import '../widgets/empty_state.dart';

/// Manage the repositories the store reads from.
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StoreState>();

    return Scaffold(
      body: state.sources.isEmpty
          ? EmptyState(
              icon: Icons.rss_feed_outlined,
              title: 'No repositories',
              message: 'Add an index URL to load apps. Repositories are just JSON '
                  'documents — host one anywhere.',
              action: FilledButton.icon(
                onPressed: () => showAddSourceDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add repository'),
              ),
            )
          : ListView.separated(
              itemCount: state.sources.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final source = state.sources[index];
                return _SourceTile(source: source, state: state);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddSourceDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add repository'),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source, required this.state});
  final StoreSource source;
  final StoreState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = state.errorFor(source);
    final count = state.appCountFor(source);

    String subtitle;
    Color? subtitleColor;
    if (!source.enabled) {
      subtitle = 'Disabled';
    } else if (error != null) {
      subtitle = error;
      subtitleColor = theme.colorScheme.error;
    } else {
      subtitle = '$count app${count == 1 ? '' : 's'}';
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: error != null
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.primaryContainer,
        child: Icon(
          error != null ? Icons.error_outline : Icons.rss_feed,
          color: error != null
              ? theme.colorScheme.onErrorContainer
              : theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(source.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: subtitleColor == null ? null : TextStyle(color: subtitleColor),
          ),
          Text(
            source.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
      trailing: SizedBox(
        width: 96,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: source.enabled,
              onChanged: (value) => state.setSourceEnabled(source, value),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'rename':
                    await _rename(context, source);
                  case 'remove':
                    await _remove(context, source);
                  case 'refresh':
                    await state.refresh();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'refresh', child: Text('Refresh')),
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
            ),
          ],
        ),
      ),
      isThreeLine: true,
      onTap: () => state.setSourceEnabled(source, !source.enabled),
    );
  }

  Future<void> _rename(BuildContext context, StoreSource source) async {
    final controller = TextEditingController(text: source.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename repository'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) {
      await state.renameSource(source, name);
    }
  }

  Future<void> _remove(BuildContext context, StoreSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${source.name}?'),
        content: const Text('Apps from this repository will no longer be listed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await state.removeSource(source);
    }
  }
}
