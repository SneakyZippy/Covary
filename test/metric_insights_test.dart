import 'package:flutter_test/flutter_test.dart';
import 'package:covary/ui/screens/metric_insights_screen.dart';

void main() {
  group('MetricInsightsHelper Tests', () {
    test('getEffectiveLabel resolves labels correctly based on InsightViewMode', () {
      // Daily mode should return the original label
      expect(
        MetricInsightsHelper.getEffectiveLabel('step_count', InsightViewMode.daily),
        equals('step_count'),
      );
      expect(
        MetricInsightsHelper.getEffectiveLabel('total_screen_time', InsightViewMode.daily),
        equals('total_screen_time'),
      );

      // Circadian & Timeline modes should resolve to hourly segments
      expect(
        MetricInsightsHelper.getEffectiveLabel('step_count', InsightViewMode.circadian),
        equals('step_segment'),
      );
      expect(
        MetricInsightsHelper.getEffectiveLabel('total_screen_time', InsightViewMode.timeline),
        equals('app_usage_segment'),
      );
      expect(
        MetricInsightsHelper.getEffectiveLabel('category_time:social', InsightViewMode.circadian),
        equals('category_segment:social'),
      );
      expect(
        MetricInsightsHelper.getEffectiveLabel('category_time:entertainment', InsightViewMode.timeline),
        equals('category_segment:entertainment'),
      );

      // App-specific daily time to per-app segment
      expect(
        MetricInsightsHelper.getEffectiveLabel('app_time:com.instagram.android', InsightViewMode.circadian),
        equals('app_segment:com.instagram.android'),
      );

      // Subjective metrics shouldn't change
      expect(
        MetricInsightsHelper.getEffectiveLabel('mood', InsightViewMode.circadian),
        equals('mood'),
      );
    });

    test('formatMetricValue formats values correctly', () {
      // Steps formatting (decimal)
      expect(MetricInsightsHelper.formatMetricValue('step_count', 12345), equals('12,345'));
      expect(MetricInsightsHelper.formatMetricValue('step_segment', 450.6), equals('451'));

      // Sleep duration formatting (h suffix)
      expect(MetricInsightsHelper.formatMetricValue('sleep_duration_hours', 7.52), equals('7.5h'));
      expect(MetricInsightsHelper.formatMetricValue('sleep_duration_hours', 8.0), equals('8.0h'));

      // Sleep bedtime/wakeup/midpoint formatting (clock time)
      expect(MetricInsightsHelper.formatMetricValue('sleep_bedtime', 23.5), equals('23:30'));
      expect(MetricInsightsHelper.formatMetricValue('sleep_bedtime', 24.25), equals('00:15'));
      expect(MetricInsightsHelper.formatMetricValue('sleep_wakeup', 7.75), equals('07:45'));

      // Screen time and app categories formatting (minutes / hours + minutes)
      expect(MetricInsightsHelper.formatMetricValue('total_screen_time', 45.0), equals('45m'));
      expect(MetricInsightsHelper.formatMetricValue('total_screen_time', 125.0), equals('2h 5m'));
      expect(MetricInsightsHelper.formatMetricValue('category_time:social', 60.0), equals('1h 0m'));

      // Mindless scrolling formatting
      expect(MetricInsightsHelper.formatMetricValue('Mindless Scrolling', 15.0), equals('15m'));
      expect(MetricInsightsHelper.formatMetricValue('Mindless Scrolling', 75.0), equals('1h 15m'));

      // Defaults
      expect(MetricInsightsHelper.formatMetricValue('mood', 4.0), equals('4'));
      expect(MetricInsightsHelper.formatMetricValue('mood', 4.5), equals('4.5'));
    });

    test('formatAxisLabel formats values correctly for axes', () {
      // Steps formatting (k abbreviation)
      expect(MetricInsightsHelper.formatAxisLabel('step_count', 4500), equals('4.5k'));
      expect(MetricInsightsHelper.formatAxisLabel('step_count', 950), equals('950'));

      // Sleep bedtime/wakeup/midpoint formatting (clock time to hour)
      expect(MetricInsightsHelper.formatAxisLabel('sleep_bedtime', 23.5), equals('23:00'));
      expect(MetricInsightsHelper.formatAxisLabel('sleep_wakeup', 7.25), equals('07:00'));

      // Screen time formatting
      expect(MetricInsightsHelper.formatAxisLabel('total_screen_time', 45), equals('45m'));
      expect(MetricInsightsHelper.formatAxisLabel('total_screen_time', 120), equals('2.0h'));

      // Mindless scrolling axis formatting
      expect(MetricInsightsHelper.formatAxisLabel('Mindless Scrolling', 15), equals('15m'));
      expect(MetricInsightsHelper.formatAxisLabel('Mindless Scrolling', 90), equals('1.5h'));

      // Defaults
      expect(MetricInsightsHelper.formatAxisLabel('mood', 4), equals('4'));
    });
  });
}
