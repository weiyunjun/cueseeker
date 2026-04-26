import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;
import '../models/subtitle.dart';
import '../models/search_path_entry.dart';
import '../providers/database_provider.dart';
import 'favorite_service.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

final indexerProvider = Provider<IndexerService>((ref) {
  final dbService = ref.watch(databaseProvider);
  return IndexerService(dbPath: dbService.dbPath);
});

class IndexProgress {
  final int current;
  final int total;
  final String currentFile;
  final String status;
  final String message;

  IndexProgress({
    required this.current,
    required this.total,
    required this.currentFile,
    required this.status,
    required this.message,
  });
}

class IndexerService {
  final String dbPath;

  IndexerService({required this.dbPath});

  Future<int> removeIndexedContentForPath(SearchPathEntry entry) async {
    final removedCount = _removeIndexedContentForPath(entry);
    if (entry.type == PathEntryType.local) {
      _syncFavoritesForLocalRoot(entry.path);
    } else {
      _syncFavoritesForWebdavRoot(entry.path);
    }
    return removedCount;
  }

  Future<void> indexDirectory(
    SearchPathEntry entry,
    void Function(IndexProgress)? onProgress,
  ) async {
    if (entry.type == PathEntryType.local) {
      final rootDir = Directory(entry.path);
      if (!await rootDir.exists()) {
        onProgress?.call(
          IndexProgress(
            current: 0,
            total: 0,
            currentFile: '',
            status: 'error',
            message: 'Directory not found',
          ),
        );
        return;
      }
      onProgress?.call(
        IndexProgress(
          current: 0,
          total: 0,
          currentFile: '',
          status: 'scanning',
          message: 'Scanning for .srt files (Local)...',
        ),
      );

      final srtPaths = await _findAllSrtFilesLocal(rootDir);
      if (srtPaths.isEmpty) {
        final removedCount = await removeIndexedContentForPath(entry);
        final message = removedCount == 0
            ? 'No .srt files found.'
            : 'No .srt files found. Cleared $removedCount indexed files.';
        onProgress?.call(
          IndexProgress(
            current: 0,
            total: 0,
            currentFile: '',
            status: 'done',
            message: message,
          ),
        );
        return;
      }

      onProgress?.call(
        IndexProgress(
          current: 0,
          total: srtPaths.length,
          currentFile: '',
          status: 'indexing',
          message: 'Optimizing and parsing...',
        ),
      );

      final resultMsg = await Isolate.run(() {
        return _runIsolateTaskLocal(dbPath, rootDir.path, srtPaths);
      });
      _syncFavoritesForLocalRoot(rootDir.path);

      onProgress?.call(
        IndexProgress(
          current: srtPaths.length,
          total: srtPaths.length,
          currentFile: '',
          status: 'done',
          message: resultMsg,
        ),
      );
    } else if (entry.type == PathEntryType.webdav) {
      onProgress?.call(
        IndexProgress(
          current: 0,
          total: 0,
          currentFile: '',
          status: 'scanning',
          message: 'Connecting to WebDAV...',
        ),
      );
      try {
        final client = webdav.newClient(
          entry.path,
          user: entry.username ?? '',
          password: entry.password ?? '',
          debug: false,
        );

        onProgress?.call(
          IndexProgress(
            current: 0,
            total: 0,
            currentFile: '',
            status: 'scanning',
            message:
                'Crawling WebDAV for .srt files (This might take a while)...',
          ),
        );
        final allWebdavFiles = <webdav.File>[];
        await _crawlWebdav(client, '/', allWebdavFiles);
        debugPrint(
          '[Indexer] Crawled total ${allWebdavFiles.length} files from WebDAV',
        );

        final srtFiles = allWebdavFiles
            .where(
              (f) =>
                  !f.isDir! &&
                  (f.name?.toLowerCase().endsWith('.srt') ?? false),
            )
            .toList();
        debugPrint('[Indexer] Found ${srtFiles.length} .srt files');

        if (srtFiles.isEmpty) {
          final removedCount = await removeIndexedContentForPath(entry);
          final message = removedCount == 0
              ? 'No .srt files found on WebDAV.'
              : 'No .srt files found on WebDAV. Cleared $removedCount indexed files.';
          onProgress?.call(
            IndexProgress(
              current: 0,
              total: 0,
              currentFile: '',
              status: 'done',
              message: message,
            ),
          );
          return;
        }

        onProgress?.call(
          IndexProgress(
            current: 0,
            total: srtFiles.length,
            currentFile: '',
            status: 'indexing',
            message: 'Fetching and translating .srt from WebDAV...',
          ),
        );

        int indexed = 0;
        int skipped = 0;

        final uri = Uri.parse(entry.path);
        String? userInfo;
        if (entry.username?.isNotEmpty == true ||
            entry.password?.isNotEmpty == true) {
          final user = Uri.encodeComponent(entry.username ?? '');
          final pass = Uri.encodeComponent(entry.password ?? '');
          userInfo = '$user:$pass';
        }

        // CRITICAL: Do NOT use uri.replace().toString() — it percent-encodes Chinese characters
        // in the path (e.g. 百度网盘 → %E7%99%BE...), which Alist cannot resolve.
        // Instead, build the base URL via string concatenation to preserve raw characters.
        final rawPath = Uri.decodeComponent(
          uri.path,
        ).replaceAll(RegExp(r"/$"), "");
        final portSuffix = (uri.hasPort && uri.port != 0) ? ':${uri.port}' : '';
        final basePath = userInfo != null
            ? '${uri.scheme}://$userInfo@${uri.host}$portSuffix$rawPath'
            : '${uri.scheme}://${uri.host}$portSuffix$rawPath';
        debugPrint('[Indexer] WebDAV BasePath configured as: $basePath');

        for (final srtFile in srtFiles) {
          final separator = srtFile.path!.startsWith('/') ? '' : '/';
          // Do NOT use Uri.encodeFull() — preserve raw Chinese characters for Alist compatibility
          final srtPathUrl = '$basePath$separator${srtFile.path!}';

          onProgress?.call(
            IndexProgress(
              current: indexed,
              total: srtFiles.length,
              currentFile: srtFile.name ?? '',
              status: 'downloading',
              message: 'Fetching ${srtFile.name}',
            ),
          );
          debugPrint('[Indexer] Downloading SRT: ${srtFile.path}');

          final bytes = await client.read(srtFile.path!);
          debugPrint(
            '[Indexer] Downloaded ${bytes.length} bytes for ${srtFile.name}',
          );

          final videoPathUrl = _findVideoFileWebdav(
            srtFile,
            allWebdavFiles,
            basePath,
          );
          if (videoPathUrl == null) {
            debugPrint(
              '[Indexer] SKIPPED ${srtFile.name}: No matching video file found on WebDAV.',
            );
            skipped++;
            continue;
          }
          debugPrint('[Indexer] Matched Video URL: $videoPathUrl');

          await Isolate.run(() {
            _parseAndInsertWebdavItem(
              dbPath,
              srtPathUrl,
              videoPathUrl,
              bytes,
              srtFile.mTime?.toIso8601String() ?? '',
              srtFile.size ?? 0,
            );
          });
          indexed++;
          debugPrint('[Indexer] Successfully indexed ${srtFile.name}');
        }
        _syncFavoritesForWebdavRoot(basePath);
        onProgress?.call(
          IndexProgress(
            current: srtFiles.length,
            total: srtFiles.length,
            currentFile: '',
            status: 'done',
            message: 'Done! Indexed: $indexed, Skipped: $skipped (WebDAV)',
          ),
        );
      } catch (e) {
        debugPrint('[Indexer] WebDAV Fatal Error: $e');
        onProgress?.call(
          IndexProgress(
            current: 0,
            total: 0,
            currentFile: '',
            status: 'error',
            message: 'WebDAV Error: $e',
          ),
        );
      }
    }
  }

  Future<void> _crawlWebdav(
    webdav.Client client,
    String path,
    List<webdav.File> allFiles,
  ) async {
    final list = await client.readDir(path);
    for (final item in list) {
      if (item.path == path || item.path == '$path/') continue; // skip self
      if (item.isDir == true) {
        await _crawlWebdav(client, item.path!, allFiles);
      } else {
        allFiles.add(item);
      }
    }
  }

  String? _findVideoFileWebdav(
    webdav.File srtFile,
    List<webdav.File> allFiles,
    String basePath,
  ) {
    if (srtFile.path == null || srtFile.name == null) return null;
    final dir = p.dirname(srtFile.path!);
    final baseName = p.basenameWithoutExtension(srtFile.name!);
    final match = _langSuffixRegex.firstMatch(baseName);

    final candidates = [baseName.toLowerCase()];
    if (match != null && match.group(1) != null) {
      candidates.add(match.group(1)!.toLowerCase());
    }

    const videoExts = ['.mp4', '.mkv', '.webm', '.avi', '.mov'];

    for (final file in allFiles) {
      if (file.path?.startsWith(dir) ?? false) {
        // sibling check
        if (p.dirname(file.path!) == dir && !file.isDir!) {
          for (final cb in candidates) {
            for (final ve in videoExts) {
              final fname = file.name!.toLowerCase();
              if (fname == '$cb$ve' || fname == '$cb${ve.toUpperCase()}') {
                // Return full prepended auth path + path.
                // E.g. basePath is http://192.168.1.173:5244/dav/百度网盘
                // Do NOT use Uri.encodeFull() — preserve raw Chinese characters
                final separator = file.path!.startsWith('/') ? '' : '/';
                return '$basePath$separator${file.path!}';
              }
            }
          }
        }
      }
    }
    return null;
  }

  static void _parseAndInsertWebdavItem(
    String dbFilePath,
    String srtPath,
    String videoPath,
    List<int> bytes,
    String modifiedAt,
    int fileSize,
  ) {
    final db = sqlite3.open(dbFilePath);
    try {
      final checkMeta = db.select(
        'SELECT file_size, modified_at FROM index_meta WHERE srt_path = ?',
        [srtPath],
      );
      if (checkMeta.isNotEmpty) {
        final row = checkMeta.first;
        if (row['file_size'] == fileSize && row['modified_at'] == modifiedAt) {
          return; // Skipped
        }
      }

      final content = utf8.decode(bytes, allowMalformed: true);
      final entries = _parseSrtFileText(srtPath, videoPath, content);
      if (entries.isEmpty) return;

      db.execute('BEGIN TRANSACTION');
      db.execute(
        'DELETE FROM subtitles_fts WHERE rowid IN (SELECT id FROM subtitles WHERE srt_path = ?)',
        [srtPath],
      );
      db.execute('DELETE FROM subtitles WHERE srt_path = ?', [srtPath]);

      final insertSubStmt = db.prepare(
        'INSERT INTO subtitles (video_path, video_name, srt_path, seq, start_time, end_time, start_ms, end_ms, content) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      );
      final insertFtsStmt = db.prepare(
        'INSERT INTO subtitles_fts(rowid, content) VALUES (?, ?)',
      );

      for (final entry in entries) {
        insertSubStmt.execute([
          entry.videoPath,
          entry.videoName,
          entry.srtPath,
          entry.seq,
          entry.startTime,
          entry.endTime,
          entry.startMs,
          entry.endMs,
          entry.content,
        ]);
        final newId = db.lastInsertRowId;
        insertFtsStmt.execute([newId, _segmentCJK(entry.content)]);
      }

      db.execute(
        "INSERT OR REPLACE INTO index_meta (srt_path, file_size, modified_at, indexed_at) VALUES (?, ?, ?, datetime('now'))",
        [srtPath, fileSize, modifiedAt],
      );
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
    } finally {
      db.close();
    }
  }

  Future<List<String>> _findAllSrtFilesLocal(Directory dir) async {
    final paths = <String>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.srt')) {
        paths.add(entity.path);
      }
    }
    return paths;
  }

  // === 性能核武器：提取静态正则表达式缓存，避免百万次运行时重编译 ===
  static final _seqRegex = RegExp(r'^\d+$');
  static final _timeRegex = RegExp(
    r'(\d{2}:\d{2}:\d{2}[,.]\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}[,.]\d{3})',
  );
  static final _timeParseRegex = RegExp(r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})');
  static final _langSuffixRegex = RegExp(
    r"^(.*)\.([a-z]{2,3}(?:-[A-Za-z0-9]{2,8})?)$",
  );

  static String _runIsolateTaskLocal(
    String dbFilePath,
    String rootDirPath,
    List<String> srtPaths,
  ) {
    int indexed = 0;
    int skipped = 0;

    final db = sqlite3.open(dbFilePath);

    // SQLite 性能调优：关闭同步阻塞指令，打开内存临时表缓冲，极大加速批量 INSERT
    db.execute('PRAGMA journal_mode=WAL;');
    db.execute('PRAGMA synchronous=NORMAL;');
    db.execute('PRAGMA temp_store=MEMORY;');

    String errorDetails = '';
    try {
      final metaResult = db.select('SELECT srt_path FROM index_meta');
      final existingPaths = metaResult
          .map((row) => row['srt_path'] as String)
          .where((path) => p.isWithin(rootDirPath, path) || path == rootDirPath)
          .toSet();
      final currentPaths = srtPaths.toSet();

      final stalePaths = existingPaths.difference(currentPaths);
      if (stalePaths.isNotEmpty) {
        db.execute('BEGIN TRANSACTION');
        for (final p in stalePaths) {
          db.execute(
            'DELETE FROM subtitles_fts WHERE rowid IN (SELECT id FROM subtitles WHERE srt_path = ?)',
            [p],
          );
          db.execute('DELETE FROM subtitles WHERE srt_path = ?', [p]);
          db.execute('DELETE FROM index_meta WHERE srt_path = ?', [p]);
        }
        db.execute('COMMIT');
      }

      // 将外层巨型事务包裹整个文件列表，而不是按单个文件事务写入（避免上千次磁盘 fsync 锁定）
      db.execute('BEGIN TRANSACTION');

      final insertSubStmt = db.prepare(
        'INSERT INTO subtitles (video_path, video_name, srt_path, seq, start_time, end_time, start_ms, end_ms, content) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      );
      final insertFtsStmt = db.prepare(
        'INSERT INTO subtitles_fts(rowid, content) VALUES (?, ?)',
      );

      for (final srtPath in srtPaths) {
        try {
          final stat = File(srtPath).statSync();
          final fileSize = stat.size;
          final modifiedAt = stat.modified.toIso8601String();

          final checkMeta = db.select(
            'SELECT file_size, modified_at FROM index_meta WHERE srt_path = ?',
            [srtPath],
          );
          if (checkMeta.isNotEmpty) {
            final row = checkMeta.first;
            if (row['file_size'] == fileSize &&
                row['modified_at'] == modifiedAt) {
              skipped++;
              if (errorDetails.isEmpty) {
                errorDetails = 'Skipped because already indexed and unchanged';
              }
              continue;
            }
          }

          final videoPath = _findVideoFile(srtPath);
          if (videoPath == null) {
            skipped++;
            if (errorDetails.isEmpty) {
              errorDetails = 'Video file not found for: $srtPath';
            }
            try {
              File(
                '/Users/weiyunjun/Desktop/indexer_error.log',
              ).writeAsStringSync(
                'Skip: Video missing for $srtPath\n',
                mode: FileMode.append,
              );
            } catch (logErr) {
              debugPrint('[Indexer] Failed to write log: $logErr');
            }
            continue;
          }

          final f = File(srtPath);
          final contentBytes = f.readAsBytesSync();
          final text = utf8.decode(contentBytes, allowMalformed: true);
          final entries = _parseSrtFileText(srtPath, videoPath, text);
          if (entries.isEmpty) {
            skipped++;
            if (errorDetails.isEmpty) {
              errorDetails = 'Parsed entries empty for: $srtPath';
            }
            try {
              File(
                '/Users/weiyunjun/Desktop/indexer_error.log',
              ).writeAsStringSync(
                'Skip: Parsed empty for $srtPath\n',
                mode: FileMode.append,
              );
            } catch (logErr) {
              debugPrint('[Indexer] Failed to write log: $logErr');
            }
            continue;
          }

          db.execute(
            'DELETE FROM subtitles_fts WHERE rowid IN (SELECT id FROM subtitles WHERE srt_path = ?)',
            [srtPath],
          );
          db.execute('DELETE FROM subtitles WHERE srt_path = ?', [srtPath]);

          for (final entry in entries) {
            insertSubStmt.execute([
              entry.videoPath,
              entry.videoName,
              entry.srtPath,
              entry.seq,
              entry.startTime,
              entry.endTime,
              entry.startMs,
              entry.endMs,
              entry.content,
            ]);
            final newId = db.lastInsertRowId;
            insertFtsStmt.execute([newId, _segmentCJK(entry.content)]);
          }

          db.execute(
            "INSERT OR REPLACE INTO index_meta (srt_path, file_size, modified_at, indexed_at) VALUES (?, ?, ?, datetime('now'))",
            [srtPath, fileSize, modifiedAt],
          );
          indexed++;
        } catch (fileErr) {
          skipped++;
          if (errorDetails.isEmpty) {
            errorDetails = 'File parsing/DB inserted exception: $fileErr';
          }
          try {
            File(
              '/Users/weiyunjun/Desktop/indexer_error.log',
            ).writeAsStringSync(
              'Error on $srtPath:\n$fileErr\n\n',
              mode: FileMode.append,
            );
          } catch (logErr) {
            debugPrint('[Indexer] Failed to write log: $logErr');
          }
        }
      }

      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      errorDetails = 'Outer try-catch global error: $e';
      try {
        File(
          '/Users/weiyunjun/Desktop/indexer_error.log',
        ).writeAsStringSync('GLOBAL ERROR:\n$e\n\n', mode: FileMode.append);
      } catch (_) {}
    } finally {
      db.close();
    }

    return 'Done! Indexed: $indexed, Skipped: $skipped \n($errorDetails)';
  }

  static String? _findVideoFile(String srtPath) {
    final dir = p.dirname(srtPath);
    final baseName = p.basenameWithoutExtension(srtPath);

    final match = _langSuffixRegex.firstMatch(baseName);

    final candidates = [baseName];
    if (match != null && match.group(1) != null) {
      candidates.add(match.group(1)!);
    }

    const videoExts = ['.mp4', '.mkv', '.webm', '.avi', '.mov'];

    for (final cb in candidates.toSet()) {
      for (final ve in videoExts) {
        // 先检查小写
        var vp = p.join(dir, cb + ve);
        if (File(vp).existsSync()) return vp;
        // 再检查大写例如 .MP4
        vp = p.join(dir, cb + ve.toUpperCase());
        if (File(vp).existsSync()) return vp;
      }
    }
    return null;
  }

  static List<SubtitleEntry> _parseSrtFileText(
    String srtPath,
    String videoPath,
    String content,
  ) {
    final videoName = p.basename(videoPath);
    final lines = const LineSplitter().convert(content);

    final entries = <SubtitleEntry>[];
    String state = 'expect_seq';
    int currentSeq = 0;
    String currentStartTime = '';
    String currentEndTime = '';
    int currentStartMs = 0;
    int currentEndMs = 0;
    List<String> currentTextLines = [];

    void flushEntry() {
      if (currentTextLines.isEmpty) return;
      entries.add(
        SubtitleEntry(
          videoPath: videoPath,
          videoName: videoName,
          srtPath: srtPath,
          seq: currentSeq,
          startTime: currentStartTime,
          endTime: currentEndTime,
          startMs: currentStartMs,
          endMs: currentEndMs,
          content: currentTextLines.join('\n'),
        ),
      );
      currentTextLines = [];
    }

    for (var rawLine in lines) {
      final line = rawLine.trim();

      switch (state) {
        case 'expect_seq':
          if (_seqRegex.hasMatch(line)) {
            currentSeq = int.parse(line);
            state = 'expect_time';
          }
          break;
        case 'expect_time':
          final timeMatch = _timeRegex.firstMatch(line);
          if (timeMatch != null) {
            currentStartTime = timeMatch.group(1)!;
            currentEndTime = timeMatch.group(2)!;
            currentStartMs = _parseTimeToMs(currentStartTime);
            currentEndMs = _parseTimeToMs(currentEndTime);
            state = 'expect_text';
          } else {
            state = 'expect_seq';
          }
          break;
        case 'expect_text':
          if (line.isEmpty) {
            flushEntry();
            state = 'expect_seq';
          } else {
            currentTextLines.add(rawLine.trimRight());
          }
          break;
      }
    }

    if (state == 'expect_text') {
      flushEntry();
    }

    return entries;
  }

  static int _parseTimeToMs(String timeStr) {
    final match = _timeParseRegex.firstMatch(timeStr.trim());
    if (match == null) return 0;
    final h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    final s = int.parse(match.group(3)!);
    final ms = int.parse(match.group(4)!);
    return h * 3600000 + m * 60000 + s * 1000 + ms;
  }

  /// 在中文/日韩字符后插入空格，强制打断成独立 token 供 FTS 分词
  static String _segmentCJK(String text) {
    if (text.isEmpty) return text;
    return text.replaceAllMapped(
      RegExp(r'[\u4E00-\u9FA5]'),
      (match) => '${match.group(0)} ',
    );
  }

  int _removeIndexedContentForPath(SearchPathEntry entry) {
    final db = sqlite3.open(dbPath);
    try {
      final indexedPaths = _findIndexedPathsForEntry(db, entry);
      if (indexedPaths.isEmpty) {
        return 0;
      }

      db.execute('BEGIN TRANSACTION');
      for (final srtPath in indexedPaths) {
        db.execute(
          'DELETE FROM subtitles_fts WHERE rowid IN (SELECT id FROM subtitles WHERE srt_path = ?)',
          [srtPath],
        );
        db.execute('DELETE FROM subtitles WHERE srt_path = ?', [srtPath]);
        db.execute('DELETE FROM index_meta WHERE srt_path = ?', [srtPath]);
      }
      db.execute('COMMIT');
      return indexedPaths.length;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    } finally {
      db.close();
    }
  }

  List<String> _findIndexedPathsForEntry(Database db, SearchPathEntry entry) {
    final rows = db.select('''
      SELECT srt_path FROM subtitles
      UNION
      SELECT srt_path FROM index_meta
    ''');

    final matched = <String>[];
    if (entry.type == PathEntryType.local) {
      final normalizedRoot = p.normalize(entry.path);
      for (final row in rows) {
        final srtPath = row['srt_path'] as String;
        if (p.isWithin(normalizedRoot, srtPath) ||
            p.equals(normalizedRoot, srtPath)) {
          matched.add(srtPath);
        }
      }
      return matched;
    }

    final normalizedRoot = FavoriteService.normalizeWebdavComparable(
      entry.path,
    );
    for (final row in rows) {
      final srtPath = row['srt_path'] as String;
      if (FavoriteService.normalizeWebdavComparable(
        srtPath,
      ).startsWith(normalizedRoot)) {
        matched.add(srtPath);
      }
    }
    return matched;
  }

  void _syncFavoritesForLocalRoot(String rootPath) {
    final db = sqlite3.open(dbPath);
    try {
      final favorites = db.select(
        'SELECT id, srt_path, start_ms, end_ms FROM favorites',
      );
      db.execute('BEGIN TRANSACTION');
      for (final row in favorites) {
        final srtPath = row['srt_path'] as String;
        if (!(p.isWithin(rootPath, srtPath) || p.equals(rootPath, srtPath))) {
          continue;
        }
        _syncSingleFavorite(
          db,
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
    } finally {
      db.close();
    }
  }

  void _syncFavoritesForWebdavRoot(String rootUrl) {
    final db = sqlite3.open(dbPath);
    try {
      final normalizedRoot = FavoriteService.normalizeWebdavComparable(rootUrl);
      final favorites = db.select(
        'SELECT id, srt_path, start_ms, end_ms FROM favorites',
      );
      db.execute('BEGIN TRANSACTION');
      for (final row in favorites) {
        final srtPath = row['srt_path'] as String;
        if (!FavoriteService.normalizeWebdavComparable(
          srtPath,
        ).startsWith(normalizedRoot)) {
          continue;
        }
        _syncSingleFavorite(
          db,
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
    } finally {
      db.close();
    }
  }

  void _syncSingleFavorite(
    Database db, {
    required int id,
    required String srtPath,
    required int startMs,
    required int endMs,
  }) {
    final matched = db.select(
      '''
      SELECT content, video_path, video_name
      FROM subtitles
      WHERE srt_path = ? AND start_ms = ? AND end_ms = ?
      LIMIT 1
      ''',
      [srtPath, startMs, endMs],
    );

    if (matched.isEmpty) {
      db.execute('UPDATE favorites SET is_valid = 0 WHERE id = ?', [id]);
      return;
    }

    final row = matched.first;
    db.execute(
      '''
      UPDATE favorites
      SET content = ?, video_path = ?, video_name = ?, is_valid = 1
      WHERE id = ?
      ''',
      [
        row['content'] as String,
        row['video_path'] as String,
        row['video_name'] as String,
        id,
      ],
    );
  }
}
