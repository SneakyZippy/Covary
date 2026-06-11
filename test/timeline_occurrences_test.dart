import 'package:flutter_test/flutter_test.dart';
import 'package:covary/services/metric_service.dart';
import 'package:covary/data/database/app_database.dart';
import 'package:covary/data/models/enums.dart';
import 'package:covary/data/repositories/event_repository.dart';
import 'package:covary/data/repositories/metric_repository.dart';
import 'package:covary/data/repositories/profile_repository.dart';
import 'package:covary/data/repositories/tracking_window_repository.dart';

class FakeMetricRepository extends Fake implements MetricRepository {
  @override
  Future<List<CustomMetric>> getAllCustomMetrics() async => [];
}

class FakeTrackingWindowRepository extends Fake implements TrackingWindowRepository {
  final List<TrackingWindow> windows;
  FakeTrackingWindowRepository(this.windows);

  @override
  Future<List<TrackingWindow>> getAllTrackingWindows() async => windows;
}

class FakeEventRepository extends Fake implements EventRepository {}

class FakeProfileRepository extends Fake implements ProfileRepository {
  final Map<String, dynamic> _settings = {};

  @override
  bool getBoolSetting(String key, {bool defaultValue = false}) {
    return _settings[key] ?? defaultValue;
  }

  @override
  Future<void> setBoolSetting(String key, bool value) async {
    _settings[key] = value;
  }

  @override
  String? getStringSetting(String key) {
    return _settings[key];
  }

  @override
  Future<void> setStringSetting(String key, String value) async {
    _settings[key] = value;
  }

  @override
  List<String>? getStringListSetting(String key) {
    return _settings[key] != null ? List<String>.from(_settings[key]) : null;
  }

  @override
  Future<void> setStringListSetting(String key, List<String> value) async {
    _settings[key] = value;
  }

  @override
  Future<void> removeSetting(String key) async {
    _settings.remove(key);
  }
}

void main() {
  group('MetricService - getTimelineOccurrences Tests', () {
    late FakeProfileRepository profileRepo;
    late FakeTrackingWindowRepository windowRepo;
    late MetricService metricService;

    final window1 = TrackingWindow(
      id: 'afternoon',
      label: 'Afternoon',
      startHour: 14,
      startMinute: 0,
      endHour: 16,
      endMinute: 0,
      isNotificationEnabled: false,
      notificationHour: 14,
      notificationMinute: 0,
      isEnabled: true,
    );

    setUp(() async {
      profileRepo = FakeProfileRepository();
      windowRepo = FakeTrackingWindowRepository([window1]);

      metricService = MetricService(
        metricRepo: FakeMetricRepository(),
        trackingWindowRepo: windowRepo,
        eventRepo: FakeEventRepository(),
        profileRepo: profileRepo,
      );

      await metricService.init();
    });

    test('Include today and yesterday if not completed/dismissed', () {
      // Current time is 13:59:00 on 2026-06-11
      final now = DateTime(2026, 6, 11, 13, 59, 0);

      // Today's afternoon window starts at 14:00, so it hasn't started yet.
      // Yesterday's afternoon window (ended at 16:00 yesterday) has ended.
      // With no events, both should be present.
      final occurrences = metricService.getTimelineOccurrences(now, []);

      expect(occurrences.length, equals(2));
      expect(occurrences[0].start, equals(DateTime(2026, 6, 10, 14, 0, 0))); // Yesterday's
      expect(occurrences[1].start, equals(DateTime(2026, 6, 11, 14, 0, 0))); // Today's
    });

    test('Exclude yesterday if completed', () {
      final now = DateTime(2026, 6, 11, 13, 59, 0);

      // Yesterday's afternoon window completed event
      final completedEvent = Event(
        id: 'e1',
        timestamp: DateTime(2026, 6, 10, 14, 30, 0), // during yesterday's window
        category: EventCategory.meta,
        label: 'SessionCompleted',
        value: 'afternoon',
        latencyMs: 1200,
        triggerSource: TriggerSource.manual,
        interactionType: InteractionType.click,
      );

      final occurrences = metricService.getTimelineOccurrences(now, [completedEvent]);

      // Yesterday's should be excluded because it is completed, leaving only today's
      expect(occurrences.length, equals(1));
      expect(occurrences[0].start, equals(DateTime(2026, 6, 11, 14, 0, 0)));
    });

    test('Exclude yesterday if dismissed', () {
      final now = DateTime(2026, 6, 11, 13, 59, 0);

      // Yesterday's afternoon window dismissed event
      final dismissedEvent = Event(
        id: 'e2',
        timestamp: DateTime(2026, 6, 10, 15, 0, 0), // during yesterday's window
        category: EventCategory.meta,
        label: 'SessionDismissed',
        value: 'afternoon',
        latencyMs: 1000,
        triggerSource: TriggerSource.manual,
        interactionType: InteractionType.click,
      );

      final occurrences = metricService.getTimelineOccurrences(now, [dismissedEvent]);

      expect(occurrences.length, equals(1));
      expect(occurrences[0].start, equals(DateTime(2026, 6, 11, 14, 0, 0)));
    });
  });
}
