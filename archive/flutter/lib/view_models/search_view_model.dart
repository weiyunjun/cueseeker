import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subtitle.dart';
import '../services/search_service.dart';

class SearchKeywordNotifier extends Notifier<String> {
  @override
  String build() => '';
  void updateKeyword(String word) => state = word;
}
final searchKeywordProvider = NotifierProvider<SearchKeywordNotifier, String>(SearchKeywordNotifier.new);

// 带防抖的搜索结果提供者 (300毫秒延迟)
final searchResultsProvider = FutureProvider<List<SubtitleEntry>>((ref) async {
  final keyword = ref.watch(searchKeywordProvider);
  if (keyword.isEmpty) return [];
  
  bool cancelled = false;
  // 如果在 300 毫秒内有新的按键输入，这个 Provider 就会被刷新，触发 onDispose 标记放弃
  ref.onDispose(() => cancelled = true);
  
  await Future.delayed(const Duration(milliseconds: 300));
  
  if (cancelled) {
    throw Exception('debounce cancelled');
  }
  
  final service = ref.watch(searchServiceProvider);
  return service.search(keyword);
});
