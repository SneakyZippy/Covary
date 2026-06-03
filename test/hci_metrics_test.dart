import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:covary/data/database/app_database.dart';
import 'package:covary/data/models/enums.dart';

void main() {
  group('HCI Metrics Database & Schema Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Can insert and retrieve event with notificationDelayMs', () async {
      await db.insertEvent(
        EventsCompanion.insert(
          category: EventCategory.mood,
          label: 'mood',
          value: '4',
          latencyMs: const drift.Value(1200),
          notificationDelayMs: const drift.Value(45000),
          triggerSource: TriggerSource.notification,
          interactionType: InteractionType.click,
        ),
      );

      final events = await db.getAllEvents();
      expect(events.length, equals(1));
      expect(events.first.notificationDelayMs, equals(45000));
      expect(events.first.latencyMs, equals(1200));
    });

    test('Default value for notificationDelayMs is null', () async {
      await db.insertEvent(
        EventsCompanion.insert(
          category: EventCategory.mood,
          label: 'mood',
          value: '3',
          latencyMs: const drift.Value(800),
          triggerSource: TriggerSource.manual,
          interactionType: InteractionType.click,
        ),
      );

      final events = await db.getAllEvents();
      expect(events.length, equals(1));
      expect(events.first.notificationDelayMs, isNull);
    });
  });
}
