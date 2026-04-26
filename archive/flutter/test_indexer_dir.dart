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
      // 先检查小写
      var vp = p.join(dir, cb + ve);
      if (File(vp).existsSync()) return vp;
      // 再检查大写
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

void main() async {
  final rootDir = Directory('/Volumes/Synology/游戏录像');
  final srtPaths = <String>[];
  await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.toLowerCase().endsWith('.srt')) {
      srtPaths.add(entity.path);
    }
  }

  print('Found ${srtPaths.length} srt files.');

  int indexed = 0;
  int skipped = 0;
  String firstSkippedReason = '';

  for (final srtPath in srtPaths) {
    try {
      final videoPath = _findVideoFile(srtPath);
      if (videoPath == null) {
        skipped++;
        if (firstSkippedReason.isEmpty) firstSkippedReason = 'Video file not found for: $srtPath';
        continue;
      }

      final entries = _parseSrtFile(srtPath, videoPath);
      if (entries.isEmpty) {
        skipped++;
        if (firstSkippedReason.isEmpty) firstSkippedReason = 'Parsed entries empty for: $srtPath';
        continue;
      }

      indexed++;
    } catch(fileErr) {
       skipped++;
       if (firstSkippedReason.isEmpty) firstSkippedReason = 'File logic error $srtPath: $fileErr';
    }
  }

  print('Done! Indexed: $indexed, Skipped: $skipped');
  print('First skipped reason: $firstSkippedReason');
}
