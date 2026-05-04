import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/icon_selector.dart';
import '../../data/models/enums.dart';
import '../../data/models/metric_definition.dart';
import '../../services/metric_service.dart';
import '../widgets/metric_icon.dart';

// =============================================================================
// Add Metric Selector (Bottom Sheet)
// =============================================================================

/// Shows available core templates grouped by category, plus a "Custom" option.
class AddMetricSelector extends StatelessWidget {
  const AddMetricSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metricService = context.watch<MetricService>();
    final existingIds = metricService.allMetrics.map((m) => m.id).toSet();
    final existingLabels = metricService.allMetrics.map((m) => m.label.toLowerCase().trim()).toSet();
    
    final availableTemplates = MetricService.templates
        .where((t) => !existingIds.contains(t.id) && !existingLabels.contains(t.label.toLowerCase().trim()))
        .toList();

    final Map<EventCategory, List<MetricDefinition>> categorized = {};
    for (var t in availableTemplates) {
      categorized.putIfAbsent(t.category, () => []).add(t);
    }
    final sortedCategories = categorized.keys.toList()
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
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
                title: const Text('Create New Metric'),
                subtitle: const Text('Build from scratch'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (ctx) => const AddMetricDialog(),
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
                    final templates = categorized[category]!;
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
                        ...templates.map((t) => _buildTemplateTile(context, t)),
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
      subtitle: Text(template.inputType.displayLabel),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (ctx) => AddMetricDialog(template: template),
        );
      },
    );
  }
}

// =============================================================================
// Edit Metric Dialog
// =============================================================================

class EditMetricDialog extends StatefulWidget {
  final MetricDefinition metric;
  const EditMetricDialog({super.key, required this.metric});

  @override
  State<EditMetricDialog> createState() => _EditMetricDialogState();
}

class _EditMetricDialogState extends State<EditMetricDialog> {
  final _labelController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late EventCategory _selectedCategory;
  late MetricInputType _selectedInputType;
  late List<String> _selectedWindowIds;
  late String? _selectedEmoji;
  bool? _retroReliableOverride;

  @override
  void initState() {
    super.initState();
    _labelController.text = widget.metric.label;

    final allowedCategories = EventCategory.values
        .where((c) => c != EventCategory.appUsage && c != EventCategory.meta)
        .toList();

    _selectedCategory = allowedCategories.contains(widget.metric.category)
        ? widget.metric.category
        : EventCategory.behavior;

    _selectedInputType = widget.metric.inputType;
    _selectedWindowIds = List.from(widget.metric.windowIds);
    _selectedEmoji = widget.metric.emoji;
    _retroReliableOverride = widget.metric.retroReliableOverride;
  }

  bool get _isScaleChangeDangerous {
    final oldType = widget.metric.inputType;
    final newType = _selectedInputType;
    if (oldType == newType) return false;

    // Scale to Scale change
    if ((oldType == MetricInputType.scale1to5 && newType == MetricInputType.scale1to10) ||
        (oldType == MetricInputType.scale1to10 && newType == MetricInputType.scale1to5)) {
      return true;
    }

    // Scale to non-Scale change
    final wasScale = oldType == MetricInputType.scale1to5 || oldType == MetricInputType.scale1to10;
    final isScale = newType == MetricInputType.scale1to5 || newType == MetricInputType.scale1to10;
    if (wasScale != isScale) return true;

    return false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  bool get _effectiveReliable =>
      _retroReliableOverride ??
      (_selectedInputType == MetricInputType.yesNo ||
          _selectedInputType == MetricInputType.counter);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final metricService = context.read<MetricService>();
    await metricService.updateMetric(
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Please enter a name' : null,
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: MetricInputType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.displayLabel)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedInputType = value);
                },
              ),
              if (_isScaleChangeDangerous) ...[
                const SizedBox(height: 16),
                _buildScaleWarning(),
              ],
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
              WindowCheckboxList(
                selectedIds: _selectedWindowIds,
                onChanged: (ids) => setState(() => _selectedWindowIds = ids),
              ),
              const SizedBox(height: 16),
              ReliabilityToggle(
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
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildScaleWarning() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Integrity Warning',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Changing the scale mid-study will make existing logs incomparable to new ones. Averages and correlations for this metric will be skewed.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Add Metric Dialog
// =============================================================================

class AddMetricDialog extends StatefulWidget {
  final MetricDefinition? template;
  const AddMetricDialog({super.key, this.template});

  @override
  State<AddMetricDialog> createState() => _AddMetricDialogState();
}

class _AddMetricDialogState extends State<AddMetricDialog> {
  final _labelController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  EventCategory _selectedCategory = EventCategory.behavior;
  MetricInputType _selectedInputType = MetricInputType.yesNo;
  List<String> _selectedWindowIds = ['anytime'];
  String _selectedEmoji = 'bolt';
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

  int _calculateLatencyMs() =>
      DateTime.now().difference(_dialogOpenedAt).inMilliseconds;

  bool get _effectiveReliable =>
      _retroReliableOverride ??
      (_selectedInputType == MetricInputType.yesNo ||
          _selectedInputType == MetricInputType.counter);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final metricService = context.read<MetricService>();
    await metricService.addMetric(
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
      title: const Text('Add Metric'),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter a name';
                  if (value.trim().length > 50) return 'Name must be 50 characters or less';
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: MetricInputType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.displayLabel)))
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
              WindowCheckboxList(
                selectedIds: _selectedWindowIds,
                onChanged: (ids) => setState(() => _selectedWindowIds = ids),
              ),
              const SizedBox(height: 16),
              ReliabilityToggle(
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
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add'),
        ),
      ],
    );
  }
}

// =============================================================================
// Window Checkbox List
// =============================================================================

/// A list of checkboxes for assigning a metric to tracking windows.
class WindowCheckboxList extends StatelessWidget {
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  const WindowCheckboxList({
    super.key,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final metricService = context.watch<MetricService>();
    final windows = metricService.allWindows;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Special Locations ---
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('Home Screen'),
              selected: selectedIds.contains('homescreen'),
              onSelected: (val) {
                final newIds = List<String>.from(selectedIds);
                val ? newIds.add('homescreen') : newIds.remove('homescreen');
                onChanged(newIds);
              },
              avatar: Icon(Icons.home_outlined, 
                  size: 18, 
                  color: selectedIds.contains('homescreen') ? colorScheme.onSecondaryContainer : colorScheme.primary),
              selectedColor: colorScheme.secondaryContainer,
              checkmarkColor: colorScheme.onSecondaryContainer,
            ),
            FilterChip(
              label: const Text('Always Track'),
              selected: selectedIds.contains('anytime'),
              onSelected: (val) {
                final newIds = List<String>.from(selectedIds);
                if (val) {
                  // If Always Track is on, remove all specific window assignments (redundant)
                  final windows = metricService.allWindows.map((w) => w.id).toSet();
                  newIds.removeWhere((id) => windows.contains(id));
                  newIds.add('anytime');
                } else {
                  newIds.remove('anytime');
                }
                onChanged(newIds);
              },
              avatar: Icon(Icons.all_inclusive_rounded, 
                  size: 18, 
                  color: selectedIds.contains('anytime') ? colorScheme.onPrimaryContainer : colorScheme.primary),
              selectedColor: colorScheme.primaryContainer,
              checkmarkColor: colorScheme.onPrimaryContainer,
            ),
          ],
        ),
        
        if (windows.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Specific Windows',
            style: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: windows.map((w) {
              final isSelected = selectedIds.contains(w.id);
              return FilterChip(
                label: Text(w.label),
                tooltip: '${w.startHour.toString().padLeft(2, '0')}:${w.startMinute.toString().padLeft(2, '0')} - '
                         '${w.endHour.toString().padLeft(2, '0')}:${w.endMinute.toString().padLeft(2, '0')}',
                selected: isSelected,
                onSelected: (val) {
                  final newIds = List<String>.from(selectedIds);
                  if (val) {
                    newIds.add(w.id);
                    // If a specific window is selected, Always Track is no longer true
                    newIds.remove('anytime');
                  } else {
                    newIds.remove(w.id);
                  }
                  onChanged(newIds);
                },
                selectedColor: colorScheme.primaryContainer,
                checkmarkColor: colorScheme.onPrimaryContainer,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// Reliability Toggle
// =============================================================================

/// A toggle widget for controlling retrospective recall reliability on a metric.
class ReliabilityToggle extends StatelessWidget {
  final bool effectiveValue;
  final bool isOverridden;
  final ValueChanged<bool> onChanged;
  final VoidCallback onReset;

  const ReliabilityToggle({
    super.key,
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
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Factual metrics (Yes/No, counters) can be\n'
                      'accurately logged hours after they happened.\n'
                      'Subjective scales (mood, stress) are best captured\n'
                      'in the moment — retroactive ratings introduce bias.',
                  triggerMode: TooltipTriggerMode.tap,
                  child: Icon(Icons.info_outline_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            subtitle: Text(
              isOverridden ? 'Custom override active' : 'Auto (based on input type)',
              style: textTheme.bodySmall?.copyWith(
                color: isOverridden ? colorScheme.primary : colorScheme.onSurfaceVariant,
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
