import 'package:flutter/material.dart';

import '../components/result_list_widget.dart';
import '../components/search_bar_widget.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SearchBarWidget(),
        Divider(height: 1),
        Expanded(child: ResultListWidget(mode: ResultListMode.search)),
      ],
    );
  }
}
