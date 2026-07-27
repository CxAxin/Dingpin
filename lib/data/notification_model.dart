// Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
// Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.

import 'package:uuid/uuid.dart';

/// Mirrors the original Pinnit `PinnitNotification` Room entity.
///
/// Key behaviours preserved from the native app:
///  * [isPinned] defaults to true (a new notification is pinned by default).
///  * [deletedAt] implements soft-deletion (deleted rows stay in the DB but
///    are filtered out of every query).
class PinnitNotification {
  final String uuid;
  final String title;
  final String? content;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  PinnitNotification({
    String? uuid,
    required this.title,
    this.content,
    this.isPinned = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  })  : uuid = uuid ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  PinnitNotification copyWith({
    String? title,
    String? content,
    bool? isPinned,
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
    );
  }

  /// Matches the original `equalsTitleAndContent` helper.
  bool equalsTitleAndContent(String? otherTitle, String? otherContent) =>
      title == (otherTitle ?? '') && (content ?? '') == (otherContent ?? '');

  Map<String, Object?> toMap() => {
        'uuid': uuid,
        'title': title,
        'content': content,
        'isPinned': isPinned ? 1 : 0,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deletedAt': deletedAt?.millisecondsSinceEpoch,
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
    );
  }
}
