// Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
// Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pinnit_flutter/data/app_database.dart';
import 'package:pinnit_flutter/data/third_party_notification.dart';
import 'package:pinnit_flutter/services/notification_listener_bridge.dart';

/// Holds the list of captured third-party notifications and exposes the
/// mutating actions (delete / clear / note). Mirrors [NotificationsNotifier]
/// but for notification history instead of pinned notes.
final thirdPartyProvider =
    NotifierProvider<ThirdPartyNotifier, List<ThirdPartyNotification>>(
  ThirdPartyNotifier.new,
);

class ThirdPartyNotifier extends Notifier<List<ThirdPartyNotification>> {
  @override
  List<ThirdPartyNotification> build() {
    // Initial load, then keep the list live as the listener captures more.
    _load();
    NotificationListenerBridge.instance.captured.listen((_) => _load());
    return const [];
  }

  Future<void> _load() async {
    state = await AppDatabase.thirdPartyNotifications();
  }

  Future<void> refresh() => _load();

  Future<void> delete(String uuid) async {
    await AppDatabase.deleteThirdParty(uuid);
    await _load();
  }

  Future<void> clearAll() async {
    await AppDatabase.clearThirdParty();
    await _load();
  }

  Future<void> setNote(String uuid, String? note) async {
    await AppDatabase.updateThirdPartyNote(uuid, note);
    await _load();
  }
}
