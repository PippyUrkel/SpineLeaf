import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../library/library_screen.dart';
import '../search/search_screen.dart';
import '../statistics/statistics_screen.dart';
import '../settings/settings_screen.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabProvider);
    final width = MediaQuery.of(context).size.width;
    final useRail = width >= kCompactWidth;

    final destinations = const [
      NavigationDestination(
        icon: Icon(Icons.library_books_outlined),
        selectedIcon: Icon(Icons.library_books),
        label: 'Library',
      ),
      NavigationDestination(
        icon: Icon(Icons.search_outlined),
        selectedIcon: Icon(Icons.search),
        label: 'Search',
      ),
      NavigationDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart),
        label: 'Statistics',
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ];

    final railDestinations = destinations
        .map((d) => NavigationRailDestination(
              icon: d.icon,
              selectedIcon: d.selectedIcon,
              label: Text(d.label),
            ))
        .toList();

    final screens = [
      const LibraryScreen(),
      const SearchScreen(),
      const StatisticsScreen(),
      const SettingsScreen(),
    ];

    if (useRail) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                ref.read(selectedTabProvider.notifier).state = index;
              },
              extended: width >= kMediumWidth,
              destinations: railDestinations,
              labelType: width >= kMediumWidth
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.selected,
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: AnimatedSwitcher(
                duration: kFastAnimation,
                child: KeyedSubtree(
                  key: ValueKey(selectedIndex),
                  child: screens[selectedIndex],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: AnimatedSwitcher(
        duration: kFastAnimation,
        child: KeyedSubtree(
          key: ValueKey(selectedIndex),
          child: screens[selectedIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          ref.read(selectedTabProvider.notifier).state = index;
        },
        destinations: destinations,
      ),
    );
  }
}
