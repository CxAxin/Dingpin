// Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
// Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pinnit_flutter/data/app_database.dart';
import 'package:pinnit_flutter/data/third_party_notification.dart';
import 'package:pinnit_flutter/services/notification_listener_bridge.dart';

/// Snapshot of the history list held in memory.
///
/// Kept as an explicit record (instead of a bare `List`) so the screen can
/// distinguish "loaded" from "empty", and "still loading" from "no more rows".
class HistoryState {
  const HistoryState({
    this.items = const [],
    this.hasMore = true,
    this.loading = false,
    this.query = '',
    this.groupByApp = false,
  });

  final List<ThirdPartyNotification> items;
  final bool hasMore;
  final bool loading;

  /// Active search term. Empty means "browse mode" (paged); anything else
  /// means "search mode" (single server-side query, no paging).
  final String query;

  /// Whether the history list is rendered grouped by app (vs flat).
  final bool groupByApp;

  HistoryState copyWith({
    List<ThirdPartyNotification>? items,
    bool? hasMore,
    bool? loading,
    String? query,
    bool? groupByApp,
  }) {
    return HistoryState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      loading: loading ?? this.loading,
      query: query ?? this.query,
      groupByApp: groupByApp ?? this.groupByApp,
    );
  }
}

/// Holds the list of captured third-party notifications and exposes the
/// mutating actions (delete / clear / note). Mirrors [NotificationsNotifier]
/// but for notification history instead of pinned notes.
///
/// Performance contract (this used to be the app's main jank source):
///  * the list is paged — never the whole table;
///  * a newly captured notification is spliced into the in-memory list rather
///    than triggering a full re-query + rebuild for every single notification;
///  * every mutation patches the local list instead of reloading from disk.
final thirdPartyProvider =
    NotifierProvider<ThirdPartyNotifier, HistoryState>(ThirdPartyNotifier.new);

class ThirdPartyNotifier extends Notifier<HistoryState> {
  static const int pageSize = 100;

  StreamSubscription<ThirdPartyNotification>? _sub;

  /// Guards `state =` after dispose (async work can finish late). Notifier has
  /// no `mounted` on every version we support, so track it ourselves.
  bool _disposed = false;

  @override
  HistoryState build() {
    _load();
    _sub = NotificationListenerBridge.instance.captured.listen(_onCaptured);
    ref.onDispose(() {
      _disposed = true;
      _sub?.cancel();
    });
    return const HistoryState();
  }

  /// A notification arrived: splice it in place.
  ///
  /// Previously every captured notification re-ran the full ordered query and
  /// rebuilt the whole list. On a busy phone that meant dozens of full-table
  /// scans per minute, which is what blocked the sqflite queue that saving a
  /// pin depends on.
  void _onCaptured(ThirdPartyNotification n) {
    if (state.query.isNotEmpty) return;
    // Defensive: drop an existing entry that carries the same content key, not
    // just the same uuid. The DB guarantees at most one row per
    // (package, title, content), so anything matching on content here is a
    // leftover duplicate and must not be shown twice.
    final key = _contentKey(n);
    final items = state.items
        .where((e) => e.uuid != n.uuid && _contentKey(e) != key)
        .toList();
    items.insert(0, n);
    state = state.copyWith(items: items);
  }

  /// Identity of a notification as the user perceives it. Must stay in sync
  /// with the de-duplication key used by `AppDatabase._dedupeThirdPartyExact`
  /// (NULL title/content compare equal to each other, not as "distinct").
  static String _contentKey(ThirdPartyNotification n) =>
      '${n.packageName}\u0000${n.title ?? ''}\u0000${n.content ?? ''}';

  Future<void> _load() async {
    if (state.query.isNotEmpty) {
      await _runSearch(state.query);
      return;
    }
    final rows = await AppDatabase.thirdPartyNotifications(limit: pageSize);
    if (_disposed) return;
    state = HistoryState(items: rows, hasMore: rows.length >= pageSize);
  }

  Future<void> refresh() => _load();

  /// Append the next page. No-op while a page is in flight or in search mode.
  Future<void> loadMore() async {
    if (state.loading || !state.hasMore || state.query.isNotEmpty) return;
    state = state.copyWith(loading: true);
    final more = await AppDatabase.thirdPartyNotifications(
      limit: pageSize,
      offset: state.items.length,
    );
    if (_disposed) return;
    state = state.copyWith(
      items: [...state.items, ...more],
      hasMore: more.length >= pageSize,
      loading: false,
    );
  }

  /// Update the search term. Filtering happens in SQL, not in Dart.
  Future<void> setQuery(String query) async {
    final q = query.trim();
    if (q == state.query) return;
    state = state.copyWith(query: q);
    if (q.isEmpty) {
      await _load();
      return;
    }
    await _runSearch(q);
  }

  Future<void> _runSearch(String q) async {
    final rows = await AppDatabase.searchThirdParty(q);
    if (_disposed) return;
    state = state.copyWith(items: rows, hasMore: false, loading: false);
  }

  Future<void> delete(String uuid) async {
    await AppDatabase.deleteThirdParty(uuid);
    if (_disposed) return;
    state = state.copyWith(
      items: state.items.where((e) => e.uuid != uuid).toList(),
    );
  }

  /// Undo a delete — restore a third-party notification that was
  /// dismissed accidentally. Re-inserts the row via [upsertThirdParty]
  /// (which won't dedupe since the row was just deleted) and splices
  /// the item back into the in-memory list.
  Future<void> restore(ThirdPartyNotification n) async {
    await AppDatabase.upsertThirdParty(n);
    if (_disposed) return;
    final items = [...state.items, n]
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
    state = state.copyWith(items: items);
  }

  Future<void> clearAll() async {
    await AppDatabase.clearThirdParty();
    if (_disposed) return;
    state = state.copyWith(items: const [], hasMore: false);
  }

  /// Toggle flat / grouped-by-app rendering. The data is the same; only the
  /// UI presentation changes.
  void toggleGroupByApp() {
    state = state.copyWith(groupByApp: !state.groupByApp);
  }

  Future<void> setNote(String uuid, String? note) async {
    await AppDatabase.updateThirdPartyNote(uuid, note);
    if (_disposed) return;
    state = state.copyWith(
      items: state.items
          .map((e) => e.uuid == uuid
              ? e.copyWith(note: note, clearNote: note == null)
              : e)
          .toList(),
    );
  }
}
