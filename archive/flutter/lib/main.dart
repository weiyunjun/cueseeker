import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video_controls/media_kit_video_controls.dart';

import 'providers/database_provider.dart';
import 'services/favorite_service.dart';
import 'view_models/favorite_view_model.dart';
import 'view_models/player_view_model.dart';
import 'ui/components/action_feedback_overlay.dart';
import 'ui/home_page.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 必须首选初始化媒体框架环境以便挂载底层 C 库
  MediaKit.ensureInitialized();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _isDialogActive = false;
  bool _isTogglingFullscreen = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    super.dispose();
  }

  bool _isTypingIntoEditable() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    final focusContext = primaryFocus?.context;
    return focusContext != null &&
        (focusContext.widget is EditableText ||
            focusContext.findAncestorWidgetOfExactType<EditableText>() != null);
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }

    final key = event.logicalKey;
    final navigator = _navigatorKey.currentState;

    // Escape 最优先处理：无论修饰键、对话框、输入框状态如何
    if (key == LogicalKeyboardKey.escape) {
      if (_isTypingIntoEditable()) {
        // 在文本框中按 Escape → 取消焦点
        FocusManager.instance.primaryFocus?.unfocus();
        return true;
      }
      navigator?.maybePop();
      return true;
    }

    // 有修饰键按下时放行，让系统处理 Cmd+Z/C/X/F/S 等标准快捷键
    if (HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return false;
    }

    if (_isTypingIntoEditable()) {
      return false;
    }

    // 对话框期间放行所有非 Escape 键，让对话框自行处理按钮激活等
    if (_isDialogActive) {
      return false;
    }

    final activeSubtitle = ref.read(activeSubtitleProvider);
    if (activeSubtitle == null) {
      return false;
    }

    final player = ref.read(playerProvider);
    switch (key) {
      case LogicalKeyboardKey.arrowLeft:
        player.seek(player.state.position - const Duration(seconds: 5));
        ref
            .read(feedbackBusProvider)
            .emit(const FeedbackEvent(FeedbackType.rewind));
        return true;
      case LogicalKeyboardKey.arrowRight:
        player.seek(player.state.position + const Duration(seconds: 5));
        ref
            .read(feedbackBusProvider)
            .emit(const FeedbackEvent(FeedbackType.forward));
        return true;
      case LogicalKeyboardKey.arrowUp:
        final newVol = (player.state.volume + 5.0).clamp(0.0, 100.0);
        player.setVolume(newVol);
        ref
            .read(feedbackBusProvider)
            .emit(FeedbackEvent(FeedbackType.volume, value: newVol));
        return true;
      case LogicalKeyboardKey.arrowDown:
        final newVol = (player.state.volume - 5.0).clamp(0.0, 100.0);
        player.setVolume(newVol);
        ref
            .read(feedbackBusProvider)
            .emit(FeedbackEvent(FeedbackType.volume, value: newVol));
        return true;
      case LogicalKeyboardKey.space:
        final willPlay = !player.state.playing;
        player.playOrPause();
        ref
            .read(feedbackBusProvider)
            .emit(FeedbackEvent(FeedbackType.playPause, boolValue: willPlay));
        return true;
      case LogicalKeyboardKey.keyZ:
        player.setRate(1.0);
        ref
            .read(feedbackBusProvider)
            .emit(const FeedbackEvent(FeedbackType.speed, value: 1.0));
        return true;
      case LogicalKeyboardKey.keyX:
        final newRate = (player.state.rate + 0.1).clamp(0.1, 4.0);
        player.setRate(newRate);
        ref
            .read(feedbackBusProvider)
            .emit(FeedbackEvent(FeedbackType.speed, value: newRate));
        return true;
      case LogicalKeyboardKey.keyC:
        final newRate = (player.state.rate - 0.1).clamp(0.1, 4.0);
        player.setRate(newRate);
        ref
            .read(feedbackBusProvider)
            .emit(FeedbackEvent(FeedbackType.speed, value: newRate));
        return true;
      case LogicalKeyboardKey.keyQ:
        final nextVisible = !ref.read(subtitleVisibleProvider);
        ref.read(subtitleVisibleProvider.notifier).setVisible(nextVisible);
        ref
            .read(feedbackBusProvider)
            .emit(
              FeedbackEvent.message(
                icon: nextVisible
                    ? Icons.subtitles_rounded
                    : Icons.subtitles_off_rounded,
                text: nextVisible ? '显示字幕' : '隐藏字幕',
              ),
            );
        return true;
      case LogicalKeyboardKey.keyW:
        final nextVisible = !ref.read(videoBottomMaskVisibleProvider);
        ref
            .read(videoBottomMaskVisibleProvider.notifier)
            .setVisible(nextVisible);
        ref
            .read(feedbackBusProvider)
            .emit(
              FeedbackEvent.message(
                icon: nextVisible
                    ? Icons.grid_view_rounded
                    : Icons.grid_off_rounded,
                text: nextVisible ? '开启底部遮挡' : '关闭底部遮挡',
              ),
            );
        return true;
      case LogicalKeyboardKey.keyF:
        _handleFullscreenShortcut();
        return true;
      case LogicalKeyboardKey.keyS:
        _handleFavoriteShortcut();
        return true;
      default:
        return false;
    }
  }

  Future<void> _handleFullscreenShortcut() async {
    if (_isTogglingFullscreen) return;
    _isTogglingFullscreen = true;
    try {
      final fullscreenContext = ref.read(videoFullscreenContextProvider);
      final inlineContext = ref.read(videoInlineContextProvider);
      final videoContext = fullscreenContext?.mounted == true
          ? fullscreenContext
          : inlineContext;
      if (videoContext == null || !videoContext.mounted) {
        return;
      }
      await toggleFullscreen(videoContext);
    } finally {
      _isTogglingFullscreen = false;
    }
  }

  Future<void> _handleFavoriteShortcut() async {
    final active = ref.read(activeSubtitleProvider);
    if (active == null) {
      return;
    }

    final service = ref.read(favoriteServiceProvider);
    final player = ref.read(playerProvider);
    final currentMs = player.state.position.inMilliseconds;
    final target = service.resolveFavoriteTarget(
      srtPath: active.srtPath,
      currentMs: currentMs,
    );

    if (target == null) {
      ref
          .read(feedbackBusProvider)
          .emit(
            const FeedbackEvent.message(
              icon: Icons.error_outline_rounded,
              text: '收藏失败：当前时间点之前没有可收藏的字幕',
            ),
          );
      return;
    }

    final isFavorite = service.isFavorite(
      target.srtPath,
      target.startMs,
      target.endMs,
    );

    if (!isFavorite) {
      service.addFavorite(target);
      ref.invalidate(favoriteLookupProvider);
      ref.invalidate(favoriteResultsProvider);
      ref
          .read(feedbackBusProvider)
          .emit(
            const FeedbackEvent.message(
              icon: Icons.star_rounded,
              text: '已加入收藏',
            ),
          );
      return;
    }

    _isDialogActive = true;
    try {
      await player.pause();
      if (!mounted) {
        return;
      }
      final dialogContext = _navigatorKey.currentContext;
      if (dialogContext == null || !dialogContext.mounted) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: dialogContext,
        useRootNavigator: true,
        builder: (context) {
          return AlertDialog(
            title: const Text('移除收藏'),
            content: const Text('确定要移除对该句子的收藏吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('确定'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        return;
      }

      service.removeFavoriteByIdentity(
        target.srtPath,
        target.startMs,
        target.endMs,
      );
      ref.invalidate(favoriteLookupProvider);
      ref.invalidate(favoriteResultsProvider);
      ref
          .read(feedbackBusProvider)
          .emit(
            const FeedbackEvent.message(
              icon: Icons.star_outline_rounded,
              text: '已取消收藏',
            ),
          );
    } finally {
      _isDialogActive = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 强制先初始化数据库逻辑，等待结束前保持启动屏幕
    final dbInitState = ref.watch(databaseInitProvider);

    return Shortcuts(
      shortcuts:
          <
            ShortcutActivator,
            Intent
          >{}, // 清空所有 Flutter 默认快捷键 (Space/Arrow/Tab/Enter 等)
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'SubFinderX',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          useMaterial3: true,
          fontFamily: 'Inter',
          colorSchemeSeed: Colors.indigo,
        ),
        home: dbInitState.when(
          data: (_) => const HomePage(),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, stack) =>
              Scaffold(body: Center(child: Text('Error: \$err'))),
        ),
      ),
    );
  }
}
