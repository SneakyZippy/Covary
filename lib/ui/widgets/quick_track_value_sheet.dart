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
  late DateTime _selectedDate;
  bool _saveAsDefault = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
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
    DateTime baseTime;
    switch (_selectedTimeIndex) {
      case 1:
        baseTime = now.subtract(const Duration(minutes: 15));
        break;
      case 2:
        baseTime = now.subtract(const Duration(minutes: 30));
        break;
      case 3:
        baseTime = now.subtract(const Duration(hours: 1));
        break;
      case 4:
        baseTime = _customTime ?? now;
        break;
      case 0:
      default:
        baseTime = now;
        break;
    }

    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      baseTime.hour,
      baseTime.minute,
      baseTime.second,
    );
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

  Future<void> _selectCustomDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date != null) {
      setState(() {
        _selectedDate = DateTime(date.year, date.month, date.day);
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

          // Dynamic portion preview
          if (!isToilet) ...[
            _PortionPreview(
              metricId: widget.metric.id,
              value: _currentValue,
              minVal: widget.min,
              maxVal: widget.max,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            const SizedBox(height: 16),
          ],

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
          const SizedBox(height: 16),

          // Inline picker row: Happened at [Time] on [Date]
          _buildInlinePickerRow(colorScheme, textTheme, displayDateTime),
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
          Builder(
            builder: (context) {
              final today = DateTime.now();
              final isSameDay = displayDateTime.year == today.year &&
                                displayDateTime.month == today.month &&
                                displayDateTime.day == today.day;
              final yesterday = today.subtract(const Duration(days: 1));
              final isYesterday = displayDateTime.year == yesterday.year &&
                                  displayDateTime.month == yesterday.month &&
                                  displayDateTime.day == yesterday.day;

              String dateSuffix;
              if (isSameDay) {
                dateSuffix = 'at ${timeFormatter.format(displayDateTime)}';
              } else if (isYesterday) {
                dateSuffix = 'at ${timeFormatter.format(displayDateTime)} (Yesterday)';
              } else {
                dateSuffix = 'at ${timeFormatter.format(displayDateTime)} on ${DateFormat('MMM d').format(displayDateTime)}';
              }

              return FilledButton.icon(
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
                      ? 'Log 1 Visit $dateSuffix'
                      : 'Log ${_formatDisplayValue(_currentValue, widget.unit, widget.metric.id)} $dateSuffix',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              );
            }
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildInlinePickerRow(ColorScheme colorScheme, TextTheme textTheme, DateTime displayDateTime) {
    final now = DateTime.now();
    final isToday = displayDateTime.year == now.year &&
                    displayDateTime.month == now.month &&
                    displayDateTime.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = displayDateTime.year == yesterday.year &&
                        displayDateTime.month == yesterday.month &&
                        displayDateTime.day == yesterday.day;

    final dateStr = isToday
        ? 'Today'
        : (isYesterday ? 'Yesterday' : DateFormat('EEE, MMM d').format(displayDateTime));
    final timeStr = DateFormat('HH:mm').format(displayDateTime);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(50),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule_rounded, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            'Happened at ',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          InkWell(
            onTap: () {
              _selectCustomTime();
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                timeStr,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          Text(
            ' on ',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          InkWell(
            onTap: () {
              _selectCustomDate();
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isToday ? colorScheme.surfaceContainerHighest : colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isToday) ...[
                    Icon(Icons.calendar_today_rounded, size: 14, color: colorScheme.onTertiaryContainer),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    dateStr,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isToday ? colorScheme.onSurface : colorScheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
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

// =============================================================================
// Portion Size Preview Widget
// =============================================================================

class _PortionPreview extends StatelessWidget {
  final String metricId;
  final double value;
  final double minVal;
  final double maxVal;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _PortionPreview({
    required this.metricId,
    required this.value,
    required this.minVal,
    required this.maxVal,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    String emoji = '📊';
    String title = 'Portion';
    double baseScale = 1.0;

    final range = maxVal - minVal;
    final normalized = range > 0 ? (value - minVal) / range : 0.0;

    if (metricId == 'core_water_intake') {
      baseScale = 0.75 + (normalized * 0.65); // ranges from 0.75 to 1.4
      if (value < 250) {
        emoji = '💧';
        title = 'Quick Sip';
      } else if (value < 500) {
        emoji = '🥛';
        title = 'Small Glass';
      } else if (value < 750) {
        emoji = '🥤';
        title = 'Regular Bottle';
      } else {
        emoji = '🫙';
        title = 'Mega Pitcher';
      }
    } else if (metricId == 'core_coffee_intake') {
      baseScale = 0.8 + (normalized * 0.6); // ranges from 0.8 to 1.4
      if (value <= 1.0) {
        emoji = '☕';
        title = 'Single Espresso';
      } else if (value <= 2.0) {
        emoji = '🍵';
        title = 'Comforting Mug';
      } else {
        emoji = '🫖';
        title = 'Huge Coffee Pot';
      }
    } else if (metricId == 'core_meal_count') {
      if (value == 1.0) {
        emoji = '🍪';
        title = 'Light Snack';
        baseScale = 0.85;
      } else if (value == 2.0) {
        emoji = '🍝';
        title = 'Full Meal';
        baseScale = 1.15;
      } else {
        emoji = '🍱';
        title = 'Large Feast';
        baseScale = 1.45;
      }
    } else if (metricId == 'core_screen_mindless') {
      baseScale = 0.8 + (normalized * 0.6);
      if (value <= 10.0) {
        emoji = '📱';
        title = 'Quick scroll';
      } else if (value <= 30.0) {
        emoji = '📲';
        title = 'Medium Session';
      } else {
        emoji = '🧟';
        title = 'Doom Scroll';
      }
    } else if (metricId == 'core_alcohol_intake') {
      baseScale = 0.8 + (normalized * 0.6);
      if (value <= 1.0) {
        emoji = '🍷';
        title = 'Single Serving';
      } else if (value <= 3.0) {
        emoji = '🍺';
        title = 'A Few Drinks';
      } else {
        emoji = '🍻';
        title = 'Party Mode';
      }
    } else if (metricId.contains('smoked') || metricId == '4b4ab972-ef92-4344-8573-18bda9e259db') {
      baseScale = 0.8 + (normalized * 0.6);
      if (value <= 1.0) {
        emoji = '🚬';
        title = 'Just One';
      } else if (value <= 3.0) {
        emoji = '💨';
        title = 'Moderate Session';
      } else {
        emoji = '🌫️';
        title = 'Heavy Session';
      }
    } else {
      baseScale = 0.9 + (normalized * 0.4);
      emoji = '📦';
      title = 'Custom Portion';
    }

    return Center(
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              colorScheme.primary.withAlpha(25),
              colorScheme.primary.withAlpha(0),
            ],
          ),
          border: Border.all(
            color: colorScheme.primary.withAlpha(20),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: baseScale,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: anim,
                    child: child,
                  ),
                ),
                child: Text(
                  emoji,
                  key: ValueKey(emoji),
                  style: const TextStyle(fontSize: 44),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


