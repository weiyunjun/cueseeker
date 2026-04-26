import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subtitle.dart';
import '../providers/database_provider.dart';
import 'database_service.dart';

final searchServiceProvider = Provider((ref) {
  final dbService = ref.watch(databaseProvider);
  return SearchService(dbService: dbService);
});

class SearchService {
  final DatabaseService dbService;
  static final RegExp _ftsOperatorRegex = RegExp(r'\b(AND|OR|NOT|NEAR)\b');
  static final RegExp _cjkRegex = RegExp(r'[\u4E00-\u9FA5]');
  static final RegExp _latinTokenRegex = RegExp(
    r"[A-Za-z0-9]+(?:'[A-Za-z0-9]+)?",
  );

  SearchService({required this.dbService});

  List<SubtitleEntry> search(String keyword, {int limit = 500}) {
    final db = dbService.db;
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return [];

    final hasExplicitPhrase =
        trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"');
    final hasFtsSyntax =
        hasExplicitPhrase ||
        trimmed.contains('*') ||
        _ftsOperatorRegex.hasMatch(trimmed);
    final hasCJK = _cjkRegex.hasMatch(trimmed);
    final queryTokens = hasCJK
        ? const <String>[]
        : _tokenizeLatinTokens(trimmed);
    final useOrderedTokenFilter =
        !hasFtsSyntax && !hasCJK && queryTokens.length > 1;

    if (!hasFtsSyntax && !hasCJK && queryTokens.isEmpty) {
      return [];
    }

    String ftsQuery;
    if (hasFtsSyntax) {
      ftsQuery = trimmed;
    } else {
      if (hasCJK) {
        // 对于带中文字符的搜索，自动打散并通过双引号触发 Phrase Match 短语检索
        // 以贴合入库时预处理插入的独立 token
        final spaced = trimmed
            .replaceAllMapped(_cjkRegex, (m) => '${m.group(0)} ')
            .trim();
        ftsQuery = '"$spaced"';
      } else if (queryTokens.length > 1) {
        // 多词英文搜索先做完整词粗召回，再在应用层做保序过滤。
        ftsQuery = queryTokens.join(' AND ');
      } else {
        ftsQuery = '${queryTokens.first}*'; // prefix match
      }
    }

    try {
      final sqlLimit = useOrderedTokenFilter ? limit * 5 : limit;
      final result = db.select(
        '''
        SELECT
          s.id,
          s.video_name,
          s.video_path,
          s.srt_path,
          s.seq,
          s.start_time,
          s.end_time,
          s.start_ms,
          s.end_ms,
          s.content
        FROM subtitles_fts fts
        JOIN subtitles s ON s.id = CAST(fts.rowid AS INTEGER)
        WHERE subtitles_fts MATCH ?
        ORDER BY s.video_name, s.start_ms
        LIMIT ?
      ''',
        [ftsQuery, sqlLimit],
      );

      final entries = result.map((row) => SubtitleEntry.fromRow(row)).toList();

      if (!useOrderedTokenFilter) {
        return entries.take(limit).toList();
      }

      return entries
          .where(
            (entry) => _matchesOrderedWholeTokens(entry.content, queryTokens),
          )
          .take(limit)
          .toList();
    } catch (e) {
      // 捕获语法错误等
      return [];
    }
  }

  List<String> _tokenizeLatinTokens(String text) {
    return _latinTokenRegex
        .allMatches(text.toLowerCase())
        .map((match) => match.group(0)!)
        .toList();
  }

  bool _matchesOrderedWholeTokens(String content, List<String> queryTokens) {
    if (queryTokens.isEmpty) return false;

    final contentTokens = _tokenizeLatinTokens(content);
    if (contentTokens.length < queryTokens.length) return false;

    var queryIndex = 0;
    for (final token in contentTokens) {
      if (token != queryTokens[queryIndex]) continue;
      queryIndex++;
      if (queryIndex == queryTokens.length) {
        return true;
      }
    }
    return false;
  }
}
