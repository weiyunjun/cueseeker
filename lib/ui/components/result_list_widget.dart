import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subtitle.dart';
import '../../services/favorite_service.dart';
import '../../view_models/favorite_view_model.dart';
import '../../view_models/player_view_model.dart';
import '../../view_models/search_view_model.dart';
import 'action_feedback_overlay.dart';

enum ResultListMode { search, favorites }

class ResultListWidget extends ConsumerWidget {
  const ResultListWidget({super.key, required this.mode});

  final ResultListMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return mode == ResultListMode.search
        ? _buildSearchList(context, ref)
        : _buildFavoriteList(context, ref);
  }

  Widget _buildSearchList(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchResultsProvider);
    final favoritesAsync = ref.watch(favoriteLookupProvider);
    final activeSubtitle = ref.watch(activeSubtitleProvider);
    final currentKeyword = ref.watch(searchKeywordProvider);

    return resultsAsync.when(
      data: (results) {
        return favoritesAsync.when(
          data: (lookup) {
            if (results.isEmpty) {
              return const Center(
                child: Text(
                  'No matching subtitles found.',
                  style: TextStyle(color: Colors.black45),
                ),
              );
            }

            return ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final entry = results[index];
                final favorite = lookup[entry.identityKey];
                return _ResultTile(
                  playbackEntry: entry,
                  content: entry.content,
                  currentKeyword: currentKeyword,
                  videoName: entry.videoName,
                  startMs: entry.startMs,
                  isSelected: activeSubtitle?.identityKey == entry.identityKey,
                  isFavorite: favorite != null,
                  showFavoriteStar: favorite != null,
                  isPlayable: true,
                  onTap: () {
                    ref.read(activeSubtitleProvider.notifier).setActive(entry);
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  onToggleFavorite: () async {
                    await _toggleFavorite(
                      context: context,
                      ref: ref,
                      entry: entry,
                      isFavorite: favorite != null,
                    );
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Favorites Error: $error')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(child: Text('Search Error: $e')),
    );
  }

  Widget _buildFavoriteList(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(favoriteResultsProvider);
    final activeSubtitle = ref.watch(activeSubtitleProvider);
    final currentKeyword = ref.watch(favoriteSearchKeywordProvider);

    return resultsAsync.when(
      data: (results) {
        if (results.isEmpty) {
          return const Center(
            child: Text('No favorites yet.', style: TextStyle(color: Colors.black45)),
          );
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final favorite = results[index];
            final playbackEntry = favorite.toSubtitleEntry();
            return _ResultTile(
              playbackEntry: playbackEntry,
              content: favorite.content,
              currentKeyword: currentKeyword,
              videoName: favorite.videoName,
              startMs: favorite.startMs,
              isSelected: activeSubtitle?.identityKey == favorite.identityKey,
              isFavorite: true,
              showFavoriteStar: false,
              isPlayable: favorite.isValid,
              onTap: () {
                if (!favorite.isValid) {
                  ref.read(feedbackBusProvider).emit(
                    const FeedbackEvent.message(
                      icon: Icons.error_outline_rounded,
                      text: '无法找到对应视频片段。',
                    ),
                  );
                  return;
                }
                ref
                    .read(activeSubtitleProvider.notifier)
                    .setActive(playbackEntry);
                FocusManager.instance.primaryFocus?.unfocus();
              },
              onToggleFavorite: () async {
                await _toggleFavorite(
                  context: context,
                  ref: ref,
                  entry: playbackEntry,
                  isFavorite: true,
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(child: Text('Favorites Error: $e')),
    );
  }

  Future<void> _toggleFavorite({
    required BuildContext context,
    required WidgetRef ref,
    required SubtitleEntry entry,
    required bool isFavorite,
  }) async {
    final service = ref.read(favoriteServiceProvider);
    if (!isFavorite) {
      service.addFavorite(entry);
      ref.invalidate(favoriteLookupProvider);
      ref.invalidate(favoriteResultsProvider);
      ref.read(feedbackBusProvider).emit(
        const FeedbackEvent.message(
          icon: Icons.star_rounded,
          text: '已加入收藏',
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('移除收藏'),
          content: const Text('确定要移除对该句子的收藏吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    service.removeFavoriteByIdentity(entry.srtPath, entry.startMs, entry.endMs);
    ref.invalidate(favoriteLookupProvider);
    ref.invalidate(favoriteResultsProvider);
    ref.read(feedbackBusProvider).emit(
      const FeedbackEvent.message(
        icon: Icons.star_outline_rounded,
        text: '已取消收藏',
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.playbackEntry,
    required this.content,
    required this.currentKeyword,
    required this.videoName,
    required this.startMs,
    required this.isSelected,
    required this.isFavorite,
    required this.showFavoriteStar,
    required this.isPlayable,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final SubtitleEntry playbackEntry;
  final String content;
  final String currentKeyword;
  final String videoName;
  final int startMs;
  final bool isSelected;
  final bool isFavorite;
  final bool showFavoriteStar;
  final bool isPlayable;
  final VoidCallback onTap;
  final Future<void> Function() onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final baseTextColor = isPlayable ? Colors.black87 : Colors.black38;
    final metaColor = isPlayable ? Colors.black45 : Colors.black26;

    return GestureDetector(
      onTap: onTap,
      onSecondaryTapDown: (details) async {
        final selected = await showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy,
            details.globalPosition.dx,
            details.globalPosition.dy,
          ),
          items: [
            PopupMenuItem<String>(
              value: 'toggle',
              child: Text(isFavorite ? '移除收藏' : '收藏'),
            ),
          ],
        );
        if (selected == 'toggle') {
          await onToggleFavorite();
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.indigo.withValues(alpha: 0.05)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isSelected ? Colors.indigoAccent : Colors.transparent,
                width: 4,
              ),
              bottom: BorderSide(color: Colors.grey.shade100),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showFavoriteStar)
                    const Padding(
                      padding: EdgeInsets.only(top: 1, right: 6),
                      child: Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: Colors.amber,
                      ),
                    ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: _buildHighlightedText(
                          text: content,
                          currentKeyword: currentKeyword,
                          baseStyle: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: baseTextColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    _formatTimestamp(startMs),
                    style: TextStyle(
                      fontSize: 12,
                      color: metaColor,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      videoName,
                      style: TextStyle(fontSize: 12, color: metaColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTimestamp(int ms) {
    final hours = ms ~/ 3600000;
    final minutes = (ms % 3600000) ~/ 60000;
    final seconds = (ms % 60000) ~/ 1000;
    final millis = ms % 1000;
    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    final mmm = millis.toString().padLeft(3, '0');
    return hours > 0 ? '$hh:$mm:$ss.$mmm' : '$mm:$ss.$mmm';
  }

  static List<TextSpan> _buildHighlightedText({
    required String text,
    required String currentKeyword,
    required TextStyle baseStyle,
  }) {
    if (text.isEmpty) return [TextSpan(text: '', style: baseStyle)];

    final priorities = List<int>.filled(text.length, 0);
    _paintKeyword(priorities, text, currentKeyword, 1);

    final spans = <TextSpan>[];
    var start = 0;
    while (start < text.length) {
      final priority = priorities[start];
      var end = start + 1;
      while (end < text.length && priorities[end] == priority) {
        end++;
      }
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: _styleForPriority(baseStyle, priority),
        ),
      );
      start = end;
    }
    return spans;
  }

  static void _paintKeyword(
    List<int> priorities,
    String text,
    String keyword,
    int priority,
  ) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    final lowerText = text.toLowerCase();
    final lowerKeyword = trimmed.toLowerCase();
    var start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerKeyword, start);
      if (index == -1) return;
      for (var i = index; i < index + trimmed.length && i < priorities.length; i++) {
        if (priority > priorities[i]) {
          priorities[i] = priority;
        }
      }
      start = index + trimmed.length;
    }
  }

  static TextStyle _styleForPriority(TextStyle baseStyle, int priority) {
    switch (priority) {
      case 1:
        return baseStyle.copyWith(
          backgroundColor: Colors.yellow.withValues(alpha: 0.45),
          color: Colors.indigo.shade900,
          fontWeight: FontWeight.bold,
        );
      default:
        return baseStyle;
    }
  }
}
