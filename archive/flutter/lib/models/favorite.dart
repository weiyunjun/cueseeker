import 'subtitle.dart';

class FavoriteEntry {
  final int id;
  final String srtPath;
  final int startMs;
  final int endMs;
  final String videoPath;
  final String videoName;
  final String content;
  final bool isValid;
  final int createdAt;

  const FavoriteEntry({
    required this.id,
    required this.srtPath,
    required this.startMs,
    required this.endMs,
    required this.videoPath,
    required this.videoName,
    required this.content,
    required this.isValid,
    required this.createdAt,
  });

  factory FavoriteEntry.fromRow(Map<String, Object?> row) {
    return FavoriteEntry(
      id: row['id'] as int,
      srtPath: row['srt_path'] as String,
      startMs: row['start_ms'] as int,
      endMs: row['end_ms'] as int,
      videoPath: row['video_path'] as String,
      videoName: row['video_name'] as String,
      content: row['content'] as String,
      isValid: (row['is_valid'] as int? ?? 0) == 1,
      createdAt: row['created_at'] as int,
    );
  }

  String get identityKey => '$srtPath|$startMs|$endMs';

  SubtitleEntry toSubtitleEntry() {
    return SubtitleEntry(
      videoPath: videoPath,
      videoName: videoName,
      srtPath: srtPath,
      seq: 0,
      startTime: '',
      endTime: '',
      startMs: startMs,
      endMs: endMs,
      content: content,
    );
  }
}
