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
  static const _dbVersion = 3;

  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _createPinnitTable(db);
    await _createThirdPartyTable(db);
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

  /// Wipe every row (used by "clear history" / tests).
  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('PinnitNotification');
    await db.delete('ThirdPartyNotification');
  }

  // ---------------------------------------------------------------------------
  // Third-party notification history (captured via NotificationListenerService)
  // ---------------------------------------------------------------------------

  /// Insert, or skip if an identical notification from the same app was posted
  /// within the last [dedupeWindowMs] (ongoing notifications re-fire a lot).
  static Future<void> upsertThirdParty(
    ThirdPartyNotification n, {
    int dedupeWindowMs = 2 * 60 * 1000,
  }) async {
    final db = await database;

    final recent = await db.query(
      'ThirdPartyNotification',
      where: 'packageName = ? AND title IS ? AND content IS ?',
      whereArgs: [n.packageName, n.title, n.content],
      orderBy: 'postedAt DESC',
      limit: 1,
    );

    if (recent.isNotEmpty) {
      final existing = ThirdPartyNotification.fromMap(recent.first);
      final withinWindow =
          (n.postedAt - existing.postedAt).abs() <= dedupeWindowMs;
      if (withinWindow) {
        // Keep the existing record but refresh its postedAt so ordering stays
        // sensible; don't create a duplicate.
        await db.update(
          'ThirdPartyNotification',
          {'postedAt': n.postedAt},
          where: 'uuid = ?',
          whereArgs: [existing.uuid],
        );
        return;
      }
    }

    await db.insert(
      'ThirdPartyNotification',
      n.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<ThirdPartyNotification>> thirdPartyNotifications() async {
    final db = await database;
    final rows = await db.query(
      'ThirdPartyNotification',
      orderBy: 'postedAt DESC',
    );
    return rows.map(ThirdPartyNotification.fromMap).toList();
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
