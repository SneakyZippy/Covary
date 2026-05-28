import 'dart:convert';

class MealReminder {
  final String id;
  final String label;
  final int hour;
  final int minute;
  final bool isEnabled;

  MealReminder({
    required this.id,
    required this.label,
    required this.hour,
    required this.minute,
    required this.isEnabled,
  });

  MealReminder copyWith({
    String? id,
    String? label,
    int? hour,
    int? minute,
    bool? isEnabled,
  }) {
    return MealReminder(
      id: id ?? this.id,
      label: label ?? this.label,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'hour': hour,
      'minute': minute,
      'isEnabled': isEnabled,
    };
  }

  factory MealReminder.fromMap(Map<String, dynamic> map) {
    return MealReminder(
      id: map['id'] ?? '',
      label: map['label'] ?? '',
      hour: map['hour'] ?? 0,
      minute: map['minute'] ?? 0,
      isEnabled: map['isEnabled'] ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory MealReminder.fromJson(String source) => MealReminder.fromMap(json.decode(source));
}
