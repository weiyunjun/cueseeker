import 'dart:async';
import 'package:flutter/material.dart';

/// 反馈事件类型
enum FeedbackType { forward, rewind, playPause, speed, volume, message }

/// 承载反馈事件的数据类
class FeedbackEvent {
  final FeedbackType type;
  final double? value;
  final bool? boolValue;
  final IconData? icon;
  final String? text;

  const FeedbackEvent(this.type, {this.value, this.boolValue, this.icon, this.text});

  const FeedbackEvent.message({required IconData icon, required String text})
      : this(FeedbackType.message, icon: icon, text: text);
}

class ActionFeedbackOverlay extends StatefulWidget {
  /// 事件流：外部通过往 stream 中添加 FeedbackEvent 来触发动画
  final Stream<FeedbackEvent> stream;

  const ActionFeedbackOverlay({super.key, required this.stream});

  @override
  ActionFeedbackOverlayState createState() => ActionFeedbackOverlayState();
}

class ActionFeedbackOverlayState extends State<ActionFeedbackOverlay> with TickerProviderStateMixin {
  // Seek State
  int _forwardSecs = 0;
  int _rewindSecs = 0;
  Timer? _forwardTimer;
  Timer? _rewindTimer;
  bool _showForward = false;
  bool _showRewind = false;

  // Center State
  IconData? _centerIcon;
  String? _centerText;
  bool _showCenter = false;
  Timer? _centerTimer;
  
  // Animators
  late AnimationController _centerAnimCtrl;
  late AnimationController _sideAnimCtrl;

  StreamSubscription<FeedbackEvent>? _eventSub;

  @override
  void initState() {
    super.initState();
    _centerAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _sideAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _eventSub = widget.stream.listen(_handleEvent);
  }

  @override
  void didUpdateWidget(covariant ActionFeedbackOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _eventSub?.cancel();
      _eventSub = widget.stream.listen(_handleEvent);
    }
  }

  void _handleEvent(FeedbackEvent event) {
    switch (event.type) {
      case FeedbackType.forward:
        _showForwardAnim();
      case FeedbackType.rewind:
        _showRewindAnim();
      case FeedbackType.playPause:
        _showPlayPauseAnim(event.boolValue ?? true);
      case FeedbackType.speed:
        _showSpeedAnim(event.value ?? 1.0);
      case FeedbackType.volume:
        _showVolumeAnim(event.value ?? 100.0);
      case FeedbackType.message:
        _showMessageAnim(event.icon, event.text ?? '');
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _forwardTimer?.cancel();
    _rewindTimer?.cancel();
    _centerTimer?.cancel();
    _centerAnimCtrl.dispose();
    _sideAnimCtrl.dispose();
    super.dispose();
  }

  void _showForwardAnim() {
    setState(() {
      _showRewind = false;
      _rewindSecs = 0;
      _forwardSecs += 5;
      _showForward = true;
    });
    _sideAnimCtrl.forward(from: 0.0);
    _forwardTimer?.cancel();
    _forwardTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() { _showForward = false; _forwardSecs = 0; });
    });
  }

  void _showRewindAnim() {
    setState(() {
      _showForward = false;
      _forwardSecs = 0;
      _rewindSecs += 5;
      _showRewind = true;
    });
    _sideAnimCtrl.forward(from: 0.0);
    _rewindTimer?.cancel();
    _rewindTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() { _showRewind = false; _rewindSecs = 0; });
    });
  }

  void _showPlayPauseAnim(bool isPlaying) {
    setState(() {
      _centerIcon = isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded;
      _centerText = null;
      _showCenter = true;
    });
    _centerAnimCtrl.forward(from: 0.0);
    _centerTimer?.cancel();
    _centerTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() { _showCenter = false; });
    });
  }

  void _showSpeedAnim(double rate) {
    setState(() {
      _centerIcon = Icons.speed_rounded;
      _centerText = '${rate.toStringAsFixed(1)}x';
      _showCenter = true;
    });
    _centerAnimCtrl.forward(from: 0.0);
    _centerTimer?.cancel();
    _centerTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() { _showCenter = false; });
    });
  }

  void _showVolumeAnim(double volume) {
    setState(() {
      _centerIcon = volume > 0 ? Icons.volume_up_rounded : Icons.volume_off_rounded;
      _centerText = '${volume.toInt()}%';
      _showCenter = true;
    });
    _centerAnimCtrl.forward(from: 0.0);
    _centerTimer?.cancel();
    _centerTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() { _showCenter = false; });
    });
  }

  void _showMessageAnim(IconData? icon, String text) {
    setState(() {
      _centerIcon = icon;
      _centerText = text;
      _showCenter = true;
    });
    _centerAnimCtrl.forward(from: 0.0);
    _centerTimer?.cancel();
    _centerTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() { _showCenter = false; });
    });
  }

  Widget _buildSidePill(bool isForward) {
    final secs = isForward ? _forwardSecs : _rewindSecs;
    final icon = isForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded;
    final text = isForward ? '+ $secs' : '- $secs';
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(32),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isForward 
            ? [
                Text(text, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white, size: 32),
              ]
            : [
                Icon(icon, color: Colors.white, size: 32),
                const SizedBox(width: 8),
                Text(text, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_showRewind)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 64.0),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _sideAnimCtrl, curve: const Interval(0.5, 1.0))),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.9, end: 1.05).animate(CurvedAnimation(parent: _sideAnimCtrl, curve: Curves.easeOutCubic)),
                    child: _buildSidePill(false),
                  ),
                ),
              ),
            ),
            
          if (_showForward)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 64.0),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _sideAnimCtrl, curve: const Interval(0.5, 1.0))),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.9, end: 1.05).animate(CurvedAnimation(parent: _sideAnimCtrl, curve: Curves.easeOutCubic)),
                    child: _buildSidePill(true),
                  ),
                ),
              ),
            ),
            
          if (_showCenter)
            Center(
              child: FadeTransition(
                opacity: Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _centerAnimCtrl, curve: const Interval(0.5, 1.0))),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _centerAnimCtrl, curve: Curves.easeOutCubic)),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: _centerIcon != null && _centerText == null ? BoxShape.circle : BoxShape.rectangle,
                      borderRadius: _centerIcon != null && _centerText == null ? null : BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_centerIcon != null) Icon(_centerIcon, color: Colors.white, size: 64),
                        if (_centerText != null)
                          Text(_centerText!, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
