import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:drift/drift.dart' hide Column;

import '../../data/database/app_database.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/models/enums.dart';
import '../../services/metric_service.dart';
import '../widgets/metric_input_card.dart';
import '../widgets/help_button.dart';


/// Screen showing all raw event data grouped by session and date.
///
/// Users can see their data in context (e.g. all metrics from one check-in)
/// and delete individual entries or entire sessions.
class RawDataScreen extends StatefulWidget {
  const RawDataScreen({super.key});

  @override
  State<RawDataScreen> createState() => _RawDataScreenState();
}

class _RawDataScreenState extends State<RawDataScreen> {
  final TextEditingController _searchController = TextEditingController();
  EventCategory? _selectedCategory;
  bool _isSearching = false;
  Stream<List<Event>>? _eventsStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _eventsStream ??= context.read<EventRepository>().watchAllEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: StreamBuilder<List<Event>>(
        stream: _eventsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var events = snapshot.data ?? [];
          
          // Apply Filters
          if (_searchController.text.isNotEmpty) {
            final query = _searchController.text.toLowerCase();
            events = events.where((e) {
              final labelMatch = e.label.toLowerCase().contains(query);
              final cleanLabelMatch = _getDisplayLabel(context, e).toLowerCase().contains(query);
              final valueMatch = e.value.toLowerCase().contains(query);
              return labelMatch || cleanLabelMatch || valueMatch;
            }).toList();
          }

          if (_selectedCategory != null) {
            events = events.where((e) => e.category == _selectedCategory).toList();
          }

          if (events.isEmpty) {
            return _buildEmptyState(colorScheme, textTheme, isFiltered: _searchController.text.isNotEmpty || _selectedCategory != null);
          }

          final metricService = context.watch<MetricService>();
          final windows = metricService.allWindows;
          final dayGroups = _groupEvents(events, windows);

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar.large(
                title: _isSearching 
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search labels or values...',
                        border: InputBorder.none,
                        hintStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      style: textTheme.bodyLarge,
                      onChanged: (_) => setState(() {}),
                    )
                  : const Text('Detailed Records'),
                centerTitle: !_isSearching,
                backgroundColor: Colors.transparent,
                scrolledUnderElevation: 0,
                actions: [
                  IconButton(
                    icon: Icon(_isSearching ? Icons.close : Icons.search),
                    onPressed: () {
                      setState(() {
                        if (_isSearching) {
                          _searchController.clear();
                        }
                        _isSearching = !_isSearching;
                      });
                    },
                  ),
                  const AppBarHelpButton(screenKey: 'raw_data'),
                ],
              ),
              SliverToBoxAdapter(
                child: _buildFilterChips(colorScheme),
              ),
              ...dayGroups.map((group) => _DaySection(group: group)),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips(ColorScheme colorScheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: EventCategory.values.where((c) => c != EventCategory.meta).map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category.name[0].toUpperCase() + category.name.substring(1)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected ? category : null;
                });
              },
              selectedColor: colorScheme.primaryContainer,
              checkmarkColor: colorScheme.onPrimaryContainer,
              labelStyle: TextStyle(
                color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme, {bool isFiltered = false}) {
    return Scaffold(
      appBar: isFiltered ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _searchController.clear();
              _selectedCategory = null;
              _isSearching = false;
            });
          },
        ),
      ) : null,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFiltered ? Icons.search_off_rounded : Icons.dataset_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered ? 'No matches found' : 'No data recorded yet',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (isFiltered) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _selectedCategory = null;
                  });
                },
                child: const Text('Clear all filters'),
              ),
            ],
          ],
        ),
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

String _getDisplayLabel(BuildContext context, Event event) {
  final metricService = context.read<MetricService>();
  final metricDef = metricService.allMetrics
      .where((m) => m.id == event.label || m.label == event.label)
      .firstOrNull;
  if (metricDef != null) {
    return metricDef.label;
  }

  // Weather Location & Passive Metrics
  if (event.label == 'core_weather_location') {
    return 'Weather Location';
  }
  if (event.label == 'core_weather_rain') return 'Rain (Passive)';
  if (event.label == 'core_weather_sun') return 'Sun (Passive)';
  if (event.label == 'core_weather_wind') return 'Wind (Passive)';

  // Sleep
  if (event.label == 'sleep_duration_hours') return 'Sleep Duration';
  if (event.label == 'sleep_bedtime') return 'Sleep Bedtime';
  if (event.label == 'sleep_wakeup') return 'Sleep Wakeup';
  if (event.label == 'sleep_midpoint') return 'Sleep Midpoint';

  // Steps
  if (event.label == 'step_count') return 'Step Count';
  if (event.label == 'step_segment') return 'Step Segment';

  // App Usage
  if (event.label == 'total_screen_time') return 'Total Screen Time';
  if (event.label.startsWith('category_time:')) {
    final cat = event.label.split(':').last;
    return '${cat[0].toUpperCase()}${cat.substring(1)} Screen Time';
  }
  if (event.label.startsWith('app_time:')) {
    final pkg = event.label.split(':').last;
    final name = pkg.split('.').last;
    return '${name[0].toUpperCase()}${name.substring(1)} Screen Time';
  }
  if (event.label.startsWith('app_segment:')) {
    final pkg = event.label.split(':').last;
    final name = pkg.split('.').last;
    return '${name[0].toUpperCase()}${name.substring(1)} Usage Segment';
  }
  if (event.label.startsWith('category_segment:')) {
    final cat = event.label.split(':').last;
    return '${cat[0].toUpperCase()}${cat.substring(1)} Usage Segment';
  }
  if (event.label == 'app_usage_segment') return 'App Usage Segment';

  // Fallback to formatting
  var clean = _cleanLabel(event.label);
  if (clean.startsWith('core_')) {
    final part = clean.substring(5);
    return part
        .split('_')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
  }
  return clean;
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

  String title(BuildContext context) {
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
      if (events.any((e) => e.category == EventCategory.health)) return 'Health Data Sync';
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
    
    if (events.length == 1) return _getDisplayLabel(context, events.first);
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
            onTap: () {
              if (isMulti) {
                setState(() => _isExpanded = !_isExpanded);
              } else {
                // Using the widget method to reuse the bottom sheet UI logic
                _EventRow(event: session.events.first)._showEventDetails(context);
              }
            },
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
                          session.title(context),
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
        .map((e) => _getDisplayLabel(context, e))
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

    if (widget.session.events.isNotEmpty) {
      final label = widget.session.events.first.label;
      final valNum = double.tryParse(value);
      if (valNum != null) {
        if (label == 'sleep_bedtime' || label == 'sleep_wakeup' || label == 'sleep_midpoint') {
          double hours = valNum;
          if (hours >= 24) hours -= 24;
          final int h = hours.floor();
          final int m = ((hours - h) * 60).round();
          return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
        } else if (label == 'sleep_duration_hours') {
          return '${valNum.toStringAsFixed(1)} hrs';
        } else if (label == 'step_count' || label == 'step_segment') {
          return NumberFormat.decimalPattern().format(valNum.round());
        } else if (label == 'total_screen_time' || label.startsWith('category_time:') || label.startsWith('app_time:') || label.startsWith('app_segment:') || label.startsWith('category_segment:') || label == 'app_usage_segment') {
          if (valNum >= 60) {
            final h = valNum ~/ 60;
            final m = (valNum % 60).round();
            return '${h}h ${m}m';
          }
          return '${valNum.round()} min';
        }

        if (label == 'Mindless Scrolling' || label == 'Mindless Scrolling?') {
          return '${valNum.toInt()} min';
        } else if (label == 'Water Intake') {
          return '${valNum.toInt()} ml';
        } else if (label == 'Coffee Intake') {
          final isPlural = valNum != 1.0;
          final formatted = valNum == valNum.toInt() ? valNum.toInt().toString() : valNum.toStringAsFixed(1);
          return '$formatted cup${isPlural ? 's' : ''}';
        } else if (label == 'Alcoholic Drink') {
          final isPlural = valNum != 1.0;
          final formatted = valNum == valNum.toInt() ? valNum.toInt().toString() : valNum.toStringAsFixed(1);
          return '$formatted drink${isPlural ? 's' : ''}';
        } else if (label == 'Bathroom Visit') {
          final isPlural = valNum != 1.0;
          return '${valNum.toInt()} visit${isPlural ? 's' : ''}';
        } else if (label.startsWith('Bachelor Work')) {
          final isPlural = valNum != 1.0;
          return '${valNum.toInt()} block${isPlural ? 's' : ''}';
        }
      }
    }

    if (value.length > 15) return '${value.substring(0, 12)}...';
    return value;
  }

  void _deleteSession(BuildContext context) async {
    final eventRepo = context.read<EventRepository>();
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
        await eventRepo.deleteEvent(event.id);
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
                _getDisplayLabel(context, event),
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

    final label = event.label;
    final valNum = double.tryParse(value);
    if (valNum != null) {
      if (label == 'sleep_bedtime' || label == 'sleep_wakeup' || label == 'sleep_midpoint') {
        double hours = valNum;
        if (hours >= 24) hours -= 24;
        final int h = hours.floor();
        final int m = ((hours - h) * 60).round();
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      } else if (label == 'sleep_duration_hours') {
        return '${valNum.toStringAsFixed(1)} hrs';
      } else if (label == 'step_count' || label == 'step_segment') {
        return NumberFormat.decimalPattern().format(valNum.round());
      } else if (label == 'total_screen_time' || label.startsWith('category_time:') || label.startsWith('app_time:') || label.startsWith('app_segment:') || label.startsWith('category_segment:') || label == 'app_usage_segment') {
        if (valNum >= 60) {
          final h = valNum ~/ 60;
          final m = (valNum % 60).round();
          return '${h}h ${m}m';
        }
        return '${valNum.round()} min';
      }

      if (label == 'Mindless Scrolling' || label == 'Mindless Scrolling?') {
        return '${valNum.toInt()} min';
      } else if (label == 'Water Intake') {
        return '${valNum.toInt()} ml';
      } else if (label == 'Coffee Intake') {
        final isPlural = valNum != 1.0;
        final formatted = valNum == valNum.toInt() ? valNum.toInt().toString() : valNum.toStringAsFixed(1);
        return '$formatted cup${isPlural ? 's' : ''}';
      } else if (label == 'Alcoholic Drink') {
        final isPlural = valNum != 1.0;
        final formatted = valNum == valNum.toInt() ? valNum.toInt().toString() : valNum.toStringAsFixed(1);
        return '$formatted drink${isPlural ? 's' : ''}';
      } else if (label == 'Bathroom Visit') {
        final isPlural = valNum != 1.0;
        return '${valNum.toInt()} visit${isPlural ? 's' : ''}';
      } else if (label.startsWith('Bachelor Work')) {
        final isPlural = valNum != 1.0;
        return '${valNum.toInt()} block${isPlural ? 's' : ''}';
      }
    }

    if (value.length > 15) return '${value.substring(0, 12)}...';
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
      case EventCategory.biological:
        icon = Icons.water_drop_outlined;
        color = colorScheme.primary;
        break;
      case EventCategory.weather:
        icon = Icons.cloud_outlined;
        color = colorScheme.secondary;
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
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
                        _getDisplayLabel(context, event),
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        event.category.name.toUpperCase(),
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Container(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                  _DetailRow(label: 'Recorded Value', value: event.value),
                  const SizedBox(height: 12),
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
              child: FilledButton.icon(
                onPressed: () {
                  _showEditDialog(context, event);
                },
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit Entry'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                   final eventRepo = context.read<EventRepository>();
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
                      await eventRepo.deleteEvent(event.id);
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
    ),
  );
}

  void _showEditDialog(BuildContext context, Event event) {
    final metricService = context.read<MetricService>();
    final metricDef = metricService.allMetrics.where((m) => m.id == event.label || m.label == event.label).firstOrNull;
    
    String newValue = event.value;
    DateTime newTimestamp = event.timestamp;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final timeStr = DateFormat('yyyy-MM-dd HH:mm').format(newTimestamp);

          return AlertDialog(
            title: const Text('Edit Entry'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (metricDef != null)
                      MetricInputCard(
                        metric: metricDef,
                        initialValue: event.value,
                        onChanged: (val) => setState(() => newValue = val),
                      )
                    else
                      TextFormField(
                        initialValue: newValue,
                        onChanged: (val) => setState(() => newValue = val),
                        decoration: const InputDecoration(labelText: 'New Value'),
                      ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time_rounded),
                      title: const Text('Occurrence Time'),
                      subtitle: Text(timeStr),
                      trailing: const Icon(Icons.edit_rounded, size: 16),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: newTimestamp,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null && context.mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(newTimestamp),
                          );
                          if (time != null && context.mounted) {
                            setState(() {
                              newTimestamp = DateTime(
                                date.year, date.month, date.day, time.hour, time.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (newValue == event.value && newTimestamp.isAtSameMomentAs(event.timestamp)) {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                    return;
                  }

                  final eventRepo = ctx.read<EventRepository>();
                  
                  // Update the actual event
                  await eventRepo.updateEvent(event.id, EventsCompanion(
                    value: Value(newValue),
                    timestamp: Value(newTimestamp),
                  ));
                  
                  // Insert a meta event tracking the change
                  await eventRepo.insertEvent(EventsCompanion.insert(
                    category: EventCategory.meta,
                    label: 'data_edited',
                    value: '${event.label}: ${event.value} -> $newValue, time ${event.timestamp} -> $newTimestamp',
                    triggerSource: TriggerSource.manual,
                    interactionType: InteractionType.click,
                    sessionId: Value(event.sessionId),
                    timestamp: Value(DateTime.now()),
                  ));

                  if (ctx.mounted) {
                    Navigator.pop(ctx); // Close dialog
                    Navigator.pop(context); // Close bottom sheet
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
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

    final isLong = value.length > 20;

    if (isLong) {
      return SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied $label to clipboard'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(24, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  tooltip: 'Copy to clipboard',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: (mono
                      ? textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        )
                      : textTheme.bodyLarge)
                  ?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      );
    }

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
