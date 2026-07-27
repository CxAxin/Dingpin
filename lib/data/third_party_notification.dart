import 'package:uuid/uuid.dart';

/// A notification captured from another app via the system
/// [NotificationListenerService].
///
/// This mirrors the original Pinnit "notification history" feature: other
/// apps' notifications are recorded, searchable/filterable, and the user can
/// attach a personal note to any of them.
class ThirdPartyNotification {
  final String uuid;
  final String packageName;
  final String? appName;
  final String? title;
  final String? content;

  /// When the system notification was posted (epoch millis).
  final int postedAt;

  /// User-added note (the original Pinnit's "add note" capability).
  final String? note;

  final int createdAt;

  ThirdPartyNotification({
    String? uuid,
    required this.packageName,
    this.appName,
    this.title,
    this.content,
    required this.postedAt,
    this.note,
    int? createdAt,
  })  : uuid = uuid ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  ThirdPartyNotification copyWith({
    String? note,
    int? postedAt,
  }) {
    return ThirdPartyNotification(
      uuid: uuid,
      packageName: packageName,
      appName: appName,
      title: title,
      content: content,
      postedAt: postedAt ?? this.postedAt,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'uuid': uuid,
        'packageName': packageName,
        'appName': appName,
        'title': title,
        'content': content,
        'postedAt': postedAt,
        'note': note,
        'createdAt': createdAt,
      };

  factory ThirdPartyNotification.fromMap(Map<String, Object?> map) {
    return ThirdPartyNotification(
      uuid: map['uuid'] as String,
      packageName: map['packageName'] as String,
      appName: map['appName'] as String?,
      title: map['title'] as String?,
      content: map['content'] as String?,
      postedAt: map['postedAt'] as int,
      note: map['note'] as String?,
      createdAt: map['createdAt'] as int,
    );
  }

  /// Used to de-duplicate rapidly re-posted (often "ongoing") notifications
  /// from the same app with identical content.
  bool sameContent(ThirdPartyNotification other) =>
      packageName == other.packageName &&
      title == other.title &&
      content == other.content;
}
