import 'package:flutter_test/flutter_test.dart';
import 'package:covary/services/export_service.dart';
import 'package:covary/services/profile_service.dart';
import 'package:covary/data/database/app_database.dart';
import 'package:covary/data/models/enums.dart';
import 'package:covary/data/repositories/event_repository.dart';
import 'package:covary/data/repositories/metric_repository.dart';
import 'package:covary/data/repositories/tracking_window_repository.dart';

class FakeProfileService extends Fake implements ProfileService {
  @override
  String get uuid => 'test-uuid-1234';

  @override
  String get nickname => 'Test User';
}

class FakeEventRepository extends Fake implements EventRepository {}
class FakeMetricRepository extends Fake implements MetricRepository {}
class FakeTrackingWindowRepository extends Fake implements TrackingWindowRepository {}

void main() {
  group('ExportService Filtering Tests', () {
    late ExportService exportService;

    setUp(() {
      exportService = ExportService(
        eventRepo: FakeEventRepository(),
        metricRepo: FakeMetricRepository(),
        trackingWindowRepo: FakeTrackingWindowRepository(),
        profileService: FakeProfileService(),
      );
    });

    test('buildExportPayload includes all metrics and events when filter is null', () {
      final events = [
        Event(
          id: '1',
          timestamp: DateTime.now(),
          category: EventCategory.mood,
          label: 'Mood',
          value: '8',
          latencyMs: 1000,
          triggerSource: TriggerSource.manual,
          interactionType: InteractionType.click,
        ),
        Event(
          id: '2',
          timestamp: DateTime.now(),
          category: EventCategory.meta,
          label: 'SessionCompleted',
          value: 'anytime',
          latencyMs: 0,
          triggerSource: TriggerSource.system,
          interactionType: InteractionType.click,
        ),
      ];

      final customMetrics = [
        CustomMetric(
          id: 'core_mood',
          label: 'Mood',
          category: EventCategory.mood,
          inputType: MetricInputType.scale1to10,
          isEnabled: true,
          windowIds: 'anytime',
          isActivityIndicator: true,
        ),
      ];

      final trackingWindows = <TrackingWindow>[];

      final payload = exportService.buildExportPayload(
        events: events,
        customMetrics: customMetrics,
        trackingWindows: trackingWindows,
        filteredMetricLabels: null,
      );

      final researchData = payload['research_data'] as Map<String, dynamic>;
      final exportedEvents = researchData['events'] as List<dynamic>;
      final exportedMetrics = researchData['custom_metrics'] as List<dynamic>;

      expect(exportedEvents.length, equals(2));
      expect(exportedMetrics.length, equals(1));
    });

    test('buildExportPayload filters events and custom metrics based on labels', () {
      final events = [
        Event(
          id: '1',
          timestamp: DateTime.now(),
          category: EventCategory.mood,
          label: 'Mood',
          value: '8',
          latencyMs: 1000,
          triggerSource: TriggerSource.manual,
          interactionType: InteractionType.click,
        ),
        Event(
          id: '2',
          timestamp: DateTime.now(),
          category: EventCategory.behavior,
          label: 'Steps',
          value: '5000',
          latencyMs: 2000,
          triggerSource: TriggerSource.manual,
          interactionType: InteractionType.click,
        ),
        Event(
          id: '3',
          timestamp: DateTime.now(),
          category: EventCategory.meta,
          label: 'SessionCompleted',
          value: 'anytime',
          latencyMs: 0,
          triggerSource: TriggerSource.system,
          interactionType: InteractionType.click,
        ),
      ];

      final customMetrics = [
        CustomMetric(
          id: 'core_mood',
          label: 'Mood',
          category: EventCategory.mood,
          inputType: MetricInputType.scale1to10,
          isEnabled: true,
          windowIds: 'anytime',
          isActivityIndicator: true,
        ),
        CustomMetric(
          id: 'core_steps',
          label: 'Steps',
          category: EventCategory.behavior,
          inputType: MetricInputType.counter,
          isEnabled: true,
          windowIds: 'anytime',
          isActivityIndicator: true,
        ),
      ];

      final trackingWindows = <TrackingWindow>[];

      // Filter: Only include 'Steps'
      final payload = exportService.buildExportPayload(
        events: events,
        customMetrics: customMetrics,
        trackingWindows: trackingWindows,
        filteredMetricLabels: ['Steps'],
      );

      final researchData = payload['research_data'] as Map<String, dynamic>;
      final exportedEvents = researchData['events'] as List<dynamic>;
      final exportedMetrics = researchData['custom_metrics'] as List<dynamic>;

      // Should contain 'Steps' event AND the system-level 'SessionCompleted' meta event
      expect(exportedEvents.length, equals(2));
      final labels = exportedEvents.map((e) => e['label']).toList();
      expect(labels, contains('Steps'));
      expect(labels, contains('SessionCompleted'));
      expect(labels, isNot(contains('Mood')));

      // Should only contain 'Steps' metric definition
      expect(exportedMetrics.length, equals(1));
      expect(exportedMetrics.first['label'], equals('Steps'));
    });
  });
}
