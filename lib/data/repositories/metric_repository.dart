import '../database/app_database.dart';

abstract class MetricRepository {
  Future<int> insertCustomMetric(CustomMetricsCompanion metric);
  Future<List<CustomMetric>> getAllCustomMetrics();
  Stream<List<CustomMetric>> watchCustomMetrics();
  Future<int> setCustomMetricEnabled(String id, bool enabled);
  Future<int> updateCustomMetricWindows(String id, String windowIds);
  Future<int> updateCustomMetric(String id, CustomMetricsCompanion companion);
  Future<int> setCustomMetricRetroReliable(String id, bool? value);
  Future<int> deleteCustomMetric(String id);
  Future<void> clearAllMetrics();
  Future<void> insertRawMap(Map<String, dynamic> map);
}

class DriftMetricRepository implements MetricRepository {
  final AppDatabase _db;

  DriftMetricRepository(this._db);

  @override
  Future<int> insertCustomMetric(CustomMetricsCompanion metric) {
    return _db.insertCustomMetric(metric);
  }

  @override
  Future<List<CustomMetric>> getAllCustomMetrics() {
    return _db.getAllCustomMetrics();
  }

  @override
  Stream<List<CustomMetric>> watchCustomMetrics() {
    return _db.watchCustomMetrics();
  }

  @override
  Future<int> setCustomMetricEnabled(String id, bool enabled) {
    return _db.setCustomMetricEnabled(id, enabled);
  }

  @override
  Future<int> updateCustomMetricWindows(String id, String windowIds) {
    return _db.updateCustomMetricWindows(id, windowIds);
  }

  @override
  Future<int> updateCustomMetric(String id, CustomMetricsCompanion companion) {
    return _db.updateCustomMetric(id, companion);
  }

  @override
  Future<int> setCustomMetricRetroReliable(String id, bool? value) {
    return _db.setCustomMetricRetroReliable(id, value);
  }

  @override
  Future<int> deleteCustomMetric(String id) {
    return _db.deleteCustomMetric(id);
  }

  @override
  Future<void> clearAllMetrics() {
    return _db.clearAllMetrics();
  }

  @override
  Future<void> insertRawMap(Map<String, dynamic> map) async {
    final entity = _db.customMetrics.map(map);
    await _db.insertCustomMetric(entity.toCompanion(true));
  }
}
