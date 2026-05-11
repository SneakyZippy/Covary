import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../services/analytics_service.dart';
import '../../services/metric_service.dart';
import '../../ui/theme/design_system.dart';

enum InsightViewMode { daily, circadian }

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
  static const List<int> _dayRangeOptions = [7, 14, 30];

  // Data
  Map<dynamic, double> _seriesPrimary = {};
  Map<dynamic, double> _seriesSecondary = {};
  bool _isLoading = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  static const _passiveLabels = <_SelectableMetric>[
    _SelectableMetric('category_time:social', 'Social Media', '📱'),
    _SelectableMetric('total_screen_time', 'Screen Time', '⌛'),
    _SelectableMetric('category_time:entertainment', 'Entertainment', '🎬'),
    _SelectableMetric('sleep_duration_hours', 'Sleep Duration', '🛌'),
    _SelectableMetric('step_count', 'Steps', '🏃'),
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
        .map((m) => _SelectableMetric(m.label, m.label, _emojiFor(m.emoji)))
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

    // If secondary is selected, we MUST normalize to compare them on the same axis.
    // If only primary is selected, we do NOT normalize, so the user sees raw values (e.g., 5000 steps).
    final bool shouldNormalize = _secondaryLabel != null;

    Map<dynamic, double> primaryData = {};
    Map<dynamic, double> secondaryData = {};

    if (_viewMode == InsightViewMode.daily) {
      primaryData = await analytics.getDailyTimeSeries(_primaryLabel!, normalize: shouldNormalize, lastNDays: _dayRange);
      if (_secondaryLabel != null) {
        secondaryData = await analytics.getDailyTimeSeries(_secondaryLabel!, normalize: true, lastNDays: _dayRange);
      }
    } else {
      primaryData = await analytics.getHourlyTimeSeries(_primaryLabel!, normalize: shouldNormalize, lastNDays: _dayRange);
      if (_secondaryLabel != null) {
        secondaryData = await analytics.getHourlyTimeSeries(_secondaryLabel!, normalize: true, lastNDays: _dayRange);
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

  String _displayName(String label) {
    final match = _allMetrics.where((m) => m.label == label);
    if (match.isNotEmpty) return match.first.displayName;
    if (label.contains(':')) return label.split(':').last.toUpperCase();
    return label.replaceAll('_', ' ');
  }

  String _emojiFor(String? key) {
    const map = {
      'mood': '😊', 'bolt': '⚡', 'stress': '😫', 'sleep': '😴',
      'star': '⭐', 'bedtime': '🛌', 'run': '🏃', 'edit': '📝',
      'favorite': '❤️', 'meat': '🥩', 'lightbulb': '💡',
      'psychology': '🧠', 'water': '💧', 'meditation': '🧘',
      'book': '📚', 'coffee': '☕',
    };
    return map[key] ?? '📊';
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
          value: InsightViewMode.circadian,
          label: Text('Circadian Rhythm'),
          icon: Icon(Icons.wb_sunny_rounded),
        ),
      ],
      selected: {_viewMode},
      onSelectionChanged: (set) {
        setState(() => _viewMode = set.first);
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
            color: CovaryDesignSystem.secondary,
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
      backgroundColor: CovaryDesignSystem.level1Surface,
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
                        leading: Text(m.emoji, style: const TextStyle(fontSize: 20)),
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
    return Row(
      children: [
        Icon(Icons.date_range_rounded, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text('Range:', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
        const SizedBox(width: 8),
        ..._dayRangeOptions.map((d) {
          final isActive = _dayRange == d;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text('${d}d'),
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
    final bool isComparing = _secondaryLabel != null;

    // Keys are either DateTime (daily) or int (circadian)
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

    final spotsA = <FlSpot>[];
    final spotsB = <FlSpot>[];

    double maxValA = 0;
    
    for (int i = 0; i < allKeys.length; i++) {
      final key = allKeys[i];
      final double xPos = isCircadian ? (key as int).toDouble() : i.toDouble();

      if (_seriesPrimary.containsKey(key)) {
        final val = _seriesPrimary[key]!;
        spotsA.add(FlSpot(xPos, val));
        if (val > maxValA) maxValA = val;
      }
      if (_seriesSecondary.containsKey(key)) {
        spotsB.add(FlSpot(xPos, _seriesSecondary[key]!));
      }
    }

    final accentA = colorScheme.primary;
    const accentB = CovaryDesignSystem.secondary;

    // Y Axis scaling
    final maxY = isComparing ? 1.0 : (maxValA > 0 ? maxValA * 1.2 : 1.0);
    // X Axis scaling
    final minX = 0.0;
    final maxX = isCircadian ? 23.0 : (allKeys.isNotEmpty ? allKeys.length.toDouble() - 1 : 0.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
      decoration: BoxDecoration(
        color: CovaryDesignSystem.surfaceContainerHighest.withAlpha(40),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(15)),
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
            child: LineChart(
              LineChartData(
                minX: minX,
                maxX: maxX,
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: isComparing ? 0.25 : (maxY / 4),
                  getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withAlpha(15), strokeWidth: 0.5),
                  drawVerticalLine: false,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: isComparing ? 0.5 : (maxY / 4),
                      getTitlesWidget: (v, _) => Text(
                        isComparing ? v.toStringAsFixed(1) : v.toStringAsFixed(0),
                        style: TextStyle(fontSize: 9, color: Colors.white.withAlpha(80)),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: isCircadian ? 4 : max(1, (allKeys.length / 5).ceilToDouble()),
                      getTitlesWidget: (v, _) {
                        if (isCircadian) {
                          final hour = v.toInt();
                          if (hour < 0 || hour > 23) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('${hour.toString().padLeft(2, '0')}:00', style: TextStyle(fontSize: 8, color: Colors.white.withAlpha(100))),
                          );
                        } else {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= allKeys.length) return const SizedBox();
                          final key = allKeys[idx];
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(DateFormat('d MMM').format(key as DateTime), style: TextStyle(fontSize: 8, color: Colors.white.withAlpha(100))),
                          );
                        }
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  _lineBar(spotsA, accentA, isFilled: !isComparing),
                  if (isComparing) _lineBar(spotsB, accentB, isFilled: false),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => CovaryDesignSystem.level1Surface,
                    getTooltipItems: (spots) => spots.map((s) {
                      final color = s.barIndex == 0 ? accentA : accentB;
                      return LineTooltipItem(
                        s.y.toStringAsFixed(isComparing ? 2 : 1),
                        TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                      );
                    }).toList(),
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

  LineChartBarData _lineBar(List<FlSpot> spots, Color color, {required bool isFilled}) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, xPercentage, bar, index) => FlDotCirclePainter(
          radius: 3,
          color: color,
          strokeWidth: 0,
        ),
      ),
      belowBarData: BarAreaData(
        show: isFilled,
        gradient: LinearGradient(
          colors: [color.withAlpha(50), color.withAlpha(0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label, TextTheme textTheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: textTheme.labelSmall?.copyWith(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ─── Insights ─────────────────────────────────────────────────────────────

  Widget _buildInsightCard(ColorScheme colorScheme, TextTheme textTheme) {
    final isCircadian = _viewMode == InsightViewMode.circadian;
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
}

/// Internal helper for the metric picker.
class _SelectableMetric {
  final String label;
  final String displayName;
  final String emoji;
  const _SelectableMetric(this.label, this.displayName, this.emoji);
}
