import 'package:flutter/material.dart';

import '../../data/models/enums.dart';
import '../../data/models/metric_definition.dart';
import 'metric_icon.dart';

/// A Material 3 card that renders the appropriate input widget for a metric.
///
/// Supports four input types:
/// - **Yes/No** → animated toggle button
/// - **1–5 Scale** → row of selectable chips
/// - **1–10 Scale** → slider with labeled endpoints
/// - **Counter** → single-tap event logger
///
/// Each card tracks [latencyMs] from the moment it first receives user
/// interaction to when the "Save" is confirmed (HCI research requirement).
/// The saved data is inserted as an [Event] in the Drift database.
class MetricInputCard extends StatefulWidget {
  final MetricDefinition metric;
  final String? initialValue;
  final void Function(String value)? onChanged;

  const MetricInputCard({
    super.key,
    required this.metric,
    this.initialValue,
    this.onChanged,
  });

  @override
  State<MetricInputCard> createState() => _MetricInputCardState();
}

class _MetricInputCardState extends State<MetricInputCard> {
  /// The currently selected value.
  String? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.initialValue;
  }

  /// Notifies the parent of the new value.
  void _emitChange() {
    if (_selectedValue == null) return;
    widget.onChanged?.call(_selectedValue!);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header row ---
            Row(
              children: [
                MetricIcon(
                  iconName: widget.metric.emoji,
                  size: 28,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          widget.metric.label,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: widget.metric.isActivityIndicator ? 'Activity Required' : 'Optional',
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: widget.metric.isActivityIndicator
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.metric.description != null) ...[
                  IconButton(
                    icon: Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant.withAlpha(200),
                    ),
                    onPressed: () => _showHelpDialog(context, widget.metric),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  if (_selectedValue != null && widget.metric.inputType != MetricInputType.counter)
                    const SizedBox(width: 8),
                ],
                // Selection indicator (hidden for counter type — each tap is discrete)
                if (_selectedValue != null && widget.metric.inputType != MetricInputType.counter)
                  Icon(
                    Icons.check_circle_rounded,
                    color: colorScheme.primary,
                    size: 28,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // --- Input widget based on type ---
            _buildInput(colorScheme, textTheme),
          ],
        ),
      ),
    );
  }

  /// Renders the correct input widget based on [MetricInputType].
  Widget _buildInput(ColorScheme colorScheme, TextTheme textTheme) {
    switch (widget.metric.inputType) {
      case MetricInputType.yesNo:
        return _buildYesNoInput(colorScheme, textTheme);
      case MetricInputType.scale1to5:
        return _buildScaleInput(colorScheme, textTheme, maxValue: 5);
      case MetricInputType.scale1to10:
        return _buildSliderInput(colorScheme, textTheme, maxValue: 10);
      case MetricInputType.counter:
        return _buildCounterInput(colorScheme, textTheme);
    }
  }

  /// Yes/No toggle using two segmented-style buttons.
  Widget _buildYesNoInput(ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      children: [
        Expanded(
          child: _ToggleOption(
            label: 'Yes',
            icon: Icons.check_rounded,
            isSelected: _selectedValue == 'true',
            colorScheme: colorScheme,
            onTap: () {
              setState(() => _selectedValue = 'true');
              _emitChange();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ToggleOption(
            label: 'No',
            icon: Icons.close_rounded,
            isSelected: _selectedValue == 'false',
            colorScheme: colorScheme,
            onTap: () {
              setState(() => _selectedValue = 'false');
              _emitChange();
            },
          ),
        ),
      ],
    );
  }

  /// 1–5 scale using selectable chips.
  Widget _buildScaleInput(
    ColorScheme colorScheme,
    TextTheme textTheme, {
    required int maxValue,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(maxValue, (index) {
        final value = (index + 1).toString();
        final isSelected = _selectedValue == value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < maxValue - 1 ? 8 : 0),
            child: GestureDetector(
                onTap: () {
                setState(() => _selectedValue = value);
                _emitChange();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    value,
                    style: textTheme.titleSmall?.copyWith(
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// 1–10 scale using a slider for compact display.
  Widget _buildSliderInput(
    ColorScheme colorScheme,
    TextTheme textTheme, {
    required int maxValue,
  }) {
    final currentValue = _selectedValue != null
        ? double.tryParse(_selectedValue!) ?? 5.0
        : 5.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (_selectedValue != null)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _selectedValue!,
                  key: ValueKey(_selectedValue),
                  style: textTheme.headlineSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Text(
                'Slide to rate',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            Text(
              '$maxValue',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Slider(
          value: currentValue,
          min: 1,
          max: maxValue.toDouble(),
          divisions: maxValue - 1,
          label: currentValue.toInt().toString(),
          onChanged: (value) {
            setState(() => _selectedValue = value.toInt().toString());
          },
          onChangeEnd: (value) {
            _emitChange();
          },
        ),
      ],
    );
  }

  /// Counter input: a single large tap button that immediately logs.
  Widget _buildCounterInput(ColorScheme colorScheme, TextTheme textTheme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() => _selectedValue = '1');
            _emitChange();
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app_rounded,
                color: colorScheme.onPrimaryContainer,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Tap to Log',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context, MetricDefinition metric) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: colorScheme.surface,
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          title: Row(
            children: [
              MetricIcon(
                iconName: metric.emoji,
                size: 32,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  metric.label,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TRACKING GUIDELINES',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    metric.description ?? '',
                    style: textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A styled toggle option button for Yes/No inputs.
class _ToggleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? (label == 'Yes'
                    ? colorScheme.primaryContainer
                    : colorScheme.errorContainer)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? (label == 'Yes' ? colorScheme.primary : colorScheme.error)
                : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? (label == 'Yes'
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onErrorContainer)
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (label == 'Yes'
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onErrorContainer)
                    : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
