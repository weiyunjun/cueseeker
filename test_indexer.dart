import 'dart:io';
import 'package:path/path.dart' as p;
import 'dart:convert';

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

void testFile(String srtPath) {
  print('Testing: $srtPath');
  final videoPath = _findVideoFile(srtPath);
  if (videoPath == null) {
    print('  Skipped: Video file not found');
    return;
  }
  
  final f = File(srtPath);
  final content = utf8.decode(f.readAsBytesSync(), allowMalformed: true);
  final lines = const LineSplitter().convert(content);
  
  int entriesCount = 0;
  String state = 'expect_seq';

  for (var rawLine in lines) {
    final line = rawLine.trim();

    switch (state) {
      case 'expect_seq':
        if (_seqRegex.hasMatch(line)) {
          state = 'expect_time';
        }
        break;
      case 'expect_time':
        final timeMatch = _timeRegex.firstMatch(line);
        if (timeMatch != null) {
          state = 'expect_text';
        } else {
          state = 'expect_seq';
        }
        break;
      case 'expect_text':
        if (line.isEmpty) {
          entriesCount++;
          state = 'expect_seq';
        }
        break;
    }
  }
  if (state == 'expect_text') {
    entriesCount++;
  }

  if (entriesCount == 0) {
    print('  Skipped: Entries is empty (parse failed)');
    print('  Sample first 5 lines:');
    for (int i=0; i< (lines.length < 5 ? lines.length : 5); i++) {
        print('    [${lines[i]}] -> bytes: ${lines[i].codeUnits}');
    }
  } else {
    print('  Success: Found $entriesCount entries');
  }
}

void main() {
  final testPaths = [
    '/Volumes/Synology/游戏录像/Beyond Two Souls/Beyond Two Souls 2026-03-31 09-14-54_clipped.srt',
    '/Volumes/Synology/游戏录像/Tell Me Why/Tell Me Why 2026-04-09 20-38-49_clipped.srt',
    '/Volumes/Synology/游戏录像/Hogwarts Legacy/Hogwarts Legacy 2026-04-10 11-42-31_clipped.srt'
  ];
  for (final p in testPaths) {
    if (File(p).existsSync()) {
      testFile(p);
    } else {
      print('File missing: $p');
    }
  }
}
