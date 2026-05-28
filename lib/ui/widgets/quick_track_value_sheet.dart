import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/metric_definition.dart';
import 'metric_icon.dart';

/// A custom, premium bottom sheet for adjusting the value and time of
/// quick-track counter metrics, with an option to save the new value as default.
class QuickTrackValueSheet extends StatefulWidget {
  final MetricDefinition metric;
  final double initialValue;
  final String unit;
  final double step;
  final double min;
  final double max;
  final Function(double value, DateTime time, bool saveAsDefault) onConfirm;

  const QuickTrackValueSheet({
    super.key,
    required this.metric,
    required this.initialValue,
    required this.unit,
    required this.step,
    required this.min,
    required this.max,
    required this.onConfirm,
  });

  @override
  State<QuickTrackValueSheet> createState() => _QuickTrackValueSheetState();
}

class _QuickTrackValueSheetState extends State<QuickTrackValueSheet> {
  late double _currentValue;
  int _selectedTimeIndex = 0; // 0: Now, 1: 15m ago, 2: 30m ago, 3: 1h ago, 4: Custom
  DateTime? _customTime;
  bool _saveAsDefault = false;

  @override
  void initState() {
    super.initState();
    // Clamp initial value to min/max just in case
    _currentValue = widget.initialValue.clamp(widget.min, widget.max);
  }

  String _formatDisplayValue(double value, String unit, String metricId) {
    if (metricId == 'core_meal_count') {
      if (value == 1.0) return 'Snack';
      if (value == 2.0) return 'Meal';
      return 'Feast';
    }

    final valStr = value == value.toInt() ? value.toInt().toString() : value.toStringAsFixed(1);

    if (value == 1.0) {
      // Singular unit cases for better grammar
      if (unit == 'cups') return '1 cup';
      if (unit == 'drinks') return '1 drink';
      if (unit == 'cigarettes') return '1 cigarette';
      if (unit == 'visits') return '1 visit';
      if (unit == 'meals') return '1 meal';
    }

    return '$valStr $unit';
  }

  DateTime _getSelectedDateTime() {
    final now = DateTime.now();
    switch (_selectedTimeIndex) {
      case 1:
        return now.subtract(const Duration(minutes: 15));
      case 2:
        return now.subtract(const Duration(minutes: 30));
      case 3:
        return now.subtract(const Duration(hours: 1));
      case 4:
        if (_customTime != null) {
          return DateTime(
            now.year,
            now.month,
            now.day,
            _customTime!.hour,
            _customTime!.minute,
          );
        }
        return now;
      case 0:
      default:
        return now;
    }
  }

  Future<void> _selectCustomTime() async {
    final now = DateTime.now();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_customTime ?? now),
    );

    if (time != null) {
      setState(() {
        _customTime = DateTime(
          now.year,
          now.month,
          now.day,
          time.hour,
          time.minute,
        );
        _selectedTimeIndex = 4;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final displayDateTime = _getSelectedDateTime();
    final timeFormatter = DateFormat.jm();
    final customTimeLabel = _customTime != null
        ? timeFormatter.format(_customTime!)
        : 'Custom...';

    final isMeal = widget.metric.id == 'core_meal_count';
    final isToilet = widget.metric.id == 'core_toilet_urge';

    // Calculate number of divisions for the slider
    final range = widget.max - widget.min;
    final divisions = (range / widget.step).round();

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              if (widget.metric.emoji != null) ...[
                MetricIcon(iconName: widget.metric.emoji!, size: 28),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToilet
                          ? 'Bathroom Visit Time'
                          : 'Adjust ${widget.metric.label}',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isToilet
                          ? 'Select when this occurred'
                          : 'Choose amount and time below',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Core Input Section
          if (isToilet) ...[
            // Toilet visits need no value input, just a clean confirmation
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  '1 Visit',
                  style: textTheme.displayMedium!.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ] else if (isMeal) ...[
            // Meal count: Snack (1), Meal (2), Feast (3) Segmented Control
            Center(
              child: Text(
                _formatDisplayValue(_currentValue, widget.unit, widget.metric.id),
                style: textTheme.displayMedium!.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<double>(
              segments: const <ButtonSegment<double>>[
                ButtonSegment<double>(
                  value: 1.0,
                  label: Text('Snack'),
                  icon: Icon(Icons.cookie_outlined),
                ),
                ButtonSegment<double>(
                  value: 2.0,
                  label: Text('Meal'),
                  icon: Icon(Icons.restaurant_menu_outlined),
                ),
                ButtonSegment<double>(
                  value: 3.0,
                  label: Text('Feast'),
                  icon: Icon(Icons.dinner_dining_outlined),
                ),
              ],
              selected: <double>{_currentValue},
              onSelectionChanged: (Set<double> newSelection) {
                setState(() {
                  _currentValue = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 16),
          ] else ...[
            // Standard continuous slider (e.g. water, coffee)
            Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: textTheme.displayMedium!.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                ),
                child: Text(_formatDisplayValue(_currentValue, widget.unit, widget.metric.id)),
              ),
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                activeTrackColor: colorScheme.primary,
                inactiveTrackColor: colorScheme.primaryContainer.withAlpha(100),
                thumbColor: colorScheme.primary,
                overlayColor: colorScheme.primary.withAlpha(30),
                valueIndicatorColor: colorScheme.primary,
                valueIndicatorTextStyle: TextStyle(color: colorScheme.onPrimary),
              ),
              child: Slider(
                value: _currentValue,
                min: widget.min,
                max: widget.max,
                divisions: divisions > 0 ? divisions : null,
                label: _formatDisplayValue(_currentValue, widget.unit, widget.metric.id),
                onChanged: (newValue) {
                  setState(() {
                    _currentValue = newValue;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Time selection section
          Text(
            'Time occurred',
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTimeChip(0, 'Now'),
                const SizedBox(width: 8),
                _buildTimeChip(1, '15m ago'),
                const SizedBox(width: 8),
                _buildTimeChip(2, '30m ago'),
                const SizedBox(width: 8),
                _buildTimeChip(3, '1h ago'),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(customTimeLabel),
                  selected: _selectedTimeIndex == 4,
                  onSelected: (selected) {
                    if (selected) {
                      _selectCustomTime();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Save as Default portion toggle (hide for toilet visits as it is always 1)
          if (!isToilet)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withAlpha(100),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withAlpha(100),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set as default portion',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Future taps will log ${_formatDisplayValue(_currentValue, widget.unit, widget.metric.id)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _saveAsDefault,
                    onChanged: (val) {
                      setState(() {
                        _saveAsDefault = val;
                      });
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // Confirm button
          FilledButton.icon(
            onPressed: () {
              widget.onConfirm(
                _currentValue,
                displayDateTime,
                _saveAsDefault,
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              isToilet
                  ? 'Log 1 Visit at ${timeFormatter.format(displayDateTime)}'
                  : 'Log ${_formatDisplayValue(_currentValue, widget.unit, widget.metric.id)} at ${timeFormatter.format(displayDateTime)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTimeChip(int index, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedTimeIndex == index,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedTimeIndex = index;
          });
        }
      },
    );
  }
}
