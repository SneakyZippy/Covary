import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/database/app_database.dart';

// =============================================================================
// Identity Card
// =============================================================================

/// Displays the participant's anonymised research ID and study day.
class IdentityCard extends StatelessWidget {
  final String uuid;
  final int studyDay;

  const IdentityCard({super.key, required this.uuid, required this.studyDay});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final shortUuid = uuid.length > 8 ? uuid.substring(0, 8).toUpperCase() : uuid;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withAlpha(180)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha(40),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RESEARCH IDENTITY',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onPrimary.withAlpha(180),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withAlpha(40),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'DAY $studyDay',
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Participant ID',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onPrimary.withAlpha(150)),
          ),
          Row(
            children: [
              Text(
                '#$shortUuid',
                style: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.copy_rounded, color: colorScheme.onPrimary, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: uuid));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Participant ID copied to clipboard')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Activity Summary Card
// =============================================================================

/// Shows today's log count and number of currently active metrics.
class ActivitySummaryCard extends StatelessWidget {
  final int todayCount;
  final int activeMetricsCount;

  const ActivitySummaryCard({
    super.key,
    required this.todayCount,
    required this.activeMetricsCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withAlpha(150),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Progress',
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$todayCount logs today',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                           size: 14,
                           color: colorScheme.onPrimaryContainer.withAlpha(180)),
                      const SizedBox(width: 4),
                      Text(
                        '$activeMetricsCount metrics currently active',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer.withAlpha(180),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.onPrimaryContainer.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_rounded,
                color: colorScheme.onPrimaryContainer,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Mini Heatmap
// =============================================================================

/// A compact 14-day compliance heatmap displayed on the Insights screen.
class MiniHeatmap extends StatelessWidget {
  final Map<DateTime, bool> complianceMap;

  const MiniHeatmap({super.key, required this.complianceMap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final sortedDates = complianceMap.keys.toList()..sort((a, b) => a.compareTo(b));
    final firstRow = sortedDates.take(7).toList();
    final secondRow = sortedDates.skip(7).take(7).toList();

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Activity',
              style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FittedBox(child: _buildHeatRow(firstRow, colorScheme)),
            const SizedBox(height: 4),
            FittedBox(child: _buildHeatRow(secondRow, colorScheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatRow(List<DateTime> dates, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: dates.map((d) {
        final active = complianceMap[d] ?? false;
        return Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: active ? colorScheme.primary : colorScheme.surface,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: active ? colorScheme.primary : colorScheme.outlineVariant.withAlpha(50),
              width: 0.5,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// =============================================================================
// Recent Activity Preview
// =============================================================================

/// Shows the 3 most recent log entries with a "View All" link.
class RecentActivityPreview extends StatelessWidget {
  final List<Event> events;
  final VoidCallback onViewAll;

  const RecentActivityPreview({
    super.key,
    required this.events,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Logs',
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        ...events.map((e) {
          final time = '${e.timestamp.hour.toString().padLeft(2, '0')}:${e.timestamp.minute.toString().padLeft(2, '0')}';
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              onTap: onViewAll,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                dense: true,
                leading: Icon(Icons.history_toggle_off_rounded, size: 18, color: colorScheme.secondary),
                title: Text(
                  e.label,
                  style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Value: ${e.value}',
                  style: textTheme.bodySmall,
                ),
                trailing: Text(
                  time,
                  style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
