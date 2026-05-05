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
