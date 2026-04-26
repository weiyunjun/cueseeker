import 'package:shared_preferences/shared_preferences.dart';

import '../models/search_path_entry.dart';

class SearchPathService {
  static const _prefsKey = 'search_paths';

  Future<List<SearchPathEntry>> loadPaths() async {
    final prefs = await SharedPreferences.getInstance();
    final rawPaths = prefs.getStringList(_prefsKey);
    if (rawPaths == null) {
      return [
        SearchPathEntry(
          type: PathEntryType.local,
          path: '/Volumes/Synology/游戏录像',
        ),
      ];
    }

    final loaded = <SearchPathEntry>[];
    for (final raw in rawPaths) {
      try {
        if (raw.startsWith('{')) {
          loaded.add(SearchPathEntry.decode(raw));
        } else {
          loaded.add(SearchPathEntry(type: PathEntryType.local, path: raw));
        }
      } catch (_) {}
    }
    return loaded;
  }

  Future<void> savePaths(List<SearchPathEntry> paths) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = paths.map((entry) => entry.encode()).toList();
    await prefs.setStringList(_prefsKey, encoded);
  }
}
