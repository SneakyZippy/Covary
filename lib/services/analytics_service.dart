import 'dart:math';
import '../data/database/app_database.dart';
import '../data/models/enums.dart';

/// Service responsible for on-device statistical analysis and correlations.
class AnalyticsService {
  final AppDatabase _db;

  AnalyticsService(this._db);

  /// Calculates the Spearman Rank Correlation between two metrics.
  /// 
  /// [metricA] and [metricB] are the labels of the metrics to correlate.
  /// [lagDays] specifies the time offset (0-7 days). Positive value means 
  /// [metricA] at Day T is correlated with [metricB] at Day T + lagDays.
  Future<double?> calculateSpearmanCorrelation({
    required String metricA,
    required String metricB,
    int lagDays = 0,
    DateTime? start,
    DateTime? end,
  }) async {
    // 1. Fetch data for both metrics
    final eventsA = await _db.getEventsByLabel(metricA);
    final eventsB = await _db.getEventsByLabel(metricB);

    if (eventsA.isEmpty || eventsB.isEmpty) return null;

    // 2. Aggregate by day
    final Map<DateTime, double> dailyA = _aggregateByDay(eventsA);
    final Map<DateTime, double> dailyB = _aggregateByDay(eventsB);

    // 3. Align dates with lag
    final List<double> listA = [];
    final List<double> listB = [];

    // We iterate through dates in dailyA
    for (final dateA in dailyA.keys) {
      final dateB = dateA.add(Duration(days: lagDays));
      
      if (dailyB.containsKey(dateB)) {
        listA.add(dailyA[dateA]!);
        listB.add(dailyB[dateB]!);
      }
    }

    if (listA.length < 3) return null; // Need at least 3 points for a meaningful correlation

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
    final eventsA = await _db.getEventsByLabel(metricA);
    final eventsB = await _db.getEventsByLabel(metricB);

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

    if (listA.length < 5) return null; 
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
    int lastNDays = 14,
  }) async {
    final events = await _db.getEventsByLabel(label);
    if (events.isEmpty) return {};

    final daily = _aggregateByDay(events);

    // Filter to last N days
    final cutoff = DateTime.now().subtract(Duration(days: lastNDays));
    final cutoffDate = DateTime(cutoff.year, cutoff.month, cutoff.day);
    daily.removeWhere((date, _) => date.isBefore(cutoffDate));

    if (!normalize || daily.isEmpty) return daily;

    // Min-max normalization
    final values = daily.values.toList();
    final minVal = values.reduce(min);
    final maxVal = values.reduce(max);
    final range = maxVal - minVal;

    if (range == 0) {
      // All values are identical — normalize to 0.5
      return daily.map((k, _) => MapEntry(k, 0.5));
    }

    return daily.map((k, v) => MapEntry(k, (v - minVal) / range));
  }

  /// Returns the hourly aggregated time series for a metric across the last N days,
  /// optionally normalized to 0.0–1.0 range via min-max scaling.
  /// 
  /// The key is the hour of the day (0-23).
  Future<Map<int, double>> getHourlyTimeSeries(
    String label, {
    bool normalize = false,
    int lastNDays = 14,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: lastNDays));
    final events = await _db.getEventsByLabel(label);
    
    // Filter to last N days
    final filteredEvents = events.where((e) => e.timestamp.isAfter(cutoff)).toList();
    if (filteredEvents.isEmpty) return {};

    final hourly = _aggregateByHour(filteredEvents);

    if (!normalize || hourly.isEmpty) return hourly;

    // Min-max normalization
    final values = hourly.values.toList();
    final minVal = values.reduce(min);
    final maxVal = values.reduce(max);
    final range = maxVal - minVal;

    if (range == 0) {
      return hourly.map((k, _) => MapEntry(k, 0.5));
    }

    return hourly.map((k, v) => MapEntry(k, (v - minVal) / range));
  }

  /// Returns a raw hourly timeline for a metric across the last N days.
  /// The key is the exact DateTime (truncated to hour).
  Future<Map<DateTime, double>> getRawHourlyTimeline(
    String label, {
    bool normalize = false,
    int lastNDays = 2,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: lastNDays));
    final events = await _db.getEventsByLabel(label);
    
    final filteredEvents = events.where((e) => e.timestamp.isAfter(cutoff)).toList();
    if (filteredEvents.isEmpty) return {};

    final timeline = _aggregateByRawHour(filteredEvents);

    if (!normalize || timeline.isEmpty) return timeline;
    
    final values = timeline.values.toList();
    final minVal = values.reduce(min);
    final maxVal = values.reduce(max);
    final range = maxVal - minVal;

    if (range == 0) return timeline.map((k, _) => MapEntry(k, 0.5));

    return timeline.map((k, v) => MapEntry(k, (v - minVal) / range));
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
          firstEvent.label.toLowerCase().contains('quality')) {
        result[date] = vals.reduce((a, b) => a + b) / vals.length;
      } else if (firstEvent.label == 'step_segment' || 
                 firstEvent.label == 'app_usage_segment' ||
                 firstEvent.label.startsWith('app_segment:') ||
                 firstEvent.label.startsWith('category_segment:')) {
        // Segments are already hourly values, so we just take the sum (usually only 1 exists)
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

  /// Aggregates events into daily values.
  /// 
  /// For mood/scales, it takes the average.
  /// For screen time/counters, it takes the sum (or the latest value if it's already a daily total).
  Map<DateTime, double> _aggregateByDay(List<Event> events) {
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
      
      // Determine aggregation strategy
      if (firstEvent.category == EventCategory.mood || 
          firstEvent.category == EventCategory.productivity ||
          firstEvent.label.toLowerCase().contains('quality')) {
        // Average for scales and quality metrics
        result[date] = vals.reduce((a, b) => a + b) / vals.length;
      } else if (firstEvent.category == EventCategory.appUsage || 
                 firstEvent.category == EventCategory.health) {
        // Take MAX for daily totals (steps, screen time, sleep duration)
        // This ensures that if we have multiple syncs, we take the most complete one.
        result[date] = vals.reduce(max);
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
  Map<int, double> _aggregateByHour(List<Event> events) {
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
        if (firstEvent.category == EventCategory.mood || 
            firstEvent.category == EventCategory.productivity ||
            firstEvent.label.toLowerCase().contains('quality')) {
          // Do not insert 0.0 for subjective scales, leave it missing to avoid graph drops
          continue;
        } else {
          // For counters like steps, 0.0 is accurate
          result[i] = 0.0;
          continue;
        }
      }
      
      final vals = hourlyGroups[i]!;
      
      if (firstEvent.category == EventCategory.mood || 
          firstEvent.category == EventCategory.productivity ||
          firstEvent.label.toLowerCase().contains('quality')) {
        // Average for scales and quality metrics
        result[i] = vals.reduce((a, b) => a + b) / vals.length;
      } else if (firstEvent.label == 'step_segment' || 
                 firstEvent.label == 'app_usage_segment' ||
                 firstEvent.label.startsWith('app_segment:') ||
                 firstEvent.label.startsWith('category_segment:') ||
                 firstEvent.category == EventCategory.behavior) {
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
