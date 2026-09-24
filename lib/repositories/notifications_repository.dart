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
  /// Guards `state =` after dispose (async work can finish late).
  bool _disposed = false;

  @override
  List<PinnitNotification> build() {
    _disposed = false;
    // Kick off the initial load; state updates when it completes.
    _load();
    ref.onDispose(() => _disposed = true);
    return const [];
  }

  Future<void> _load() async {
    final rows = await AppDatabase.notifications();
    if (_disposed) return;
    state = rows;
  }

  Future<void> refresh() => _load();

  /// Insert or update a notification and reflect the change in the shade.
  ///
  /// The in-memory list is patched in place (_upsertLocal) instead of being
  /// re-queried, so saving stays responsive even while the notification
  /// listener is busy writing history rows.
  Future<void> save(PinnitNotification n) async {
    await AppDatabase.save(n);
    _upsertLocal(n);
    if (n.isPinned) {
      await NotificationService.instance.showPinned(n);
    } else {
      await NotificationService.instance.cancelPinned(n.uuid);
    }
  }

  Future<void> togglePin(PinnitNotification n) => save(n.copyWith(isPinned: !n.isPinned));

  /// Soft delete + remove the system notification.
  Future<void> delete(PinnitNotification n) async {
    await AppDatabase.softDelete(n.uuid);
    await NotificationService.instance.cancelPinned(n.uuid);
    if (_disposed) return;
    state = state.where((e) => e.uuid != n.uuid).toList();
  }

  /// Undo a delete — restore a notification that was dismissed
  /// accidentally (via the SnackBar "撤销" action).
  Future<void> restore(PinnitNotification n) async {
    await AppDatabase.undelete(n.uuid);
    if (n.isPinned) {
      await NotificationService.instance.showPinned(n);
    }
    if (_disposed) return;
    _upsertLocal(n);
  }

  /// Keep `state` in the same order as the DB query: pinned first, then
  /// most-recently updated.
  void _upsertLocal(PinnitNotification n) {
    if (_disposed) return;
    final next = state.where((e) => e.uuid != n.uuid).toList()..add(n);
    next.sort((a, b) {
      final pin = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
      if (pin != 0) return pin;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    state = next;
  }

  /// Re-post every pinned notification to the shade (e.g. after reboot).
  Future<void> restorePinnedToSystem() async {
    final pinned = await AppDatabase.pinnedNotifications();
    for (final n in pinned) {
      await NotificationService.instance.showPinned(n);
    }
  }
}
