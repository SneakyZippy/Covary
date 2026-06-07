import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/analytics_service.dart';
import '../../services/metric_service.dart';
import '../../ui/theme/design_system.dart';

enum LagViewMode { daily, hourly }

class LaggedTrendScreen extends StatefulWidget {
  const LaggedTrendScreen({super.key});

  @override
  State<LaggedTrendScreen> createState() => _LaggedTrendScreenState();
}

class _LaggedTrendScreenState extends State<LaggedTrendScreen>
    with TickerProviderStateMixin {
  // Available metric labels for selection
  List<_SelectableMetric> _allMetrics = [];

  // Selected pair
  String? _labelA;
  String? _labelB;

  // Data
  Map<DateTime, double> _seriesA = {};
  Map<DateTime, double> _seriesB = {};
  int _bestLag = 0;
  double _peakCorrelation = 0.0;
  int _selectedLag = 0;
  double _currentCorrelation = 0.0;
  bool _autoDetect = true;
  bool _alignLag = true;
  LagViewMode _viewMode = LagViewMode.daily;
  bool _isLoading = true;
  bool _isAutoDetecting = false;

  // Date range: 7, 14, 30 days
  int _dayRange = 14;
  static const List<int> _dayRangeOptions = [7, 14, 30];

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  // Passive metrics matching correlation_matrix_screen.dart
  static const _passiveLabels = <_SelectableMetric>[
    _SelectableMetric('category_time:social', 'Social Media', '📱'),
    _SelectableMetric('total_screen_time', 'Screen Time', '⌛'),
    _SelectableMetric('category_time:entertainment', 'Entertainment', '🎬'),
    _SelectableMetric('sleep_duration_hours', 'Sleep Duration', '🛌'),
    _SelectableMetric('sleep_bedtime', 'Bedtime', '🛌'),
    _SelectableMetric('sleep_wakeup', 'Wake-up Time', 'sunny'),
    _SelectableMetric('sleep_midpoint', 'Sleep Midpoint', 'star'),
    _SelectableMetric('step_count', 'Steps', '🏃'),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
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
      if (_allMetrics.length >= 2) {
        _labelA = _allMetrics[0].label;
        _labelB = _allMetrics[1].label;
      }
    });

    _loadData();
  }

  Future<void> _autoDetectBestPair() async {
    if (_allMetrics.length < 2) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isAutoDetecting = true;
      _autoDetect = true;
    });
    final analytics = context.read<AnalyticsService>();
    final labels = _allMetrics.map((m) => m.label).toList();
    final best = await analytics.findMostCorrelatedPair(labels);

    if (best != null && mounted) {
      setState(() {
        _labelA = best.labelA;
        _labelB = best.labelB;
      });
      await _loadData();
    } else if (mounted) {
      // Fallback: pick first two
      setState(() {
        _labelA = _allMetrics[0].label;
        _labelB = _allMetrics[1].label;
        _isAutoDetecting = false;
      });
      await _loadData();
    }
  }

  Future<void> _loadData() async {
    if (_labelA == null || _labelB == null) return;
    setState(() => _isLoading = true);

    final analytics = context.read<AnalyticsService>();

    if (_viewMode == LagViewMode.daily) {
      final seriesA = await analytics.getDailyTimeSeries(_labelA!, normalize: true, lastNDays: _dayRange);
      final seriesB = await analytics.getDailyTimeSeries(_labelB!, normalize: true, lastNDays: _dayRange);
      final lagResult = await analytics.findPeakLagCorrelation(metricA: _labelA!, metricB: _labelB!);

      if (mounted) {
        setState(() {
          _seriesA = seriesA;
          _seriesB = seriesB;
          _bestLag = lagResult?.bestLag ?? 0;
          _peakCorrelation = lagResult?.correlation ?? 0.0;
          if (_autoDetect) {
            _selectedLag = _bestLag;
            _currentCorrelation = _peakCorrelation;
          }
          _isLoading = false;
          _isAutoDetecting = false;
        });
      }
    } else {
      // Hourly mode
      final seriesA = await analytics.getRawHourlyTimeline(_labelA!, normalize: true, lastNDays: 3);
      final seriesB = await analytics.getRawHourlyTimeline(_labelB!, normalize: true, lastNDays: 3);
      final lagResult = await analytics.findPeakLagCorrelationHourly(metricA: _labelA!, metricB: _labelB!);

      if (mounted) {
        setState(() {
          _seriesA = seriesA;
          _seriesB = seriesB;
          _bestLag = lagResult?.bestLagHours ?? 0;
          _peakCorrelation = lagResult?.correlation ?? 0.0;
          if (_autoDetect) {
            _selectedLag = _bestLag;
            _currentCorrelation = _peakCorrelation;
          }
          _isLoading = false;
          _isAutoDetecting = false;
        });
      }
    }

    if (!_autoDetect) {
      final maxLag = _viewMode == LagViewMode.daily ? 7 : 12;
      if (_selectedLag > maxLag) {
        _selectedLag = maxLag;
      }
      await _updateCorrelationForLag(_selectedLag);
    }

    _fadeController.forward(from: 0);
  }

  Future<void> _updateCorrelationForLag(int lag) async {
    if (_labelA == null || _labelB == null) return;
    final analytics = context.read<AnalyticsService>();
    final double? r;
    if (_viewMode == LagViewMode.daily) {
      r = await analytics.calculateSpearmanCorrelation(
        metricA: _labelA!,
        metricB: _labelB!,
        lagDays: lag,
      );
    } else {
      r = await analytics.calculateSpearmanCorrelationHourly(
        metricA: _labelA!,
        metricB: _labelB!,
        lagHours: lag,
      );
    }
    if (mounted) {
      setState(() {
        _currentCorrelation = r ?? 0.0;
      });
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
        title: const Text('Lagged Trend'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'Auto-detect best pair',
            onPressed: _autoDetectBestPair,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _isAutoDetecting
                        ? 'Scanning metric pairs…'
                        : 'Loading trend data…',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : _allMetrics.length < 2
              ? _buildEmptyState(textTheme)
              : FadeTransition(
                  opacity: _fadeAnim,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    children: [
                      _buildViewToggle(colorScheme, textTheme),
                      const SizedBox(height: 16),
                      _buildMetricSelectors(colorScheme, textTheme),
                      const SizedBox(height: 16),
                      if (_viewMode == LagViewMode.daily) ...[
                        _buildDayRangeSelector(colorScheme, textTheme),
                        const SizedBox(height: 20),
                      ],
                      _buildChartCard(colorScheme, textTheme),
                      const SizedBox(height: 16),
                      _buildLagControllerCard(colorScheme, textTheme),
                      const SizedBox(height: 16),
                      _buildInsightCard(colorScheme, textTheme),
                      const SizedBox(height: 16),
                      _buildStatsRow(colorScheme, textTheme),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  // ─── View Toggle ──────────────────────────────────────────────────────────

  Widget _buildViewToggle(ColorScheme colorScheme, TextTheme textTheme) {
    return SegmentedButton<LagViewMode>(
      segments: const [
        ButtonSegment(
          value: LagViewMode.daily,
          label: Text('Daily Lags'),
          icon: Icon(Icons.calendar_view_day_rounded),
        ),
        ButtonSegment(
          value: LagViewMode.hourly,
          label: Text('Hourly Lags'),
          icon: Icon(Icons.more_time_rounded),
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
            label: _labelA,
            color: colorScheme.primary,
            hint: 'Metric A',
            colorScheme: colorScheme,
            textTheme: textTheme,
            onSelect: (label) {
              setState(() => _labelA = label);
              _loadData();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.compare_arrows_rounded,
              size: 20, color: colorScheme.onSurfaceVariant),
        ),
        Expanded(
          child: _buildMetricChip(
            label: _labelB,
            color: CovaryDesignSystem.secondary,
            hint: 'Metric B',
            colorScheme: colorScheme,
            textTheme: textTheme,
            onSelect: (label) {
              setState(() => _labelB = label);
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
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required ValueChanged<String> onSelect,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showMetricPicker(color, onSelect),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label != null ? _displayName(label).toUpperCase() : hint,
                style: textTheme.labelSmall?.copyWith(
                  color: label != null ? Colors.white : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.unfold_more_rounded, size: 16, color: color.withAlpha(150)),
          ],
        ),
      ),
    );
  }

  void _showMetricPicker(Color accent, ValueChanged<String> onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: CovaryDesignSystem.level1Surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('Select Metric',
                  style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _allMetrics.length,
                  itemBuilder: (_, i) {
                    final m = _allMetrics[i];
                    final isSelected = m.label == _labelA || m.label == _labelB;
                    return ListTile(
                      leading: Text(m.emoji, style: const TextStyle(fontSize: 20)),
                      title: Text(m.displayName),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: accent, size: 20)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        onSelect(m.label);
                      },
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

  // ─── Day Range ────────────────────────────────────────────────────────────

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
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }),
      ],
    );
  }

  // ─── Chart ────────────────────────────────────────────────────────────────

  Widget _buildChartCard(ColorScheme colorScheme, TextTheme textTheme) {
    // Build sorted date list (union of both series)
    final allDates = <DateTime>{..._seriesA.keys, ..._seriesB.keys}.toList()
      ..sort();

    if (allDates.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text('Not enough data to chart.',
            style: textTheme.bodySmall?.copyWith(color: Colors.grey)),
      );
    }

    final spotsA = <FlSpot>[];
    final spotsB = <FlSpot>[];

    for (int i = 0; i < allDates.length; i++) {
      final d = allDates[i];
      if (_seriesA.containsKey(d)) spotsA.add(FlSpot(i.toDouble(), _seriesA[d]!));
      if (_alignLag) {
        final shiftedDate = _viewMode == LagViewMode.daily
            ? d.add(Duration(days: _selectedLag))
            : d.add(Duration(hours: _selectedLag));
        if (_seriesB.containsKey(shiftedDate)) {
          spotsB.add(FlSpot(i.toDouble(), _seriesB[shiftedDate]!));
        }
      } else {
        if (_seriesB.containsKey(d)) {
          spotsB.add(FlSpot(i.toDouble(), _seriesB[d]!));
        }
      }
    }

    final accentA = colorScheme.primary;
    const accentB = CovaryDesignSystem.secondary;

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
          // Header + Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lagged Trend',
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 2),
                      Text(
                        _viewMode == LagViewMode.daily
                            ? (_selectedLag == 0 ? 'SAME-DAY ANALYSIS' : '$_selectedLag-DAY DELTA ANALYSIS${_alignLag ? ' (ALIGNED)' : ''}')
                            : (_selectedLag == 0 ? 'SAME-HOUR ANALYSIS' : '$_selectedLag-HOUR DELTA ANALYSIS${_alignLag ? ' (ALIGNED)' : ''}'),
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 9,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _legendDot(accentA, _displayName(_labelA ?? '').toUpperCase(), textTheme),
                    const SizedBox(height: 4),
                    _legendDot(accentB, _displayName(_labelB ?? '').toUpperCase(), textTheme),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Chart
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 1,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 0.25,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withAlpha(15),
                    strokeWidth: 0.5,
                  ),
                  drawVerticalLine: false,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 0.5,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(1),
                        style: TextStyle(fontSize: 9, color: Colors.white.withAlpha(80)),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: max(1, (allDates.length / 6).ceilToDouble()),
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= allDates.length) return const SizedBox();
                        final date = allDates[idx];
                        
                        if (_viewMode == LagViewMode.hourly) {
                          if (idx % 6 != 0 && date.hour != 0) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              date.hour == 0 ? DateFormat('E').format(date) : '${date.hour}h',
                              style: TextStyle(fontSize: 8, color: Colors.white.withAlpha(100)),
                            ),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('d MMM').format(date),
                            style: TextStyle(fontSize: 8, color: Colors.white.withAlpha(100)),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  _lineBar(spotsA, accentA),
                  _lineBar(spotsB, accentB),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => CovaryDesignSystem.level1Surface,
                    getTooltipItems: (spots) => spots.map((s) {
                      final color = s.barIndex == 0 ? accentA : accentB;
                      return LineTooltipItem(
                        s.y.toStringAsFixed(2),
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

  LineChartBarData _lineBar(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, xPercentage, bar, index) => FlDotCirclePainter(
          radius: 2.5,
          color: color,
          strokeWidth: 0,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
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
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: textTheme.labelSmall?.copyWith(fontSize: 9, color: Colors.white.withAlpha(180))),
      ],
    );
  }

  // ─── Lag Configuration Card ───────────────────────────────────────────────

  Widget _buildLagControllerCard(ColorScheme colorScheme, TextTheme textTheme) {
    final maxLag = _viewMode == LagViewMode.daily ? 7.0 : 12.0;
    final unitLabel = _viewMode == LagViewMode.daily
        ? (_selectedLag == 1 ? 'day' : 'days')
        : (_selectedLag == 1 ? 'hour' : 'hours');
        
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CovaryDesignSystem.surfaceContainerHighest.withAlpha(40),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lag Configuration',
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Text(
                    'Auto-detect',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: _autoDetect,
                    activeThumbColor: colorScheme.primary,
                    onChanged: (val) {
                      setState(() {
                        _autoDetect = val;
                        if (val) {
                          _selectedLag = _bestLag;
                          _currentCorrelation = _peakCorrelation;
                        }
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Lag Offset:',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              Text(
                '$_selectedLag $unitLabel',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: _selectedLag.toDouble().clamp(0.0, maxLag),
            min: 0.0,
            max: maxLag,
            divisions: maxLag.toInt(),
            label: '$_selectedLag',
            activeColor: _autoDetect ? colorScheme.primary.withAlpha(120) : colorScheme.primary,
            inactiveColor: Colors.white10,
            onChanged: _autoDetect
                ? null
                : (val) {
                    final newLag = val.round();
                    setState(() {
                      _selectedLag = newLag;
                    });
                    _updateCorrelationForLag(newLag);
                  },
          ),
          const Divider(color: Colors.white10, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Align Lag on Chart',
                      style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Visually shifts the lines to show alignment',
                      style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _alignLag,
                activeThumbColor: CovaryDesignSystem.secondary,
                onChanged: (val) {
                  setState(() {
                    _alignLag = val;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Insight Card ─────────────────────────────────────────────────────────

  Widget _buildInsightCard(ColorScheme colorScheme, TextTheme textTheme) {
    final nameA = _displayName(_labelA ?? '');
    final nameB = _displayName(_labelB ?? '');

    final String insightText;
    if (_currentCorrelation.abs() < 0.15) {
      insightText = 'There is no clear correlation or lagged relationship between your $nameA and $nameB in this window.';
    } else {
      final direction = _currentCorrelation >= 0 ? 'peaks' : 'dips';
      final relationship = _currentCorrelation >= 0 ? 'high' : 'low';
      final unit = _viewMode == LagViewMode.daily
          ? (_selectedLag == 1 ? 'day' : 'days')
          : (_selectedLag == 1 ? 'hour' : 'hours');

      insightText = _selectedLag == 0
          ? 'Your $nameB $direction on ${_viewMode == LagViewMode.daily ? 'days' : 'hours'} with $relationship $nameA.'
          : 'Your $nameB $direction $_selectedLag $unit after $relationship $nameA.';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withAlpha(20),
                CovaryDesignSystem.surfaceContainerHighest.withAlpha(60),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(20)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.insights_rounded, color: colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withAlpha(200),
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'Lagged Window: '),
                      TextSpan(
                        text: _selectedLag == 0 
                            ? (_viewMode == LagViewMode.daily ? 'same day' : 'same hour') 
                            : '+$_selectedLag ${_viewMode == LagViewMode.daily ? (_selectedLag == 1 ? 'day' : 'days') : (_selectedLag == 1 ? 'hour' : 'hours')}',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(text: '. $insightText'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Stats Row ────────────────────────────────────────────────────────────

  Widget _buildStatsRow(ColorScheme colorScheme, TextTheme textTheme) {
    final lagUnitLabel = _viewMode == LagViewMode.daily
        ? (_selectedLag == 1 ? 'DAY' : 'DAYS')
        : (_selectedLag == 1 ? 'HOUR' : 'HOURS');
        
    return Row(
      children: [
        Expanded(child: _buildCorrelationCard(colorScheme, textTheme)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(
          _autoDetect ? 'OPTIMAL LAG' : 'SELECTED LAG',
          '$_selectedLag $lagUnitLabel',
          _viewMode == LagViewMode.daily ? (_selectedLag / 7.0) : (_selectedLag / 12.0),
          CovaryDesignSystem.secondary,
          colorScheme,
          textTheme,
        )),
      ],
    );
  }

  Widget _buildCorrelationCard(ColorScheme colorScheme, TextTheme textTheme) {
    final double correlation = _currentCorrelation;
    final String title = _autoDetect ? 'PEAK CORRELATION' : 'LAGGED CORRELATION';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CovaryDesignSystem.surfaceContainerHighest.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 9, color: Colors.white.withAlpha(120), letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(correlation.toStringAsFixed(2),
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold, fontSize: 28)),
              const Spacer(),
              _getCorrelationStrengthBadge(correlation, textTheme),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: const LinearGradient(
                    colors: [
                      Colors.orange,
                      Colors.grey,
                      Colors.cyan,
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment(((correlation + 1.0) / 2.0 * 2.0 - 1.0).clamp(-1.0, 1.0), 0.0),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black45, blurRadius: 2, spreadRadius: 1),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _getCorrelationStrengthBadge(double r, TextTheme textTheme) {
    final absR = r.abs();
    final String label;
    final Color color;
    if (absR < 0.15) {
      label = 'None';
      color = Colors.grey;
    } else if (absR < 0.35) {
      label = 'Weak';
      color = Colors.blueGrey;
    } else if (absR < 0.55) {
      label = 'Moderate';
      color = Colors.indigo;
    } else {
      label = 'Strong';
      color = r >= 0 ? Colors.cyan : Colors.orange;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label.toUpperCase(),
        style: textTheme.labelSmall?.copyWith(fontSize: 8, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    double progress,
    Color accent,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CovaryDesignSystem.surfaceContainerHighest.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 9, color: Colors.white.withAlpha(120), letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(value,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold, fontSize: 28)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: Colors.white.withAlpha(15),
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty State ──────────────────────────────────────────────────────────

  Widget _buildEmptyState(TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timeline_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Not enough metrics yet.',
                textAlign: TextAlign.center, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Enable at least two metrics and log data for 3+ days to see lagged trend analysis.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
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
