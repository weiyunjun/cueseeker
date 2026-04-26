import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import '../models/subtitle.dart';
import '../ui/components/action_feedback_overlay.dart';

// 记录当前被点击激活的字幕项（包含完整的视频路径和起止时间）
class ActiveSubtitleNotifier extends Notifier<SubtitleEntry?> {
  @override
  SubtitleEntry? build() => null;
  void setActive(SubtitleEntry? entry) => state = entry;
}

final activeSubtitleProvider =
    NotifierProvider<ActiveSubtitleNotifier, SubtitleEntry?>(
      ActiveSubtitleNotifier.new,
    );

class SubtitleVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
  void setVisible(bool visible) => state = visible;
}

final subtitleVisibleProvider =
    NotifierProvider<SubtitleVisibilityNotifier, bool>(
      SubtitleVisibilityNotifier.new,
    );

class VideoBottomMaskVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void setVisible(bool visible) => state = visible;
}

final videoBottomMaskVisibleProvider =
    NotifierProvider<VideoBottomMaskVisibilityNotifier, bool>(
      VideoBottomMaskVisibilityNotifier.new,
    );

class VideoFullscreenContextNotifier extends Notifier<BuildContext?> {
  @override
  BuildContext? build() => null;

  void setContext(BuildContext? context) => state = context;
}

final videoFullscreenContextProvider =
    NotifierProvider<VideoFullscreenContextNotifier, BuildContext?>(
      VideoFullscreenContextNotifier.new,
    );

class VideoInlineContextNotifier extends Notifier<BuildContext?> {
  @override
  BuildContext? build() => null;

  void setContext(BuildContext? context) => state = context;
}

final videoInlineContextProvider =
    NotifierProvider<VideoInlineContextNotifier, BuildContext?>(
      VideoInlineContextNotifier.new,
    );

// 统管全局生命周期的播放器引擎实例
final playerProvider = Provider<Player>((ref) {
  final player = Player(
    configuration: const PlayerConfiguration(logLevel: MPVLogLevel.debug),
  );
  // 当应用退出或者引擎销毁时，切记利用 FFI 释放底层 libmpv 的 C 内存
  ref.onDispose(() => player.dispose());
  return player;
});

class FeedbackBus {
  final StreamController<FeedbackEvent> _controller =
      StreamController<FeedbackEvent>.broadcast();

  Stream<FeedbackEvent> get stream => _controller.stream;

  void emit(FeedbackEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  void dispose() {
    _controller.close();
  }
}

final feedbackBusProvider = Provider<FeedbackBus>((ref) {
  final bus = FeedbackBus();
  ref.onDispose(bus.dispose);
  return bus;
});
