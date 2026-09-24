// Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
// Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.

import 'package:shared_preferences/shared_preferences.dart';

/// Keyword-based blocklist for third-party notification history.
///
/// The user adds words like "正在扫描" / "正在获取" and any captured
/// notification whose title, content, or app name *contains* one of these
/// words is silently dropped — never written to the DB, never shown in the
/// history list.
///
/// Implemented as a singleton so it stays alive for the whole app lifetime
/// (the cached FlutterEngine keeps recording in the background). The word
/// list is loaded once from [SharedPreferences] at startup and cached in
/// memory; [isBlocked] is a hot path called on every single notification,
/// so it must not touch disk.
class BlocklistService {
  BlocklistService._();
  static final instance = BlocklistService._();

  static const _key = 'notification_blocklist';

  List<String> _words = const [];
  int _blockedCount = 0;
  bool _loaded = false;

  /// Whether the blocklist has been loaded from disk at least once.
  bool get isLoaded => _loaded;

  /// Read-only view of the current blocklist words.
  List<String> get words => List.unmodifiable(_words);

  /// Total notifications dropped since startup (for UI display only).
  int get blockedCount => _blockedCount;

  /// Load the blocklist from disk. Call once at startup (`main()`).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key);
    _words = (stored ?? const []).whereType<String>().toList();
    _loaded = true;
  }

  /// Add a word. Trims, ignores empties and duplicates. Persists immediately.
  Future<void> add(String word) async {
    final w = word.trim();
    if (w.isEmpty || _words.contains(w)) return;
    _words = [..._words, w];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _words);
  }

  /// Remove a word. Persists immediately.
  Future<void> remove(String word) async {
    if (!_words.contains(word)) return;
    _words = _words.where((w) => w != word).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _words);
  }

  /// True if any blocklist word is a case-insensitive substring of the
  /// notification's title, content, or app name.
  ///
  /// Returns false instantly when the blocklist is empty — this is the hot
  /// path on every captured notification, so the empty-list short-circuit
  /// matters.
  bool isBlocked({String? title, String? content, String? appName}) {
    if (_words.isEmpty) return false;
    final titleL = (title ?? '').toLowerCase();
    final contentL = (content ?? '').toLowerCase();
    final appL = (appName ?? '').toLowerCase();
    for (final w in _words) {
      final wl = w.toLowerCase();
      if (wl.isEmpty) continue;
      if (titleL.contains(wl) ||
          contentL.contains(wl) ||
          appL.contains(wl)) {
        _blockedCount++;
        return true;
      }
    }
    return false;
  }
}
