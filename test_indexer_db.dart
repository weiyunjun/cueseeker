import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';

import 'lib/models/subtitle.dart';

final _seqRegex = RegExp(r'^\d+$');
final _timeRegex = RegExp(r'(\d{2}:\d{2}:\d{2}[,.]\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}[,.]\d{3})');
final _timeParseRegex = RegExp(r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})');
final _langSuffixRegex = RegExp(r"^(.*)\.([a-z]{2,3}(?:-[A-Za-z0-9]{2,8})?)$");

String? _findVideoFile(String srtPath) {
  final dir = p.dirname(srtPath);
  final ext = p.extension(srtPath);
  final baseName = p.basenameWithoutExtension(srtPath);
  final match = _langSuffixRegex.firstMatch(baseName);
  final candidates = [baseName];
  if (match != null && match.group(1) != null) {
    candidates.add(match.group(1)!);
  }
  const videoExts = ['.mp4', '.mkv', '.webm', '.avi', '.mov'];
  for (final cb in candidates.toSet()) {
    for (final ve in videoExts) {
      var vp = p.join(dir, cb + ve);
      if (File(vp).existsSync()) return vp;
      vp = p.join(dir, cb + ve.toUpperCase());
      if (File(vp).existsSync()) return vp;
    }
  }
  return null;
}

int _parseTimeToMs(String timeStr) {
  final match = _timeParseRegex.firstMatch(timeStr.trim());
  if (match == null) return 0;
  final h = int.parse(match.group(1)!);
  final m = int.parse(match.group(2)!);
  final s = int.parse(match.group(3)!);
  final ms = int.parse(match.group(4)!);
  return h * 3600000 + m * 60000 + s * 1000 + ms;
}

List<SubtitleEntry> _parseSrtFile(String srtPath, String videoPath) {
  final videoName = p.basename(videoPath);
  final File f = File(srtPath);
  final content = utf8.decode(f.readAsBytesSync(), allowMalformed: true);
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
    entries.add(SubtitleEntry(
      videoPath: videoPath,
      videoName: videoName,
      srtPath: srtPath,
      seq: currentSeq,
      startTime: currentStartTime,
      endTime: currentEndTime,
      startMs: currentStartMs,
      endMs: currentEndMs,
      content: currentTextLines.join('\n'),
    ));
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

void main() {
  final dbPath = '/Users/weiyunjun/Library/Application Support/com.weiyunjun.subfinderx/com.weiyunjun.subfinderx/subfinder.db';
  final srtPaths = ['/Volumes/Synology/游戏录像/Beyond Two Souls/Beyond Two Souls 2026-03-31 09-14-54_clipped.srt'];

  int indexed = 0;
  int skipped = 0;

  final db = sqlite3.open(dbPath);

  try {
    final metaResult = db.select('SELECT srt_path FROM index_meta');
    print('Meta result size: ${metaResult.length}');

    final insertSubStmt = db.prepare(
      'INSERT INTO subtitles (video_path, video_name, srt_path, seq, start_time, end_time, start_ms, content) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    );
    final insertFtsStmt = db.prepare(
      'INSERT INTO subtitles_fts(rowid, content) VALUES (?, ?)'
    );

    for (final srtPath in srtPaths) {
      try {
        final stat = File(srtPath).statSync();
        final fileSize = stat.size;
        final modifiedAt = stat.modified.toIso8601String();
        
        final checkMeta = db.select('SELECT file_size, modified_at FROM index_meta WHERE srt_path = ?', [srtPath]);
        if (checkMeta.isNotEmpty) {
           print('Skipped due to meta matching');
           skipped++;
           continue;
        }

        final videoPath = _findVideoFile(srtPath);
        if (videoPath == null) {
          print('Video not found for $srtPath');
          continue;
        }

        final entries = _parseSrtFile(srtPath, videoPath);
        print('Parsed ${entries.length} entries for $srtPath');

        for (final entry in entries) {
           insertSubStmt.execute([
              entry.videoPath,
              entry.videoName,
              entry.srtPath,
              entry.seq,
              entry.startTime,
              entry.endTime,
              entry.startMs,
              entry.content,
           ]);
           final newId = db.lastInsertRowId;
           insertFtsStmt.execute([newId, entry.content]);
        }

        db.execute('INSERT OR REPLACE INTO index_meta (srt_path, file_size, modified_at, indexed_at) VALUES (?, ?, ?, datetime("now"))', [srtPath, fileSize, modifiedAt]);
        indexed++;
      } catch(fileErr, st) {
         print('Error: $fileErr');
         print(st);
      }
    }
  } catch (e) {
    print('Global error: $e');
  } finally {
    db.dispose();
  }
}
