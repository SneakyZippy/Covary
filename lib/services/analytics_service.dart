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

  /// Aggregates events into daily values.
  /// 
  /// For mood/scales, it takes the average.
  /// For screen time/counters, it takes the sum (or the latest value if it's already a daily total).
  Map<DateTime, double> _aggregateByDay(List<Event> events) {
    final Map<DateTime, List<double>> dailyGroups = {};

    for (final e in events) {
      final date = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      final val = double.tryParse(e.value) ?? 0.0;
      dailyGroups.putIfAbsent(date, () => []).add(val);
    }

    final Map<DateTime, double> result = {};
    for (final date in dailyGroups.keys) {
      final vals = dailyGroups[date]!;
      
      // Determine aggregation strategy based on category
      // This is a simplification; in a real scenario we'd check the MetricInputType
      final event = events.firstWhere((e) => e.label == events.first.label);
      
      if (event.category == EventCategory.mood || event.category == EventCategory.productivity) {
        // Average for scales
        result[date] = vals.reduce((a, b) => a + b) / vals.length;
      } else if (event.category == EventCategory.appUsage) {
        // App usage is usually already a daily total in our app (logged at end of day)
        // But if multiple logs exist, we take the MAX (cumulative for that day)
        result[date] = vals.reduce(max);
      } else {
        // Sum for counters/behavior
        result[date] = vals.reduce((a, b) => a + b);
      }
    }

    return result;
  }

  /// Computes Spearman Rank Correlation Coefficient.
  double _computeSpearman(List<double> x, List<double> y) {
    final n = x.length;
    
    // 1. Convert to ranks
    final rankX = _getRanks(x);
    final rankY = _getRanks(y);

    // 2. Sum of squared differences of ranks
    double sumD2 = 0;
    for (int i = 0; i < n; i++) {
      final d = rankX[i] - rankY[i];
      sumD2 += d * d;
    }

    // 3. Formula: 1 - (6 * sumD2) / (n * (n^2 - 1))
    return 1 - (6 * sumD2) / (n * (n * n - 1));
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
