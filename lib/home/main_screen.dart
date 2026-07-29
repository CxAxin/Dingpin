import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pinnit_flutter/editor/editor_screen.dart';
import 'package:pinnit_flutter/notifications/notifications_screen.dart';
import 'package:pinnit_flutter/notifications/history_screen.dart';
import 'package:pinnit_flutter/about/about_screen.dart';
import 'package:pinnit_flutter/l10n/app_localizations.dart';

/// M3 bottom-navigation host: three tabs (自建 / 历史 / 我的) that keep their
/// own top app bars. The "new notification" FAB only shows on the 自建 tab.
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _index = 0;

  static const _screens = <Widget>[
    NotificationsScreen(),
    HistoryScreen(),
    AboutScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.push_pin_outlined),
            selectedIcon: const Icon(Icons.push_pin),
            label: l10n.tabPinned,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: l10n.tabHistory,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.tabAbout,
          ),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditorScreen()),
              ),
              tooltip: l10n.tooltipNew,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
