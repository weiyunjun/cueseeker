import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final defaultDbPath =
      '${Platform.environment['HOME']}/Library/Application Support/com.weiyunjun.subfinderx/subfinder.db';
  final dbPath = args.isNotEmpty ? args.first : defaultDbPath;
  final dbFile = File(dbPath);

  if (!dbFile.existsSync()) {
    stderr.writeln('Database not found: $dbPath');
    exitCode = 1;
    return;
  }

  final db = sqlite3.open(dbPath);
  try {
    final favoriteTable = db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='favorites'",
    );
    if (favoriteTable.isEmpty) {
      stdout.writeln('No favorites table found, nothing to migrate.');
      return;
    }

    final columns = db.select('PRAGMA table_info(favorites)');
    final hasKeyword = columns.any((row) => row['name'] == 'keyword');
    if (!hasKeyword) {
      stdout.writeln('favorites table already has no keyword column.');
      return;
    }

    db.execute('BEGIN TRANSACTION');
    db.execute('ALTER TABLE favorites RENAME TO favorites_old');
    db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        srt_path TEXT NOT NULL,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        video_path TEXT NOT NULL,
        video_name TEXT NOT NULL,
        content TEXT NOT NULL,
        is_valid INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL
      );
    ''');
    db.execute('''
      INSERT INTO favorites (
        id, srt_path, start_ms, end_ms, video_path, video_name,
        content, is_valid, created_at
      )
      SELECT
        id, srt_path, start_ms, end_ms, video_path, video_name,
        content, is_valid, created_at
      FROM favorites_old
    ''');
    db.execute('DROP TABLE favorites_old');
    db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_favorites_identity ON favorites(srt_path, start_ms, end_ms)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_favorites_created_at ON favorites(created_at DESC)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_favorites_srt_time ON favorites(srt_path, start_ms, end_ms)',
    );
    db.execute('COMMIT');

    stdout.writeln('favorites table migrated successfully: $dbPath');
  } catch (error) {
    try {
      db.execute('ROLLBACK');
    } catch (_) {}
    stderr.writeln('Migration failed: $error');
    exitCode = 1;
  } finally {
    db.close();
  }
}
