import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/store_app.dart';
import '../state/store_state.dart';
import '../widgets/add_source_dialog.dart';
import '../widgets/app_list_tile.dart';
import '../widgets/empty_state.dart';
import 'app_detail_screen.dart';

/// The main catalog: every app from every enabled repository.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final _searchController = TextEditingController();
  String? _category;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StoreState>();

    if (!state.ready) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.sources.isEmpty) {
      return EmptyState(
        icon: Icons.storefront_outlined,
        title: 'No repositories yet',
        message: 'This store ships empty on purpose. Add a repository index URL '
            'to start browsing apps.',
        action: FilledButton.icon(
          onPressed: () => showAddSourceDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Add repository'),
        ),
      );
    }

    final results = state.search(_searchController.text, category: _category);
    final categories = state.categories;

    return Column(
      children: [
        if (state.refreshing) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search ${state.apps.length} apps',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
        ),
        if (categories.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                ),
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category),
                      selected: _category == category,
                      onSelected: (selected) =>
                          setState(() => _category = selected ? category : null),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: _buildBody(state, results),
        ),
      ],
    );
  }

  Widget _buildBody(StoreState state, List<StoreApp> results) {
    if (results.isEmpty) {
      if (state.apps.isEmpty) {
        final errors = state.sources
            .where((s) => s.enabled && state.errorFor(s) != null)
            .toList();
        if (errors.isNotEmpty) {
          return EmptyState(
            icon: Icons.cloud_off,
            title: 'Could not load any repository',
            message: errors.map((s) => '${s.name}: ${state.errorFor(s)}').join('\n\n'),
            action: FilledButton.icon(
              onPressed: state.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          );
        }
        return const EmptyState(
          icon: Icons.apps,
          title: 'No apps found',
          message: 'The enabled repositories did not return any apps.',
        );
      }
      return const EmptyState(
        icon: Icons.search_off,
        title: 'No matches',
        message: 'Try a different search or category.',
      );
    }

    return RefreshIndicator(
      onRefresh: state.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: results.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 80),
        itemBuilder: (context, index) {
          final app = results[index];
          return AppListTile(
            app: app,
            installed: state.isInstalled(app),
            updateAvailable: state.updateAvailable(app),
            badge: app.sourceName.isEmpty ? null : app.sourceName,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AppDetailScreen(app: app)),
            ),
          );
        },
      ),
    );
  }
}
