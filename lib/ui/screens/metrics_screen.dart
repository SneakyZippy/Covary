import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/enums.dart';
import '../../data/models/metric_definition.dart';
import '../../services/metric_service.dart';
import '../widgets/metric_icon.dart';
import '../widgets/metric_dialogs.dart';

/// Screen for managing tracked metrics and their configurations.
class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  EventCategory? _filterCategory;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final metricService = context.watch<MetricService>();
    
    final allMetrics = metricService.allMetrics;
    final filteredMetrics = _filterCategory == null
        ? allMetrics
        : allMetrics.where((m) => m.category == _filterCategory).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracked Metrics'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // --- Category Filter ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<EventCategory?>(
                    segments: [
                      const ButtonSegment(
                        value: null,
                        label: Text('All'),
                        icon: Icon(Icons.all_inclusive_rounded),
                      ),
                      ...EventCategory.values
                          .where((c) => c != EventCategory.appUsage && c != EventCategory.meta)
                          .map((c) => ButtonSegment(
                                value: c,
                                label: Text(c.name.substring(0, 1).toUpperCase() + c.name.substring(1)),
                                icon: Icon(_categoryIcon(c)),
                              )),
                    ],
                    selected: {_filterCategory},
                    onSelectionChanged: (newSelection) {
                      setState(() => _filterCategory = newSelection.first);
                    },
                    showSelectedIcon: false,
                  ),
                ),
              ),
            ),

            // --- Tracked Metrics Section Header ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _filterCategory == null 
                            ? 'All Metrics' 
                            : '${_filterCategory!.name.substring(0, 1).toUpperCase()}${_filterCategory!.name.substring(1)} Metrics',
                        style: textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded),
                      tooltip: 'Bulk Actions',
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'enable_all',
                          child: Text('Enable All Tracking'),
                        ),
                        const PopupMenuItem(
                          value: 'disable_all',
                          child: Text('Disable All Tracking'),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'require_all',
                          child: Text('Make All Required'),
                        ),
                        const PopupMenuItem(
                          value: 'optional_all',
                          child: Text('Make All Optional'),
                        ),
                      ],
                      onSelected: (value) {
                        for (var m in filteredMetrics) {
                          if (value == 'enable_all' && !m.isEnabled) {
                            metricService.toggleMetric(m.id);
                          } else if (value == 'disable_all' && m.isEnabled) {
                            metricService.toggleMetric(m.id);
                          } else if (value == 'require_all' && !m.isActivityIndicator) {
                            metricService.setMetricActivityIndicator(m.id, true);
                          } else if (value == 'optional_all' && m.isActivityIndicator) {
                            metricService.setMetricActivityIndicator(m.id, false);
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => _showAddMetricBottomSheet(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add'),
                      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                  ],
                ),
              ),
            ),

            if (filteredMetrics.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.layers_clear_outlined,
                          size: 48,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filterCategory == null 
                              ? 'No metrics tracked yet.' 
                              : 'No ${_filterCategory!.name} metrics tracked.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverReorderableList(
                  itemCount: filteredMetrics.length,
                  onReorder: (oldIndex, newIndex) {
                    metricService.reorderMetrics(
                      oldIndex,
                      newIndex,
                      currentList: filteredMetrics,
                    );
                  },
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        return Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.transparent,
                          child: child,
                        );
                      },
                      child: child,
                    );
                  },
                  itemBuilder: (context, index) {
                    final metric = filteredMetrics[index];
                    return _MetricTile(
                      key: ValueKey(metric.id),
                      metric: metric,
                      index: index,
                    );
                  },
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(EventCategory category) {
    switch (category) {
      case EventCategory.mood: return Icons.mood_rounded;
      case EventCategory.behavior: return Icons.directions_run_rounded;
      case EventCategory.health: return Icons.favorite_rounded;
      case EventCategory.nutrition: return Icons.restaurant_rounded;
      case EventCategory.social: return Icons.people_rounded;
      case EventCategory.productivity: return Icons.lightbulb_rounded;
      default: return Icons.category_rounded;
    }
  }

  void _showAddMetricBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => const AddMetricSelector(),
    );
  }
}

// =============================================================================
// Metric Tile (swipe-to-delete + drag-to-reorder)
// =============================================================================

class _MetricTile extends StatelessWidget {
  final MetricDefinition metric;
  final int index;

  const _MetricTile({
    required super.key,
    required this.metric,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metricService = context.read<MetricService>();

    return Dismissible(
      key: ValueKey('dismiss_${metric.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) {
        metricService.deleteMetric(metric.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${metric.label}" removed from tracking. Past research data remains safe in the database.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline_rounded, color: colorScheme.onErrorContainer),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: metric.isEnabled ? colorScheme.surface : colorScheme.surface.withAlpha(150),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: metric.isEnabled ? colorScheme.outlineVariant : colorScheme.outlineVariant.withAlpha(100),
          ),
          boxShadow: metric.isEnabled ? [
            BoxShadow(
              color: colorScheme.shadow.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: metric.isEnabled ? colorScheme.primary.withAlpha(30) : colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: MetricIcon(
              iconName: metric.emoji, 
              size: 24,
              color: metric.isEnabled ? colorScheme.primary : colorScheme.outline,
            ),
          ),
          title: Text(
            metric.label,
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: metric.isEnabled ? colorScheme.onSurface : colorScheme.outline,
            ),
          ),
          subtitle: Row(
            children: [
              Text(
                metric.inputType.displayLabel,
                style: TextStyle(
                  color: metric.isEnabled ? colorScheme.onSurfaceVariant : colorScheme.outline, 
                  fontSize: 12,
                ),
              ),
              if (metric.isEnabled) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: metric.isActivityIndicator ? 'Activity Required' : 'Optional',
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: metric.isActivityIndicator
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
              if (metric.isEnabled && metric.windowIds.isEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Quick Log Only',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
          trailing: Switch(
            value: metric.isEnabled,
            onChanged: (_) => metricService.toggleMetric(metric.id),
          ),
          onTap: () => _showEditDialog(context),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => EditMetricDialog(metric: metric),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Metric?'),
            content: Text('Remove "${metric.label}" from your tracked metrics? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
