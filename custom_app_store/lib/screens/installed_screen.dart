import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/store_state.dart';
import '../widgets/app_list_tile.dart';
import '../widgets/empty_state.dart';
import 'app_detail_screen.dart';

/// Apps that were installed through this store.
class InstalledScreen extends StatelessWidget {
  const InstalledScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StoreState>();
    final apps = state.installedApps;

    if (apps.isEmpty) {
      return const EmptyState(
        icon: Icons.download_done_outlined,
        title: 'Nothing installed yet',
        message: 'Apps you install from the store show up here so you can track '
            'updates. Apps installed outside the store are not listed.',
      );
    }

    return ListView.separated(
      itemCount: apps.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 80),
      itemBuilder: (context, index) {
        final app = apps[index];
        final current = state.installedVersionCode(app);
        return Dismissible(
          key: ValueKey(app.key),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.errorContainer,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_outline),
          ),
          onDismissed: (_) => state.forgetInstalled(app),
          child: AppListTile(
            app: app,
            installed: true,
            updateAvailable: state.updateAvailable(app),
            badge: current == null ? null : 'installed #$current',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AppDetailScreen(app: app)),
            ),
          ),
        );
      },
    );
  }
}
