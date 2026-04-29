import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/database/app_database.dart';
import '../../services/app_usage_service.dart';

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
  Set<String> _selectedLabels = {'social_screen_time_minutes', 'entertainment_screen_time_minutes'};
  bool _showTop5 = false;

  // Processed Data
  List<_ChartSeries> _seriesData = [];
  List<DateTime> _xAxisDates = [];
  double _maxY = 100;

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
    // Map<Date, Map<Label, Value>>
    final Map<DateTime, Map<String, int>> dailyMap = {};
    final Set<String> availableAppLabels = {};

    for (final event in events) {
      final date = DateTime(event.timestamp.year, event.timestamp.month, event.timestamp.day);
      
      // Filter by Day Type (Workday/Weekend)
      if (_dayFilter == DayFilter.workdays && (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday)) continue;
      if (_dayFilter == DayFilter.weekends && (date.weekday != DateTime.saturday && date.weekday != DateTime.sunday)) continue;

      final value = int.tryParse(event.value) ?? 0;
      
      dailyMap.putIfAbsent(date, () => {});
      // Latest value per day
      dailyMap[date]![event.label] = value;
      
      if (event.label.startsWith('app_time:')) {
        availableAppLabels.add(event.label);
      }
    }

    // 4. Handle "Top 5" Logic
    if (_showTop5) {
      final Map<String, int> totalUsage = {};
      for (final label in availableAppLabels) {
        int total = 0;
        dailyMap.forEach((date, labels) {
          total += labels[label] ?? 0;
        });
        totalUsage[label] = total;
      }
      
      final sortedApps = totalUsage.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      _selectedLabels = sortedApps.take(5).map((e) => e.key).toSet();
      // If empty, fallback to categories
      if (_selectedLabels.isEmpty) {
        _selectedLabels = {'social_screen_time_minutes', 'entertainment_screen_time_minutes'};
      }
    }

    // 5. Aggregate by Period (Daily/Weekly)
    final List<_ChartSeries> newSeries = [];
    final List<DateTime> dates = [];
    
    if (_aggregation == Aggregation.daily) {
      // Generate daily points
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
      // Weekly Aggregation
      // Group dates by week (Monday as start)
      final Map<int, List<DateTime>> weeks = {};
      int daysCount = end.difference(start).inDays + 1;
      for (int i = 0; i < daysCount; i++) {
        final d = start.add(Duration(days: i));
        // Simple week key: year * 100 + weekNumber
        final weekNum = _getWeekNumber(d);
        final key = d.year * 100 + weekNum;
        weeks.putIfAbsent(key, () => []).add(d);
      }
      
      final sortedWeekKeys = weeks.keys.toList()..sort();
      for (final key in sortedWeekKeys) {
        dates.add(weeks[key]!.first); // Representative date for the week
      }
      
      for (final label in _selectedLabels) {
        final List<FlSpot> spots = [];
        for (int i = 0; i < sortedWeekKeys.length; i++) {
          final weekDates = weeks[sortedWeekKeys[i]]!;
          double sum = 0;
          int count = 0;
          for (final d in weekDates) {
            sum += dailyMap[d]?[label] ?? 0;
            count++;
          }
          final avg = count > 0 ? sum / count : 0.0;
          spots.add(FlSpot(i.toDouble(), avg));
        }
        newSeries.add(_ChartSeries(label: label, spots: spots));
      }
    }

    // Calculate MaxY for better scaling
    double maxVal = 60; // minimum scale
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
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Usage Analytics',
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Explore your behavioral trends.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _showAppSelector,
                    icon: const Icon(Icons.apps_rounded),
                    tooltip: 'Select Apps',
                  ),
                ],
              ),
            ),
            _buildFilterBar(),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _seriesData.isEmpty || _seriesData.every((s) => s.spots.every((sp) => sp.y == 0))
                  ? _buildEmptyState()
                  : _buildChartContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5)),
      ),
      child: Column(
        children: [
          // Row 1: Time Range
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _FilterChip(
                  label: '7 Days',
                  selected: _range == TimeRange.last7d,
                  onSelected: (_) => _updateRange(TimeRange.last7d),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '14 Days',
                  selected: _range == TimeRange.last14d,
                  onSelected: (_) => _updateRange(TimeRange.last14d),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '30 Days',
                  selected: _range == TimeRange.last30d,
                  onSelected: (_) => _updateRange(TimeRange.last30d),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: _range == TimeRange.custom && _customRange != null
                    ? '${DateFormat('MMM d').format(_customRange!.start)} - ${DateFormat('MMM d').format(_customRange!.end)}'
                    : 'Custom...',
                  selected: _range == TimeRange.custom,
                  onSelected: (_) => _pickCustomRange(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Row 2: Aggregation & Days
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<Aggregation>(
                    segments: const [
                      ButtonSegment(value: Aggregation.daily, label: Text('Daily'), icon: Icon(Icons.calendar_view_day_rounded)),
                      ButtonSegment(value: Aggregation.weekly, label: Text('Weekly'), icon: Icon(Icons.calendar_view_week_rounded)),
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
                const SizedBox(width: 12),
                PopupMenuButton<DayFilter>(
                  initialValue: _dayFilter,
                  onSelected: (val) {
                    setState(() => _dayFilter = val);
                    _loadData();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: DayFilter.all, child: Text('All Days')),
                    const PopupMenuItem(value: DayFilter.workdays, child: Text('Workdays Only')),
                    const PopupMenuItem(value: DayFilter.weekends, child: Text('Weekends Only')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.filter_list_rounded, size: 18, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          _dayFilter == DayFilter.all ? 'Days' : _dayFilter.name.toUpperCase(),
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

  Widget _buildChartContent() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.3,
            child: LineChart(
              LineChartData(
                maxY: _maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: colorScheme.outlineVariant,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: _aggregation == Aggregation.daily ? (_xAxisDates.length > 10 ? 5 : 1) : 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= _xAxisDates.length) return const SizedBox();
                        final date = _xAxisDates[index];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _aggregation == Aggregation.daily 
                              ? DateFormat('dd').format(date)
                              : 'W${_getWeekNumber(date)}',
                            style: textTheme.bodySmall?.copyWith(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text('${value.toInt()}m', style: textTheme.bodySmall?.copyWith(fontSize: 10)),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(
                  verticalLines: _aggregation == Aggregation.daily ? _xAxisDates.asMap().entries
                    .where((e) => e.value.weekday == DateTime.saturday || e.value.weekday == DateTime.sunday)
                    .map((e) => VerticalLine(
                      x: e.key.toDouble(),
                      color: colorScheme.primary.withAlpha(15),
                      strokeWidth: 20, // Adjust based on width
                    )).toList() : [],
                ),
                lineBarsData: _seriesData.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  final color = Colors.primaries[i % Colors.primaries.length];
                  return LineChartBarData(
                    spots: s.spots,
                    isCurved: true,
                    color: color,
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3,
                        color: Colors.white,
                        strokeWidth: 2.5,
                        strokeColor: color,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true, 
                      color: color.withAlpha(25),
                      gradient: LinearGradient(
                        colors: [color.withAlpha(40), color.withAlpha(0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  );
                }).toList(),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                    return spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        FlLine(color: colorScheme.primary.withAlpha(80), strokeWidth: 2, dashArray: [5, 5]),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 6,
                            color: barData.color ?? colorScheme.primary,
                            strokeWidth: 3,
                            strokeColor: Colors.white,
                          ),
                        ),
                      );
                    }).toList();
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => colorScheme.surfaceContainerHigh,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final label = _seriesData[spot.barIndex].label;
                        final name = label == 'social_screen_time_minutes' ? 'Social' :
                                   label == 'entertainment_screen_time_minutes' ? 'Ent.' :
                                   AppUsageService.readableName(label.replaceFirst('app_time:', ''));
                        return LineTooltipItem(
                          '$name\n',
                          textTheme.labelSmall!.copyWith(color: colorScheme.onSurfaceVariant),
                          children: [
                            TextSpan(
                              text: '${spot.y.toInt()} min',
                              style: textTheme.titleMedium!.copyWith(
                                color: Colors.primaries[spot.barIndex % Colors.primaries.length],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildLegend(),
          const SizedBox(height: 32),
          Text('Key Insights', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._seriesData.map((s) => _buildMiniStat(s)),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _seriesData.asMap().entries.map((e) {
        final label = e.value.label;
        final name = label == 'social_screen_time_minutes' ? 'Social' :
                   label == 'entertainment_screen_time_minutes' ? 'Ent.' :
                   AppUsageService.readableName(label.replaceFirst('app_time:', ''));
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.primaries[e.key % Colors.primaries.length], shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(name, style: Theme.of(context).textTheme.bodySmall),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMiniStat(_ChartSeries series) {
    final colorScheme = Theme.of(context).colorScheme;
    final avg = series.spots.map((e) => e.y).reduce((a, b) => a + b) / series.spots.length;
    final name = series.label == 'social_screen_time_minutes' ? 'Social' :
               series.label == 'entertainment_screen_time_minutes' ? 'Entertainment' :
               AppUsageService.readableName(series.label.replaceFirst('app_time:', ''));

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withAlpha(100),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text('${avg.toStringAsFixed(1)} m / ${_aggregation == Aggregation.daily ? 'day' : 'week'}'),
      ),
    );
  }

  void _updateRange(TimeRange range) {
    setState(() {
      _range = range;
      if (range != TimeRange.custom) _customRange = null;
    });
    _loadData();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _customRange,
    );
    if (picked != null) {
      setState(() {
        _range = TimeRange.custom;
        _customRange = picked;
      });
      _loadData();
    }
  }

  void _showAppSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AppSelector(
        selected: _selectedLabels,
        showTop5: _showTop5,
        onChanged: (labels, top5) {
          setState(() {
            _selectedLabels = labels;
            _showTop5 = top5;
          });
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
          const Text('No data found for this filter.'),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Function(bool) onSelected;

  const _FilterChip({required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: onSelected,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ChartSeries {
  final String label;
  final List<FlSpot> spots;
  _ChartSeries({required this.label, required this.spots});
}

// Bottom Sheet for App Selection
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

  @override
  void initState() {
    super.initState();
    _tempSelected = Set.from(widget.selected);
    _tempTop5 = widget.showTop5;
    _loadAvailableApps();
  }

  Future<void> _loadAvailableApps() async {
    final db = context.read<AppDatabase>();
    final events = await db.getUsageEvents(DateTime.now().subtract(const Duration(days: 30)), DateTime.now());
    final apps = events.where((e) => e.label.startsWith('app_time:')).map((e) => e.label).toSet().toList();
    setState(() => _availableApps = apps);
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
            child: Row(
              children: [
                Text('Visualize Data', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Auto-select Top 5 Apps'),
            subtitle: const Text('Shows the most used apps in this period'),
            value: _tempTop5,
            onChanged: (val) {
              setState(() => _tempTop5 = val);
              widget.onChanged(_tempSelected, _tempTop5);
            },
          ),
          if (!_tempTop5) ...[
            Expanded(
              child: ListView(
                children: [
                  _buildSectionHeader('Categories'),
                  _buildCheckbox('social_screen_time_minutes', 'All Social Media'),
                  _buildCheckbox('entertainment_screen_time_minutes', 'All Entertainment'),
                  _buildSectionHeader('Individual Apps'),
                  ..._availableApps.map((pkg) => _buildCheckbox(pkg, AppUsageService.readableName(pkg.replaceFirst('app_time:', '')))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCheckbox(String label, String name) {
    return CheckboxListTile(
      title: Text(name),
      value: _tempSelected.contains(label),
      onChanged: (val) {
        setState(() {
          if (val == true) {
            _tempSelected.add(label);
          } else {
            _tempSelected.remove(label);
          }
        });
        widget.onChanged(_tempSelected, _tempTop5);
      },
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
