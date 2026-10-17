import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/store_state.dart';
import 'about_screen.dart';
import 'installed_screen.dart';
import 'sources_screen.dart';
import 'store_screen.dart';

/// Root scaffold with the bottom navigation between the main sections.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['Store', 'Sources', 'Installed', 'About'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (_index == 0 || _index == 2)
            Consumer<StoreState>(
              builder: (context, state, _) => IconButton(
                tooltip: 'Refresh repositories',
                onPressed: state.refreshing ? null : state.refresh,
                icon: state.refreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          StoreScreen(),
          SourcesScreen(),
          InstalledScreen(),
          AboutScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Store'),
          NavigationDestination(
              icon: Icon(Icons.rss_feed_outlined),
              selectedIcon: Icon(Icons.rss_feed),
              label: 'Sources'),
          NavigationDestination(
              icon: Icon(Icons.download_done_outlined),
              selectedIcon: Icon(Icons.download_done),
              label: 'Installed'),
          NavigationDestination(
              icon: Icon(Icons.info_outline),
              selectedIcon: Icon(Icons.info),
              label: 'About'),
        ],
      ),
    );
  }
}
