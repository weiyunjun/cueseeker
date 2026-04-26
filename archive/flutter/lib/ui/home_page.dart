import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/database_provider.dart';
import '../view_models/home_view_model.dart';
import '../view_models/player_view_model.dart';
import 'components/video_player_pane.dart';
import 'pages/favorite_page.dart';
import 'pages/search_page.dart';
import 'settings_window.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _didTriggerForcedReindex = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerForcedReindexIfNeeded();
    });
  }

  void _triggerForcedReindexIfNeeded() {
    if (_didTriggerForcedReindex) return;
    final dbService = ref.read(databaseProvider);
    if (!dbService.requiresFullReindex) return;
    _didTriggerForcedReindex = true;
    ref.read(reindexStateProvider.notifier).reindexAllPaths();
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(homeTabProvider);
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final reindexState = ref.watch(reindexStateProvider);
    final activeSubtitle = ref.watch(activeSubtitleProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Row(
          children: [
            _Sidebar(
              collapsed: collapsed,
              currentTab: currentTab,
              isIndexing: reindexState.isRunning,
              indexMessage: reindexState.message,
              onToggleCollapsed: () {
                ref.read(sidebarCollapsedProvider.notifier).toggle();
              },
              onSelectTab: (tab) async {
                final player = ref.read(playerProvider);
                await player.pause();
                ref.read(homeTabProvider.notifier).setTab(tab);
              },
              onRefresh: () {
                ref.read(reindexStateProvider.notifier).reindexAllPaths();
              },
            ),
            Expanded(
              flex: activeSubtitle == null ? 1 : 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: activeSubtitle == null
                      ? null
                      : Border(right: BorderSide(color: Colors.grey.shade200)),
                ),
                child: _buildContent(currentTab),
              ),
            ),
            if (activeSubtitle != null)
              const Expanded(flex: 29, child: VideoPlayerPane()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(HomeTab tab) {
    switch (tab) {
      case HomeTab.search:
        return const SearchPage();
      case HomeTab.favorites:
        return const FavoritePage();
      case HomeTab.settings:
        return const SettingsPage();
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.collapsed,
    required this.currentTab,
    required this.isIndexing,
    required this.indexMessage,
    required this.onToggleCollapsed,
    required this.onSelectTab,
    required this.onRefresh,
  });

  final bool collapsed;
  final HomeTab currentTab;
  final bool isIndexing;
  final String indexMessage;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<HomeTab> onSelectTab;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final width = collapsed ? 80.0 : 220.0;
    return ExcludeFocus(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        color: const Color(0xFFF3F4F6),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          crossAxisAlignment: collapsed
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: collapsed ? Alignment.center : Alignment.centerLeft,
              child: IconButton(
                onPressed: onToggleCollapsed,
                icon: Icon(
                  collapsed
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _SidebarButton(
              collapsed: collapsed,
              icon: Icons.search_rounded,
              label: 'Search',
              selected: currentTab == HomeTab.search,
              onTap: () => onSelectTab(HomeTab.search),
            ),
            const SizedBox(height: 8),
            _SidebarButton(
              collapsed: collapsed,
              icon: Icons.star_rounded,
              label: 'Favorites',
              selected: currentTab == HomeTab.favorites,
              onTap: () => onSelectTab(HomeTab.favorites),
            ),
            const Spacer(),
            if (!collapsed && indexMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  indexMessage,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            _SidebarButton(
              collapsed: collapsed,
              icon: isIndexing ? Icons.sync : Icons.refresh_rounded,
              label: isIndexing ? 'Refreshing' : 'Refresh',
              selected: false,
              onTap: isIndexing ? null : onRefresh,
            ),
            const SizedBox(height: 8),
            _SidebarButton(
              collapsed: collapsed,
              icon: Icons.settings_rounded,
              label: 'Settings',
              selected: currentTab == HomeTab.settings,
              onTap: () => onSelectTab(HomeTab.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.collapsed,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final bool collapsed;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = selected ? Colors.white : Colors.transparent;
    final foreground = selected ? Colors.indigoAccent : Colors.black87;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 10 : 14,
            vertical: 12,
          ),
          child: Row(
            mainAxisAlignment: collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(icon, color: foreground),
              if (!collapsed) ...[
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
