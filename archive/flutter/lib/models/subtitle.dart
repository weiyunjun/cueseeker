class SubtitleEntry {
  final int? id;
  final String videoPath;
  final String videoName;
  final String srtPath;
  final int seq;
  final String startTime;
  final String endTime;
  final int startMs;
  final int endMs;
  final String content;

  SubtitleEntry({
    this.id,
    required this.videoPath,
    required this.videoName,
    required this.srtPath,
    required this.seq,
    required this.startTime,
    required this.endTime,
    required this.startMs,
    required this.endMs,
    required this.content,
  });

  factory SubtitleEntry.fromRow(Map<String, dynamic> row) {
    return SubtitleEntry(
      id: row['id'] as int?,
      videoPath: row['video_path'] as String,
      videoName: row['video_name'] as String,
      srtPath: row['srt_path'] as String,
      seq: row['seq'] as int,
      startTime: row['start_time'] as String,
      endTime: row['end_time'] as String,
      startMs: row['start_ms'] as int,
      endMs: row['end_ms'] as int? ?? 0,
      content: row['content'] as String,
    );
  }

  String get identityKey => '$srtPath|$startMs|$endMs';

  SubtitleEntry copyWith({
    int? id,
    String? videoPath,
    String? videoName,
    String? srtPath,
    int? seq,
    String? startTime,
    String? endTime,
    int? startMs,
    int? endMs,
    String? content,
  }) {
    return SubtitleEntry(
      id: id ?? this.id,
      videoPath: videoPath ?? this.videoPath,
      videoName: videoName ?? this.videoName,
      srtPath: srtPath ?? this.srtPath,
      seq: seq ?? this.seq,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      content: content ?? this.content,
    );
  }

  bool hasSameIdentity(SubtitleEntry other) {
    return srtPath == other.srtPath &&
        startMs == other.startMs &&
        endMs == other.endMs;
  }
}

class IndexMeta {
  final String srtPath;
  final int fileSize;
  final String modifiedAt;

  IndexMeta({
    required this.srtPath,
    required this.fileSize,
    required this.modifiedAt,
  });
}
