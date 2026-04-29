// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $EventsTable extends Events with TableInfo<$EventsTable, Event> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => uuid.v4(),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  late final GeneratedColumnWithTypeConverter<EventCategory, String> category =
      GeneratedColumn<String>(
        'category',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<EventCategory>($EventsTable.$convertercategory);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latencyMsMeta = const VerificationMeta(
    'latencyMs',
  );
  @override
  late final GeneratedColumn<int> latencyMs = GeneratedColumn<int>(
    'latency_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<TriggerSource, String>
  triggerSource = GeneratedColumn<String>(
    'trigger_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<TriggerSource>($EventsTable.$convertertriggerSource);
  @override
  late final GeneratedColumnWithTypeConverter<InteractionType, String>
  interactionType = GeneratedColumn<String>(
    'interaction_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<InteractionType>($EventsTable.$converterinteractionType);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timestamp,
    category,
    label,
    value,
    latencyMs,
    triggerSource,
    interactionType,
    sessionId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<Event> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('latency_ms')) {
      context.handle(
        _latencyMsMeta,
        latencyMs.isAcceptableOrUnknown(data['latency_ms']!, _latencyMsMeta),
      );
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Event map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Event(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      category: $EventsTable.$convertercategory.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}category'],
        )!,
      ),
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      latencyMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latency_ms'],
      )!,
      triggerSource: $EventsTable.$convertertriggerSource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}trigger_source'],
        )!,
      ),
      interactionType: $EventsTable.$converterinteractionType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}interaction_type'],
        )!,
      ),
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      ),
    );
  }

  @override
  $EventsTable createAlias(String alias) {
    return $EventsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EventCategory, String, String> $convertercategory =
      const EnumNameConverter<EventCategory>(EventCategory.values);
  static JsonTypeConverter2<TriggerSource, String, String>
  $convertertriggerSource = const EnumNameConverter<TriggerSource>(
    TriggerSource.values,
  );
  static JsonTypeConverter2<InteractionType, String, String>
  $converterinteractionType = const EnumNameConverter<InteractionType>(
    InteractionType.values,
  );
}

class Event extends DataClass implements Insertable<Event> {
  /// Unique identifier for each event (UUID v4).
  final String id;

  /// When the event occurred.
  final DateTime timestamp;

  /// High-level research domain: Mood, Behavior, Health, AppUsage, or Meta.
  final EventCategory category;

  /// Specific metric name, e.g. 'Instagram', 'Steps', 'Good Deed', 'Fatigue'.
  final String label;

  /// The actual data value, stored as text for flexibility.
  final String value;

  /// HCI metric: milliseconds from opening the input form to pressing save.
  final int latencyMs;

  /// How the event was triggered: Manual, Notification, or System.
  final TriggerSource triggerSource;

  /// How the user interacted: Click, SwipeAway, or Snooze.
  final InteractionType interactionType;

  /// Optional grouping ID to correlate events that belong to the same session.
  final String? sessionId;
  const Event({
    required this.id,
    required this.timestamp,
    required this.category,
    required this.label,
    required this.value,
    required this.latencyMs,
    required this.triggerSource,
    required this.interactionType,
    this.sessionId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    {
      map['category'] = Variable<String>(
        $EventsTable.$convertercategory.toSql(category),
      );
    }
    map['label'] = Variable<String>(label);
    map['value'] = Variable<String>(value);
    map['latency_ms'] = Variable<int>(latencyMs);
    {
      map['trigger_source'] = Variable<String>(
        $EventsTable.$convertertriggerSource.toSql(triggerSource),
      );
    }
    {
      map['interaction_type'] = Variable<String>(
        $EventsTable.$converterinteractionType.toSql(interactionType),
      );
    }
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    return map;
  }

  EventsCompanion toCompanion(bool nullToAbsent) {
    return EventsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      category: Value(category),
      label: Value(label),
      value: Value(value),
      latencyMs: Value(latencyMs),
      triggerSource: Value(triggerSource),
      interactionType: Value(interactionType),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
    );
  }

  factory Event.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Event(
      id: serializer.fromJson<String>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      category: $EventsTable.$convertercategory.fromJson(
        serializer.fromJson<String>(json['category']),
      ),
      label: serializer.fromJson<String>(json['label']),
      value: serializer.fromJson<String>(json['value']),
      latencyMs: serializer.fromJson<int>(json['latencyMs']),
      triggerSource: $EventsTable.$convertertriggerSource.fromJson(
        serializer.fromJson<String>(json['triggerSource']),
      ),
      interactionType: $EventsTable.$converterinteractionType.fromJson(
        serializer.fromJson<String>(json['interactionType']),
      ),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'category': serializer.toJson<String>(
        $EventsTable.$convertercategory.toJson(category),
      ),
      'label': serializer.toJson<String>(label),
      'value': serializer.toJson<String>(value),
      'latencyMs': serializer.toJson<int>(latencyMs),
      'triggerSource': serializer.toJson<String>(
        $EventsTable.$convertertriggerSource.toJson(triggerSource),
      ),
      'interactionType': serializer.toJson<String>(
        $EventsTable.$converterinteractionType.toJson(interactionType),
      ),
      'sessionId': serializer.toJson<String?>(sessionId),
    };
  }

  Event copyWith({
    String? id,
    DateTime? timestamp,
    EventCategory? category,
    String? label,
    String? value,
    int? latencyMs,
    TriggerSource? triggerSource,
    InteractionType? interactionType,
    Value<String?> sessionId = const Value.absent(),
  }) => Event(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    category: category ?? this.category,
    label: label ?? this.label,
    value: value ?? this.value,
    latencyMs: latencyMs ?? this.latencyMs,
    triggerSource: triggerSource ?? this.triggerSource,
    interactionType: interactionType ?? this.interactionType,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
  );
  Event copyWithCompanion(EventsCompanion data) {
    return Event(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      category: data.category.present ? data.category.value : this.category,
      label: data.label.present ? data.label.value : this.label,
      value: data.value.present ? data.value.value : this.value,
      latencyMs: data.latencyMs.present ? data.latencyMs.value : this.latencyMs,
      triggerSource: data.triggerSource.present
          ? data.triggerSource.value
          : this.triggerSource,
      interactionType: data.interactionType.present
          ? data.interactionType.value
          : this.interactionType,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Event(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('category: $category, ')
          ..write('label: $label, ')
          ..write('value: $value, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('triggerSource: $triggerSource, ')
          ..write('interactionType: $interactionType, ')
          ..write('sessionId: $sessionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    timestamp,
    category,
    label,
    value,
    latencyMs,
    triggerSource,
    interactionType,
    sessionId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Event &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.category == this.category &&
          other.label == this.label &&
          other.value == this.value &&
          other.latencyMs == this.latencyMs &&
          other.triggerSource == this.triggerSource &&
          other.interactionType == this.interactionType &&
          other.sessionId == this.sessionId);
}

class EventsCompanion extends UpdateCompanion<Event> {
  final Value<String> id;
  final Value<DateTime> timestamp;
  final Value<EventCategory> category;
  final Value<String> label;
  final Value<String> value;
  final Value<int> latencyMs;
  final Value<TriggerSource> triggerSource;
  final Value<InteractionType> interactionType;
  final Value<String?> sessionId;
  final Value<int> rowid;
  const EventsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.category = const Value.absent(),
    this.label = const Value.absent(),
    this.value = const Value.absent(),
    this.latencyMs = const Value.absent(),
    this.triggerSource = const Value.absent(),
    this.interactionType = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventsCompanion.insert({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    required EventCategory category,
    required String label,
    required String value,
    this.latencyMs = const Value.absent(),
    required TriggerSource triggerSource,
    required InteractionType interactionType,
    this.sessionId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : category = Value(category),
       label = Value(label),
       value = Value(value),
       triggerSource = Value(triggerSource),
       interactionType = Value(interactionType);
  static Insertable<Event> custom({
    Expression<String>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? category,
    Expression<String>? label,
    Expression<String>? value,
    Expression<int>? latencyMs,
    Expression<String>? triggerSource,
    Expression<String>? interactionType,
    Expression<String>? sessionId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (category != null) 'category': category,
      if (label != null) 'label': label,
      if (value != null) 'value': value,
      if (latencyMs != null) 'latency_ms': latencyMs,
      if (triggerSource != null) 'trigger_source': triggerSource,
      if (interactionType != null) 'interaction_type': interactionType,
      if (sessionId != null) 'session_id': sessionId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? timestamp,
    Value<EventCategory>? category,
    Value<String>? label,
    Value<String>? value,
    Value<int>? latencyMs,
    Value<TriggerSource>? triggerSource,
    Value<InteractionType>? interactionType,
    Value<String?>? sessionId,
    Value<int>? rowid,
  }) {
    return EventsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      label: label ?? this.label,
      value: value ?? this.value,
      latencyMs: latencyMs ?? this.latencyMs,
      triggerSource: triggerSource ?? this.triggerSource,
      interactionType: interactionType ?? this.interactionType,
      sessionId: sessionId ?? this.sessionId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(
        $EventsTable.$convertercategory.toSql(category.value),
      );
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (latencyMs.present) {
      map['latency_ms'] = Variable<int>(latencyMs.value);
    }
    if (triggerSource.present) {
      map['trigger_source'] = Variable<String>(
        $EventsTable.$convertertriggerSource.toSql(triggerSource.value),
      );
    }
    if (interactionType.present) {
      map['interaction_type'] = Variable<String>(
        $EventsTable.$converterinteractionType.toSql(interactionType.value),
      );
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('category: $category, ')
          ..write('label: $label, ')
          ..write('value: $value, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('triggerSource: $triggerSource, ')
          ..write('interactionType: $interactionType, ')
          ..write('sessionId: $sessionId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomMetricsTable extends CustomMetrics
    with TableInfo<$CustomMetricsTable, CustomMetric> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomMetricsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => uuid.v4(),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<EventCategory, String> category =
      GeneratedColumn<String>(
        'category',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<EventCategory>($CustomMetricsTable.$convertercategory);
  @override
  late final GeneratedColumnWithTypeConverter<MetricInputType, String>
  inputType = GeneratedColumn<String>(
    'input_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<MetricInputType>($CustomMetricsTable.$converterinputType);
  static const VerificationMeta _windowIdsMeta = const VerificationMeta(
    'windowIds',
  );
  @override
  late final GeneratedColumn<String> windowIds = GeneratedColumn<String>(
    'window_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('anytime'),
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isRetroReliableMeta = const VerificationMeta(
    'isRetroReliable',
  );
  @override
  late final GeneratedColumn<bool> isRetroReliable = GeneratedColumn<bool>(
    'is_retro_reliable',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_retro_reliable" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    label,
    category,
    inputType,
    windowIds,
    isEnabled,
    emoji,
    isRetroReliable,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'custom_metrics';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomMetric> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('window_ids')) {
      context.handle(
        _windowIdsMeta,
        windowIds.isAcceptableOrUnknown(data['window_ids']!, _windowIdsMeta),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    }
    if (data.containsKey('is_retro_reliable')) {
      context.handle(
        _isRetroReliableMeta,
        isRetroReliable.isAcceptableOrUnknown(
          data['is_retro_reliable']!,
          _isRetroReliableMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CustomMetric map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomMetric(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      category: $CustomMetricsTable.$convertercategory.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}category'],
        )!,
      ),
      inputType: $CustomMetricsTable.$converterinputType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}input_type'],
        )!,
      ),
      windowIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}window_ids'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      ),
      isRetroReliable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_retro_reliable'],
      ),
    );
  }

  @override
  $CustomMetricsTable createAlias(String alias) {
    return $CustomMetricsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EventCategory, String, String> $convertercategory =
      const EnumNameConverter<EventCategory>(EventCategory.values);
  static JsonTypeConverter2<MetricInputType, String, String>
  $converterinputType = const EnumNameConverter<MetricInputType>(
    MetricInputType.values,
  );
}

class CustomMetric extends DataClass implements Insertable<CustomMetric> {
  /// Unique identifier (UUID v4).
  final String id;

  /// Display name for the metric.
  final String label;

  /// Research domain: mood, behavior, health, etc.
  final EventCategory category;

  /// Determines the input widget.
  final MetricInputType inputType;

  /// Comma-separated list of TrackingWindow IDs.
  final String windowIds;

  /// Whether this metric is currently shown on the Home screen.
  final bool isEnabled;

  /// Visual identifier (emoji or icon).
  final String? emoji;

  /// User-set override for retrospective recall reliability.
  /// null  → derived from inputType (yesNo/counter = reliable, scales = not).
  /// true  → always reliable (e.g. a scale metric the user knows is factual).
  /// false → always unreliable (user explicitly marks a yesNo as subjective).
  final bool? isRetroReliable;
  const CustomMetric({
    required this.id,
    required this.label,
    required this.category,
    required this.inputType,
    required this.windowIds,
    required this.isEnabled,
    this.emoji,
    this.isRetroReliable,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['label'] = Variable<String>(label);
    {
      map['category'] = Variable<String>(
        $CustomMetricsTable.$convertercategory.toSql(category),
      );
    }
    {
      map['input_type'] = Variable<String>(
        $CustomMetricsTable.$converterinputType.toSql(inputType),
      );
    }
    map['window_ids'] = Variable<String>(windowIds);
    map['is_enabled'] = Variable<bool>(isEnabled);
    if (!nullToAbsent || emoji != null) {
      map['emoji'] = Variable<String>(emoji);
    }
    if (!nullToAbsent || isRetroReliable != null) {
      map['is_retro_reliable'] = Variable<bool>(isRetroReliable);
    }
    return map;
  }

  CustomMetricsCompanion toCompanion(bool nullToAbsent) {
    return CustomMetricsCompanion(
      id: Value(id),
      label: Value(label),
      category: Value(category),
      inputType: Value(inputType),
      windowIds: Value(windowIds),
      isEnabled: Value(isEnabled),
      emoji: emoji == null && nullToAbsent
          ? const Value.absent()
          : Value(emoji),
      isRetroReliable: isRetroReliable == null && nullToAbsent
          ? const Value.absent()
          : Value(isRetroReliable),
    );
  }

  factory CustomMetric.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomMetric(
      id: serializer.fromJson<String>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      category: $CustomMetricsTable.$convertercategory.fromJson(
        serializer.fromJson<String>(json['category']),
      ),
      inputType: $CustomMetricsTable.$converterinputType.fromJson(
        serializer.fromJson<String>(json['inputType']),
      ),
      windowIds: serializer.fromJson<String>(json['windowIds']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      emoji: serializer.fromJson<String?>(json['emoji']),
      isRetroReliable: serializer.fromJson<bool?>(json['isRetroReliable']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'label': serializer.toJson<String>(label),
      'category': serializer.toJson<String>(
        $CustomMetricsTable.$convertercategory.toJson(category),
      ),
      'inputType': serializer.toJson<String>(
        $CustomMetricsTable.$converterinputType.toJson(inputType),
      ),
      'windowIds': serializer.toJson<String>(windowIds),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'emoji': serializer.toJson<String?>(emoji),
      'isRetroReliable': serializer.toJson<bool?>(isRetroReliable),
    };
  }

  CustomMetric copyWith({
    String? id,
    String? label,
    EventCategory? category,
    MetricInputType? inputType,
    String? windowIds,
    bool? isEnabled,
    Value<String?> emoji = const Value.absent(),
    Value<bool?> isRetroReliable = const Value.absent(),
  }) => CustomMetric(
    id: id ?? this.id,
    label: label ?? this.label,
    category: category ?? this.category,
    inputType: inputType ?? this.inputType,
    windowIds: windowIds ?? this.windowIds,
    isEnabled: isEnabled ?? this.isEnabled,
    emoji: emoji.present ? emoji.value : this.emoji,
    isRetroReliable: isRetroReliable.present
        ? isRetroReliable.value
        : this.isRetroReliable,
  );
  CustomMetric copyWithCompanion(CustomMetricsCompanion data) {
    return CustomMetric(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      category: data.category.present ? data.category.value : this.category,
      inputType: data.inputType.present ? data.inputType.value : this.inputType,
      windowIds: data.windowIds.present ? data.windowIds.value : this.windowIds,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      isRetroReliable: data.isRetroReliable.present
          ? data.isRetroReliable.value
          : this.isRetroReliable,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomMetric(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('category: $category, ')
          ..write('inputType: $inputType, ')
          ..write('windowIds: $windowIds, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('emoji: $emoji, ')
          ..write('isRetroReliable: $isRetroReliable')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    category,
    inputType,
    windowIds,
    isEnabled,
    emoji,
    isRetroReliable,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomMetric &&
          other.id == this.id &&
          other.label == this.label &&
          other.category == this.category &&
          other.inputType == this.inputType &&
          other.windowIds == this.windowIds &&
          other.isEnabled == this.isEnabled &&
          other.emoji == this.emoji &&
          other.isRetroReliable == this.isRetroReliable);
}

class CustomMetricsCompanion extends UpdateCompanion<CustomMetric> {
  final Value<String> id;
  final Value<String> label;
  final Value<EventCategory> category;
  final Value<MetricInputType> inputType;
  final Value<String> windowIds;
  final Value<bool> isEnabled;
  final Value<String?> emoji;
  final Value<bool?> isRetroReliable;
  final Value<int> rowid;
  const CustomMetricsCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.category = const Value.absent(),
    this.inputType = const Value.absent(),
    this.windowIds = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.emoji = const Value.absent(),
    this.isRetroReliable = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomMetricsCompanion.insert({
    this.id = const Value.absent(),
    required String label,
    required EventCategory category,
    required MetricInputType inputType,
    this.windowIds = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.emoji = const Value.absent(),
    this.isRetroReliable = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : label = Value(label),
       category = Value(category),
       inputType = Value(inputType);
  static Insertable<CustomMetric> custom({
    Expression<String>? id,
    Expression<String>? label,
    Expression<String>? category,
    Expression<String>? inputType,
    Expression<String>? windowIds,
    Expression<bool>? isEnabled,
    Expression<String>? emoji,
    Expression<bool>? isRetroReliable,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (category != null) 'category': category,
      if (inputType != null) 'input_type': inputType,
      if (windowIds != null) 'window_ids': windowIds,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (emoji != null) 'emoji': emoji,
      if (isRetroReliable != null) 'is_retro_reliable': isRetroReliable,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomMetricsCompanion copyWith({
    Value<String>? id,
    Value<String>? label,
    Value<EventCategory>? category,
    Value<MetricInputType>? inputType,
    Value<String>? windowIds,
    Value<bool>? isEnabled,
    Value<String?>? emoji,
    Value<bool?>? isRetroReliable,
    Value<int>? rowid,
  }) {
    return CustomMetricsCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      category: category ?? this.category,
      inputType: inputType ?? this.inputType,
      windowIds: windowIds ?? this.windowIds,
      isEnabled: isEnabled ?? this.isEnabled,
      emoji: emoji ?? this.emoji,
      isRetroReliable: isRetroReliable ?? this.isRetroReliable,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(
        $CustomMetricsTable.$convertercategory.toSql(category.value),
      );
    }
    if (inputType.present) {
      map['input_type'] = Variable<String>(
        $CustomMetricsTable.$converterinputType.toSql(inputType.value),
      );
    }
    if (windowIds.present) {
      map['window_ids'] = Variable<String>(windowIds.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (isRetroReliable.present) {
      map['is_retro_reliable'] = Variable<bool>(isRetroReliable.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomMetricsCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('category: $category, ')
          ..write('inputType: $inputType, ')
          ..write('windowIds: $windowIds, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('emoji: $emoji, ')
          ..write('isRetroReliable: $isRetroReliable, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrackingWindowsTable extends TrackingWindows
    with TableInfo<$TrackingWindowsTable, TrackingWindow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackingWindowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => uuid.v4(),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startHourMeta = const VerificationMeta(
    'startHour',
  );
  @override
  late final GeneratedColumn<int> startHour = GeneratedColumn<int>(
    'start_hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endHourMeta = const VerificationMeta(
    'endHour',
  );
  @override
  late final GeneratedColumn<int> endHour = GeneratedColumn<int>(
    'end_hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isNotificationEnabledMeta =
      const VerificationMeta('isNotificationEnabled');
  @override
  late final GeneratedColumn<bool> isNotificationEnabled =
      GeneratedColumn<bool>(
        'is_notification_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_notification_enabled" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _notificationHourMeta = const VerificationMeta(
    'notificationHour',
  );
  @override
  late final GeneratedColumn<int> notificationHour = GeneratedColumn<int>(
    'notification_hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notificationMinuteMeta =
      const VerificationMeta('notificationMinute');
  @override
  late final GeneratedColumn<int> notificationMinute = GeneratedColumn<int>(
    'notification_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    label,
    startHour,
    startMinute,
    endHour,
    endMinute,
    isNotificationEnabled,
    notificationHour,
    notificationMinute,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracking_windows';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackingWindow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('start_hour')) {
      context.handle(
        _startHourMeta,
        startHour.isAcceptableOrUnknown(data['start_hour']!, _startHourMeta),
      );
    } else if (isInserting) {
      context.missing(_startHourMeta);
    }
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startMinuteMeta);
    }
    if (data.containsKey('end_hour')) {
      context.handle(
        _endHourMeta,
        endHour.isAcceptableOrUnknown(data['end_hour']!, _endHourMeta),
      );
    } else if (isInserting) {
      context.missing(_endHourMeta);
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    } else if (isInserting) {
      context.missing(_endMinuteMeta);
    }
    if (data.containsKey('is_notification_enabled')) {
      context.handle(
        _isNotificationEnabledMeta,
        isNotificationEnabled.isAcceptableOrUnknown(
          data['is_notification_enabled']!,
          _isNotificationEnabledMeta,
        ),
      );
    }
    if (data.containsKey('notification_hour')) {
      context.handle(
        _notificationHourMeta,
        notificationHour.isAcceptableOrUnknown(
          data['notification_hour']!,
          _notificationHourMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_notificationHourMeta);
    }
    if (data.containsKey('notification_minute')) {
      context.handle(
        _notificationMinuteMeta,
        notificationMinute.isAcceptableOrUnknown(
          data['notification_minute']!,
          _notificationMinuteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_notificationMinuteMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrackingWindow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackingWindow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      startHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_hour'],
      )!,
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      )!,
      endHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_hour'],
      )!,
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      )!,
      isNotificationEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_notification_enabled'],
      )!,
      notificationHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_hour'],
      )!,
      notificationMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_minute'],
      )!,
    );
  }

  @override
  $TrackingWindowsTable createAlias(String alias) {
    return $TrackingWindowsTable(attachedDatabase, alias);
  }
}

class TrackingWindow extends DataClass implements Insertable<TrackingWindow> {
  /// Unique identifier (UUID v4).
  final String id;

  /// Human-readable name for the window (e.g. "Morning Routine").
  final String label;

  /// Start time of the window.
  final int startHour;
  final int startMinute;

  /// End time of the window.
  final int endHour;
  final int endMinute;

  /// Whether to send a notification for this window.
  final bool isNotificationEnabled;

  /// The time to send the notification.
  final int notificationHour;
  final int notificationMinute;
  const TrackingWindow({
    required this.id,
    required this.label,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.isNotificationEnabled,
    required this.notificationHour,
    required this.notificationMinute,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['label'] = Variable<String>(label);
    map['start_hour'] = Variable<int>(startHour);
    map['start_minute'] = Variable<int>(startMinute);
    map['end_hour'] = Variable<int>(endHour);
    map['end_minute'] = Variable<int>(endMinute);
    map['is_notification_enabled'] = Variable<bool>(isNotificationEnabled);
    map['notification_hour'] = Variable<int>(notificationHour);
    map['notification_minute'] = Variable<int>(notificationMinute);
    return map;
  }

  TrackingWindowsCompanion toCompanion(bool nullToAbsent) {
    return TrackingWindowsCompanion(
      id: Value(id),
      label: Value(label),
      startHour: Value(startHour),
      startMinute: Value(startMinute),
      endHour: Value(endHour),
      endMinute: Value(endMinute),
      isNotificationEnabled: Value(isNotificationEnabled),
      notificationHour: Value(notificationHour),
      notificationMinute: Value(notificationMinute),
    );
  }

  factory TrackingWindow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackingWindow(
      id: serializer.fromJson<String>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      startHour: serializer.fromJson<int>(json['startHour']),
      startMinute: serializer.fromJson<int>(json['startMinute']),
      endHour: serializer.fromJson<int>(json['endHour']),
      endMinute: serializer.fromJson<int>(json['endMinute']),
      isNotificationEnabled: serializer.fromJson<bool>(
        json['isNotificationEnabled'],
      ),
      notificationHour: serializer.fromJson<int>(json['notificationHour']),
      notificationMinute: serializer.fromJson<int>(json['notificationMinute']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'label': serializer.toJson<String>(label),
      'startHour': serializer.toJson<int>(startHour),
      'startMinute': serializer.toJson<int>(startMinute),
      'endHour': serializer.toJson<int>(endHour),
      'endMinute': serializer.toJson<int>(endMinute),
      'isNotificationEnabled': serializer.toJson<bool>(isNotificationEnabled),
      'notificationHour': serializer.toJson<int>(notificationHour),
      'notificationMinute': serializer.toJson<int>(notificationMinute),
    };
  }

  TrackingWindow copyWith({
    String? id,
    String? label,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    bool? isNotificationEnabled,
    int? notificationHour,
    int? notificationMinute,
  }) => TrackingWindow(
    id: id ?? this.id,
    label: label ?? this.label,
    startHour: startHour ?? this.startHour,
    startMinute: startMinute ?? this.startMinute,
    endHour: endHour ?? this.endHour,
    endMinute: endMinute ?? this.endMinute,
    isNotificationEnabled: isNotificationEnabled ?? this.isNotificationEnabled,
    notificationHour: notificationHour ?? this.notificationHour,
    notificationMinute: notificationMinute ?? this.notificationMinute,
  );
  TrackingWindow copyWithCompanion(TrackingWindowsCompanion data) {
    return TrackingWindow(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      startHour: data.startHour.present ? data.startHour.value : this.startHour,
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      endHour: data.endHour.present ? data.endHour.value : this.endHour,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
      isNotificationEnabled: data.isNotificationEnabled.present
          ? data.isNotificationEnabled.value
          : this.isNotificationEnabled,
      notificationHour: data.notificationHour.present
          ? data.notificationHour.value
          : this.notificationHour,
      notificationMinute: data.notificationMinute.present
          ? data.notificationMinute.value
          : this.notificationMinute,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackingWindow(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('startHour: $startHour, ')
          ..write('startMinute: $startMinute, ')
          ..write('endHour: $endHour, ')
          ..write('endMinute: $endMinute, ')
          ..write('isNotificationEnabled: $isNotificationEnabled, ')
          ..write('notificationHour: $notificationHour, ')
          ..write('notificationMinute: $notificationMinute')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    startHour,
    startMinute,
    endHour,
    endMinute,
    isNotificationEnabled,
    notificationHour,
    notificationMinute,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackingWindow &&
          other.id == this.id &&
          other.label == this.label &&
          other.startHour == this.startHour &&
          other.startMinute == this.startMinute &&
          other.endHour == this.endHour &&
          other.endMinute == this.endMinute &&
          other.isNotificationEnabled == this.isNotificationEnabled &&
          other.notificationHour == this.notificationHour &&
          other.notificationMinute == this.notificationMinute);
}

class TrackingWindowsCompanion extends UpdateCompanion<TrackingWindow> {
  final Value<String> id;
  final Value<String> label;
  final Value<int> startHour;
  final Value<int> startMinute;
  final Value<int> endHour;
  final Value<int> endMinute;
  final Value<bool> isNotificationEnabled;
  final Value<int> notificationHour;
  final Value<int> notificationMinute;
  final Value<int> rowid;
  const TrackingWindowsCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.startHour = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endHour = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.isNotificationEnabled = const Value.absent(),
    this.notificationHour = const Value.absent(),
    this.notificationMinute = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrackingWindowsCompanion.insert({
    this.id = const Value.absent(),
    required String label,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    this.isNotificationEnabled = const Value.absent(),
    required int notificationHour,
    required int notificationMinute,
    this.rowid = const Value.absent(),
  }) : label = Value(label),
       startHour = Value(startHour),
       startMinute = Value(startMinute),
       endHour = Value(endHour),
       endMinute = Value(endMinute),
       notificationHour = Value(notificationHour),
       notificationMinute = Value(notificationMinute);
  static Insertable<TrackingWindow> custom({
    Expression<String>? id,
    Expression<String>? label,
    Expression<int>? startHour,
    Expression<int>? startMinute,
    Expression<int>? endHour,
    Expression<int>? endMinute,
    Expression<bool>? isNotificationEnabled,
    Expression<int>? notificationHour,
    Expression<int>? notificationMinute,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (startHour != null) 'start_hour': startHour,
      if (startMinute != null) 'start_minute': startMinute,
      if (endHour != null) 'end_hour': endHour,
      if (endMinute != null) 'end_minute': endMinute,
      if (isNotificationEnabled != null)
        'is_notification_enabled': isNotificationEnabled,
      if (notificationHour != null) 'notification_hour': notificationHour,
      if (notificationMinute != null) 'notification_minute': notificationMinute,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrackingWindowsCompanion copyWith({
    Value<String>? id,
    Value<String>? label,
    Value<int>? startHour,
    Value<int>? startMinute,
    Value<int>? endHour,
    Value<int>? endMinute,
    Value<bool>? isNotificationEnabled,
    Value<int>? notificationHour,
    Value<int>? notificationMinute,
    Value<int>? rowid,
  }) {
    return TrackingWindowsCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      isNotificationEnabled:
          isNotificationEnabled ?? this.isNotificationEnabled,
      notificationHour: notificationHour ?? this.notificationHour,
      notificationMinute: notificationMinute ?? this.notificationMinute,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (startHour.present) {
      map['start_hour'] = Variable<int>(startHour.value);
    }
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (endHour.present) {
      map['end_hour'] = Variable<int>(endHour.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    if (isNotificationEnabled.present) {
      map['is_notification_enabled'] = Variable<bool>(
        isNotificationEnabled.value,
      );
    }
    if (notificationHour.present) {
      map['notification_hour'] = Variable<int>(notificationHour.value);
    }
    if (notificationMinute.present) {
      map['notification_minute'] = Variable<int>(notificationMinute.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackingWindowsCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('startHour: $startHour, ')
          ..write('startMinute: $startMinute, ')
          ..write('endHour: $endHour, ')
          ..write('endMinute: $endMinute, ')
          ..write('isNotificationEnabled: $isNotificationEnabled, ')
          ..write('notificationHour: $notificationHour, ')
          ..write('notificationMinute: $notificationMinute, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EventsTable events = $EventsTable(this);
  late final $CustomMetricsTable customMetrics = $CustomMetricsTable(this);
  late final $TrackingWindowsTable trackingWindows = $TrackingWindowsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    events,
    customMetrics,
    trackingWindows,
  ];
}

typedef $$EventsTableCreateCompanionBuilder =
    EventsCompanion Function({
      Value<String> id,
      Value<DateTime> timestamp,
      required EventCategory category,
      required String label,
      required String value,
      Value<int> latencyMs,
      required TriggerSource triggerSource,
      required InteractionType interactionType,
      Value<String?> sessionId,
      Value<int> rowid,
    });
typedef $$EventsTableUpdateCompanionBuilder =
    EventsCompanion Function({
      Value<String> id,
      Value<DateTime> timestamp,
      Value<EventCategory> category,
      Value<String> label,
      Value<String> value,
      Value<int> latencyMs,
      Value<TriggerSource> triggerSource,
      Value<InteractionType> interactionType,
      Value<String?> sessionId,
      Value<int> rowid,
    });

class $$EventsTableFilterComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<EventCategory, EventCategory, String>
  get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TriggerSource, TriggerSource, String>
  get triggerSource => $composableBuilder(
    column: $table.triggerSource,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<InteractionType, InteractionType, String>
  get interactionType => $composableBuilder(
    column: $table.interactionType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventsTableOrderingComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triggerSource => $composableBuilder(
    column: $table.triggerSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get interactionType => $composableBuilder(
    column: $table.interactionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EventCategory, String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get latencyMs =>
      $composableBuilder(column: $table.latencyMs, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TriggerSource, String> get triggerSource =>
      $composableBuilder(
        column: $table.triggerSource,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<InteractionType, String>
  get interactionType => $composableBuilder(
    column: $table.interactionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);
}

class $$EventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventsTable,
          Event,
          $$EventsTableFilterComposer,
          $$EventsTableOrderingComposer,
          $$EventsTableAnnotationComposer,
          $$EventsTableCreateCompanionBuilder,
          $$EventsTableUpdateCompanionBuilder,
          (Event, BaseReferences<_$AppDatabase, $EventsTable, Event>),
          Event,
          PrefetchHooks Function()
        > {
  $$EventsTableTableManager(_$AppDatabase db, $EventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<EventCategory> category = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> latencyMs = const Value.absent(),
                Value<TriggerSource> triggerSource = const Value.absent(),
                Value<InteractionType> interactionType = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsCompanion(
                id: id,
                timestamp: timestamp,
                category: category,
                label: label,
                value: value,
                latencyMs: latencyMs,
                triggerSource: triggerSource,
                interactionType: interactionType,
                sessionId: sessionId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                required EventCategory category,
                required String label,
                required String value,
                Value<int> latencyMs = const Value.absent(),
                required TriggerSource triggerSource,
                required InteractionType interactionType,
                Value<String?> sessionId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsCompanion.insert(
                id: id,
                timestamp: timestamp,
                category: category,
                label: label,
                value: value,
                latencyMs: latencyMs,
                triggerSource: triggerSource,
                interactionType: interactionType,
                sessionId: sessionId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventsTable,
      Event,
      $$EventsTableFilterComposer,
      $$EventsTableOrderingComposer,
      $$EventsTableAnnotationComposer,
      $$EventsTableCreateCompanionBuilder,
      $$EventsTableUpdateCompanionBuilder,
      (Event, BaseReferences<_$AppDatabase, $EventsTable, Event>),
      Event,
      PrefetchHooks Function()
    >;
typedef $$CustomMetricsTableCreateCompanionBuilder =
    CustomMetricsCompanion Function({
      Value<String> id,
      required String label,
      required EventCategory category,
      required MetricInputType inputType,
      Value<String> windowIds,
      Value<bool> isEnabled,
      Value<String?> emoji,
      Value<bool?> isRetroReliable,
      Value<int> rowid,
    });
typedef $$CustomMetricsTableUpdateCompanionBuilder =
    CustomMetricsCompanion Function({
      Value<String> id,
      Value<String> label,
      Value<EventCategory> category,
      Value<MetricInputType> inputType,
      Value<String> windowIds,
      Value<bool> isEnabled,
      Value<String?> emoji,
      Value<bool?> isRetroReliable,
      Value<int> rowid,
    });

class $$CustomMetricsTableFilterComposer
    extends Composer<_$AppDatabase, $CustomMetricsTable> {
  $$CustomMetricsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<EventCategory, EventCategory, String>
  get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<MetricInputType, MetricInputType, String>
  get inputType => $composableBuilder(
    column: $table.inputType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get windowIds => $composableBuilder(
    column: $table.windowIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRetroReliable => $composableBuilder(
    column: $table.isRetroReliable,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomMetricsTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomMetricsTable> {
  $$CustomMetricsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputType => $composableBuilder(
    column: $table.inputType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get windowIds => $composableBuilder(
    column: $table.windowIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRetroReliable => $composableBuilder(
    column: $table.isRetroReliable,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomMetricsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomMetricsTable> {
  $$CustomMetricsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EventCategory, String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MetricInputType, String> get inputType =>
      $composableBuilder(column: $table.inputType, builder: (column) => column);

  GeneratedColumn<String> get windowIds =>
      $composableBuilder(column: $table.windowIds, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<bool> get isRetroReliable => $composableBuilder(
    column: $table.isRetroReliable,
    builder: (column) => column,
  );
}

class $$CustomMetricsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomMetricsTable,
          CustomMetric,
          $$CustomMetricsTableFilterComposer,
          $$CustomMetricsTableOrderingComposer,
          $$CustomMetricsTableAnnotationComposer,
          $$CustomMetricsTableCreateCompanionBuilder,
          $$CustomMetricsTableUpdateCompanionBuilder,
          (
            CustomMetric,
            BaseReferences<_$AppDatabase, $CustomMetricsTable, CustomMetric>,
          ),
          CustomMetric,
          PrefetchHooks Function()
        > {
  $$CustomMetricsTableTableManager(_$AppDatabase db, $CustomMetricsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomMetricsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomMetricsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomMetricsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<EventCategory> category = const Value.absent(),
                Value<MetricInputType> inputType = const Value.absent(),
                Value<String> windowIds = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<String?> emoji = const Value.absent(),
                Value<bool?> isRetroReliable = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomMetricsCompanion(
                id: id,
                label: label,
                category: category,
                inputType: inputType,
                windowIds: windowIds,
                isEnabled: isEnabled,
                emoji: emoji,
                isRetroReliable: isRetroReliable,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String label,
                required EventCategory category,
                required MetricInputType inputType,
                Value<String> windowIds = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<String?> emoji = const Value.absent(),
                Value<bool?> isRetroReliable = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomMetricsCompanion.insert(
                id: id,
                label: label,
                category: category,
                inputType: inputType,
                windowIds: windowIds,
                isEnabled: isEnabled,
                emoji: emoji,
                isRetroReliable: isRetroReliable,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomMetricsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomMetricsTable,
      CustomMetric,
      $$CustomMetricsTableFilterComposer,
      $$CustomMetricsTableOrderingComposer,
      $$CustomMetricsTableAnnotationComposer,
      $$CustomMetricsTableCreateCompanionBuilder,
      $$CustomMetricsTableUpdateCompanionBuilder,
      (
        CustomMetric,
        BaseReferences<_$AppDatabase, $CustomMetricsTable, CustomMetric>,
      ),
      CustomMetric,
      PrefetchHooks Function()
    >;
typedef $$TrackingWindowsTableCreateCompanionBuilder =
    TrackingWindowsCompanion Function({
      Value<String> id,
      required String label,
      required int startHour,
      required int startMinute,
      required int endHour,
      required int endMinute,
      Value<bool> isNotificationEnabled,
      required int notificationHour,
      required int notificationMinute,
      Value<int> rowid,
    });
typedef $$TrackingWindowsTableUpdateCompanionBuilder =
    TrackingWindowsCompanion Function({
      Value<String> id,
      Value<String> label,
      Value<int> startHour,
      Value<int> startMinute,
      Value<int> endHour,
      Value<int> endMinute,
      Value<bool> isNotificationEnabled,
      Value<int> notificationHour,
      Value<int> notificationMinute,
      Value<int> rowid,
    });

class $$TrackingWindowsTableFilterComposer
    extends Composer<_$AppDatabase, $TrackingWindowsTable> {
  $$TrackingWindowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startHour => $composableBuilder(
    column: $table.startHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endHour => $composableBuilder(
    column: $table.endHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isNotificationEnabled => $composableBuilder(
    column: $table.isNotificationEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notificationHour => $composableBuilder(
    column: $table.notificationHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notificationMinute => $composableBuilder(
    column: $table.notificationMinute,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrackingWindowsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackingWindowsTable> {
  $$TrackingWindowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startHour => $composableBuilder(
    column: $table.startHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endHour => $composableBuilder(
    column: $table.endHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isNotificationEnabled => $composableBuilder(
    column: $table.isNotificationEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationHour => $composableBuilder(
    column: $table.notificationHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationMinute => $composableBuilder(
    column: $table.notificationMinute,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrackingWindowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackingWindowsTable> {
  $$TrackingWindowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get startHour =>
      $composableBuilder(column: $table.startHour, builder: (column) => column);

  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endHour =>
      $composableBuilder(column: $table.endHour, builder: (column) => column);

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);

  GeneratedColumn<bool> get isNotificationEnabled => $composableBuilder(
    column: $table.isNotificationEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notificationHour => $composableBuilder(
    column: $table.notificationHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notificationMinute => $composableBuilder(
    column: $table.notificationMinute,
    builder: (column) => column,
  );
}

class $$TrackingWindowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrackingWindowsTable,
          TrackingWindow,
          $$TrackingWindowsTableFilterComposer,
          $$TrackingWindowsTableOrderingComposer,
          $$TrackingWindowsTableAnnotationComposer,
          $$TrackingWindowsTableCreateCompanionBuilder,
          $$TrackingWindowsTableUpdateCompanionBuilder,
          (
            TrackingWindow,
            BaseReferences<
              _$AppDatabase,
              $TrackingWindowsTable,
              TrackingWindow
            >,
          ),
          TrackingWindow,
          PrefetchHooks Function()
        > {
  $$TrackingWindowsTableTableManager(
    _$AppDatabase db,
    $TrackingWindowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackingWindowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackingWindowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackingWindowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> startHour = const Value.absent(),
                Value<int> startMinute = const Value.absent(),
                Value<int> endHour = const Value.absent(),
                Value<int> endMinute = const Value.absent(),
                Value<bool> isNotificationEnabled = const Value.absent(),
                Value<int> notificationHour = const Value.absent(),
                Value<int> notificationMinute = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrackingWindowsCompanion(
                id: id,
                label: label,
                startHour: startHour,
                startMinute: startMinute,
                endHour: endHour,
                endMinute: endMinute,
                isNotificationEnabled: isNotificationEnabled,
                notificationHour: notificationHour,
                notificationMinute: notificationMinute,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String label,
                required int startHour,
                required int startMinute,
                required int endHour,
                required int endMinute,
                Value<bool> isNotificationEnabled = const Value.absent(),
                required int notificationHour,
                required int notificationMinute,
                Value<int> rowid = const Value.absent(),
              }) => TrackingWindowsCompanion.insert(
                id: id,
                label: label,
                startHour: startHour,
                startMinute: startMinute,
                endHour: endHour,
                endMinute: endMinute,
                isNotificationEnabled: isNotificationEnabled,
                notificationHour: notificationHour,
                notificationMinute: notificationMinute,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrackingWindowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrackingWindowsTable,
      TrackingWindow,
      $$TrackingWindowsTableFilterComposer,
      $$TrackingWindowsTableOrderingComposer,
      $$TrackingWindowsTableAnnotationComposer,
      $$TrackingWindowsTableCreateCompanionBuilder,
      $$TrackingWindowsTableUpdateCompanionBuilder,
      (
        TrackingWindow,
        BaseReferences<_$AppDatabase, $TrackingWindowsTable, TrackingWindow>,
      ),
      TrackingWindow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db, _db.events);
  $$CustomMetricsTableTableManager get customMetrics =>
      $$CustomMetricsTableTableManager(_db, _db.customMetrics);
  $$TrackingWindowsTableTableManager get trackingWindows =>
      $$TrackingWindowsTableTableManager(_db, _db.trackingWindows);
}
