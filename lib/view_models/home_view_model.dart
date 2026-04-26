import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/search_path_entry.dart';
import '../services/search_path_service.dart';
import '../services/indexer_service.dart';
import 'favorite_view_model.dart';
import 'search_view_model.dart';

enum HomeTab { search, favorites, settings }

const _sidebarCollapsedPrefsKey = 'sidebar_collapsed';

class HomeTabNotifier extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.search;

  void setTab(HomeTab tab) => state = tab;
}

class SidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadPersistedState();
    return false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sidebarCollapsedPrefsKey, state);
  }

  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final persisted = prefs.getBool(_sidebarCollapsedPrefsKey);
    if (persisted != null && persisted != state) {
      state = persisted;
    }
  }
}

final homeTabProvider = NotifierProvider<HomeTabNotifier, HomeTab>(
  HomeTabNotifier.new,
);
final sidebarCollapsedProvider =
    NotifierProvider<SidebarCollapsedNotifier, bool>(
      SidebarCollapsedNotifier.new,
    );
final searchPathServiceProvider = Provider<SearchPathService>(
  (ref) => SearchPathService(),
);

class ReindexState {
  final bool isRunning;
  final String message;

  const ReindexState({this.isRunning = false, this.message = ''});

  ReindexState copyWith({bool? isRunning, String? message}) {
    return ReindexState(
      isRunning: isRunning ?? this.isRunning,
      message: message ?? this.message,
    );
  }
}

class ReindexStateNotifier extends Notifier<ReindexState> {
  @override
  ReindexState build() => const ReindexState();

  Future<void> reindexAllPaths() async {
    if (state.isRunning) return;
    final pathService = ref.read(searchPathServiceProvider);
    final paths = await pathService.loadPaths();
    await _reindexPaths(paths);
  }

  Future<void> _reindexPaths(List<SearchPathEntry> paths) async {
    final indexer = ref.read(indexerProvider);
    state = state.copyWith(isRunning: true, message: 'Starting index...');
    try {
      for (final pathEntry in paths) {
        await indexer.indexDirectory(pathEntry, (progress) {
          state = state.copyWith(
            isRunning: true,
            message: '[${pathEntry.path}] ${progress.message}',
          );
        });
      }

      _invalidateIndexedDataProviders();
    } finally {
      state = const ReindexState();
    }
  }

  Future<void> savePathsAndReindex(List<SearchPathEntry> paths) async {
    final pathService = ref.read(searchPathServiceProvider);
    final indexer = ref.read(indexerProvider);
    final previousPaths = await pathService.loadPaths();
    await pathService.savePaths(paths);
    final nextKeys = paths.map((entry) => entry.encode()).toSet();
    final removedPaths = previousPaths
        .where((entry) => !nextKeys.contains(entry.encode()))
        .toList();
    try {
      for (final removedPath in removedPaths) {
        state = state.copyWith(
          isRunning: true,
          message: '[${removedPath.path}] Removing indexed content...',
        );
        await indexer.removeIndexedContentForPath(removedPath);
      }

      await _reindexPaths(paths);
    } finally {
      if (state.isRunning || state.message.isNotEmpty) {
        state = const ReindexState();
      }
    }
  }

  void _invalidateIndexedDataProviders() {
    ref.invalidate(searchResultsProvider);
    ref.invalidate(favoriteLookupProvider);
    ref.invalidate(favoriteResultsProvider);
  }
}

final reindexStateProvider =
    NotifierProvider<ReindexStateNotifier, ReindexState>(
      ReindexStateNotifier.new,
    );
