import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';

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

/// Shows the most recent log entries formatted as an interactive timeline.
class RecentActivityPreview extends StatefulWidget {
  final List<Event> events;
  final VoidCallback onViewAll;

  const RecentActivityPreview({
    super.key,
    required this.events,
    required this.onViewAll,
  });

  @override
  State<RecentActivityPreview> createState() => _RecentActivityPreviewState();
}

class _RecentActivityPreviewState extends State<RecentActivityPreview> {
  String? _expandedEventId;

  Color _getCategoryColor(EventCategory category, ColorScheme colorScheme) {
    switch (category) {
      case EventCategory.mood:
        return colorScheme.primary;
      case EventCategory.behavior:
        return colorScheme.secondary;
      case EventCategory.health:
        return const Color(0xFFC71585); // Ruby
      case EventCategory.productivity:
        return colorScheme.tertiary;
      case EventCategory.social:
        return const Color(0xFF007FFF); // Azure
      case EventCategory.nutrition:
        return const Color(0xFFFF7F50); // Coral
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  Widget _buildTimelineDetailRow(String label, String value, ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

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
                onPressed: widget.onViewAll,
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              ...widget.events.asMap().entries.map((entry) {
                final idx = entry.key;
                final e = entry.value;
                final isLast = idx == widget.events.length - 1;
                final isExpanded = _expandedEventId == e.id;
                
                final now = DateTime.now();
                final isToday = e.timestamp.year == now.year &&
                    e.timestamp.month == now.month &&
                    e.timestamp.day == now.day;
                final isYesterday = e.timestamp.year == now.year &&
                    e.timestamp.month == now.month &&
                    e.timestamp.day == now.day - 1;
                
                final String datePrefix;
                if (isToday) {
                  datePrefix = '';
                } else if (isYesterday) {
                  datePrefix = 'Yesterday, ';
                } else {
                  final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                  datePrefix = '${e.timestamp.day} ${monthNames[e.timestamp.month - 1]}, ';
                }
                
                final timeStr = "$datePrefix${e.timestamp.hour.toString().padLeft(2, '0')}:${e.timestamp.minute.toString().padLeft(2, '0')}";
                final displayValue = e.value == '1' && e.label.toLowerCase().contains('coffee')
                    ? '☕'
                    : (e.value == 'true'
                        ? 'Yes'
                        : (e.value == 'false' ? 'No' : e.value));

                final catColor = _getCategoryColor(e.category, colorScheme);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Node column
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _expandedEventId = isExpanded ? null : e.id;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 16,
                            height: 16,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: catColor,
                              border: Border.all(
                                color: isExpanded ? Colors.white : Colors.transparent,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: catColor.withValues(alpha: 0.4),
                                  blurRadius: isExpanded ? 8 : 4,
                                  spreadRadius: isExpanded ? 2 : 0,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!isLast)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 2,
                            height: isExpanded ? 115 : 24,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                          )
                        else
                          const SizedBox(height: 24),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Details column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() {
                                _expandedEventId = isExpanded ? null : e.id;
                              });
                            },
                            child: Row(
                              children: [
                                Text(
                                  timeStr,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    e.label,
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  displayValue,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: catColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedCrossFade(
                            firstChild: const SizedBox.shrink(),
                            secondChild: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 8, bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTimelineDetailRow('Category', e.category.name.toUpperCase(), colorScheme, textTheme),
                                  const SizedBox(height: 4),
                                  _buildTimelineDetailRow('Source', e.triggerSource.name.toUpperCase(), colorScheme, textTheme),
                                  if (e.latencyMs > 0) ...[
                                    const SizedBox(height: 4),
                                    _buildTimelineDetailRow('Latency', '${(e.latencyMs / 1000).toStringAsFixed(1)}s', colorScheme, textTheme),
                                  ],
                                ],
                              ),
                            ),
                            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 200),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
