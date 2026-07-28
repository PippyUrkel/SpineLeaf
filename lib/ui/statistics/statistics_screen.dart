import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/extensions.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(bookRepositoryProvider);
    final stats = repo.getStats();

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Today's reading
            _StatCard(
              icon: Icons.timer,
              title: 'Today',
              value: stats.readingTimeToday.formatted,
              subtitle: 'reading time',
              color: context.colorScheme.primary,
            ),
            const SizedBox(height: 12),

            // Stats grid
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.schedule,
                    title: 'Total Time',
                    value: stats.totalReadingTime.formatted,
                    subtitle: '',
                    color: context.colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.local_fire_department,
                    title: 'Streak',
                    value: '${stats.currentStreak}',
                    subtitle: 'days',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.check_circle,
                    title: 'Completed',
                    value: '${stats.booksCompleted}',
                    subtitle: 'books',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.menu_book,
                    title: 'Reading',
                    value: '${stats.booksReading}',
                    subtitle: 'books',
                    color: context.colorScheme.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _StatCard(
              icon: Icons.layers,
              title: 'Chapters Read',
              value: '${stats.totalChaptersRead}',
              subtitle: 'across all books',
              color: context.colorScheme.primary,
            ),

            const SizedBox(height: 24),

            // Recent activity chart
            Text('Recent Activity', style: context.textTheme.titleMedium),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      height: 120,
                      child: _ActivityChart(activity: stats.recentActivity),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: stats.recentActivity.map((day) {
                        return Text(
                          DateFormat.E().format(day.date).substring(0, 2),
                          style: context.textTheme.labelSmall,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.textTheme.labelMedium),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: context.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(subtitle, style: context.textTheme.labelSmall),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityChart extends StatelessWidget {
  final List<DailyReading> activity;

  const _ActivityChart({required this.activity});

  @override
  Widget build(BuildContext context) {
    if (activity.isEmpty) {
      return const Center(child: Text('No recent activity'));
    }

    final maxMinutes = activity
        .map((a) => a.readingTime.inMinutes)
        .fold<int>(1, (a, b) => a > b ? a : b);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: activity.map((day) {
        final height = maxMinutes > 0
            ? (day.readingTime.inMinutes / maxMinutes * 100).clamp(4.0, 100.0)
            : 4.0;
        final isToday = day.date.isToday;

        return Tooltip(
          message: '${day.readingTime.formatted}\n${day.chaptersRead} chapters',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 28,
            height: height,
            decoration: BoxDecoration(
              color: isToday
                  ? context.colorScheme.primary
                  : context.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }).toList(),
    );
  }
}
