import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/enums.dart';
import '../../data/repositories/event_repository.dart';
import '../../services/metric_service.dart';
import '../widgets/confetti_animation.dart';
import '../widgets/help_button.dart';


class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  bool _isLoading = true;
  Map<DateTime, int> _activityMap = {};
  DateTime _firstDate = DateTime.now();
  int _currentStreak = 0;
  int _maxConsecutivePerfectDays = 0;
  double _last7DaysCompliance = 0.0;
  int _actualDaysEvaluated = 0;

  @override
  void initState() {
    super.initState();
    _loadAllActivity();
  }

  Future<void> _loadAllActivity() async {
    final eventRepo = context.read<EventRepository>();
    final metricService = context.read<MetricService>();
    final allEvents = await eventRepo.getAllEvents();

    final indicatorLabels = metricService.allMetrics
        .where((m) => m.isActivityIndicator)
        .map((m) => m.label)
        .toSet();

    final userEvents = allEvents.where((e) => 
        e.triggerSource != TriggerSource.system && 
        e.category != EventCategory.meta &&
        indicatorLabels.contains(e.label)
    ).toList();
    
    final Map<DateTime, int> tempMap = {};
    DateTime? earliest;

    for (final e in userEvents) {
      final date = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      tempMap[date] = (tempMap[date] ?? 0) + 1;
      
      if (earliest == null || date.isBefore(earliest)) {
        earliest = date;
      }
    }

    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final earliestDate = earliest ?? todayStart;
    final earliestDateStart = DateTime(earliestDate.year, earliestDate.month, earliestDate.day);

    // Dynamic compliance calculations for new achievements
    final sessionEvents = allEvents.where((e) => 
      e.category == EventCategory.meta && 
      e.label == 'SessionCompleted'
    ).toList();

    final totalWindows = metricService.allWindows.where((w) => w.isEnabled).length;

    // 1. Calculate daily session completions
    final Map<DateTime, int> dailyCompletions = {};
    for (final e in sessionEvents) {
      final date = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      dailyCompletions[date] = (dailyCompletions[date] ?? 0) + 1;
    }

    // 2. Calculate daily user activity counts
    final Map<DateTime, int> dailyActivityCount = {};
    for (final e in userEvents) {
      final date = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      dailyActivityCount[date] = (dailyActivityCount[date] ?? 0) + 1;
    }

    // 3. Chronological trace to calculate currentStreak, shields, and maxConsecutivePerfectDays
    final totalDays = todayStart.difference(earliestDateStart).inDays + 1;
    
    int currentStreak = 0;
    int streakShields = 0;
    int consecutivePerfectDays = 0;
    int maxConsecutivePerfectDays = 0;

    for (int i = 0; i < totalDays; i++) {
      final date = earliestDateStart.add(Duration(days: i));
      final hasActivity = (dailyActivityCount[date] ?? 0) > 0;
      final completed = dailyCompletions[date] ?? 0;
      final isPerfect = totalWindows > 0 && completed >= totalWindows;

      // Perfect days counting
      if (isPerfect) {
        consecutivePerfectDays++;
        if (consecutivePerfectDays > maxConsecutivePerfectDays) {
          maxConsecutivePerfectDays = consecutivePerfectDays;
        }
        if (consecutivePerfectDays % 3 == 0) {
          streakShields = (streakShields + 1).clamp(0, 2);
        }
      } else {
        if (date.isBefore(todayStart)) {
          consecutivePerfectDays = 0;
        }
      }

      // Streak & Shield consumption logic
      if (hasActivity) {
        currentStreak++;
      } else {
        if (date == todayStart) {
          continue; // Today doesn't break streak yet
        }
        if (streakShields > 0) {
          streakShields--;
          currentStreak++; // Shielded gap day
        } else {
          currentStreak = 0; // Streak broken
        }
      }
    }

    // 4. Calculate 7-day compliance (excluding today)
    int actualDaysEvaluated = 0;
    int completedInEvaluation = 0;
    for (int i = 1; i <= 7; i++) {
      final date = todayStart.subtract(Duration(days: i));
      if (date.isBefore(earliestDateStart)) continue;
      actualDaysEvaluated++;
      completedInEvaluation += dailyCompletions[date] ?? 0;
    }
    
    final totalPossibleEvaluation = totalWindows * actualDaysEvaluated;
    final last7DaysCompliance = totalPossibleEvaluation > 0
        ? (completedInEvaluation / totalPossibleEvaluation)
        : 0.0;

    if (mounted) {
      setState(() {
        _activityMap = tempMap;
        _firstDate = earliestDateStart;
        _currentStreak = currentStreak;
        _maxConsecutivePerfectDays = maxConsecutivePerfectDays;
        _last7DaysCompliance = last7DaysCompliance;
        _actualDaysEvaluated = actualDaysEvaluated;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity History'),
        actions: const [
          AppBarHelpButton(screenKey: 'compliance'),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'All-Time Activity Heatmap',
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'A complete overview of your logging consistency since your first day.',
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                _buildFullHeatmap(textTheme, colorScheme),
                _buildMilestonesSection(textTheme, colorScheme),
              ],
            ),
    );
  }

  Widget _buildMilestonesSection(TextTheme textTheme, ColorScheme colorScheme) {
    final milestones = [
      (
        title: '3-Day Bronze Spark',
        emoji: '⚡',
        desc: 'Log at least once a day for 3 consecutive days to build a tracking habit.',
        color: Colors.orange.shade400,
        isUnlocked: _currentStreak >= 3,
        progress: (_currentStreak / 3).clamp(0.0, 1.0),
        progressText: '$_currentStreak/3d',
      ),
      (
        title: '3-Day Perfect Sync',
        emoji: '🎯',
        desc: 'Complete all scheduled daily check-in sessions for 3 consecutive days.',
        color: Colors.teal.shade400,
        isUnlocked: _maxConsecutivePerfectDays >= 3,
        progress: (_maxConsecutivePerfectDays / 3).clamp(0.0, 1.0),
        progressText: '$_maxConsecutivePerfectDays/3d',
      ),
      (
        title: '7-Day Silver Flame',
        emoji: '🔥',
        desc: 'Log at least once a day for 7 consecutive days to capture baseline patterns.',
        color: Colors.blueGrey.shade300,
        isUnlocked: _currentStreak >= 7,
        progress: (_currentStreak / 7).clamp(0.0, 1.0),
        progressText: '$_currentStreak/7d',
      ),
      (
        title: '7-Day High Consistency',
        emoji: '📈',
        desc: 'Keep check-in compliance above 80% over a 7-day period for highly reliable trends.',
        color: Colors.cyan.shade400,
        isUnlocked: _last7DaysCompliance >= 0.8 && _actualDaysEvaluated >= 3,
        progress: _actualDaysEvaluated < 3 ? 0.0 : (_last7DaysCompliance / 0.8).clamp(0.0, 1.0),
        progressText: _actualDaysEvaluated < 3 ? 'Waiting for 3d of data' : '${(_last7DaysCompliance * 100).toStringAsFixed(0)}%/80%',
      ),
      (
        title: '14-Day Golden Beacon',
        emoji: '✨',
        desc: 'Log at least once a day for 14 consecutive days for a strong data baseline.',
        color: Colors.amber.shade600,
        isUnlocked: _currentStreak >= 14,
        progress: (_currentStreak / 14).clamp(0.0, 1.0),
        progressText: '$_currentStreak/14d',
      ),
      (
        title: '30-Day Master Beacon',
        emoji: '👑',
        desc: 'Log at least once a day for 30 consecutive days for comprehensive clinical insights.',
        color: Colors.purple.shade400,
        isUnlocked: _currentStreak >= 30,
        progress: (_currentStreak / 30).clamp(0.0, 1.0),
        progressText: '$_currentStreak/30d',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text(
          'Achievements & Milestones',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Maintain streaks and keep check-in compliance high to unlock validation rewards.',
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        ...milestones.map((m) {
          final badgeColor = m.isUnlocked ? m.color : colorScheme.onSurfaceVariant.withAlpha(50);

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 0,
            color: m.isUnlocked 
                ? colorScheme.surfaceContainerHighest.withAlpha(150)
                : colorScheme.surfaceContainerHighest.withAlpha(65),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: m.isUnlocked 
                    ? m.color.withAlpha(120) 
                    : colorScheme.outlineVariant.withAlpha(50),
                width: m.isUnlocked ? 1.5 : 1.0,
              ),
            ),
            child: InkWell(
              onTap: m.isUnlocked
                  ? () {
                      final overlay = ConfettiOverlay.of(context);
                      if (overlay != null) {
                        overlay.celebrate();
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🎉 Celebration burst for the ${m.title}!'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: colorScheme.primary,
                          ),
                        );
                      }
                    }
                  : null,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: badgeColor.withAlpha(m.isUnlocked ? 35 : 15),
                        shape: BoxShape.circle,
                        border: m.isUnlocked 
                            ? Border.all(color: m.color.withAlpha(100), width: 1)
                            : null,
                      ),
                      child: Text(
                        m.emoji,
                        style: TextStyle(
                          fontSize: 28,
                          color: m.isUnlocked ? null : Colors.grey.withAlpha(150),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  m.title,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: m.isUnlocked ? colorScheme.onSurface : colorScheme.outline,
                                  ),
                                ),
                              ),
                              if (m.isUnlocked)
                                Icon(Icons.stars_rounded, size: 20, color: m.color)
                              else
                                Text(
                                  m.progressText,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.outline,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            m.desc,
                            style: textTheme.bodySmall?.copyWith(
                              color: m.isUnlocked ? colorScheme.onSurfaceVariant : colorScheme.outline,
                              height: 1.4,
                            ),
                          ),
                          if (!m.isUnlocked) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: m.progress,
                                minHeight: 6,
                                backgroundColor: colorScheme.surfaceContainerHighest.withAlpha(100),
                                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary.withAlpha(120)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFullHeatmap(TextTheme textTheme, ColorScheme colorScheme) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final daysTotal = today.difference(_firstDate).inDays + 1;
    final displayDays = daysTotal < 90 ? 90 : daysTotal; // Show at least 90 days

    // Generate list of dates from oldest to today
    final dates = List.generate(displayDays, (index) {
      return today.subtract(Duration(days: displayDays - 1 - index));
    });

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withAlpha(150),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: dates.map((date) {
                final count = _activityMap[date] ?? 0;
                
                Color boxColor;
                Border? border;
                
                if (count == 0) {
                  boxColor = colorScheme.surfaceContainerHighest.withAlpha(80);
                  border = Border.all(color: colorScheme.outlineVariant.withAlpha(150), width: 1);
                } else if (count < 3) {
                  boxColor = colorScheme.primary.withAlpha(100);
                } else if (count < 6) {
                  boxColor = colorScheme.primary.withAlpha(180);
                } else {
                  boxColor = colorScheme.primary;
                }

                return GestureDetector(
                  onTap: () => _showDayReflection(date),
                  child: Tooltip(
                    message: '${date.month}/${date.day}/${date.year}: $count logs (Tap to reflect)',
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: boxColor,
                        border: border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Less', style: textTheme.bodySmall),
                const SizedBox(width: 8),
                _LegendBox(color: colorScheme.surfaceContainerHighest.withAlpha(80), hasBorder: true),
                const SizedBox(width: 4),
                _LegendBox(color: colorScheme.primary.withAlpha(100)),
                const SizedBox(width: 4),
                _LegendBox(color: colorScheme.primary.withAlpha(180)),
                const SizedBox(width: 4),
                _LegendBox(color: colorScheme.primary),
                const SizedBox(width: 8),
                Text('More', style: textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDayReflection(DateTime date) async {
    final eventRepo = context.read<EventRepository>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final events = await eventRepo.getEventsInDateRange(dayStart, dayEnd);
    final dayEvents = events.where((e) =>
      e.category != EventCategory.meta &&
      e.triggerSource != TriggerSource.system &&
      e.timestamp.year == date.year &&
      e.timestamp.month == date.month &&
      e.timestamp.day == date.day
    ).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Reflection for ${date.month}/${date.day}/${date.year}',
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (dayEvents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_off_rounded, size: 48, color: colorScheme.outline.withAlpha(100)),
                        const SizedBox(height: 12),
                        Text(
                          'No entries logged on this day.',
                          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: dayEvents.map((e) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withAlpha(20),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getCategoryIcon(e.category),
                              color: colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            e.label.replaceAll('_', ' ').toUpperCase(),
                            style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Logged at ${e.timestamp.hour.toString().padLeft(2, '0')}:${e.timestamp.minute.toString().padLeft(2, '0')}',
                            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatValue(e.value),
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(EventCategory cat) {
    switch (cat) {
      case EventCategory.mood:
        return Icons.emoji_emotions_rounded;
      case EventCategory.behavior:
        return Icons.directions_run_rounded;
      case EventCategory.productivity:
        return Icons.work_rounded;
      case EventCategory.biological:
        return Icons.health_and_safety_rounded;
      case EventCategory.social:
        return Icons.people_rounded;
      case EventCategory.nutrition:
        return Icons.restaurant_rounded;
      default:
        return Icons.bookmark_rounded;
    }
  }

  String _formatValue(String val) {
    if (val == 'true') return 'Yes';
    if (val == 'false') return 'No';
    final parsed = double.tryParse(val);
    if (parsed != null) {
      if (parsed == parsed.toInt()) {
        return parsed.toInt().toString();
      }
      return parsed.toStringAsFixed(1);
    }
    return val;
  }
}

class _LegendBox extends StatelessWidget {
  final Color color;
  final bool hasBorder;

  const _LegendBox({required this.color, this.hasBorder = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        border: hasBorder ? Border.all(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(150), width: 1) : null,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
