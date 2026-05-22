import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/enums.dart';
import '../../data/repositories/event_repository.dart';
import '../../services/metric_service.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  bool _isLoading = true;
  Map<DateTime, int> _activityMap = {};
  DateTime _firstDate = DateTime.now();

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

    if (mounted) {
      setState(() {
        _activityMap = tempMap;
        _firstDate = earliest ?? DateTime.now().subtract(const Duration(days: 30));
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
              ],
            ),
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

                return Tooltip(
                  message: '${date.month}/${date.day}/${date.year}: $count logs',
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: boxColor,
                      border: border,
                      borderRadius: BorderRadius.circular(3),
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
