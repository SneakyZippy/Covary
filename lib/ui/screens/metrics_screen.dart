import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/icon_selector.dart';
import '../../data/models/enums.dart';
import '../../data/models/metric_definition.dart';
import '../../services/metric_service.dart';
import '../widgets/metric_icon.dart';

/// Screen for managing tracked metrics and their configurations.
/// Now a sub-page with category filtering.
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
                      setState(() {
                        _filterCategory = newSelection.first;
                      });
                    },
                    showSelectedIcon: false,
                  ),
                ),
              ),
            ),

            // --- Tracked Metrics Section ---
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
                    FilledButton.tonalIcon(
                      onPressed: () => _showAddMetricBottomSheet(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (filteredMetrics.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.layers_clear_outlined, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
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
                  return _CustomMetricTile(
                    key: ValueKey(metric.id),
                    metric: metric,
                    index: index,
                  );
                },
              ),
            ),

            // Bottom padding
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
      builder: (ctx) => const _AddMetricSelector(),
    );
  }
}

// =============================================================================
// Add Metric Selector Bottom Sheet
// =============================================================================

class _AddMetricSelector extends StatelessWidget {
  const _AddMetricSelector();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metricService = context.watch<MetricService>();
    final existingIds = metricService.allMetrics.map((m) => m.id).toSet();
    final existingLabels = metricService.allMetrics.map((m) => m.label.toLowerCase().trim()).toSet();
    
    final availableTemplates = MetricService.templates
        .where((t) => !existingIds.contains(t.id) && !existingLabels.contains(t.label.toLowerCase().trim()))
        .toList();

    // Group templates by category
    final Map<EventCategory, List<MetricDefinition>> categorizedTemplates = {};
    for (var t in availableTemplates) {
      categorizedTemplates.putIfAbsent(t.category, () => []).add(t);
    }

    // Sort categories for consistent UI
    final sortedCategories = categorizedTemplates.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add Metric',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add_box_rounded, color: theme.colorScheme.primary),
                ),
                title: const Text('Create Custom Metric'),
                subtitle: const Text('Build from scratch'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (ctx) => const _AddCustomMetricDialog(),
                  );
                },
              ),
              const Divider(height: 32),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: sortedCategories.length,
                  itemBuilder: (context, index) {
                    final category = sortedCategories[index];
                    final templates = categorizedTemplates[category]!;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Text(
                            category.name.substring(0, 1).toUpperCase() + category.name.substring(1),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...templates.map((template) => _buildTemplateTile(context, template)),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTemplateTile(BuildContext context, MetricDefinition template) {
    return ListTile(
      leading: MetricIcon(iconName: template.emoji, size: 28),
      title: Text(template.label),
      subtitle: Text(_inputTypeLabel(template.inputType)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (ctx) => _AddCustomMetricDialog(template: template),
        );
      },
    );
  }

  String _inputTypeLabel(MetricInputType type) {
    switch (type) {
      case MetricInputType.yesNo:
        return 'Yes / No';
      case MetricInputType.scale1to5:
        return 'Scale 1–5';
      case MetricInputType.scale1to10:
        return 'Scale 1–10';
      case MetricInputType.counter:
        return 'Counter (Tap)';
    }
  }
}

// =============================================================================
// Custom Metric Tile (swipe-to-delete)
// =============================================================================

class _CustomMetricTile extends StatelessWidget {
  final MetricDefinition metric;
  final int index;

  const _CustomMetricTile({
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
      onDismissed: (_) => metricService.deleteCustomMetric(metric.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: colorScheme.onErrorContainer,
        ),
      ),
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 8, right: 20),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              MetricIcon(
                iconName: metric.emoji,
                size: 24,
              ),
            ],
          ),
          title: Text(
            metric.label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: Row(
            children: [
              Text(
                _inputTypeLabel(metric.inputType),
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          trailing: Switch(
            value: metric.isEnabled,
            onChanged: (_) => metricService.toggleMetric(metric.id),
          ),
          onTap: () => _showEditMetricDialog(context, metric),
        ),
      ),
    );
  }

  void _showEditMetricDialog(BuildContext context, MetricDefinition metric) {
    showDialog(
      context: context,
      builder: (ctx) => _EditMetricDialog(metric: metric),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Custom Metric?'),
            content: Text('Remove "${metric.label}" permanently?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _inputTypeLabel(MetricInputType type) {
    switch (type) {
      case MetricInputType.yesNo:
        return 'Yes / No';
      case MetricInputType.scale1to5:
        return 'Scale 1–5';
      case MetricInputType.scale1to10:
        return 'Scale 1–10';
      case MetricInputType.counter:
        return 'Counter (Tap)';
    }
  }
}

// =============================================================================
// Edit Metric Dialog
// =============================================================================

class _EditMetricDialog extends StatefulWidget {
  final MetricDefinition metric;

  const _EditMetricDialog({required this.metric});

  @override
  State<_EditMetricDialog> createState() => _EditMetricDialogState();
}

class _EditMetricDialogState extends State<_EditMetricDialog> {
  final _labelController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late EventCategory _selectedCategory;
  late MetricInputType _selectedInputType;
  late List<String> _selectedWindowIds;
  late String? _selectedEmoji;
  /// null = auto (derived from inputType), true/false = user override.
  bool? _retroReliableOverride;

  @override
  void initState() {
    super.initState();
    _labelController.text = widget.metric.label;

    final allowedCategories = EventCategory.values
        .where((c) => c != EventCategory.appUsage && c != EventCategory.meta)
        .toList();

    if (allowedCategories.contains(widget.metric.category)) {
      _selectedCategory = widget.metric.category;
    } else {
      _selectedCategory = EventCategory.behavior;
    }

    _selectedInputType = widget.metric.inputType;
    _selectedWindowIds = List.from(widget.metric.windowIds);
    _selectedEmoji = widget.metric.emoji;
    _retroReliableOverride = widget.metric.retroReliableOverride;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  /// The effective reliability value shown in the UI.
  bool get _effectiveReliable =>
      _retroReliableOverride ??
      (_selectedInputType == MetricInputType.yesNo ||
          _selectedInputType == MetricInputType.counter);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final metricService = context.read<MetricService>();
    await metricService.updateCustomMetric(
      id: widget.metric.id,
      label: _labelController.text.trim(),
      category: _selectedCategory,
      inputType: _selectedInputType,
      windowIds: _selectedWindowIds,
      emoji: _selectedEmoji,
      retroReliableOverride: _retroReliableOverride,
    );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Metric'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _labelController,
                decoration: InputDecoration(
                  labelText: 'Metric Name',
                  prefixIcon: const Icon(Icons.edit_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              IconSelector(
                selectedIcon: _selectedEmoji,
                onSelected: (icon) => setState(() => _selectedEmoji = icon),
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<EventCategory>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: EventCategory.values
                    .where((c) => c != EventCategory.appUsage && c != EventCategory.meta)
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.name.substring(0, 1).toUpperCase() +
                              c.name.substring(1)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedCategory = value);
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<MetricInputType>(
                initialValue: _selectedInputType,
                decoration: InputDecoration(
                  labelText: 'Input Type',
                  prefixIcon: const Icon(Icons.tune_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: MetricInputType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(_inputTypeLabel(t)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedInputType = value);
                },
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 8),
              Text(
                'Tracking Windows',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              _WindowCheckboxList(
                selectedIds: _selectedWindowIds,
                onChanged: (ids) => setState(() => _selectedWindowIds = ids),
              ),
              const SizedBox(height: 16),
              _ReliabilityToggle(
                effectiveValue: _effectiveReliable,
                isOverridden: _retroReliableOverride != null,
                onChanged: (newValue) => setState(() {
                  final autoValue = _selectedInputType == MetricInputType.yesNo ||
                      _selectedInputType == MetricInputType.counter;
                  _retroReliableOverride = newValue == autoValue ? null : newValue;
                }),
                onReset: () => setState(() => _retroReliableOverride = null),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Save'),
        ),
      ],
    );
  }

  String _inputTypeLabel(MetricInputType type) {
    switch (type) {
      case MetricInputType.yesNo:
        return 'Yes / No';
      case MetricInputType.scale1to5:
        return 'Scale 1–5';
      case MetricInputType.scale1to10:
        return 'Scale 1–10';
      case MetricInputType.counter:
        return 'Counter (Tap)';
    }
  }
}

// =============================================================================
// Add Custom Metric Dialog
// =============================================================================

class _AddCustomMetricDialog extends StatefulWidget {
  final MetricDefinition? template;
  const _AddCustomMetricDialog({this.template});

  @override
  State<_AddCustomMetricDialog> createState() => _AddCustomMetricDialogState();
}

class _AddCustomMetricDialogState extends State<_AddCustomMetricDialog> {
  final _labelController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  EventCategory _selectedCategory = EventCategory.behavior;
  MetricInputType _selectedInputType = MetricInputType.yesNo;
  List<String> _selectedWindowIds = ['anytime'];
  String _selectedEmoji = 'bolt';
  /// null = auto (derived from inputType), true/false = user override.
  bool? _retroReliableOverride;

  late final DateTime _dialogOpenedAt;

  @override
  void initState() {
    super.initState();
    _dialogOpenedAt = DateTime.now();
    
    if (widget.template != null) {
      _labelController.text = widget.template!.label;
      _selectedCategory = widget.template!.category;
      _selectedInputType = widget.template!.inputType;
      _selectedEmoji = widget.template!.emoji ?? 'bolt';
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  int _calculateLatencyMs() {
    return DateTime.now().difference(_dialogOpenedAt).inMilliseconds;
  }

  /// The effective reliability value shown in the UI.
  bool get _effectiveReliable =>
      _retroReliableOverride ??
      (_selectedInputType == MetricInputType.yesNo ||
          _selectedInputType == MetricInputType.counter);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final metricService = context.read<MetricService>();
    await metricService.addCustomMetric(
      id: widget.template?.id,
      label: _labelController.text.trim(),
      category: _selectedCategory,
      inputType: _selectedInputType,
      windowIds: _selectedWindowIds,
      emoji: _selectedEmoji,
      retroReliableOverride: _retroReliableOverride,
      latencyMs: _calculateLatencyMs(),
    );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Custom Metric'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _labelController,
                decoration: InputDecoration(
                  labelText: 'Metric Name',
                  hintText: 'e.g. Reading, Meditation',
                  prefixIcon: const Icon(Icons.edit_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  if (value.trim().length > 50) {
                    return 'Name must be 50 characters or less';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              IconSelector(
                selectedIcon: _selectedEmoji,
                onSelected: (icon) => setState(() => _selectedEmoji = icon),
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<EventCategory>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: EventCategory.values
                    .where((c) => c != EventCategory.appUsage && c != EventCategory.meta)
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.name.substring(0, 1).toUpperCase() + c.name.substring(1)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedCategory = value);
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<MetricInputType>(
                initialValue: _selectedInputType,
                decoration: InputDecoration(
                  labelText: 'Input Type',
                  prefixIcon: const Icon(Icons.tune_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: MetricInputType.values.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Text(_inputTypeLabel(t)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedInputType = value);
                },
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 8),
              Text(
                'Tracking Windows',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              _WindowCheckboxList(
                selectedIds: _selectedWindowIds,
                onChanged: (ids) => setState(() => _selectedWindowIds = ids),
              ),
              const SizedBox(height: 16),
              _ReliabilityToggle(
                effectiveValue: _effectiveReliable,
                isOverridden: _retroReliableOverride != null,
                onChanged: (newValue) => setState(() {
                  final autoValue = _selectedInputType == MetricInputType.yesNo ||
                      _selectedInputType == MetricInputType.counter;
                  _retroReliableOverride = newValue == autoValue ? null : newValue;
                }),
                onReset: () => setState(() => _retroReliableOverride = null),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add'),
        ),
      ],
    );
  }

  String _inputTypeLabel(MetricInputType type) {
    switch (type) {
      case MetricInputType.yesNo:
        return 'Yes / No';
      case MetricInputType.scale1to5:
        return 'Scale 1–5';
      case MetricInputType.scale1to10:
        return 'Scale 1–10';
      case MetricInputType.counter:
        return 'Counter (Tap to Log)';
    }
  }
}

class _WindowCheckboxList extends StatelessWidget {
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  const _WindowCheckboxList({
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final metricService = context.watch<MetricService>();
    final windows = metricService.allWindows;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        CheckboxListTile(
          title: const Text('Show on Home Screen'),
          subtitle: const Text('Add as a "Quick Track" button on home'),
          value: selectedIds.contains('homescreen'),
          activeColor: colorScheme.secondary, // Different color for home screen
          contentPadding: EdgeInsets.zero,
          onChanged: (checked) {
            final newIds = List<String>.from(selectedIds);
            if (checked == true) {
              newIds.add('homescreen');
            } else {
              newIds.remove('homescreen');
            }
            onChanged(newIds);
          },
        ),
        CheckboxListTile(
          title: const Text('Anytime'),
          subtitle: const Text('Include in every guided session'),
          value: selectedIds.contains('anytime'),
          activeColor: colorScheme.primary,
          contentPadding: EdgeInsets.zero,
          onChanged: (checked) {
            final newIds = List<String>.from(selectedIds);
            if (checked == true) {
              newIds.add('anytime');
            } else {
              newIds.remove('anytime');
            }
            onChanged(newIds);
          },
        ),
        ...windows.map((w) => CheckboxListTile(
              title: Text(w.label),
              subtitle: Text('${w.startHour.toString().padLeft(2, '0')}:${w.startMinute.toString().padLeft(2, '0')} - '
                  '${w.endHour.toString().padLeft(2, '0')}:${w.endMinute.toString().padLeft(2, '0')}'),
              value: selectedIds.contains(w.id),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
              onChanged: (checked) {
                final newIds = List<String>.from(selectedIds);
                if (checked == true) {
                  newIds.add(w.id);
                } else {
                  newIds.remove(w.id);
                }
                onChanged(newIds);
              },
            )),
      ],
    );
  }
}

// =============================================================================
// Reliability Toggle
// =============================================================================

/// A toggle widget used in metric edit/add dialogs to control retrospective
/// recall reliability. Shows the auto-inferred value by default, with an
/// optional user override and a "Reset to auto" escape hatch.
class _ReliabilityToggle extends StatelessWidget {
  final bool effectiveValue;
  final bool isOverridden;
  final ValueChanged<bool> onChanged;
  final VoidCallback onReset;

  const _ReliabilityToggle({
    required this.effectiveValue,
    required this.isOverridden,
    required this.onChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    'Reliable when recalled later',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Factual metrics (Yes/No, counters) can be\n'
                      'accurately logged hours after they happened.\n'
                      'Subjective scales (mood, stress) are best captured\n'
                      'in the moment — retroactive ratings introduce bias.',
                  triggerMode: TooltipTriggerMode.tap,
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            subtitle: Text(
              isOverridden ? 'Custom override active' : 'Auto (based on input type)',
              style: textTheme.bodySmall?.copyWith(
                color: isOverridden
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            value: effectiveValue,
            onChanged: onChanged,
          ),
          if (isOverridden)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 8),
              child: GestureDetector(
                onTap: onReset,
                child: Text(
                  'Reset to auto',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
