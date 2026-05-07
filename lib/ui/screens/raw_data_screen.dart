import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import '../../services/metric_service.dart';

/// Screen showing all raw event data grouped by session and date.
///
/// Users can see their data in context (e.g. all metrics from one check-in)
/// and delete individual entries or entire sessions.
class RawDataScreen extends StatelessWidget {
  const RawDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: StreamBuilder<List<Event>>(
        stream: db.watchAllEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final events = snapshot.data;
          if (events == null || events.isEmpty) {
            return _buildEmptyState(colorScheme, textTheme);
          }

          final metricService = context.watch<MetricService>();
          final windows = metricService.allWindows;
          final dayGroups = _groupEvents(events, windows);

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar.large(
                title: const Text('Detailed Records'),
                centerTitle: true,
                backgroundColor: colorScheme.surface,
                scrolledUnderElevation: 0,
              ),
              ...dayGroups.map((group) => _DaySection(group: group)),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dataset_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            'No data recorded yet',
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  List<_DayGroup> _groupEvents(List<Event> events, List<TrackingWindow> windows) {
    final dayMap = <DateTime, List<Event>>{};
    for (final event in events) {
      final day = DateTime(event.timestamp.year, event.timestamp.month, event.timestamp.day);
      dayMap.putIfAbsent(day, () => []).add(event);
    }

    final sortedDays = dayMap.keys.toList()..sort((a, b) => b.compareTo(a));
    return sortedDays.map((day) {
      final dayEvents = dayMap[day]!..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final sessionGroups = <_SessionGroup>[];
      
      final sessionMap = <String, List<Event>>{};
      final soloEvents = <Event>[];

      for (final event in dayEvents) {
        if (event.sessionId != null) {
          sessionMap.putIfAbsent(event.sessionId!, () => []).add(event);
        } else {
          soloEvents.add(event);
        }
      }

      // Add session groups
      sessionMap.forEach((id, evs) {
        evs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        String? windowLabel;
        if (evs.any((e) => e.label == 'SessionCompleted')) {
          final meta = evs.firstWhere((e) => e.label == 'SessionCompleted');
          final windowId = meta.value;
          try {
            windowLabel = windows.firstWhere((w) => w.id == windowId).label;
          } catch (_) {}
        }

        sessionGroups.add(_SessionGroup(id: id, events: evs, windowLabel: windowLabel));
      });

      // Add solo events as mini-sessions
      for (final event in soloEvents) {
        sessionGroups.add(_SessionGroup(id: null, events: [event]));
      }

      // Sort sessions by their latest event timestamp
      sessionGroups.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return _DayGroup(date: day, sessions: sessionGroups);
    }).toList();
  }
}

String _cleanLabel(String label) {
  if (label.startsWith('app_time:')) {
    final pkg = label.split(':').last;
    return pkg.split('.').last;
  }
  return label;
}

class _DayGroup {
  final DateTime date;
  final List<_SessionGroup> sessions;
  _DayGroup({required this.date, required this.sessions});
}

class _SessionGroup {
  final String? id;
  final List<Event> events;
  final String? windowLabel;

  _SessionGroup({required this.id, required this.events, this.windowLabel});

  DateTime get timestamp => events.first.timestamp;

  String get title {
    if (events.any((e) => e.label == 'SessionCompleted')) {
      final meta = events.firstWhere((e) => e.label == 'SessionCompleted');
      final windowId = meta.value;
      if (windowId == 'anytime') return 'Quick Check-in';
      if (windowLabel != null) return '$windowLabel Check-in';
      
      // Fallback if label not found but it's not a UUID (unlikely with current schema but safe)
      if (windowId.length < 20) {
        return '${windowId[0].toUpperCase()}${windowId.substring(1)} Check-in';
      }
      return 'Scheduled Check-in';
    }
    
    final source = events.first.triggerSource;
    if (source == TriggerSource.system) {
      if (events.any((e) => e.category == EventCategory.appUsage)) return 'App Usage Sync';
      return 'Passive Data Sync';
    }
    if (source == TriggerSource.notification) {
      final first = events.first;
      final interaction = first.interactionType;
      final label = first.label.replaceFirst('Notification: ', '');
      var interactionStr = interaction.name[0].toUpperCase() + interaction.name.substring(1);
      
      // If it's a snooze, append the value (e.g. "+15m" or "Until 18:30")
      if (interaction == InteractionType.snooze && first.value.isNotEmpty) {
        interactionStr += ' (${first.value})';
      }
      
      return '$label: $interactionStr';
    }
    
    if (events.length == 1) return _cleanLabel(events.first.label);
    return 'Manual Session';
  }

  IconData get icon {
    if (events.any((e) => e.label == 'SessionCompleted')) return Icons.task_alt_rounded;
    final source = events.first.triggerSource;
    if (source == TriggerSource.system) return Icons.sync_rounded;
    if (source == TriggerSource.notification) return Icons.notification_important_rounded;
    return Icons.edit_note_rounded;
  }
}

class _DaySection extends StatelessWidget {
  final _DayGroup group;
  const _DaySection({required this.group});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final today = DateTime.now();
    final isToday = group.date.year == today.year && 
                   group.date.month == today.month && 
                   group.date.day == today.day;
    
    final dateString = isToday ? 'Today' : DateFormat('EEEE, MMM dd').format(group.date);

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Text(
              dateString.toUpperCase(),
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _SessionCard(session: group.sessions[index]),
              childCount: group.sessions.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionCard extends StatefulWidget {
  final _SessionGroup session;
  const _SessionCard({required this.session});

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final session = widget.session;

    final isMulti = session.events.length > 1;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.surfaceContainerHighest.withAlpha(150),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(100)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: isMulti ? () => setState(() => _isExpanded = !_isExpanded) : null,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(session.icon, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _getSessionSummary(),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!isMulti)
                    Text(
                      _formatValue(session.events.first.value),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  if (isMulti)
                    Icon(
                      _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
          if (_isExpanded && isMulti)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(height: 1, indent: 8, endIndent: 8),
                  const SizedBox(height: 8),
                  ...session.events.map((event) => _EventRow(event: event)),
                  if (session.id != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => _deleteSession(context),
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                        label: const Text('Delete Session'),
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getSessionSummary() {
    final session = widget.session;
    final timeString = DateFormat('HH:mm').format(session.timestamp);
    
    if (session.events.length == 1) {
      return '$timeString • ${session.events.first.category.name.toUpperCase()}';
    }

    final labels = session.events
        .where((e) => e.label != 'SessionCompleted')
        .map((e) => _cleanLabel(e.label))
        .take(2)
        .toList();
    
    String summary = labels.join(', ');
    if (session.events.length > 2) {
      summary += ' +${session.events.length - 2} more';
    }
    
    return '$timeString • $summary';
  }

  String _formatValue(String value) {
    if (value == 'true') return 'Yes';
    if (value == 'false') return 'No';
    if (value.length > 15) return '${value.substring(0, 12)}...';
    return value;
  }

  void _deleteSession(BuildContext context) async {
    final db = context.read<AppDatabase>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session?'),
        content: Text('This will remove all ${widget.session.events.length} records from this session.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      for (final event in widget.session.events) {
        await db.deleteEvent(event.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session deleted')),
        );
      }
    }
  }
}

class _EventRow extends StatelessWidget {
  final Event event;
  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => _showEventDetails(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            _buildCategoryIcon(colorScheme),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _cleanLabel(event.label),
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _formatValue(event.value),
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatValue(String value) {
    if (value == 'true') return 'Yes';
    if (value == 'false') return 'No';
    return value;
  }

  Widget _buildCategoryIcon(ColorScheme colorScheme) {
    IconData icon;
    Color color;
    switch (event.category) {
      case EventCategory.mood:
        icon = Icons.mood_rounded;
        color = colorScheme.primary;
        break;
      case EventCategory.behavior:
        icon = Icons.check_circle_outline_rounded;
        color = colorScheme.tertiary;
        break;
      case EventCategory.health:
        icon = Icons.favorite_outline_rounded;
        color = colorScheme.error;
        break;
      case EventCategory.appUsage:
        icon = Icons.phone_android_rounded;
        color = colorScheme.secondary;
        break;
      case EventCategory.nutrition:
        icon = Icons.restaurant_rounded;
        color = colorScheme.secondary;
        break;
      case EventCategory.social:
        icon = Icons.people_alt_rounded;
        color = colorScheme.primary;
        break;
      case EventCategory.productivity:
        icon = Icons.lightbulb_outline_rounded;
        color = colorScheme.tertiary;
        break;
      case EventCategory.meta:
        icon = Icons.settings_rounded;
        color = colorScheme.onSurfaceVariant;
        break;
    }
    return Icon(icon, color: color.withAlpha(180), size: 18);
  }

  void _showEventDetails(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final timeString = DateFormat('EEEE, MMM dd yyyy • HH:mm:ss').format(event.timestamp);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildCategoryIcon(colorScheme),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.label,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        event.category.name.toUpperCase(),
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatValue(event.value),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _DetailRow(label: 'Timestamp', value: timeString),
                  const SizedBox(height: 12),
                  _DetailRow(label: 'Latency', value: '${event.latencyMs} ms'),
                  const SizedBox(height: 12),
                  _DetailRow(label: 'Trigger', value: event.triggerSource.name),
                  const SizedBox(height: 12),
                  _DetailRow(label: 'Interaction', value: event.interactionType.name),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: 'Event ID',
                    value: event.id.substring(0, 8),
                    mono: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                   final db = context.read<AppDatabase>();
                   final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Entry?'),
                        content: const Text('This action cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
                            onPressed: () => Navigator.pop(ctx, true), 
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      await db.deleteEvent(event.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete Entry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error.withAlpha(120)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _DetailRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: (mono
                    ? textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      )
                    : textTheme.bodyMedium)
                ?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
