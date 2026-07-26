// Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
// Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.

import 'package:uuid/uuid.dart';

/// Mirrors the original Pinnit `ScheduleType` enum (Daily / Weekly / Monthly).
enum ScheduleType {
  daily,
  weekly,
  monthly;

  String get label {
    switch (this) {
      case ScheduleType.daily:
        return '每天';
      case ScheduleType.weekly:
        return '每周';
      case ScheduleType.monthly:
        return '每月';
    }
  }
}

/// A recurring schedule attached to a notification.
///
/// Dates are stored as [DateTime] but only the relevant parts are used:
/// [date] carries the year/month/day, [time] carries the hour/minute.
class Schedule {
  final DateTime? date;
  final DateTime? time;
  final ScheduleType? type;

  const Schedule({this.date, this.time, this.type});

  Schedule copyWith({DateTime? date, DateTime? time, ScheduleType? type}) {
    return Schedule(
      date: date ?? this.date,
      time: time ?? this.time,
      type: type ?? this.type,
    );
  }

  bool get hasSchedule => type != null && date != null && time != null;

  /// Combined date+time used to actually schedule the notification.
  DateTime? get scheduledDateTime {
    if (date == null || time == null) return null;
    return DateTime(
      date!.year,
      date!.month,
      date!.day,
      time!.hour,
      time!.minute,
    );
  }

  Map<String, Object?> toMap() => {
        'scheduleDate': date?.millisecondsSinceEpoch,
        'scheduleTime': time?.millisecondsSinceEpoch,
        'scheduleType': type?.name,
      };

  factory Schedule.fromMap(Map<String, Object?> map) {
    final raw = map['scheduleType'] as String?;
    return Schedule(
      date: _fromMillis(map['scheduleDate']),
      time: _fromMillis(map['scheduleTime']),
      type: raw == null ? null : ScheduleType.values.byName(raw),
    );
  }

  static DateTime? _fromMillis(Object? v) =>
      v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);
}

/// Mirrors the original Pinnit `PinnitNotification` Room entity.
///
/// Key behaviours preserved from the native app:
///  * [isPinned] defaults to true (a new notification is pinned by default).
///  * [deletedAt] implements soft-deletion (deleted rows stay in the DB but
///    are filtered out of every query).
///  * [schedule] is embedded and optional.
class PinnitNotification {
  final String uuid;
  final String title;
  final String? content;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final Schedule? schedule;

  PinnitNotification({
    String? uuid,
    required this.title,
    this.content,
    this.isPinned = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.schedule,
  })  : uuid = uuid ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  PinnitNotification copyWith({
    String? title,
    String? content,
    bool? isPinned,
    Schedule? schedule,
    DateTime? deletedAt,
    DateTime? updatedAt,
  }) {
    return PinnitNotification(
      uuid: uuid,
      title: title ?? this.title,
      content: content ?? this.content,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      deletedAt: deletedAt ?? this.deletedAt,
      schedule: schedule ?? this.schedule,
    );
  }

  bool get hasSchedule => schedule?.hasSchedule ?? false;

  /// Matches the original `equalsTitleAndContent` helper.
  bool equalsTitleAndContent(String? otherTitle, String? otherContent) =>
      title == (otherTitle ?? '') &&
      (content ?? '') == (otherContent ?? '');

  Map<String, Object?> toMap() => {
        'uuid': uuid,
        'title': title,
        'content': content,
        'isPinned': isPinned ? 1 : 0,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deletedAt': deletedAt?.millisecondsSinceEpoch,
        ...schedule?.toMap() ?? {},
      };

  factory PinnitNotification.fromMap(Map<String, Object?> map) {
    return PinnitNotification(
      uuid: map['uuid'] as String,
      title: map['title'] as String,
      content: map['content'] as String?,
      isPinned: (map['isPinned'] as int? ?? 1) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      deletedAt: map['deletedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['deletedAt'] as int),
      schedule: Schedule.fromMap(map),
    );
  }
}
