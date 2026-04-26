import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class DatabaseService {
  late final Database db;
  late final String dbPath;
  bool requiresFullReindex = false;

  /// 初始化本地数据库
  Future<void> init() async {
    final supportDir = await getApplicationSupportDirectory();
    final appDir = Directory('${supportDir.path}/com.weiyunjun.subfinderx');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    
    dbPath = '${appDir.path}/subfinder.db';
    db = sqlite3.open(dbPath);

    _createTablesIfNotExist();
  }

  void _createTablesIfNotExist() {
    // 1. 字幕主表
    db.execute('''
      CREATE TABLE IF NOT EXISTS subtitles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        video_path TEXT NOT NULL,
        video_name TEXT NOT NULL,
        srt_path TEXT NOT NULL,
        seq INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL DEFAULT 0,
        content TEXT NOT NULL
      );
    ''');

    final subtitleColumns = db.select('PRAGMA table_info(subtitles)');
    final hasEndMs = subtitleColumns.any((row) => row['name'] == 'end_ms');
    if (!hasEndMs) {
      db.execute(
        'ALTER TABLE subtitles ADD COLUMN end_ms INTEGER NOT NULL DEFAULT 0',
      );
      requiresFullReindex = true;
    }

    // 检测旧版本外联 FTS 表并进行安全清理
    try {
      final ftsSchemaResult = db.select("SELECT sql FROM sqlite_master WHERE type='table' AND name='subtitles_fts'");
      if (ftsSchemaResult.isNotEmpty) {
        final schema = ftsSchemaResult.first['sql'] as String?;
        if (schema != null && schema.contains("content='subtitles'")) {
          // 发现老版本包含 external content 引用的 FTS 表，直接销毁，改为标准虚表
          db.execute('DROP TABLE IF EXISTS subtitles_fts');
          // 同时清空 index_meta 强迫下次重扫应用最新 CJK 分词索引
          db.execute('DROP TABLE IF EXISTS index_meta');
        }
      }
    } catch (_) {}

    // 2. FTS5 全文搜索虚拟表（支持多语言，配合人工 N-Gram 字符阻断）
    db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS subtitles_fts USING fts5(
        content, 
        tokenize='unicode61'
      );
    ''');

    // 3. 索引元数据表（用于增量扫描过滤）
    db.execute('''
      CREATE TABLE IF NOT EXISTS index_meta (
        srt_path TEXT PRIMARY KEY,
        file_size INTEGER NOT NULL,
        modified_at TEXT NOT NULL,
        indexed_at TEXT NOT NULL
      );
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS favorites (
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
    _migrateFavoritesSchemaIfNeeded();
    db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_favorites_identity ON favorites(srt_path, start_ms, end_ms)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_favorites_created_at ON favorites(created_at DESC)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_favorites_srt_time ON favorites(srt_path, start_ms, end_ms)',
    );
  }

  /// 释放数据库连接
  void dispose() {
    db.close();
  }

  void _migrateFavoritesSchemaIfNeeded() {
    final favoriteColumns = db.select('PRAGMA table_info(favorites)');
    final hasKeyword = favoriteColumns.any((row) => row['name'] == 'keyword');
    if (!hasKeyword) {
      return;
    }

    db.execute('BEGIN TRANSACTION');
    try {
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
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }
}
