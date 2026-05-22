import '../database/app_database.dart';

abstract class TrackingWindowRepository {
  Future<int> insertTrackingWindow(TrackingWindowsCompanion window);
  Future<List<TrackingWindow>> getAllTrackingWindows();
  Stream<List<TrackingWindow>> watchTrackingWindows();
  Future<int> updateTrackingWindow(String id, TrackingWindowsCompanion companion);
  Future<int> deleteTrackingWindow(String id);
  Future<void> clearAllTrackingWindows();
  Future<void> insertRawMap(Map<String, dynamic> map);
}

class DriftTrackingWindowRepository implements TrackingWindowRepository {
  final AppDatabase _db;

  DriftTrackingWindowRepository(this._db);

  @override
  Future<int> insertTrackingWindow(TrackingWindowsCompanion window) {
    return _db.insertTrackingWindow(window);
  }

  @override
  Future<List<TrackingWindow>> getAllTrackingWindows() {
    return _db.getAllTrackingWindows();
  }

  @override
  Stream<List<TrackingWindow>> watchTrackingWindows() {
    return _db.watchTrackingWindows();
  }

  @override
  Future<int> updateTrackingWindow(String id, TrackingWindowsCompanion companion) {
    return _db.updateTrackingWindow(id, companion);
  }

  @override
  Future<int> deleteTrackingWindow(String id) {
    return _db.deleteTrackingWindow(id);
  }

  @override
  Future<void> clearAllTrackingWindows() {
    return _db.clearAllTrackingWindows();
  }

  @override
  Future<void> insertRawMap(Map<String, dynamic> map) async {
    final entity = _db.trackingWindows.map(map);
    await _db.insertTrackingWindow(entity.toCompanion(true));
  }
}
