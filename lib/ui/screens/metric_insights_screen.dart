import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../services/analytics_service.dart';
import '../../services/metric_service.dart';
import '../../data/models/enums.dart';
import '../theme/design_system.dart';
import '../widgets/help_button.dart';
import '../widgets/metric_icon.dart';


enum InsightViewMode { daily, weekly, circadian }

class MetricInsightsScreen extends StatefulWidget {
  const MetricInsightsScreen({super.key});

  @override
  State<MetricInsightsScreen> createState() => _MetricInsightsScreenState();
}

class _MetricInsightsScreenState extends State<MetricInsightsScreen> with TickerProviderStateMixin {
  // Available metric labels
  List<_SelectableMetric> _allMetrics = [];

  // Selected metrics
  String? _primaryLabel;
  String? _secondaryLabel; // Optional comparison

  // View state
  InsightViewMode _viewMode = InsightViewMode.daily;
  int _dayRange = 14;

  // Data
  Map<dynamic, double> _seriesPrimary = {};
  Map<dynamic, double> _seriesSecondary = {};
  bool _isLoading = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  static const _passiveLabels = <_SelectableMetric>[
    _SelectableMetric('category_time:social', 'Social Media', 'social', inputType: MetricInputType.counter),
    _SelectableMetric('total_screen_time', 'Screen Time', 'screen_time', inputType: MetricInputType.counter),
    _SelectableMetric('category_time:entertainment', 'Entertainment', 'entertainment', inputType: MetricInputType.counter),
    _SelectableMetric('sleep_duration_hours', 'Sleep Duration', 'bedtime'),
    _SelectableMetric('sleep_bedtime', 'Bedtime', 'bedtime'),
    _SelectableMetric('sleep_wakeup', 'Wake-up Time', 'sunny'),
    _SelectableMetric('sleep_midpoint', 'Sleep Midpoint', 'midpoint'),
    _SelectableMetric('step_count', 'Steps', 'run', inputType: MetricInputType.counter),
    _SelectableMetric('core_weather_rain', 'Rain (Passive)', 'umbrella', inputType: MetricInputType.scale1to10),
    _SelectableMetric('core_weather_sun', 'Sun (Passive)', 'sunny', inputType: MetricInputType.scale1to10),
    _SelectableMetric('core_weather_wind', 'Wind (Passive)', 'air', inputType: MetricInputType.scale1to10),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initMetrics());
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _initMetrics() {
    final metricService = context.read<MetricService>();
    final subjective = metricService.allMetrics
        .where((m) => m.isEnabled)
        .map((m) => _SelectableMetric(m.label, m.label, m.emoji ?? '', inputType: m.inputType))
        .toList();

    setState(() {
      _allMetrics = [...subjective, ..._passiveLabels];
      if (_allMetrics.isNotEmpty) {
        _primaryLabel = _allMetrics.first.label;
      }
    });

    _loadData();
  }

  Future<void> _loadData() async {
    if (_primaryLabel == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    final analytics = context.read<AnalyticsService>();

    Map<dynamic, double> primaryData = {};
    Map<dynamic, double> secondaryData = {};

    final String primaryEffective = _getEffectiveLabel(_primaryLabel!, _viewMode);
    final String? secondaryEffective = _secondaryLabel != null
        ? _getEffectiveLabel(_secondaryLabel!, _viewMode)
        : null;

    if (_viewMode == InsightViewMode.daily) {
      primaryData = await analytics.getDailyTimeSeries(primaryEffective, normalize: false, lastNDays: _dayRange);
      if (secondaryEffective != null) {
        secondaryData = await analytics.getDailyTimeSeries(secondaryEffective, normalize: false, lastNDays: _dayRange);
      }
    } else if (_viewMode == InsightViewMode.weekly) {
      primaryData = await analytics.getWeeklyTimeSeries(primaryEffective, normalize: false, lastNDays: _dayRange);
      if (secondaryEffective != null) {
        secondaryData = await analytics.getWeeklyTimeSeries(secondaryEffective, normalize: false, lastNDays: _dayRange);
      }
    } else if (_viewMode == InsightViewMode.circadian) {
      primaryData = await analytics.getHourlyTimeSeries(primaryEffective, normalize: false, lastNDays: _dayRange);
      if (secondaryEffective != null) {
        secondaryData = await analytics.getHourlyTimeSeries(secondaryEffective, normalize: false, lastNDays: _dayRange);
      }
    }

    if (mounted) {
      setState(() {
        _seriesPrimary = primaryData;
        _seriesSecondary = secondaryData;
        _isLoading = false;
      });
      _fadeController.forward(from: 0);
    }
  }

  (double?, double?) _getMetricBounds(String label) {
    try {
      final metric = _allMetrics.firstWhere((m) => m.label == label);
      if (metric.inputType == MetricInputType.scale1to5) return (1.0, 5.0);
      if (metric.inputType == MetricInputType.scale1to10) return (1.0, 10.0);
      if (metric.inputType == MetricInputType.yesNo) return (0.0, 1.0);
    } catch (_) {}
    return (null, null);
  }

  String _getEffectiveLabel(String label, InsightViewMode mode) {
    return MetricInsightsHelper.getEffectiveLabel(label, mode);
  }

  String _formatMetricValue(String label, double val) {
    return MetricInsightsHelper.formatMetricValue(label, val);
  }

  String _formatAxisLabel(String label, double val) {
    return MetricInsightsHelper.formatAxisLabel(label, val);
  }

  String _displayName(String label) {
    final match = _allMetrics.where((m) => m.label == label);
    if (match.isNotEmpty) return match.first.displayName;
    if (label.contains(':')) return label.split(':').last.toUpperCase();
    return label.replaceAll('_', ' ');
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metric Insights'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData),
          const AppBarHelpButton(screenKey: 'metric_insights'),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allMetrics.isEmpty
              ? _buildEmptyState(textTheme)
              : FadeTransition(
                  opacity: _fadeAnim,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    children: [
                      _buildViewToggle(colorScheme, textTheme),
                      const SizedBox(height: 24),
                      _buildMetricSelectors(colorScheme, textTheme),
                      const SizedBox(height: 16),
                      _buildDayRangeSelector(colorScheme, textTheme),
                      const SizedBox(height: 24),
                      _buildChartCard(colorScheme, textTheme),
                      const SizedBox(height: 16),
                      _buildInsightCard(colorScheme, textTheme),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  // ─── Toggles & Selectors ──────────────────────────────────────────────────

  Widget _buildViewToggle(ColorScheme colorScheme, TextTheme textTheme) {
    return SegmentedButton<InsightViewMode>(
      segments: const [
        ButtonSegment(
          value: InsightViewMode.daily,
          label: Text('Daily Trend'),
          icon: Icon(Icons.show_chart_rounded),
        ),
        ButtonSegment(
          value: InsightViewMode.weekly,
          label: Text('Weekly Trend'),
          icon: Icon(Icons.view_week_rounded),
        ),
        ButtonSegment(
          value: InsightViewMode.circadian,
          label: Text('Circadian'),
          icon: Icon(Icons.wb_sunny_rounded),
        ),
      ],
      selected: {_viewMode},
      onSelectionChanged: (set) {
        final newMode = set.first;
        setState(() {
          _viewMode = newMode;
          if (newMode == InsightViewMode.weekly) {
            _dayRange = 60;
          } else {
            _dayRange = 14;
          }
        });
        _loadData();
      },
      showSelectedIcon: false,
    );
  }

  Widget _buildMetricSelectors(ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricChip(
            label: _primaryLabel,
            color: colorScheme.primary,
            hint: 'Select Metric',
            isPrimary: true,
            onSelect: (label) {
              setState(() {
                _primaryLabel = label;
                if (_secondaryLabel == label) _secondaryLabel = null;
              });
              _loadData();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricChip(
            label: _secondaryLabel,
            color: colorScheme.secondary,
            hint: '+ Compare',
            isPrimary: false,
            onSelect: (label) {
              setState(() {
                _secondaryLabel = label;
                if (_primaryLabel == label) _primaryLabel = null;
              });
              _loadData();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMetricChip({
    required String? label,
    required Color color,
    required String hint,
    required bool isPrimary,
    required ValueChanged<String?> onSelect,
  }) {
    final hasLabel = label != null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showMetricPicker(color, onSelect, allowClear: !isPrimary),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hasLabel ? color.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasLabel ? color.withAlpha(60) : Theme.of(context).colorScheme.outlineVariant.withAlpha(100),
            style: hasLabel ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            if (hasLabel) ...[
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                hasLabel ? _displayName(label).toUpperCase() : hint,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: hasLabel ? Colors.white : Theme.of(context).colorScheme.outline,
                  fontWeight: hasLabel ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down_rounded, size: 16, color: hasLabel ? color.withAlpha(150) : Theme.of(context).colorScheme.outline),
          ],
        ),
      ),
    );
  }

  void _showMetricPicker(Color accent, ValueChanged<String?> onSelect, {required bool allowClear}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('Select Metric', style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (allowClear)
                      ListTile(
                        leading: const Icon(Icons.clear_rounded, color: Colors.grey),
                        title: const Text('None (Clear Comparison)'),
                        onTap: () {
                          Navigator.pop(ctx);
                          onSelect(null);
                        },
                      ),
                    ..._allMetrics.map((m) {
                      final isSelected = m.label == _primaryLabel || m.label == _secondaryLabel;
                      return ListTile(
                        leading: MetricIcon(
                          iconName: m.iconName,
                          size: 24,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                        title: Text(m.displayName),
                        trailing: isSelected ? Icon(Icons.check_circle, color: accent, size: 20) : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          onSelect(m.label);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDayRangeSelector(ColorScheme colorScheme, TextTheme textTheme) {
    final bool isWeekly = _viewMode == InsightViewMode.weekly;
    final List<int> options = isWeekly ? [30, 60, 90] : [7, 14, 30];
    return Row(
      children: [
        Icon(Icons.date_range_rounded, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text('Range:', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
        const SizedBox(width: 8),
        ...options.map((d) {
          final isActive = _dayRange == d;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(isWeekly ? '${d ~/ 7}w' : '${d}d'),
              selected: isActive,
              onSelected: (_) {
                setState(() => _dayRange = d);
                _loadData();
              },
              labelStyle: textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: isActive ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
              ),
              selectedColor: colorScheme.primary,
              backgroundColor: Colors.white.withAlpha(10),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            ),
          );
        }),
      ],
    );
  }

  // ─── Chart ────────────────────────────────────────────────────────────────

  Widget _buildChartCard(ColorScheme colorScheme, TextTheme textTheme) {
    final bool isCircadian = _viewMode == InsightViewMode.circadian;
    final bool isWeekly = _viewMode == InsightViewMode.weekly;
    final bool isComparing = _secondaryLabel != null;

    // Keys are either DateTime (daily/weekly) or int (circadian)
    final allKeys = <dynamic>{..._seriesPrimary.keys, ..._seriesSecondary.keys}.toList();
    
    if (isCircadian) {
      allKeys.sort((a, b) => (a as int).compareTo(b as int));
    } else {
      allKeys.sort((a, b) => (a as DateTime).compareTo(b as DateTime));
    }

    if (allKeys.isEmpty) {
      return Container(
        height: 250,
        alignment: Alignment.center,
        child: Text('No data found for the selected range.', style: textTheme.bodySmall?.copyWith(color: Colors.grey)),
      );
    }

    final pMinMax = _getMetricBounds(_primaryLabel!);
    double minA = pMinMax.$1 ?? (_seriesPrimary.values.isNotEmpty ? _seriesPrimary.values.reduce(min) : 0.0);
    double maxA = pMinMax.$2 ?? (_seriesPrimary.values.isNotEmpty ? _seriesPrimary.values.reduce(max) : 1.0);
    if (maxA == minA) maxA = minA + 1.0;

    double minB = 0.0;
    double maxB = 1.0;
    if (isComparing) {
      final sMinMax = _getMetricBounds(_secondaryLabel!);
      minB = sMinMax.$1 ?? (_seriesSecondary.values.isNotEmpty ? _seriesSecondary.values.reduce(min) : 0.0);
      maxB = sMinMax.$2 ?? (_seriesSecondary.values.isNotEmpty ? _seriesSecondary.values.reduce(max) : 1.0);
      if (maxB == minB) maxB = minB + 1.0;
    }

    final spotsA = <FlSpot>[];
    final spotsB = <FlSpot>[];

    for (int i = 0; i < allKeys.length; i++) {
      final key = allKeys[i];
      final double xPos = isCircadian ? (key as int).toDouble() : i.toDouble();

      if (_seriesPrimary.containsKey(key)) {
        final val = _seriesPrimary[key]!;
        final double yPos = isComparing ? ((val - minA) / (maxA - minA)).clamp(0.0, 1.0) : val;
        spotsA.add(FlSpot(xPos, yPos));
      }
      if (isComparing && _seriesSecondary.containsKey(key)) {
        final val = _seriesSecondary[key]!;
        final double yPos = ((val - minB) / (maxB - minB)).clamp(0.0, 1.0);
        spotsB.add(FlSpot(xPos, yPos));
      }
    }

    final lineColors = CovaryDesignSystem.getChartLineColors(context);
    final accentA = lineColors.$1;
    final accentB = lineColors.$2;

    // Y Axis scaling
    final bool isCounter = _allMetrics.any((m) => m.label == _primaryLabel && (m.inputType == MetricInputType.counter || m.inputType == MetricInputType.numeric));
    final bool isSecondaryCounter = isComparing && _allMetrics.any((m) => m.label == _secondaryLabel && (m.inputType == MetricInputType.counter || m.inputType == MetricInputType.numeric));
    
    final double minY = isComparing ? 0.0 : (pMinMax.$1 ?? 0.0);
    final double maxY = isComparing ? 1.0 : (pMinMax.$2 ?? (maxA > 0 ? maxA * 1.15 : 1.0));

    // X Axis scaling
    final minX = 0.0;
    final maxX = isCircadian ? 23.0 : (allKeys.isNotEmpty ? allKeys.length.toDouble() - 1 : 0.0);

    // Calculate Y interval to avoid duplicate labels (0, 1, 1, 2, 2)
    double yInterval = isComparing ? 0.25 : ((maxY - minY) / 4);
    if (!isComparing && isCounter && (maxY - minY) < 6 && (maxY - minY) > 0) {
      yInterval = 1.0; 
    } else if (!isComparing && (maxY - minY) < 1 && (maxY - minY) > 0) {
      yInterval = 0.25;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(40),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _legendDot(accentA, _displayName(_primaryLabel!), textTheme),
                if (isComparing) _legendDot(accentB, _displayName(_secondaryLabel!), textTheme),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: (!isComparing && isCounter && (_viewMode == InsightViewMode.daily || _viewMode == InsightViewMode.weekly))
              ? BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    minY: minY,
                    maxY: maxY,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => colorScheme.surfaceContainer,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final int idx = group.x.toInt();
                          if (idx < 0 || idx >= allKeys.length) return null;
                          final key = allKeys[idx];
                          String timeStr = _formatTooltipKey(key, _viewMode);
                          final rawVal = rod.toY;
                          final formattedVal = _formatMetricValue(_primaryLabel!, rawVal);
                          return BarTooltipItem(
                            '$formattedVal\n$timeStr',
                            TextStyle(color: accentA, fontWeight: FontWeight.bold, fontSize: 10),
                          );
                        },
                      ),
                    ),
                    titlesData: _buildTitlesData(colorScheme, allKeys, isCircadian, isWeekly, yInterval, isComparing, minA, maxA, minB, maxB, accentB),
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval: yInterval,
                      getDrawingHorizontalLine: (_) => FlLine(color: colorScheme.outlineVariant.withValues(alpha: 0.15), strokeWidth: 0.5),
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: spotsA.map((s) => BarChartGroupData(
                      x: s.x.toInt(),
                      barRods: [
                        BarChartRodData(
                          toY: s.y,
                          color: accentA,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxY,
                            color: accentA.withAlpha(10),
                          ),
                        ),
                      ],
                    )).toList(),
                  ),
                )
              : LineChart(
                  LineChartData(
                    minX: minX,
                    maxX: maxX,
                    minY: minY,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval: yInterval,
                      getDrawingHorizontalLine: (_) => FlLine(color: colorScheme.outlineVariant.withValues(alpha: 0.15), strokeWidth: 0.5),
                      drawVerticalLine: false,
                    ),
                    titlesData: _buildTitlesData(colorScheme, allKeys, isCircadian, isWeekly, yInterval, isComparing, minA, maxA, minB, maxB, accentB),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      _lineBar(spotsA, accentA, isFilled: !isComparing, isStep: isCounter),
                      if (isComparing) _lineBar(spotsB, accentB, isFilled: false, isStep: isSecondaryCounter),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => colorScheme.surfaceContainer,
                        getTooltipItems: (spots) {
                          final dynamic key;
                          if (isCircadian) {
                            key = spots.first.x.toInt();
                          } else {
                            final int idx = spots.first.x.toInt();
                            if (idx < 0 || idx >= allKeys.length) return [];
                            key = allKeys[idx];
                          }
                          String timeStr = _formatTooltipKey(key, _viewMode);
                          
                          return spots.map((s) {
                            final isPrimarySpot = s.barIndex == 0;
                            final color = isPrimarySpot ? accentA : accentB;
                            final label = isPrimarySpot ? _displayName(_primaryLabel!) : _displayName(_secondaryLabel!);
                            final rawVal = isComparing
                                ? (isPrimarySpot ? s.y * (maxA - minA) + minA : s.y * (maxB - minB) + minB)
                                : s.y;
                            final formattedVal = _formatMetricValue(isPrimarySpot ? _primaryLabel! : _secondaryLabel!, rawVal);
                            return LineTooltipItem(
                              '$timeStr\n$label: $formattedVal',
                              TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                ),
          ),
        ],
      ),
    );
  }

  FlTitlesData _buildTitlesData(
    ColorScheme colorScheme,
    List<dynamic> allKeys,
    bool isCircadian,
    bool isWeekly,
    double yInterval,
    bool isComparing,
    double minA,
    double maxA,
    double minB,
    double maxB,
    Color accentB,
  ) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: yInterval,
          getTitlesWidget: (v, _) {
            final double rawVal = isComparing ? (v * (maxA - minA) + minA) : v;
            return Text(
              _formatAxisLabel(_primaryLabel!, rawVal),
              style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
            );
          },
        ),
      ),
      rightTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: isComparing,
          reservedSize: 40,
          interval: yInterval,
          getTitlesWidget: (v, _) {
            if (!isComparing || _secondaryLabel == null) return const SizedBox();
            final double rawVal = v * (maxB - minB) + minB;
            return Text(
              _formatAxisLabel(_secondaryLabel!, rawVal),
              style: TextStyle(fontSize: 9, color: accentB.withValues(alpha: 0.8)),
            );
          },
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: isCircadian ? 4 : (isWeekly ? 1 : max(1, (allKeys.length / 5).ceilToDouble())),
          getTitlesWidget: (v, _) {
            if (isCircadian) {
              final hour = v.toInt();
              if (hour < 0 || hour > 23) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${hour.toString().padLeft(2, '0')}:00', style: TextStyle(fontSize: 8, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8))),
              );
            } else if (isWeekly) {
              final idx = v.toInt();
              if (idx < 0 || idx >= allKeys.length) return const SizedBox();
              final key = allKeys[idx] as DateTime;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Wk ${DateFormat('d/M').format(key)}', 
                  style: TextStyle(fontSize: 8, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8))
                ),
              );
            } else {
              final idx = v.toInt();
              if (idx < 0 || idx >= allKeys.length) return const SizedBox();
              final key = allKeys[idx];
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(DateFormat('d MMM').format(key as DateTime), style: TextStyle(fontSize: 8, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8))),
              );
            }
          },
        ),
      ),
    );
  }

  LineChartBarData _lineBar(List<FlSpot> spots, Color color, {required bool isFilled, bool isStep = false}) {
    return LineChartBarData(
      spots: spots,
      isCurved: !isStep,
      isStepLineChart: false, // Switching to straight spikes for better event representation
      curveSmoothness: 0.35,
      color: color,
      barWidth: isStep ? 2 : 3, // Thinner lines for spikes
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        checkToShowDot: (spot, barData) {
          // For events/counters, only show dots for the peaks to reduce clutter
          if (isStep) return spot.y > 0;
          // For continuous scales, show dots at intervals or all
          return true;
        },
        getDotPainter: (spot, xPercentage, bar, index) => FlDotCirclePainter(
          radius: isStep ? 3 : 2,
          color: color,
          strokeWidth: 0,
        ),
      ),
      belowBarData: BarAreaData(
        show: isFilled,
        gradient: LinearGradient(
          colors: [color.withAlpha(isStep ? 80 : 50), color.withAlpha(0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label, TextTheme textTheme) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: textTheme.labelSmall?.copyWith(fontSize: 10, color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ─── Insights ─────────────────────────────────────────────────────────────

  Widget _buildInsightCard(ColorScheme colorScheme, TextTheme textTheme) {
    final isCircadian = _viewMode == InsightViewMode.circadian;
    final isWeekly = _viewMode == InsightViewMode.weekly;
    final isComparing = _secondaryLabel != null;

    String insightText = '';
    
    if (_seriesPrimary.isEmpty) {
      return const SizedBox();
    }

    if (isCircadian) {
      int peakHour = 0;
      double peakVal = -1;
      _seriesPrimary.forEach((k, v) {
        if (v > peakVal) { peakVal = v; peakHour = k as int; }
      });

      if (isComparing && _seriesSecondary.isNotEmpty) {
        int peakHourB = 0;
        double peakValB = -1;
        _seriesSecondary.forEach((k, v) {
          if (v > peakValB) { peakValB = v; peakHourB = k as int; }
        });
        
        final diff = (peakHour - peakHourB).abs();
        if (diff == 0) {
          insightText = 'Your ${_displayName(_primaryLabel!).toLowerCase()} and ${_displayName(_secondaryLabel!).toLowerCase()} both peak around $peakHour:00.';
        } else {
          insightText = 'Your ${_displayName(_primaryLabel!).toLowerCase()} peaks around $peakHour:00, while your ${_displayName(_secondaryLabel!).toLowerCase()} peaks around $peakHourB:00.';
        }
      } else {
        insightText = 'Your ${_displayName(_primaryLabel!).toLowerCase()} typically peaks around $peakHour:00.';
      }
    } else if (isWeekly) {
      double avg = 0;
      _seriesPrimary.forEach((k, v) => avg += v);
      avg /= _seriesPrimary.length;
      
      insightText = 'Your weekly average for ${_displayName(_primaryLabel!).toLowerCase()} is ${_formatMetricValue(_primaryLabel!, avg)} over the last ${_dayRange ~/ 7} weeks.';
    } else if (isComparing && _seriesPrimary.isNotEmpty && _seriesSecondary.isNotEmpty) {
      // Basic correlation check for comparison
      // We look for alignment in peaks or general trend
      double primaryAvg = _seriesPrimary.values.reduce((a, b) => a + b) / _seriesPrimary.length;
      double secondaryAvg = _seriesSecondary.values.reduce((a, b) => a + b) / _seriesSecondary.length;
      
      int agreement = 0;
      int total = 0;
      
      _seriesPrimary.forEach((k, v1) {
        if (_seriesSecondary.containsKey(k)) {
          final v2 = _seriesSecondary[k]!;
          final pHigh = v1 > primaryAvg;
          final sHigh = v2 > secondaryAvg;
          if (pHigh == sHigh) agreement++;
          total++;
        }
      });

      final ratio = total > 0 ? agreement / total : 0.5;
      final pName = _displayName(_primaryLabel!).toLowerCase();
      final sName = _displayName(_secondaryLabel!).toLowerCase();

      if (ratio > 0.7) {
        insightText = 'There is a strong positive correlation between your $pName and $sName.';
      } else if (ratio < 0.3) {
        insightText = 'Your $pName and $sName seem to move in opposite directions.';
      } else {
        insightText = 'No clear immediate correlation between $pName and $sName in this window.';
      }
    } else {
      double avg = 0;
      _seriesPrimary.forEach((k, v) => avg += v);
      avg /= _seriesPrimary.length;
      
      insightText = 'Your daily average for ${_displayName(_primaryLabel!).toLowerCase()} is ${avg.toStringAsFixed(1)} over the last $_dayRange days.';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withAlpha(30),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.primary.withAlpha(40)),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: colorScheme.primary, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  insightText,
                  style: textTheme.bodySmall?.copyWith(color: Colors.white.withAlpha(220), height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.show_chart_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No metrics available.', textAlign: TextAlign.center, style: textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  String _formatTooltipKey(dynamic key, InsightViewMode mode) {
    if (mode == InsightViewMode.circadian) {
      final hour = (key as int);
      return '${hour.toString().padLeft(2, '0')}:00';
    } else if (mode == InsightViewMode.daily) {
      return DateFormat('d MMM').format(key as DateTime);
    } else if (mode == InsightViewMode.weekly) {
      final start = key as DateTime;
      final end = start.add(const Duration(days: 6));
      return 'Week of ${DateFormat('d MMM').format(start)} - ${DateFormat('d MMM').format(end)}';
    } else {
      return '';
    }
  }
}

/// Internal helper for the metric picker.
class _SelectableMetric {
  final String label;
  final String displayName;
  final String iconName;
  final MetricInputType? inputType;
  const _SelectableMetric(this.label, this.displayName, this.iconName, {this.inputType});
}

class MetricInsightsHelper {
  static String getEffectiveLabel(String label, InsightViewMode mode) {
    if (mode == InsightViewMode.daily || mode == InsightViewMode.weekly) {
      return label;
    }
    switch (label) {
      case 'step_count':
        return 'step_segment';
      case 'total_screen_time':
        return 'app_usage_segment';
      case 'category_time:social':
        return 'category_segment:social';
      case 'category_time:entertainment':
        return 'category_segment:entertainment';
      default:
        if (label.startsWith('app_time:')) {
          final pkg = label.replaceFirst('app_time:', '');
          return 'app_segment:$pkg';
        }
        return label;
    }
  }

  static String formatMetricValue(String label, double val) {
    if (label == 'sleep_bedtime' || label == 'sleep_wakeup' || label == 'sleep_midpoint') {
      double hours = val;
      if (hours >= 24) hours -= 24;
      final int h = hours.floor();
      final int m = ((hours - h) * 60).round();
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    if (label == 'sleep_duration_hours') {
      return '${val.toStringAsFixed(1)}h';
    }
    if (label.contains('time') || label.contains('screen_time') || label.toLowerCase().contains('scrolling') || label.toLowerCase().contains('mindless')) {
      if (val >= 60) {
        final h = val ~/ 60;
        final m = (val % 60).round();
        return '${h}h ${m}m';
      }
      return '${val.round()}m';
    }
    if (label == 'step_count' || label == 'step_segment') {
      return NumberFormat.decimalPattern().format(val.round());
    }
    return val.toStringAsFixed(val % 1 == 0 ? 0 : 1);
  }

  static String formatAxisLabel(String label, double val) {
    if (label == 'sleep_bedtime' || label == 'sleep_wakeup' || label == 'sleep_midpoint') {
      double hours = val;
      if (hours >= 24) hours -= 24;
      final int h = hours.floor();
      return '${h.toString().padLeft(2, '0')}:00';
    }
    if (label.contains('time') || label.contains('screen_time') || label.toLowerCase().contains('scrolling') || label.toLowerCase().contains('mindless')) {
      if (val >= 60) {
        return '${(val / 60).toStringAsFixed(1)}h';
      }
      return '${val.round()}m';
    }
    if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1)}k';
    }
    return val.toStringAsFixed(val % 1 == 0 ? 0 : 1);
  }
}
