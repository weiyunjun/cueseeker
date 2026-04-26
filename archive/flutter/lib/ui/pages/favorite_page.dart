import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../view_models/favorite_view_model.dart';
import '../components/result_list_widget.dart';

class FavoritePage extends ConsumerStatefulWidget {
  const FavoritePage({super.key});

  @override
  ConsumerState<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends ConsumerState<FavoritePage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(favoriteSearchKeywordProvider),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _controller,
              onChanged: (text) {
                ref
                    .read(favoriteSearchKeywordProvider.notifier)
                    .updateKeyword(text);
              },
              decoration: const InputDecoration(
                hintText: '搜索收藏内容...',
                prefixIcon: Icon(Icons.star_rounded, color: Colors.amber),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        const Expanded(child: ResultListWidget(mode: ResultListMode.favorites)),
      ],
    );
  }
}
