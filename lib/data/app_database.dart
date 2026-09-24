import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:pinnit_flutter/data/notification_model.dart';
import 'package:pinnit_flutter/data/third_party_notification.dart';

/// Thin sqflite wrapper that mirrors the original Pinnit Room database.
///
/// The schema is intentionally close to the native app's `PinnitNotification`
/// table so the behaviour (pinned-first ordering, soft deletes, embedded
/// schedule) is preserved.
class AppDatabase {
  static const _dbName = 'pinnit.db';
  static const _dbVersion = 10;

  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  /// Write-ahead logging + relaxed durability.
  ///
  /// WAL lets readers and the writer run concurrently instead of blocking each
  /// other, which matters a lot here: the notification listener keeps writing
  /// while the UI is reading. `synchronous = NORMAL` is safe with WAL (a crash
  /// can only lose the last checkpoint, never corrupt the DB) and removes an
  /// fsync from every single insert.
  static Future<void> _onConfigure(Database db) async {
    // sqflite routes PRAGMA through the query pipeline (it returns a row),
    // so `db.execute(...)` rejects it on newer Android: "Queries can be
    // performed using SQLiteDatabase query or rawQuery methods only".
    // Use rawQuery and discard the row.
    await db.rawQuery('PRAGMA journal_mode = WAL');
    await db.rawQuery('PRAGMA synchronous = NORMAL');
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _createPinnitTable(db);
    await _createThirdPartyTable(db);
    await _createIndexes(db);
  }

  /// Indexes that keep the hot queries off full-table scans.
  ///
  /// History table:
  ///  * `idx_tp_posted`   — the "load latest N" list query and the de-dupe
  ///    time window both only touch the most recent rows.
  ///  * `idx_tp_dedupe`   — the de-dupe lookup on every captured notification.
  ///    Deliberately excludes `content`: it can be hundreds of chars, and
  ///    package+title+time already narrows the scan to a handful of rows.
  ///
  /// Pins table is small, but indexed anyway so ordering stays O(log n).
  static Future<void> _createIndexes(Database db) async {
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tp_posted ON ThirdPartyNotification(postedAt DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tp_dedupe ON ThirdPartyNotification(packageName, title, postedAt DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_pin_list ON PinnitNotification(isPinned DESC, updatedAt DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_pin_deleted ON PinnitNotification(deletedAt)');
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // v1 -> v2: added the third-party notification history table.
    if (oldVersion < 2) {
      await _createThirdPartyTable(db);
    }
    // v2 -> v3: the scheduled-reminder feature was removed. Drop the now
    // unused schedule columns. Recreate the table (instead of ALTER ... DROP
    // COLUMN) to stay compatible with older SQLite builds that lack DROP
    // COLUMN. Existing pinned notifications are preserved.
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE PinnitNotification RENAME TO PinnitNotification_old');
      await _createPinnitTable(db);
      await db.execute('''
        INSERT INTO PinnitNotification
          (uuid, title, content, isPinned, createdAt, updatedAt, deletedAt)
        SELECT
          uuid, title, content, isPinned, createdAt, updatedAt, deletedAt
        FROM PinnitNotification_old
      ''');
      await db.execute('DROP TABLE PinnitNotification_old');
    }
    // v5 -> v6: performance. WAL is applied in onConfigure; only the indexes
    // are new. Created last so the table rebuilds above never drop them.
    if (oldVersion < 6) {
      await _createIndexes(db);
    }
    // v6 -> v7: dedupe hardening. The old de-dupe only bumped postedAt when
    // an identical row existed, but apps that re-broadcast the same payload
    // with a slightly different UUID sneaked through before that check was
    // added, leaving historical duplicate rows. Wipe those now: keep only
    // the newest row per (packageName, title, content).
    if (oldVersion < 7) {
      await _dedupeThirdPartyExact(db);
    }
    // v7 -> v8: (RETIRED) ran a digit-stripped "fuzzy" pass that also merged
    // title-only notifications whose normalized content collapsed to the
    // empty string — wiping legitimate distinct history. It is GONE now.
    // v8 -> v9: no data migration. The new fuzzy guard (only merge when
    // BOTH sides contain digits, same non-empty title, within 24h) lives in
    // upsertThirdParty; upgrades only re-run the safe exact pass to clean
    // whatever exact duplicates accumulated under v8's buggy runtime merge.
    if (oldVersion < 9) {
      await _dedupeThirdPartyExact(db);
    }
    // v9 -> v10: fix "every notification appears twice".
    //
    // `upsertThirdParty` is a read-modify-write, so two callbacks that landed
    // inside the same await window (apps post a notification and immediately
    // update it, making the listener fire twice back-to-back) both saw "no
    // identical row yet" and both inserted — leaving two rows per real
    // notification. The runtime race is fixed (see `_serialize`), and this
    // pass collapses the duplicates that already piled up.
    if (oldVersion < 10) {
      await _dedupeThirdPartyExact(db);
    }
  }

  /// Safe one-shot cleanup: remove EXACT duplicates only — same package,
  /// title AND content. Never merges rows that merely look similar.
  ///
  /// Deliberately implemented in Dart instead of with
  /// `ROW_NUMBER() OVER (PARTITION BY ...)`: window functions require
  /// SQLite >= 3.25 (Android 11+), and a migration that throws
  /// "no such function: ROW_NUMBER" on an older device would brick the
  /// upgrade. The row count here is bounded by the history table (a few
  /// thousand at most), so a single ordered pass is cheap.
  static Future<void> _dedupeThirdPartyExact(Database db) async {
    final rows = await db.query(
      'ThirdPartyNotification',
      columns: ['uuid', 'packageName', 'title', 'content', 'postedAt'],
      orderBy: 'postedAt DESC',
    );

    final seen = <String>{};
    final doomed = <String>[];
    for (final row in rows) {
      // Newest row wins (rows come back postedAt DESC).
      //
      // The key is built manually so that a NULL title/content compares equal
      // to another NULL: two title-only notifications from the same app ARE
      // the same notification, whereas SQL's `NULL != NULL` would treat them
      // as distinct and keep both.
      final key = '${row['packageName']}\u0000${row['title'] ?? ''}'
          '\u0000${row['content'] ?? ''}';
      if (seen.add(key)) continue;
      doomed.add(row['uuid'] as String);
    }

    // Delete in chunks so the SQL statement (and its variable list) stays
    // small even when a busy phone accumulated thousands of duplicates.
    for (var i = 0; i < doomed.length; i += 200) {
      final chunk = doomed.sublist(i, i + 200 > doomed.length ? doomed.length : i + 200);
      await db.delete(
        'ThirdPartyNotification',
        where: 'uuid IN (${List.filled(chunk.length, '?').join(',')})',
        whereArgs: chunk,
      );
    }
  }

  static Future<void> _createPinnitTable(Database db) async {
    await db.execute('''
      CREATE TABLE PinnitNotification (
        uuid          TEXT PRIMARY KEY,
        title         TEXT NOT NULL,
        content       TEXT,
        isPinned      INTEGER NOT NULL DEFAULT 1,
        createdAt     INTEGER NOT NULL,
        updatedAt     INTEGER NOT NULL,
        deletedAt     INTEGER
      )
    ''');
  }

  static Future<void> _createThirdPartyTable(Database db) async {
    await db.execute('''
      CREATE TABLE ThirdPartyNotification (
        uuid          TEXT PRIMARY KEY,
        packageName   TEXT NOT NULL,
        appName       TEXT,
        title         TEXT,
        content       TEXT,
        postedAt      INTEGER NOT NULL,
        note          TEXT,
        createdAt     INTEGER NOT NULL
      )
    ''');
  }

  /// All non-deleted notifications, pinned first then most-recently updated.
  /// Mirrors the original `notifications()` Room query.
  static Future<List<PinnitNotification>> notifications() async {
    final db = await database;
    final rows = await db.query(
      'PinnitNotification',
      where: 'deletedAt IS NULL',
      orderBy: 'isPinned DESC, updatedAt DESC',
    );
    return rows.map(PinnitNotification.fromMap).toList();
  }

  /// Only the pinned notifications (used to restore the notification shade).
  static Future<List<PinnitNotification>> pinnedNotifications() async {
    final db = await database;
    final rows = await db.query(
      'PinnitNotification',
      where: 'deletedAt IS NULL AND isPinned = 1',
      orderBy: 'updatedAt DESC',
    );
    return rows.map(PinnitNotification.fromMap).toList();
  }

  static Future<PinnitNotification?> notificationByUuid(String uuid) async {
    final db = await database;
    final rows = await db.query(
      'PinnitNotification',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PinnitNotification.fromMap(rows.first);
  }

  static Future<void> save(PinnitNotification n) async {
    final db = await database;
    await db.insert(
      'PinnitNotification',
      n.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> updatePinStatus(String uuid, bool isPinned) async {
    final db = await database;
    await db.update(
      'PinnitNotification',
      {'isPinned': isPinned ? 1 : 0, 'updatedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// Soft delete, mirroring `deletedAt IS NULL` filtering everywhere.
  static Future<void> softDelete(String uuid) async {
    final db = await database;
    await db.update(
      'PinnitNotification',
      {'deletedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// Undo a soft delete — restore a notification that was dismissed
  /// accidentally. Used by the SnackBar "撤销" action on the
  /// pinned-notifications list.
  static Future<void> undelete(String uuid) async {
    final db = await database;
    await db.update(
      'PinnitNotification',
      {'deletedAt': null},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// Wipe every row (used by "clear history" / tests).
  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('PinnitNotification');
    await db.delete('ThirdPartyNotification');
  }

  // ---------------------------------------------------------------------------
  // Third-party notification history (captured via NotificationListenerService)
  // ---------------------------------------------------------------------------

  /// Insert, or update the timestamp if an identical notification from the
  /// same app already exists.
  ///
  /// Same app + same title + same content = the same notification re-firing
  /// (ongoing/status notifications like "正在扫描周围设备" re-post every few
  /// seconds). Instead of creating a duplicate row, we just refresh its
  /// `postedAt` so it stays at the top and the history list stays clean.
  ///
  /// Fuzzy layer (guarded): security apps re-broadcast the SAME logical
  /// notification with changing numbers ("发现 3 项风险" → "发现 2 项风险").
  /// A merge is only allowed when ALL of these hold — otherwise distinct
  /// notifications get erased:
  ///   1. both the incoming AND the existing row contain at least one digit;
  ///   2. titles are exactly equal AND non-empty;
  ///   3. the existing row was posted within the last 24 hours.
  ///
  /// Returns TRUE when a new row was created, FALSE when an existing row
  /// was updated — the caller uses this to avoid inserting a ghost item
  /// into the in-memory list.
  ///
  /// Every call is funnelled through [_serialize] so the underlying
  /// check-then-write is atomic. Without that, two callbacks arriving inside
  /// the same await window both read "no identical row yet" and both insert,
  /// which is exactly how each notification ended up stored twice.
  static Future<bool> upsertThirdParty(ThirdPartyNotification n) {
    return _serialize(() => _upsertThirdPartyNow(n));
  }

  /// Serialises history writes against each other.
  ///
  /// The whole read-modify-write (`upsertThirdParty`) runs to completion
  /// before the next one starts, so the "does an identical row already
  /// exist?" answer can never go stale. sqflite queues individual statements,
  /// but it does not make a Dart-level query → insert sequence atomic.
  static Future<void> _writeChain = Future<void>.value();

  static Future<T> _serialize<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeChain = _writeChain.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        // Never let one failed write sever the chain for every later write.
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  static Future<bool> _upsertThirdPartyNow(
    ThirdPartyNotification n,
  ) async {
    final db = await database;

    // Pass 1 — exact match (no time window: re-broadcast status
    // notifications must never create a second row).
    final existing = await db.query(
      'ThirdPartyNotification',
      where: 'packageName = ? AND title IS ? AND content IS ?',
      whereArgs: [n.packageName, n.title, n.content],
      orderBy: 'postedAt DESC',
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await db.update(
        'ThirdPartyNotification',
        {'postedAt': n.postedAt},
        where: 'uuid = ?',
        whereArgs: [existing.first['uuid']],
      );
      return false; // updated an existing row
    }

    // Pass 2 — guarded fuzzy match for number-changing re-broadcasts.
    final incomingDigits = _containsDigit(n.content);
    if (incomingDigits &&
        n.title != null &&
        n.title!.isNotEmpty &&
        n.content != null &&
        n.content!.isNotEmpty) {
      final dayAgo =
          DateTime.now().millisecondsSinceEpoch - 24 * 60 * 60 * 1000;
      final candidates = await db.query(
        'ThirdPartyNotification',
        columns: ['uuid', 'content', 'postedAt'],
        where:
            'packageName = ? AND title = ? AND content IS NOT NULL AND postedAt >= ?',
        whereArgs: [n.packageName, n.title, dayAgo],
        orderBy: 'postedAt DESC',
        limit: 20,
      );
      final norm = _normalizeForDedupe(n.content);
      for (final row in candidates) {
        final rowContent = row['content'] as String;
        if (!_containsDigit(rowContent)) continue; // guard 1
        if (_normalizeForDedupe(rowContent) == norm) {
          await db.update(
            'ThirdPartyNotification',
            {
              'postedAt': n.postedAt,
              'content': n.content, // show the freshest wording
            },
            where: 'uuid = ?',
            whereArgs: [row['uuid']],
          );
          return false; // merged into an existing row
        }
      }
    }

    await db.insert(
      'ThirdPartyNotification',
      n.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return true; // brand-new row
  }

  /// Whether the string contains any digit (ASCII or full-width).
  static bool _containsDigit(String? s) {
    if (s == null) return false;
    return RegExp(r'[0-9０-９]').hasMatch(s);
  }

  /// Strip digits/whitespace for fuzzy de-dupe: "发现 3 项风险" and
  /// "发现 12 项风险" both normalize to "发现项风险". Returns null for
  /// null/empty input (nothing to compare).
  static String? _normalizeForDedupe(String? s) {
    if (s == null || s.isEmpty) return null;
    return s
        .replaceAll(RegExp(r'[0-9０-９]'), '')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
  }

  /// Newest first, [limit] rows starting at [offset].
  ///
  /// The history list is paged: loading thousands of rows (each with a long
  /// content string) into memory was the single biggest source of jank.
  static Future<List<ThirdPartyNotification>> thirdPartyNotifications({
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;
    final rows = await db.query(
      'ThirdPartyNotification',
      orderBy: 'postedAt DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(ThirdPartyNotification.fromMap).toList();
  }

  /// Server-side search so filtering never materialises the whole table.
  static Future<List<ThirdPartyNotification>> searchThirdParty(
    String query, {
    int limit = 200,
  }) async {
    final db = await database;
    final like = '%$query%';
    final rows = await db.query(
      'ThirdPartyNotification',
      where:
          '(appName LIKE ? OR title LIKE ? OR content LIKE ? OR note LIKE ?)',
      whereArgs: [like, like, like, like],
      orderBy: 'postedAt DESC',
      limit: limit,
    );
    return rows.map(ThirdPartyNotification.fromMap).toList();
  }

  static Future<int> countThirdParty() async {
    final db = await database;
    final rows =
        await db.rawQuery('SELECT COUNT(*) AS c FROM ThirdPartyNotification');
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Drop everything older than the newest [keep] rows. Keeps the table from
  /// growing without bound over months of collecting.
  static Future<int> pruneThirdParty(int keep) async {
    final db = await database;
    return db.delete(
      'ThirdPartyNotification',
      where:
          'uuid NOT IN (SELECT uuid FROM ThirdPartyNotification ORDER BY postedAt DESC LIMIT ?)',
      whereArgs: [keep],
    );
  }

  static Future<void> updateThirdPartyNote(String uuid, String? note) async {
    final db = await database;
    await db.update(
      'ThirdPartyNotification',
      {'note': note},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  static Future<void> deleteThirdParty(String uuid) async {
    final db = await database;
    await db.delete(
      'ThirdPartyNotification',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  static Future<void> clearThirdParty() async {
    final db = await database;
    await db.delete('ThirdPartyNotification');
  }
}
