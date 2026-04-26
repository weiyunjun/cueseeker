import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;

import '../models/favorite.dart';
import '../models/subtitle.dart';
import '../providers/database_provider.dart';
import 'database_service.dart';

final favoriteServiceProvider = Provider<FavoriteService>((ref) {
  final dbService = ref.watch(databaseProvider);
  return FavoriteService(dbService: dbService);
});

class FavoriteService {
  FavoriteService({required this.dbService});

  final DatabaseService dbService;

  List<FavoriteEntry> searchFavorites(String keyword) {
    final db = dbService.db;
    final trimmed = keyword.trim();
    final result = trimmed.isEmpty
        ? db.select(
            '''
            SELECT id, srt_path, start_ms, end_ms, video_path, video_name,
                   content, is_valid, created_at
            FROM favorites
            ORDER BY created_at DESC
            ''',
          )
        : db.select(
            '''
            SELECT id, srt_path, start_ms, end_ms, video_path, video_name,
                   content, is_valid, created_at
            FROM favorites
            WHERE content LIKE ?
            ORDER BY created_at DESC
            ''',
            ['%$trimmed%'],
          );
    return result.map(FavoriteEntry.fromRow).toList();
  }

  Map<String, FavoriteEntry> getFavoriteLookup() {
    final result = dbService.db.select(
      '''
      SELECT id, srt_path, start_ms, end_ms, video_path, video_name,
             content, is_valid, created_at
      FROM favorites
      ''',
    );

    final lookup = <String, FavoriteEntry>{};
    for (final row in result) {
      final entry = FavoriteEntry.fromRow(row);
      lookup[entry.identityKey] = entry;
    }
    return lookup;
  }

  bool isFavorite(String srtPath, int startMs, int endMs) {
    final result = dbService.db.select(
      '''
      SELECT 1
      FROM favorites
      WHERE srt_path = ? AND start_ms = ? AND end_ms = ?
      LIMIT 1
      ''',
      [srtPath, startMs, endMs],
    );
    return result.isNotEmpty;
  }

  void addFavorite(SubtitleEntry entry) {
    dbService.db.execute(
      '''
      INSERT OR IGNORE INTO favorites (
        srt_path, start_ms, end_ms, video_path, video_name,
        content, is_valid, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, 1, ?)
      ''',
      [
        entry.srtPath,
        entry.startMs,
        entry.endMs,
        entry.videoPath,
        entry.videoName,
        entry.content,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  SubtitleEntry? resolveFavoriteTarget({
    required String srtPath,
    required int currentMs,
  }) {
    final result = dbService.db.select(
      '''
      SELECT id, video_name, video_path, srt_path, seq, start_time, end_time,
             start_ms, end_ms, content
      FROM subtitles
      WHERE srt_path = ? AND start_ms <= ?
      ORDER BY
        CASE WHEN end_ms >= ? THEN 0 ELSE 1 END,
        start_ms DESC
      LIMIT 1
      ''',
      [srtPath, currentMs, currentMs],
    );

    if (result.isEmpty) {
      return null;
    }

    return SubtitleEntry.fromRow(result.first);
  }

  void removeFavoriteByIdentity(String srtPath, int startMs, int endMs) {
    dbService.db.execute(
      'DELETE FROM favorites WHERE srt_path = ? AND start_ms = ? AND end_ms = ?',
      [srtPath, startMs, endMs],
    );
  }

  void syncFavoritesForLocalRoot(String rootPath) {
    final db = dbService.db;
    final normalizedRoot = p.normalize(rootPath);
    final favorites = db.select(
      '''
      SELECT id, srt_path, start_ms, end_ms
      FROM favorites
      ''',
    );

    db.execute('BEGIN TRANSACTION');
    try {
      for (final row in favorites) {
        final srtPath = row['srt_path'] as String;
        if (!(p.isWithin(normalizedRoot, srtPath) || p.equals(normalizedRoot, srtPath))) {
          continue;
        }
        _syncSingleFavorite(
          id: row['id'] as int,
          srtPath: srtPath,
          startMs: row['start_ms'] as int,
          endMs: row['end_ms'] as int,
        );
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void syncFavoritesForWebdavRoot(String rootUrl) {
    final db = dbService.db;
    final normalizedRoot = normalizeWebdavComparable(rootUrl);
    final favorites = db.select(
      '''
      SELECT id, srt_path, start_ms, end_ms
      FROM favorites
      ''',
    );

    db.execute('BEGIN TRANSACTION');
    try {
      for (final row in favorites) {
        final srtPath = row['srt_path'] as String;
        if (!normalizeWebdavComparable(srtPath).startsWith(normalizedRoot)) {
          continue;
        }
        _syncSingleFavorite(
          id: row['id'] as int,
          srtPath: srtPath,
          startMs: row['start_ms'] as int,
          endMs: row['end_ms'] as int,
        );
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _syncSingleFavorite({
    required int id,
    required String srtPath,
    required int startMs,
    required int endMs,
  }) {
    final db = dbService.db;
    final match = db.select(
      '''
      SELECT video_path, video_name, content
      FROM subtitles
      WHERE srt_path = ? AND start_ms = ? AND end_ms = ?
      LIMIT 1
      ''',
      [srtPath, startMs, endMs],
    );

    if (match.isEmpty) {
      db.execute('UPDATE favorites SET is_valid = 0 WHERE id = ?', [id]);
      return;
    }

    final row = match.first;
    db.execute(
      '''
      UPDATE favorites
      SET video_path = ?, video_name = ?, content = ?, is_valid = 1
      WHERE id = ?
      ''',
      [
        row['video_path'] as String,
        row['video_name'] as String,
        row['content'] as String,
        id,
      ],
    );
  }

  static String normalizeWebdavComparable(String url) {
    return url
        .replaceAll(RegExp(r'^(https?://)([^@]+)@'), r'$1')
        .replaceAll(RegExp(r'/$'), '');
  }
}
