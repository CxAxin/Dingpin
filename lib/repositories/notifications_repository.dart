// Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
// Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pinnit_flutter/data/app_database.dart';
import 'package:pinnit_flutter/data/notification_model.dart';
import 'package:pinnit_flutter/services/notification_service.dart';

/// Holds the in-memory list of (non-deleted) notifications and exposes the
/// mutating actions. Every mutation keeps the local DB, the system
/// notification shade and this list in sync.
final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<PinnitNotification>>(
  NotificationsNotifier.new,
);

class NotificationsNotifier extends Notifier<List<PinnitNotification>> {
  @override
  List<PinnitNotification> build() {
    // Kick off the initial load; state updates when it completes.
    _load();
    return const [];
  }

  Future<void> _load() async {
    state = await AppDatabase.notifications();
  }

  Future<void> refresh() => _load();

  /// Insert or update a notification and reflect the change in the shade.
  Future<void> save(PinnitNotification n) async {
    await AppDatabase.save(n);
    if (n.isPinned) {
      await NotificationService.instance.showPinned(n);
    } else {
      await NotificationService.instance.cancelPinned(n.uuid);
    }
    await _load();
  }

  Future<void> togglePin(PinnitNotification n) => save(n.copyWith(isPinned: !n.isPinned));

  /// Soft delete + remove the system notification.
  Future<void> delete(PinnitNotification n) async {
    await AppDatabase.softDelete(n.uuid);
    await NotificationService.instance.cancelPinned(n.uuid);
    await _load();
  }

  /// Re-post every pinned notification to the shade (e.g. after reboot).
  Future<void> restorePinnedToSystem() async {
    final pinned = await AppDatabase.pinnedNotifications();
    for (final n in pinned) {
      await NotificationService.instance.showPinned(n);
    }
  }
}
