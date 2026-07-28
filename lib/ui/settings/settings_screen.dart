import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/extensions.dart';
import '../../data/repositories/repositories.dart';
import '../../app.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsRepo = ref.watch(preferencesRepositoryProvider);
    final themeMode = ref.watch(themeModeProvider);
    final settings = prefsRepo.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Appearance
          _SectionHeader(title: 'Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Theme'),
            subtitle: Text(themeMode == ThemeMode.system
                ? 'System'
                : themeMode == ThemeMode.light
                    ? 'Light'
                    : 'Dark'),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (set) {
                ref.read(themeModeProvider.notifier).state = set.first;
                prefsRepo.saveThemeMode(set.first);
              },
              showSelectedIcon: false,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Color Theme'),
            subtitle: const Text('Tap to change accent color'),
            trailing: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: ref.watch(seedColorProvider),
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.colorScheme.outline,
                  width: 2,
                ),
              ),
            ),
            onTap: () => _showColorPicker(context, ref),
          ),
          const Divider(),

          // Reading
          _SectionHeader(title: 'Reading'),
          ListTile(
            leading: const Icon(Icons.text_format),
            title: const Text('Default Reader Theme'),
            subtitle: Text(settings.readingTheme.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showReaderThemePicker(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.format_size),
            title: const Text('Default Font Size'),
            subtitle: Text('${settings.fontSize.round()} px'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: settings.fontSize > kMinFontSize
                      ? () {
                          final newSettings = settings.copyWith(
                            fontSize: settings.fontSize - 1,
                          );
                          prefsRepo.saveSettings(newSettings);
                          (context as Element).markNeedsBuild();
                        }
                      : null,
                ),
                Text('${settings.fontSize.round()}'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: settings.fontSize < kMaxFontSize
                      ? () {
                          final newSettings = settings.copyWith(
                            fontSize: settings.fontSize + 1,
                          );
                          prefsRepo.saveSettings(newSettings);
                          (context as Element).markNeedsBuild();
                        }
                      : null,
                ),
              ],
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.swap_vert),
            title: const Text('Scroll Mode'),
            subtitle: const Text('Continuous scroll instead of pages'),
            value: settings.scrollMode,
            onChanged: (value) {
              prefsRepo.saveSettings(settings.copyWith(scrollMode: value));
              (context as Element).markNeedsBuild();
            },
          ),
          const Divider(),

          // Library
          _SectionHeader(title: 'Library'),
          ListTile(
            leading: const Icon(Icons.sort),
            title: const Text('Default Sort'),
            subtitle: const Text('Recently Read'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),

          // Dictionary
          _SectionHeader(title: 'Dictionary'),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('Dictionary Provider'),
            subtitle: const Text('Built-in (Offline)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.showSnack('Dictionary settings coming soon');
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wifi_off),
            title: const Text('Offline Mode'),
            subtitle: const Text('Use built-in dictionary only'),
            value: true,
            onChanged: (value) {
              context.showSnack('Online dictionary coming soon');
            },
          ),
          const Divider(),

          // AI
          _SectionHeader(title: 'AI Summaries'),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('AI Provider'),
            subtitle: const Text('Demo (Mock)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.showSnack('AI provider configuration coming soon');
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off),
            title: const Text('Spoiler Protection'),
            subtitle: const Text('Only summarize chapters you\'ve read'),
            value: true,
            onChanged: (value) {
              context.showSnack('Spoiler protection is always enabled');
            },
          ),
          const Divider(),

          // Data
          _SectionHeader(title: 'Data'),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Storage'),
            subtitle: const Text('6 demo books loaded'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: context.colorScheme.error),
            title: Text('Clear All Data', style: TextStyle(color: context.colorScheme.error)),
            subtitle: const Text('Remove all books, progress, and notes'),
            onTap: () => _showClearDataDialog(context, ref),
          ),
          const SizedBox(height: 24),

          // About
          _SectionHeader(title: 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('SpineLeaf'),
            subtitle: const Text('v0.0.1-alpha • Pre-release'),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, WidgetRef ref) {
    final colors = [
      const Color(0xFF6750A4), // M3 Baseline
      const Color(0xFF1A5276), // Deep Blue
      const Color(0xFF8B5E3C), // Warm Brown
      Colors.indigo,
      Colors.blue,
      Colors.teal,
      Colors.green,
      Colors.orange,
      Colors.pink,
      Colors.deepPurple,
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Color Theme'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((color) {
            final isSelected = ref.read(seedColorProvider) == color;
            return GestureDetector(
              onTap: () {
                ref.read(seedColorProvider.notifier).state = color;
                ref.read(preferencesRepositoryProvider).saveSeedColor(color);
                Navigator.pop(ctx);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showReaderThemePicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reader Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ReadingTheme.values.map((theme) {
            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Aa',
                    style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              title: Text(theme.label),
              onTap: () {
                final prefsRepo = ref.read(preferencesRepositoryProvider);
                prefsRepo.saveSettings(prefsRepo.settings.copyWith(readingTheme: theme));
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showClearDataDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning, color: Theme.of(ctx).colorScheme.error),
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will remove all books, reading progress, annotations, and settings. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data cleared (demo data will reload on restart)')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: context.textTheme.titleSmall?.copyWith(
          color: context.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
