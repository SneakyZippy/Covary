import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/database/app_database.dart';
import '../../services/app_usage_service.dart';
import 'app_category_manager_screen.dart';

enum TimeRange { last7d, last14d, last30d, custom }
enum Aggregation { daily, weekly }
enum DayFilter { all, workdays, weekends }

class UsageTrendsScreen extends StatefulWidget {
  const UsageTrendsScreen({super.key});

  @override
  State<UsageTrendsScreen> createState() => _UsageTrendsScreenState();
}

class _UsageTrendsScreenState extends State<UsageTrendsScreen> {
  bool _isLoading = true;
  
  // Filter State
  TimeRange _range = TimeRange.last7d;
  DateTimeRange? _customRange;
  Aggregation _aggregation = Aggregation.daily;
  DayFilter _dayFilter = DayFilter.all;
  Set<String> _selectedLabels = {'category_time:social', 'category_time:entertainment'};
  bool _showTop5 = false;
  bool _isStacked = false;

  // Processed Data
  List<_ChartSeries> _seriesData = [];
  List<DateTime> _xAxisDates = [];
  Map<int, int>? _hourlyData;
  DateTime? _selectedDayForHourly;
  double _maxY = 100;
  
  // Summary Stats
  int _totalMinutesThisPeriod = 0;
  String _topAppThisPeriod = 'N/A';
  double _deltaPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final db = context.read<AppDatabase>();
    
    // 1. Determine Date Range
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    switch (_range) {
      case TimeRange.last7d:
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        break;
      case TimeRange.last14d:
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 13));
        break;
      case TimeRange.last30d:
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
        break;
      case TimeRange.custom:
        start = _customRange?.start ?? DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        end = _customRange?.end ?? end;
        break;
    }

    // 2. Fetch Events
    final events = await db.getUsageEvents(start, end);
    
    // 3. Process & Group Data
    final Map<DateTime, Map<String, int>> dailyMap = {};
    final Set<String> availableAppLabels = {};
    final Map<String, int> totalUsageByLabel = {};

    for (final event in events) {
      final date = DateTime(event.timestamp.year, event.timestamp.month, event.timestamp.day);
      
      if (_dayFilter == DayFilter.workdays && (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday)) continue;
      if (_dayFilter == DayFilter.weekends && (date.weekday != DateTime.saturday && date.weekday != DateTime.sunday)) continue;

      final value = int.tryParse(event.value) ?? 0;
      
      dailyMap.putIfAbsent(date, () => {});
      dailyMap[date]![event.label] = value;
      
      if (event.label.startsWith('app_time:')) {
        availableAppLabels.add(event.label);
      }
      
      totalUsageByLabel[event.label] = (totalUsageByLabel[event.label] ?? 0) + value;
    }

    // Summary Stats Calculation
    _totalMinutesThisPeriod = totalUsageByLabel['total_screen_time'] ?? 0;
    if (availableAppLabels.isNotEmpty) {
      final topEntry = totalUsageByLabel.entries
          .where((e) => e.key.startsWith('app_time:'))
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
      if (topEntry.isNotEmpty) {
        _topAppThisPeriod = AppUsageService.readableName(topEntry.first.key.replaceFirst('app_time:', ''));
      }
    }

    // Delta Calculation (vs Previous Period)
    final periodDuration = end.difference(start);
    final prevStart = start.subtract(periodDuration);
    final prevEnd = start.subtract(const Duration(seconds: 1));
    final prevEvents = await db.getUsageEvents(prevStart, prevEnd);
    int prevTotal = 0;
    for (final e in prevEvents) {
      if (e.label == 'total_screen_time') {
        prevTotal += int.tryParse(e.value) ?? 0;
      }
    }
    if (prevTotal > 0) {
      _deltaPercentage = ((_totalMinutesThisPeriod - prevTotal) / prevTotal) * 100;
    } else {
      _deltaPercentage = 0.0;
    }

    // 4. Handle "Top 5" Logic
    if (_showTop5) {
      final sortedApps = totalUsageByLabel.entries
          .where((e) => e.key.startsWith('app_time:'))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      _selectedLabels = sortedApps.take(5).map((e) => e.key).toSet();
      if (_selectedLabels.isEmpty) {
        _selectedLabels = {'category_time:social', 'category_time:entertainment'};
      }
    }

    // 5. Aggregate by Period
    final List<_ChartSeries> newSeries = [];
    final List<DateTime> dates = [];
    
    if (_aggregation == Aggregation.daily) {
      int daysCount = end.difference(start).inDays + 1;
      for (int i = 0; i < daysCount; i++) {
        dates.add(start.add(Duration(days: i)));
      }
      
      for (final label in _selectedLabels) {
        final List<FlSpot> spots = [];
        for (int i = 0; i < dates.length; i++) {
          final val = dailyMap[dates[i]]?[label] ?? 0;
          spots.add(FlSpot(i.toDouble(), val.toDouble()));
        }
        newSeries.add(_ChartSeries(label: label, spots: spots));
      }
    } else {
      final Map<int, List<DateTime>> weeks = {};
      int daysCount = end.difference(start).inDays + 1;
      for (int i = 0; i < daysCount; i++) {
        final d = start.add(Duration(days: i));
        final weekNum = _getWeekNumber(d);
        final key = d.year * 100 + weekNum;
        weeks.putIfAbsent(key, () => []).add(d);
      }
      
      final sortedWeekKeys = weeks.keys.toList()..sort();
      for (final key in sortedWeekKeys) {
        dates.add(weeks[key]!.first);
      }
      
      for (final label in _selectedLabels) {
        final List<FlSpot> spots = [];
        for (int i = 0; i < sortedWeekKeys.length; i++) {
          final weekDates = weeks[sortedWeekKeys[i]]!;
          double sum = 0;
          for (final d in weekDates) {
            sum += dailyMap[d]?[label] ?? 0;
          }
          spots.add(FlSpot(i.toDouble(), sum / weekDates.length));
        }
        newSeries.add(_ChartSeries(label: label, spots: spots));
      }
    }

    double maxVal = 60;
    for (final s in newSeries) {
      for (final spot in s.spots) {
        if (spot.y > maxVal) maxVal = spot.y;
      }
    }

    if (mounted) {
      setState(() {
        _seriesData = newSeries;
        _xAxisDates = dates;
        _maxY = (maxVal * 1.2).ceilToDouble();
        _isLoading = false;
      });
    }
  }

  int _getWeekNumber(DateTime date) {
    int dayOfYear = int.parse(DateFormat('D').format(date));
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Usage Insights',
                            style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Your digital behavioral patterns',
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AppCategoryManagerScreen())),
                      icon: const Icon(Icons.settings_suggest_rounded),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _showAppSelector,
                      icon: const Icon(Icons.filter_list_rounded),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildSummaryCards()),
            SliverToBoxAdapter(child: _buildFilterBar()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Text('Trends', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: Icon(_isStacked ? Icons.stacked_bar_chart : Icons.show_chart),
                      onPressed: () => setState(() => _isStacked = !_isStacked),
                      tooltip: _isStacked ? 'Line Chart' : 'Stacked Bars',
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                height: 350,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : _seriesData.isEmpty || _seriesData.every((s) => s.spots.every((sp) => sp.y == 0))
                        ? _buildEmptyState()
                        : _buildChart(),
              ),
            ),
            if (_selectedDayForHourly != null)
              SliverToBoxAdapter(child: _buildHourlyBreakdown()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text('Key Insights', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ..._seriesData.map((s) => _buildStatCard(s)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _SummaryCard(
            title: 'Screen Time',
            value: '${(_totalMinutesThisPeriod / (_range == TimeRange.last7d ? 7 : 1)).toStringAsFixed(0)}m',
            subtitle: 'Avg. Daily',
            icon: Icons.timer_outlined,
            color: Colors.blue,
          ),
          _SummaryCard(
            title: 'Top App',
            value: _topAppThisPeriod,
            subtitle: 'Most Used',
            icon: Icons.star_border_rounded,
            color: Colors.amber,
          ),
          _SummaryCard(
            title: 'Usage Delta',
            value: '${_deltaPercentage >= 0 ? '+' : ''}${_deltaPercentage.toStringAsFixed(1)}%',
            subtitle: 'vs Prev. Period',
            icon: Icons.trending_up_rounded,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _RangeChip(label: '7D', selected: _range == TimeRange.last7d, onSelected: (_) => _updateRange(TimeRange.last7d)),
                const SizedBox(width: 8),
                _RangeChip(label: '14D', selected: _range == TimeRange.last14d, onSelected: (_) => _updateRange(TimeRange.last14d)),
                const SizedBox(width: 8),
                _RangeChip(label: '30D', selected: _range == TimeRange.last30d, onSelected: (_) => _updateRange(TimeRange.last30d)),
                const SizedBox(width: 8),
                _RangeChip(label: 'Custom', selected: _range == TimeRange.custom, onSelected: (_) => _pickCustomRange()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<Aggregation>(
                    segments: const [
                      ButtonSegment(value: Aggregation.daily, label: Text('Daily')),
                      ButtonSegment(value: Aggregation.weekly, label: Text('Weekly')),
                    ],
                    selected: {_aggregation},
                    onSelectionChanged: (set) {
                      setState(() => _aggregation = set.first);
                      _loadData();
                    },
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<DayFilter>(
                  initialValue: _dayFilter,
                  onSelected: (val) {
                    setState(() => _dayFilter = val);
                    _loadData();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: DayFilter.all, child: Text('All Days')),
                    const PopupMenuItem(value: DayFilter.workdays, child: Text('Workdays')),
                    const PopupMenuItem(value: DayFilter.weekends, child: Text('Weekends')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          _dayFilter == DayFilter.all ? 'Filter' : _dayFilter.name.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (_isStacked) return _buildBarChart();
    return _buildLineChart();
  }

  Widget _buildLineChart() {
    final colorScheme = Theme.of(context).colorScheme;
    return LineChart(
      LineChartData(
        maxY: _maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withAlpha(50),
            strokeWidth: 1,
          ),
        ),
        titlesData: _getTitlesData(),
        borderData: FlBorderData(show: false),
        lineBarsData: _seriesData.asMap().entries.map((e) {
          final color = Colors.primaries[e.key % Colors.primaries.length];
          return LineChartBarData(
            spots: e.value.spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: color,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [color.withAlpha(60), color.withAlpha(0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            shadow: Shadow(
              blurRadius: 10,
              color: color.withAlpha(50),
              offset: const Offset(0, 4),
            ),
          );
        }).toList(),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                FlLine(
                  color: barData.color?.withAlpha(100) ?? colorScheme.primary.withAlpha(100),
                  strokeWidth: 2,
                  dashArray: [5, 5],
                ),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 8,
                    color: Colors.white,
                    strokeWidth: 4,
                    strokeColor: barData.color ?? colorScheme.primary,
                  ),
                ),
              );
            }).toList();
          },
          touchCallback: (event, response) {
            if (response != null && response.lineBarSpots != null && event is FlTapUpEvent) {
              final index = response.lineBarSpots!.first.x.toInt();
              if (index >= 0 && index < _xAxisDates.length) {
                _loadHourlyData(_xAxisDates[index]);
              }
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (s) => colorScheme.surfaceContainerHigh.withAlpha(250),
            tooltipPadding: const EdgeInsets.all(12),
            tooltipMargin: 8,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) {
              // Sort spots by value descending for the tooltip
              final sortedSpots = List<LineBarSpot>.from(spots)
                ..sort((a, b) => b.y.compareTo(a.y));
              
              return sortedSpots.map((s) {
                final label = _seriesData[s.barIndex].label;
                final name = _getLabelName(label);
                return LineTooltipItem(
                  '$name: ',
                  TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10),
                  children: [
                    TextSpan(
                      text: '${s.y.toInt()} min',
                      style: TextStyle(
                        color: Colors.primaries[s.barIndex % Colors.primaries.length],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
      ),
      duration: const Duration(milliseconds: 250),
    );
  }

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        maxY: _maxY,
        gridData: const FlGridData(show: false),
        titlesData: _getTitlesData(),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(_xAxisDates.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: _seriesData.asMap().entries.map((e) {
              return BarChartRodData(
                toY: e.value.spots[i].y,
                color: Colors.primaries[e.key % Colors.primaries.length],
                width: 8,
                borderRadius: BorderRadius.circular(4),
              );
            }).toList(),
          );
        }),
      ),
    );
  }

  FlTitlesData _getTitlesData() {
    final textTheme = Theme.of(context).textTheme;
    return FlTitlesData(
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 32,
          interval: _aggregation == Aggregation.daily ? (_xAxisDates.length > 7 ? 2 : 1) : 1,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= _xAxisDates.length) return const SizedBox();
            final date = _xAxisDates[index];
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _aggregation == Aggregation.daily ? DateFormat('dd').format(date) : 'W${_getWeekNumber(date)}',
                style: textTheme.labelSmall?.copyWith(fontSize: 10),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (val, meta) => Text('${val.toInt()}m', style: textTheme.labelSmall?.copyWith(fontSize: 10)),
        ),
      ),
    );
  }

  Widget _buildHourlyBreakdown() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (_hourlyData == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(30),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Hourly Breakdown', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(DateFormat('MMM d').format(_selectedDayForHourly!), style: textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 2.5,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 4,
                      getTitlesWidget: (v, m) => Text('${v.toInt()}h', style: const TextStyle(fontSize: 8)),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _hourlyData!.entries.map((e) => BarChartGroupData(
                  x: e.key,
                  barRods: [BarChartRodData(toY: e.value.toDouble(), color: colorScheme.primary, width: 4)],
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(_ChartSeries series) {
    final colorScheme = Theme.of(context).colorScheme;
    final avg = series.spots.map((e) => e.y).reduce((a, b) => a + b) / series.spots.length;
    final color = Colors.primaries[_seriesData.indexOf(series) % Colors.primaries.length];
    
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withAlpha(40), child: Icon(Icons.circle, color: color, size: 12)),
        title: Text(_getLabelName(series.label), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        trailing: Text('${avg.toStringAsFixed(1)} min / day', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
      ),
    );
  }

  String _getLabelName(String label) {
    if (label == 'category_time:social') return 'Social';
    if (label == 'category_time:entertainment') return 'Entertainment';
    if (label.startsWith('category_time:')) return label.replaceFirst('category_time:', '').toUpperCase();
    return AppUsageService.readableName(label.replaceFirst('app_time:', ''));
  }

  void _updateRange(TimeRange range) {
    setState(() {
      _range = range;
      if (range != TimeRange.custom) _customRange = null;
    });
    _loadData();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime.now(), initialDateRange: _customRange);
    if (picked != null) {
      setState(() { _range = TimeRange.custom; _customRange = picked; });
      _loadData();
    }
  }

  Future<void> _loadHourlyData(DateTime date) async {
    final data = await context.read<AppUsageService>().fetchHourlyUsage(date);
    setState(() {
      _selectedDayForHourly = date;
      _hourlyData = data;
    });
  }

  void _showAppSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AppSelector(
        selected: _selectedLabels,
        showTop5: _showTop5,
        onChanged: (labels, top5) {
          setState(() { _selectedLabels = labels; _showTop5 = top5; });
          _loadData();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded, size: 48, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          const Text('No usage data found.'),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title, value, subtitle;
  final IconData icon;
  final Color color;
  const _SummaryCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Container(
      width: 145,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withAlpha(40),
            color.withAlpha(10),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withAlpha(50), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(20),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(150),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withAlpha(180),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Function(bool) onSelected;
  const _RangeChip({required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: onSelected,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _ChartSeries {
  final String label;
  final List<FlSpot> spots;
  _ChartSeries({required this.label, required this.spots});
}

class _AppSelector extends StatefulWidget {
  final Set<String> selected;
  final bool showTop5;
  final Function(Set<String>, bool) onChanged;
  const _AppSelector({required this.selected, required this.showTop5, required this.onChanged});

  @override
  State<_AppSelector> createState() => _AppSelectorState();
}

class _AppSelectorState extends State<_AppSelector> {
  late Set<String> _tempSelected;
  late bool _tempTop5;
  List<String> _availableApps = [];
  List<String> _availableCats = [];

  @override
  void initState() {
    super.initState();
    _tempSelected = Set.from(widget.selected);
    _tempTop5 = widget.showTop5;
    _loadAvailable();
  }

  Future<void> _loadAvailable() async {
    final db = context.read<AppDatabase>();
    final appUsage = context.read<AppUsageService>();
    final events = await db.getUsageEvents(DateTime.now().subtract(const Duration(days: 30)), DateTime.now());
    setState(() {
      _availableApps = events.where((e) => e.label.startsWith('app_time:')).map((e) => e.label).toSet().toList();
      _availableCats = appUsage.categories.keys.map((c) => 'category_time:$c').toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              Text('Customize View', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
            ]),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Auto-select Top 5 Apps'),
            value: _tempTop5,
            onChanged: (val) { setState(() => _tempTop5 = val); widget.onChanged(_tempSelected, _tempTop5); },
          ),
          if (!_tempTop5) Expanded(
            child: ListView(
              children: [
                _header('Categories'),
                ..._availableCats.map((c) => _check(c, c.replaceFirst('category_time:', '').toUpperCase())),
                _header('Individual Apps'),
                ..._availableApps.map((pkg) => _check(pkg, AppUsageService.readableName(pkg.replaceFirst('app_time:', '')))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(String t) => Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 8), child: Text(t, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)));
  Widget _check(String l, String n) => CheckboxListTile(
    title: Text(n),
    value: _tempSelected.contains(l),
    onChanged: (v) {
      setState(() {
        if (v == true) {
          _tempSelected.add(l);
        } else {
          _tempSelected.remove(l);
        }
      });
      widget.onChanged(_tempSelected, _tempTop5);
    },
    controlAffinity: ListTileControlAffinity.leading,
  );
}
