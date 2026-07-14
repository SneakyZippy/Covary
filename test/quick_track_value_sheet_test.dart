import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clock/clock.dart';
import 'package:covary/data/models/metric_definition.dart';
import 'package:covary/data/models/enums.dart';
import 'package:covary/ui/widgets/quick_track_value_sheet.dart';

void main() {
  testWidgets('QuickTrackValueSheet 1h ago past midnight logs yesterday', (WidgetTester tester) async {
    // Set a larger physical size for the test to avoid overflow issues
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Set the clock to June 10, 2026, at 00:30:00 (just past midnight)
    final mockNow = DateTime(2026, 6, 10, 0, 30, 0);

    await withClock(Clock.fixed(mockNow), () async {
      double? confirmedValue;
      DateTime? confirmedTime;
      bool? confirmedSaveAsDefault;

      final metric = const MetricDefinition(
        id: 'core_water_intake',
        label: 'Water Intake',
        category: EventCategory.nutrition,
        inputType: MetricInputType.numeric,
        isEnabled: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => QuickTrackValueSheet(
                        metric: metric,
                        initialValue: 250.0,
                        unit: 'ml',
                        step: 50.0,
                        min: 50.0,
                        max: 1000.0,
                        onConfirm: (val, time, saveDefault) {
                          confirmedValue = val;
                          confirmedTime = time;
                          confirmedSaveAsDefault = saveDefault;
                        },
                      ),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      // Open the sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Find the '1h ago' ChoiceChip and select it
      await tester.tap(find.text('1h ago'));
      await tester.pumpAndSettle();

      // Tap the Confirm button
      await tester.tap(find.byWidgetPredicate((w) => w is FilledButton));
      await tester.pumpAndSettle();

      // Verify confirmedTime is exactly June 9, 2026, at 23:30:00
      expect(confirmedTime, isNotNull);
      expect(confirmedTime!.year, equals(2026));
      expect(confirmedTime!.month, equals(6));
      expect(confirmedTime!.day, equals(9));
      expect(confirmedTime!.hour, equals(23));
      expect(confirmedTime!.minute, equals(30));

      expect(confirmedValue, equals(250.0));
      expect(confirmedSaveAsDefault, isFalse);
    });
  });
}
