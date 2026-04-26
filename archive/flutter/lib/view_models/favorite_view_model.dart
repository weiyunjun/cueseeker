import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/favorite.dart';
import '../services/favorite_service.dart';

class FavoriteSearchKeywordNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateKeyword(String value) => state = value;
}

final favoriteSearchKeywordProvider =
    NotifierProvider<FavoriteSearchKeywordNotifier, String>(
      FavoriteSearchKeywordNotifier.new,
    );

final favoriteResultsProvider = FutureProvider<List<FavoriteEntry>>((ref) async {
  final keyword = ref.watch(favoriteSearchKeywordProvider);
  final service = ref.watch(favoriteServiceProvider);
  return service.searchFavorites(keyword);
});

final favoriteLookupProvider = FutureProvider<Map<String, FavoriteEntry>>((
  ref,
) async {
  final service = ref.watch(favoriteServiceProvider);
  return service.getFavoriteLookup();
});
