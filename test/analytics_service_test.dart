import 'package:flutter_test/flutter_test.dart';
import 'package:clock/clock.dart';
import 'package:covary/services/analytics_service.dart';
import 'package:covary/data/database/app_database.dart';
import 'package:covary/data/models/enums.dart';
import 'package:covary/data/repositories/event_repository.dart';
import 'package:covary/data/repositories/metric_repository.dart';

class FakeMetricRepository extends Fake implements MetricRepository {
  final List<CustomMetric> metrics;
  FakeMetricRepository(this.metrics);

  @override
  Future<List<CustomMetric>> getAllCustomMetrics() async => metrics;
}

class FakeEventRepository extends Fake implements EventRepository {
  final List<Event> events;
  FakeEventRepository(this.events);

  @override
  Future<List<Event>> getEventsByLabel(String label, {EventCategory? category}) async {
    return events.where((e) => e.label == label).toList();
  }
}

void main() {
  group('AnalyticsService Counter Aggregation Tests', () {
    test('Daily aggregation correctly sums Bathroom Visit events (case-insensitive core check)', () async {
      final now = DateTime(2026, 7, 8, 12, 0, 0);

      // 3 Bathroom Visit events on the same day (July 8, 2026)
      final events = [
        Event(
          id: 'e1',
          timestamp: DateTime(2026, 7, 8, 10, 0, 0),
          category: EventCategory.health,
          label: 'Bathroom Visit',
          value: '1',
          latencyMs: 0,
          triggerSource: TriggerSource.manual,
          interactionType: InteractionType.click,
        ),
        Event(
          id: 'e2',
          timestamp: DateTime(2026, 7, 8, 12, 0, 0),
          category: EventCategory.health,
          label: 'Bathroom Visit',
          value: '1',
          latencyMs: 0,
          triggerSource: TriggerSource.manual,
          interactionType: InteractionType.click,
        ),
        Event(
          id: 'e3',
          timestamp: DateTime(2026, 7, 8, 15, 0, 0),
          category: EventCategory.health,
          label: 'Bathroom Visit',
          value: '1',
          latencyMs: 0,
          triggerSource: TriggerSource.manual,
          interactionType: InteractionType.click,
        ),
      ];

      final eventRepo = FakeEventRepository(events);
      final metricRepo = FakeMetricRepository([]);
      final analyticsService = AnalyticsService(eventRepo, metricRepo);

      await withClock(Clock.fixed(now), () async {
        final dailySeries = await analyticsService.getDailyTimeSeries('Bathroom Visit', normalize: false, lastNDays: 1);
        final targetDate = DateTime(2026, 7, 8);
        expect(dailySeries[targetDate], equals(3.0));
      });
    });

    test('Daily aggregation correctly sums custom metric counters', () async {
      final now = DateTime(2026, 7, 8, 12, 0, 0);

      // Custom metric: "Stool Count" in category health, which is a counter
      final customMetric = CustomMetric(
        id: 'custom_stool_count',
        label: 'Stool Count',
        category: EventCategory.health,
        inputType: MetricInputType.counter,
        windowIds: 'anytime',
        isEnabled: true,
        isActivityIndicator: true,
      );

      final events = [
        Event(
          id: 'e1',
          timestamp: DateTime(2026, 7, 8, 10, 0, 0),
          category: EventCategory.health,
          label: 'Stool Count',
          value: '1.5',
          latencyMs: 0,
          triggerSource: TriggerSource.manual,
          interactionType: InteractionType.click,
        ),
        Event(
          id: 'e2',
          timestamp: DateTime(2026, 7, 8, 14, 0, 0),
          category: EventCategory.health,
          label: 'Stool Count',
          value: '2.0',
          latencyMs: 0,
          triggerSource: TriggerSource.manual,
          interactionType: InteractionType.click,
        ),
      ];

      final eventRepo = FakeEventRepository(events);
      final metricRepo = FakeMetricRepository([customMetric]);
      final analyticsService = AnalyticsService(eventRepo, metricRepo);

      await withClock(Clock.fixed(now), () async {
        final dailySeries = await analyticsService.getDailyTimeSeries('Stool Count', normalize: false, lastNDays: 1);
        final targetDate = DateTime(2026, 7, 8);
        expect(dailySeries[targetDate], equals(3.5));
      });
    });

    test('Daily aggregation takes average for subjective scale metrics (e.g. mood)', () async {
      final now = DateTime(2026, 7, 8, 12, 0, 0);

      final events = [
        Event(
          id: 'e1',
          timestamp: DateTime(2026, 7, 8, 10, 0, 0),
          category: EventCategory.mood,
          label: 'Current Mood',
          value: '4',
          latencyMs: 0,
          triggerSource: TriggerSource.manual,
          interactionType: InteractionType.click,
        ),
        Event(
          id: 'e2',
          timestamp: DateTime(2026, 7, 8, 14, 0, 0),
          category: EventCategory.mood,
          label: 'Current Mood',
          value: '8',
          latencyMs: 0,
          triggerSource: TriggerSource.manual,
          interactionType: InteractionType.click,
        ),
      ];

      final eventRepo = FakeEventRepository(events);
      final metricRepo = FakeMetricRepository([]);
      final analyticsService = AnalyticsService(eventRepo, metricRepo);

      await withClock(Clock.fixed(now), () async {
        final dailySeries = await analyticsService.getDailyTimeSeries('Current Mood', normalize: false, lastNDays: 1);
        final targetDate = DateTime(2026, 7, 8);
        expect(dailySeries[targetDate], equals(6.0));
      });
    });
  });
}
