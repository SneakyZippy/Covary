import '../database/app_database.dart';

/// Represents a specific scheduled calendar occurrence of a [TrackingWindow].
class WindowOccurrence {
  final TrackingWindow window;
  final DateTime start;
  final DateTime end;
  final DateTime targetTime;

  WindowOccurrence({
    required this.window,
    required this.start,
    required this.end,
    required this.targetTime,
  });
}
