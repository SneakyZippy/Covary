import 'dart:math';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import '../data/database/app_database.dart' show Event;
import '../data/repositories/event_repository.dart';
import '../data/repositories/metric_repository.dart';
import '../data/models/enums.dart';
import '../data/metric_presets.dart';


/// Service responsible for on-device statistical analysis and correlations.
class AnalyticsService {
  final EventRepository _eventRepo;
  final MetricRepository _metricRepo;

  AnalyticsService(this._eventRepo, this._metricRepo);

  /// Minimum overlapping data points required before a correlation is
  /// reported. Below this, Spearman's rho is dominated by a handful of
  /// discrete outcomes and routinely hits +/-1.0 by chance alone.
  static const int _minSampleSize = 7;

  /// Midnight [days] days before today, used to restrict a correlation
  /// calculation to a recent window instead of the entire logged history.
  DateTime _dayCutoff(int days) {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: days));
  }

  /// Calculates the Spearman Rank Correlation between two metrics.
  ///
  /// [metricA] and [metricB] are the labels of the metrics to correlate.
  /// [lagDays] specifies the time offset (0-7 days). Positive value means
  /// [metricA] at Day T is correlated with [metricB] at Day T + lagDays.
  /// [lastNDays], if provided, restricts the calculation to that trailing
  /// window instead of the full logged history.
  Future<double?> calculateSpearmanCorrelation({
    required String metricA,
    required String metricB,
    int lagDays = 0,
    int? lastNDays,
  }) async {
    // 1. Fetch data for both metrics
    final eventsA = await _eventRepo.getEventsByLabel(metricA);
    final eventsB = await _eventRepo.getEventsByLabel(metricB);

    if (eventsA.isEmpty || eventsB.isEmpty) return null;

    // 2. Aggregate by day
    Map<DateTime, double> dailyA = await _aggregateByDay(eventsA);
    Map<DateTime, double> dailyB = await _aggregateByDay(eventsB);

    if (lastNDays != null) {
      final cutoff = _dayCutoff(lastNDays);
      dailyA = Map.fromEntries(dailyA.entries.where((e) => !e.key.isBefore(cutoff)));
      dailyB = Map.fromEntries(dailyB.entries.where((e) => !e.key.isBefore(cutoff)));
    }

    final zeroFillA = await _isCounterOrYesNo(metricA, eventsA.first.category);
    final zeroFillB = await _isCounterOrYesNo(metricB, eventsB.first.category);

    // 3. Align dates with lag and zero-fill if needed
    final aligned = _alignAndZeroFill(
      dailyA: dailyA,
      dailyB: dailyB,
      zeroFillA: zeroFillA,
      zeroFillB: zeroFillB,
      lagDays: lagDays,
    );

    final listA = aligned.listA;
    final listB = aligned.listB;

    if (listA.length < _minSampleSize) return null;

    // 4. Calculate Spearman Rank Correlation
    return _computeSpearman(listA, listB);
  }

  /// Calculates the Spearman Rank Correlation between two metrics at hourly resolution.
  /// 
  /// [lagHours] specifies the time offset in hours.
  Future<double?> calculateSpearmanCorrelationHourly({
    required String metricA,
    required String metricB,
    int lagHours = 0,
    int lastNDays = 7,
  }) async {
    final eventsA = await _eventRepo.getEventsByLabel(metricA);
    final eventsB = await _eventRepo.getEventsByLabel(metricB);

    if (eventsA.isEmpty || eventsB.isEmpty) return null;

    final Map<DateTime, double> hourlyA = _aggregateByRawHour(eventsA);
    final Map<DateTime, double> hourlyB = _aggregateByRawHour(eventsB);

    final List<double> listA = [];
    final List<double> listB = [];

    for (final dateA in hourlyA.keys) {
      final dateB = dateA.add(Duration(hours: lagHours));
      if (hourlyB.containsKey(dateB)) {
        listA.add(hourlyA[dateA]!);
        listB.add(hourlyB[dateB]!);
      }
    }

    if (listA.length < _minSampleSize) return null;
    return _computeSpearman(listA, listB);
  }

  /// Sweeps hourly lag 0–12 hours and returns the peak.
  Future<({int bestLagHours, double correlation, Map<int, double?> allCorrelations})?>
      findPeakLagCorrelationHourly({
    required String metricA,
    required String metricB,
    int maxLagHours = 12,
  }) async {
    final Map<int, double?> all = {};
    int bestLag = 0;
    double bestAbs = -1;
    double bestVal = 0;

    for (int lag = 0; lag <= maxLagHours; lag++) {
      final r = await calculateSpearmanCorrelationHourly(
        metricA: metricA,
        metricB: metricB,
        lagHours: lag,
      );
      all[lag] = r;
      if (r != null && r.abs() > bestAbs) {
        bestAbs = r.abs();
        bestVal = r;
        bestLag = lag;
      }
    }

    if (bestAbs < 0) return null;

    return (bestLagHours: bestLag, correlation: bestVal, allCorrelations: all);
  }

  // ---------------------------------------------------------------------------
  // Lagged Trend Analysis
  // ---------------------------------------------------------------------------

  /// Returns the daily aggregated time series for a metric, optionally
  /// normalized to 0.0–1.0 range via min-max scaling.
  ///
  /// Used by the Lagged Trend screen to plot two metrics on the same Y-axis.
  Future<Map<DateTime, double>> getDailyTimeSeries(
    String label, {
    bool normalize = false,
    int? lastNDays = 14,
    double? minValue,
    double? maxValue,
  }) async {
    final events = await _eventRepo.getEventsByLabel(label);
    if (events.isEmpty) return {};

    final daily = await _aggregateByDay(events);

    // Filter to last N days if specified (> 0)
    if (lastNDays != null && lastNDays > 0) {
      final cutoff = clock.now().subtract(Duration(days: lastNDays));
      final cutoffDate = DateTime(cutoff.year, cutoff.month, cutoff.day);
      daily.removeWhere((date, _) => date.isBefore(cutoffDate));
    }

    // Zero-fill for counters/behavior/nutrition (things that have a "none" state)
    final firstEvent = events.first;
    bool shouldZeroFill = await _isCounterOrYesNo(firstEvent.label, firstEvent.category);

    int effectiveDays = (lastNDays != null && lastNDays > 0)
        ? lastNDays
        : (daily.isNotEmpty
            ? () {
                final earliest = daily.keys.reduce((a, b) => a.isBefore(b) ? a : b);
                final today = clock.now();
                return DateTime.utc(today.year, today.month, today.day)
                        .difference(DateTime.utc(earliest.year, earliest.month, earliest.day))
                        .inDays +
                    1;
              }()
            : 0);
                         
    Map<DateTime, double> result = (shouldZeroFill && effectiveDays > 0)
        ? _zeroFillDaily(daily, effectiveDays)
        : daily;

    if (!normalize || result.isEmpty) return result;

    final values = result.values.toList();
    final actualMin = minValue ?? values.reduce(min);
    final actualMax = maxValue ?? values.reduce(max);
    final range = actualMax - actualMin;

    if (range == 0) {
      return result.map((k, _) => MapEntry(k, 0.5));
    }

    return result.map((k, v) => MapEntry(k, ((v - actualMin) / range).clamp(0.0, 1.0)));
  }

  /// Fills gaps in a daily time series with 0.0.
  Map<DateTime, double> _zeroFillDaily(Map<DateTime, double> data, int lastNDays) {
    final Map<DateTime, double> filled = {};
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    
    for (int i = 0; i < lastNDays; i++) {
      final date = DateTime(today.year, today.month, today.day - i);
      filled[date] = data[date] ?? 0.0;
    }
    return filled;
  }

  /// Returns the hourly aggregated time series for a metric across the last N days,
  /// optionally normalized to 0.0–1.0 range via min-max scaling.
  /// 
  /// The key is the hour of the day (0-23).
  Future<Map<int, double>> getHourlyTimeSeries(
    String label, {
    bool normalize = false,
    int? lastNDays = 14,
    double? minValue,
    double? maxValue,
  }) async {
    final events = await _eventRepo.getEventsByLabel(label);
    if (events.isEmpty) return {};

    // Filter to last N days if specified (> 0)
    final filteredEvents = (lastNDays != null && lastNDays > 0)
        ? events.where((e) => e.timestamp.isAfter(clock.now().subtract(Duration(days: lastNDays)))).toList()
        : events;
    if (filteredEvents.isEmpty) return {};

    final hourly = await _aggregateByHour(filteredEvents);

    if (!normalize || hourly.isEmpty) return hourly;

    // Min-max normalization
    final values = hourly.values.toList();
    final actualMin = minValue ?? values.reduce(min);
    final actualMax = maxValue ?? values.reduce(max);
    final range = actualMax - actualMin;

    if (range == 0) {
      return hourly.map((k, _) => MapEntry(k, 0.5));
    }

    return hourly.map((k, v) => MapEntry(k, ((v - actualMin) / range).clamp(0.0, 1.0)));
  }

  /// Returns the weekly aggregated time series for a metric, optionally
  /// normalized to 0.0–1.0 range via min-max scaling.
  ///
  /// Grouped by the Monday of each calendar week.
  Future<Map<DateTime, double>> getWeeklyTimeSeries(
    String label, {
    bool normalize = false,
    int? lastNDays = 30,
    double? minValue,
    double? maxValue,
  }) async {
    final daily = await getDailyTimeSeries(label, normalize: false, lastNDays: lastNDays);
    if (daily.isEmpty) return {};

    final Map<DateTime, List<double>> weeklyGroups = {};
    daily.forEach((date, val) {
      final monday = date.subtract(Duration(days: date.weekday - 1));
      final mondayDate = DateTime(monday.year, monday.month, monday.day);
      weeklyGroups.putIfAbsent(mondayDate, () => []).add(val);
    });

    final Map<DateTime, double> weekly = {};
    weeklyGroups.forEach((mondayDate, vals) {
      weekly[mondayDate] = vals.reduce((a, b) => a + b) / vals.length;
    });

    if (!normalize || weekly.isEmpty) return weekly;

    final values = weekly.values.toList();
    final actualMin = minValue ?? values.reduce(min);
    final actualMax = maxValue ?? values.reduce(max);
    final range = actualMax - actualMin;

    if (range == 0) {
      return weekly.map((k, _) => MapEntry(k, 0.5));
    }

    return weekly.map((k, v) => MapEntry(k, ((v - actualMin) / range).clamp(0.0, 1.0)));
  }

  /// Returns a raw hourly timeline for a metric across the last N days.
  /// The key is the exact DateTime (truncated to hour).
  Future<Map<DateTime, double>> getRawHourlyTimeline(
    String label, {
    bool normalize = false,
    int lastNDays = 2,
    double? minValue,
    double? maxValue,
  }) async {
    final cutoff = clock.now().subtract(Duration(days: lastNDays));
    final events = await _eventRepo.getEventsByLabel(label);
    
    final filteredEvents = events.where((e) => e.timestamp.isAfter(cutoff)).toList();
    if (filteredEvents.isEmpty) return {};

    final timeline = _aggregateByRawHour(filteredEvents);

    // Zero-fill for counters/behavior/nutrition
    final firstEvent = events.first;
    bool shouldZeroFill = firstEvent.category == EventCategory.nutrition || 
                         firstEvent.category == EventCategory.behavior ||
                         firstEvent.category == EventCategory.social;
                         
    Map<DateTime, double> result = shouldZeroFill ? _zeroFillHourly(timeline, lastNDays) : timeline;

    if (!normalize || result.isEmpty) return result;
    
    final values = result.values.toList();
    final actualMin = minValue ?? values.reduce(min);
    final actualMax = maxValue ?? values.reduce(max);
    final range = actualMax - actualMin;

    if (range == 0) return result.map((k, _) => MapEntry(k, 0.5));

    return result.map((k, v) => MapEntry(k, ((v - actualMin) / range).clamp(0.0, 1.0)));
  }

  /// Fills gaps in an hourly timeline with 0.0.
  Map<DateTime, double> _zeroFillHourly(Map<DateTime, double> data, int lastNDays) {
    final Map<DateTime, double> filled = {};
    final now = clock.now();
    final currentHour = DateTime(now.year, now.month, now.day, now.hour);
    
    final int totalHours = lastNDays * 24;
    for (int i = 0; i < totalHours; i++) {
      final date = currentHour.subtract(Duration(hours: i));
      filled[date] = data[date] ?? 0.0;
    }
    return filled;
  }

  Map<DateTime, double> _aggregateByRawHour(List<Event> events) {
    final Map<DateTime, List<double>> hourGroups = {};

    for (final e in events) {
      final date = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day, e.timestamp.hour);
      
      double val;
      if (e.value == 'true') {
        val = 1.0;
      } else if (e.value == 'false') {
        val = 0.0;
      } else {
        val = double.tryParse(e.value) ?? 0.0;
      }
      
      hourGroups.putIfAbsent(date, () => []).add(val);
    }

    final Map<DateTime, double> result = {};
    for (final date in hourGroups.keys) {
      final vals = hourGroups[date]!;
      if (vals.isEmpty) continue;
      
      final firstEvent = events.firstWhere((e) => true); // Simple label check

      if (firstEvent.category == EventCategory.mood || 
          firstEvent.category == EventCategory.productivity ||
          firstEvent.category == EventCategory.weather ||
          firstEvent.category == EventCategory.biological ||
          firstEvent.label.toLowerCase().contains('quality')) {
        result[date] = vals.reduce((a, b) => a + b) / vals.length;
      } else if (firstEvent.label == 'step_segment' || 
                 firstEvent.label == 'app_usage_segment' ||
                 firstEvent.label.startsWith('app_segment:') ||
                 firstEvent.label.startsWith('category_segment:')) {
        // Segments are already hourly values, so we just take the sum (usually only 1 exists)
        result[date] = vals.reduce((a, b) => a + b);
      } else if (firstEvent.category == EventCategory.nutrition || 
                 firstEvent.category == EventCategory.behavior ||
                 firstEvent.category == EventCategory.social) {
        // Counters and discrete behaviors should be SUMMED within the hour
        result[date] = vals.reduce((a, b) => a + b);
      } else {
        result[date] = vals.reduce(max);
      }
    }

    return result;
  }

  /// Sweeps lag 0–7 days and returns the lag with the highest |ρ|.
  ///
  /// Returns a record: `(bestLag, correlation, allCorrelations)`.
  /// [allCorrelations] is a `Map<int, double?>` of lag to ρ for chart display.
  Future<({int bestLag, double correlation, Map<int, double?> allCorrelations})?>
      findPeakLagCorrelation({
    required String metricA,
    required String metricB,
    int maxLag = 7,
    int? lastNDays,
  }) async {
    final Map<int, double?> all = {};
    int bestLag = 0;
    double bestAbs = -1;
    double bestVal = 0;

    for (int lag = 0; lag <= maxLag; lag++) {
      final r = await calculateSpearmanCorrelation(
        metricA: metricA,
        metricB: metricB,
        lagDays: lag,
        lastNDays: lastNDays,
      );
      all[lag] = r;
      if (r != null && r.abs() > bestAbs) {
        bestAbs = r.abs();
        bestVal = r;
        bestLag = lag;
      }
    }

    if (bestAbs < 0) return null; // No valid data at any lag

    return (bestLag: bestLag, correlation: bestVal, allCorrelations: all);
  }

  /// Auto-detects the most strongly correlated pair from a list of labels.
  ///
  /// Returns `(labelA, labelB, bestLag, correlation)` for the pair with
  /// the highest |ρ| at any lag 0–7.
  Future<({String labelA, String labelB, int bestLag, double correlation})?>
      findMostCorrelatedPair(List<String> labels) async {
    if (labels.length < 2) return null;

    String? bestA, bestB;
    int bestLag = 0;
    double bestAbs = -1;
    double bestVal = 0;

    for (int i = 0; i < labels.length; i++) {
      for (int j = i + 1; j < labels.length; j++) {
        final result = await findPeakLagCorrelation(
          metricA: labels[i],
          metricB: labels[j],
        );
        if (result != null && result.correlation.abs() > bestAbs) {
          bestAbs = result.correlation.abs();
          bestVal = result.correlation;
          bestLag = result.bestLag;
          bestA = labels[i];
          bestB = labels[j];
        }
      }
    }

    if (bestA == null || bestB == null) return null;
    return (
      labelA: bestA,
      labelB: bestB,
      bestLag: bestLag,
      correlation: bestVal,
    );
  }

  /// Returns true if the metric should be treated as a counter or yes/no toggle.
  /// Used to decide zero-filling and aggregation (SUM vs MAX/AVERAGE).
  Future<bool> _isCounterOrYesNo(String label, EventCategory category) async {
    // 1. Check core metric templates (case-insensitive and ID support)
    for (final template in MetricPresets.metricTemplates) {
      if (template.label.toLowerCase() == label.toLowerCase() ||
          template.id.toLowerCase() == label.toLowerCase()) {
        return template.inputType == MetricInputType.counter || 
               template.inputType == MetricInputType.yesNo;
      }
    }

    // 2. Check CustomMetrics table from DB
    try {
      final customMetrics = await _metricRepo.getAllCustomMetrics();
      for (final metric in customMetrics) {
        if (metric.label.toLowerCase() == label.toLowerCase() ||
            metric.id.toLowerCase() == label.toLowerCase()) {
          return metric.inputType == MetricInputType.counter || 
                 metric.inputType == MetricInputType.yesNo;
        }
      }
    } catch (e) {
      debugPrint('[AnalyticsService] Error checking custom metrics for counter: $e');
    }

    // 3. Fallback for custom/passive metrics using their high-level category
    return category == EventCategory.nutrition || 
           category == EventCategory.behavior || 
           category == EventCategory.social;
  }

  /// Aligns daily values for two series, optionally zero-filling counters/yes-no.
  ({List<double> listA, List<double> listB}) _alignAndZeroFill({
    required Map<DateTime, double> dailyA,
    required Map<DateTime, double> dailyB,
    required bool zeroFillA,
    required bool zeroFillB,
    required int lagDays,
  }) {
    // Copy the maps to avoid modifying the originals if they are cached or reused
    final Map<DateTime, double> mapA = Map.from(dailyA);
    final Map<DateTime, double> mapB = Map.from(dailyB);

    if (zeroFillA || zeroFillB) {
      final allDates = {...mapA.keys, ...mapB.keys};
      if (allDates.isNotEmpty) {
        DateTime minDate = allDates.reduce((a, b) => a.isBefore(b) ? a : b);
        DateTime maxDate = allDates.reduce((a, b) => a.isAfter(b) ? a : b);
        
        minDate = DateTime(minDate.year, minDate.month, minDate.day);
        maxDate = DateTime(maxDate.year, maxDate.month, maxDate.day);
        
        var current = minDate;
        while (current.isBefore(maxDate) || current.isAtSameMomentAs(maxDate)) {
          if (zeroFillA && !mapA.containsKey(current)) {
            mapA[current] = 0.0;
          }
          if (zeroFillB && !mapB.containsKey(current)) {
            mapB[current] = 0.0;
          }
          current = current.add(const Duration(days: 1));
        }
      }
    }

    final List<double> listA = [];
    final List<double> listB = [];

    for (final dateA in mapA.keys) {
      final dateB = dateA.add(Duration(days: lagDays));
      if (mapB.containsKey(dateB)) {
        listA.add(mapA[dateA]!);
        listB.add(mapB[dateB]!);
      }
    }

    return (listA: listA, listB: listB);
  }

  /// Aggregates events into daily values.
  /// 
  /// For mood/scales, it takes the average.
  /// For screen time/counters, it takes the sum (or the latest value if it's already a daily total).
  Future<Map<DateTime, double>> _aggregateByDay(List<Event> events) async {
    final Map<DateTime, List<double>> dailyGroups = {};

    for (final e in events) {
      final date = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      
      double val;
      if (e.value == 'true') {
        val = 1.0;
      } else if (e.value == 'false') {
        val = 0.0;
      } else {
        val = double.tryParse(e.value) ?? 0.0;
      }
      
      dailyGroups.putIfAbsent(date, () => []).add(val);
    }

    final Map<DateTime, double> result = {};
    for (final date in dailyGroups.keys) {
      final vals = dailyGroups[date]!;
      if (vals.isEmpty) continue;
      
      final firstEvent = events.firstWhere((e) => e.label == events.first.label);
      final isCounter = await _isCounterOrYesNo(firstEvent.label, firstEvent.category);
      
      // Determine aggregation strategy
      if (firstEvent.category == EventCategory.mood || 
          firstEvent.category == EventCategory.productivity ||
          firstEvent.category == EventCategory.weather ||
          firstEvent.category == EventCategory.biological ||
          firstEvent.label.toLowerCase().contains('quality')) {
        // Average for scales and quality metrics
        result[date] = vals.reduce((a, b) => a + b) / vals.length;
      } else if (isCounter) {
        // Sum for counters/behavior/yesNo
        result[date] = vals.reduce((a, b) => a + b);
      } else if (firstEvent.category == EventCategory.appUsage || 
                 firstEvent.category == EventCategory.health) {
        if (firstEvent.label.contains('segment')) {
          // Segments (e.g. step_segment, app_segment) should be SUMMED to get the daily total
          result[date] = vals.reduce((a, b) => a + b);
        } else {
          // Daily totals (e.g. step_count, sleep_duration_hours) should use MAX 
          // to pick the latest/most complete sync record for that day.
          result[date] = vals.reduce(max);
        }
      } else {
        // Default: Sum for counters/behavior
        result[date] = vals.reduce((a, b) => a + b);
      }
    }

    return result;

  }

  /// Aggregates events into an average 24-hour day.
  /// 
  /// For mood/scales, it calculates the average of all entries logged in that hour.
  /// For behavior/counts, it calculates the average occurrence per day for that hour.
  Future<Map<int, double>> _aggregateByHour(List<Event> events) async {
    final Map<int, List<double>> hourlyGroups = {};
    final Set<String> uniqueDays = {};

    for (final e in events) {
      final hour = e.timestamp.hour;
      uniqueDays.add('${e.timestamp.year}-${e.timestamp.month}-${e.timestamp.day}');
      
      double val;
      if (e.value == 'true') {
        val = 1.0;
      } else if (e.value == 'false') {
        val = 0.0;
      } else {
        val = double.tryParse(e.value) ?? 0.0;
      }
      
      hourlyGroups.putIfAbsent(hour, () => []).add(val);
    }

    final int totalDays = max(1, uniqueDays.length);
    final Map<int, double> result = {};
    
    if (events.isEmpty) return result;
    final firstEvent = events.firstWhere((e) => e.label == events.first.label);

    for (int i = 0; i < 24; i++) {
      if (!hourlyGroups.containsKey(i)) {
        final isCounter = await _isCounterOrYesNo(firstEvent.label, firstEvent.category);
        if (firstEvent.category == EventCategory.mood || 
            firstEvent.category == EventCategory.productivity ||
            firstEvent.category == EventCategory.weather ||
            firstEvent.category == EventCategory.biological ||
            firstEvent.label.toLowerCase().contains('quality')) {
          // Do not insert 0.0 for subjective scales, leave it missing to avoid graph drops
          continue;
        } else if (isCounter || 
                   firstEvent.category == EventCategory.appUsage || 
                   firstEvent.category == EventCategory.health) {
          // For counters like steps, 0.0 is accurate
          result[i] = 0.0;
          continue;
        } else {
          continue;
        }
      }
      
      final vals = hourlyGroups[i]!;
      final isCounter = await _isCounterOrYesNo(firstEvent.label, firstEvent.category);
      
      if (firstEvent.category == EventCategory.mood || 
          firstEvent.category == EventCategory.productivity ||
          firstEvent.category == EventCategory.weather ||
          firstEvent.category == EventCategory.biological ||
          firstEvent.label.toLowerCase().contains('quality')) {
        // Average for scales and quality metrics
        result[i] = vals.reduce((a, b) => a + b) / vals.length;
      } else if (firstEvent.label == 'step_segment' || 
                 firstEvent.label == 'app_usage_segment' ||
                 firstEvent.label.startsWith('app_segment:') ||
                 firstEvent.label.startsWith('category_segment:') ||
                 isCounter ||
                 firstEvent.category == EventCategory.appUsage || 
                 firstEvent.category == EventCategory.health) {
        // Average amount per day for that specific hour
        result[i] = vals.reduce((a, b) => a + b) / totalDays;
      } else {
        // Default: average per day
        result[i] = vals.reduce((a, b) => a + b) / totalDays;
      }
    }

    return result;
  }

  /// Computes Spearman Rank Correlation Coefficient.
  /// 
  /// Note: We use the Pearson correlation of the ranks, which is the 
  /// standard definition of Spearman's rho and correctly handles tied ranks.
  double _computeSpearman(List<double> x, List<double> y) {
    final n = x.length;
    if (n < 3) return 0.0;
    
    // 1. Convert to ranks
    final rankX = _getRanks(x);
    final rankY = _getRanks(y);

    // 2. Calculate Pearson correlation of the ranks
    return _computePearson(rankX, rankY);
  }

  /// Calculates the Pearson Correlation Coefficient between two lists.
  double _computePearson(List<double> x, List<double> y) {
    final n = x.length;
    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumX2 = 0;
    double sumY2 = 0;

    for (int i = 0; i < n; i++) {
      sumX += x[i];
      sumY += y[i];
      sumXY += x[i] * y[i];
      sumX2 += x[i] * x[i];
      sumY2 += y[i] * y[i];
    }

    final numerator = (n * sumXY) - (sumX * sumY);
    final denominator = sqrt(
      (n * sumX2 - (sumX * sumX)) * (n * sumY2 - (sumY * sumY))
    );

    if (denominator == 0) return 0.0;
    return numerator / denominator;
  }

  /// Calculates both correlation coefficient (rho) and the two-tailed p-value.
  Future<({double correlation, double pValue, int n})?> calculateSpearmanCorrelationDetailed({
    required String metricA,
    required String metricB,
    int lagDays = 0,
    int? lastNDays,
  }) async {
    final eventsA = await _eventRepo.getEventsByLabel(metricA);
    final eventsB = await _eventRepo.getEventsByLabel(metricB);

    if (eventsA.isEmpty || eventsB.isEmpty) return null;

    Map<DateTime, double> dailyA = await _aggregateByDay(eventsA);
    Map<DateTime, double> dailyB = await _aggregateByDay(eventsB);

    if (lastNDays != null) {
      final cutoff = _dayCutoff(lastNDays);
      dailyA = Map.fromEntries(dailyA.entries.where((e) => !e.key.isBefore(cutoff)));
      dailyB = Map.fromEntries(dailyB.entries.where((e) => !e.key.isBefore(cutoff)));
    }

    final zeroFillA = await _isCounterOrYesNo(metricA, eventsA.first.category);
    final zeroFillB = await _isCounterOrYesNo(metricB, eventsB.first.category);

    final aligned = _alignAndZeroFill(
      dailyA: dailyA,
      dailyB: dailyB,
      zeroFillA: zeroFillA,
      zeroFillB: zeroFillB,
      lagDays: lagDays,
    );

    final listA = aligned.listA;
    final listB = aligned.listB;

    final n = listA.length;
    if (n < _minSampleSize) return null;

    final correlation = _computeSpearman(listA, listB);

    // Clamp instead of special-casing |r| == 1.0 to p = 0.0: a "perfect"
    // rank correlation from a small sample is expected by chance fairly
    // often and isn't automatically significant. Running it through the
    // same t-approximation as every other value gives an honest p-value
    // that still correctly approaches 0 as n grows.
    final df = n - 2;
    final clampedR = correlation.abs() >= 1.0
        ? (correlation.isNegative ? -0.999999 : 0.999999)
        : correlation;
    final t = clampedR * sqrt(df / (1.0 - clampedR * clampedR));
    final pValue = _getTDistributionPValue(t.abs(), df);

    return (correlation: correlation, pValue: pValue, n: n);
  }

  double _normalCDF(double z) {
    z = z.abs();
    double t = 1.0 / (1.0 + 0.2316419 * z);
    double a1 = 0.319381530;
    double a2 = -0.356563782;
    double a3 = 1.781477937;
    double a4 = -1.821255978;
    double a5 = 1.330274429;
    
    double pdf = (1.0 / sqrt(2.0 * pi)) * exp(-0.5 * z * z);
    double phi = 1.0 - pdf * (a1 * t + a2 * t * t + a3 * pow(t, 3) + a4 * pow(t, 4) + a5 * pow(t, 5));
    return phi;
  }

  double _getTDistributionPValue(double t, int df) {
    if (df <= 0) return 1.0;
    t = t.abs();
    
    if (df == 1) {
      return 1.0 - (2.0 / pi) * atan(t);
    } else if (df == 2) {
      return 1.0 - t / sqrt(2.0 + t * t);
    }
    
    // Wallace (1959) approximation
    double logTerm = log(1.0 + (t * t) / df);
    double z = sqrt(df * logTerm * (1.0 - 1.0 / (8.0 * df)));
    
    double pVal = 2.0 * (1.0 - _normalCDF(z));
    return pVal.clamp(0.0, 1.0);
  }

  /// Converts a list of values to their ranks.
  /// Handles ties by averaging ranks.
  List<double> _getRanks(List<double> values) {
    final n = values.length;
    final List<_ValueIndex> sorted = [];
    for (int i = 0; i < n; i++) {
      sorted.add(_ValueIndex(values[i], i));
    }
    
    sorted.sort((a, b) => a.value.compareTo(b.value));

    final List<double> ranks = List.filled(n, 0.0);
    
    int i = 0;
    while (i < n) {
      int j = i;
      while (j < n - 1 && sorted[j + 1].value == sorted[i].value) {
        j++;
      }
      
      // Average rank for ties
      final avgRank = (i + 1 + j + 1) / 2.0;
      for (int k = i; k <= j; k++) {
        ranks[sorted[k].index] = avgRank;
      }
      
      i = j + 1;
    }
    
    return ranks;
  }
}

class _ValueIndex {
  final double value;
  final int index;
  _ValueIndex(this.value, this.index);
}
