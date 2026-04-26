import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../../models/search_path_entry.dart';
import '../../models/subtitle.dart';
import '../../services/alist_api_service.dart';
import '../../services/local_stream_proxy_service.dart';
import '../../view_models/player_view_model.dart';
import 'action_feedback_overlay.dart';

class VideoPlayerPane extends ConsumerStatefulWidget {
  const VideoPlayerPane({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _VideoPlayerPaneState();
}

class _VideoPlayerPaneState extends ConsumerState<VideoPlayerPane> {
  static const MaterialDesktopVideoControlsThemeData _videoControlsTheme =
      MaterialDesktopVideoControlsThemeData(
        keyboardShortcuts: <ShortcutActivator, VoidCallback>{},
        toggleFullscreenOnDoublePress: false,
        hideMouseOnControlsRemoval: true,
      );
  static const String _bottomGlassFilterGraph =
      r'lavfi=[split[main][tmp];[tmp]crop=iw:ih*0.15:0:ih*0.85,boxblur=12:2[blur];[main][blur]overlay=0:H-h]';

  late final VideoController controller;
  late final FocusNode _videoFocusNode;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<PlayerLog>? _logSub;
  final Map<String, String> _localPlaybackCache = {};
  final Map<String, String> _srtLocalCache = {};

  @override
  void initState() {
    super.initState();
    _videoFocusNode = FocusNode(debugLabel: 'VideoPlayerPane');
    // 取出 Provider 里唯一被接管生命周期的神级 Player
    final player = ref.read(playerProvider);
    controller = VideoController(player);
    _errorSub = player.stream.error.listen((message) {
      debugPrint('[VideoPlayerPane] player.error: $message');
    });
    _logSub = player.stream.log.listen((log) {
      final text = '[${log.prefix}/${log.level}] ${log.text}'.trim();
      debugPrint('[VideoPlayerPane] mpv: $text');
    });

    // 核心修复：HomePage 在 activeSubtitle 为空时不挂载本组件。
    // 所以“第一次点击”其实触发的是本组件的首次挂载，而 ref.listen 不会响应挂载前的历史变化。
    // 因此我们需要在 initState 里手动消费“第一次点击”的数据！
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialSub = ref.read(activeSubtitleProvider);
      if (initialSub != null) {
        _handlePlayback(null, initialSub);
      }
    });
  }

  Future<void> _handlePlayback(
    SubtitleEntry? previous,
    SubtitleEntry next,
  ) async {
    final player = ref.read(playerProvider);
    try {
      final startDuration = Duration(milliseconds: next.startMs);
      String targetPath = next.videoPath;
      Map<String, String>? headers;
      final hasNonAsciiUrl = targetPath.runes.any((rune) => rune > 0x7F);

      // Extract URI credentials to explicitly provide Basic Auth.
      // CRITICAL: Do NOT use Uri.tryParse().replace().toString() — it re-encodes
      // Chinese characters in the path (e.g. 百度网盘 → %E7%99%BE...).
      // Use regex to extract and strip user:pass while preserving raw path characters.
      final authRegex = RegExp(r'^(https?://)([^@]+)@(.+)$');
      final authMatch = authRegex.firstMatch(targetPath);
      if (authMatch != null) {
        final userPass = Uri.decodeComponent(authMatch.group(2)!);
        final base64Auth = base64Encode(utf8.encode(userPass));
        headers = {'Authorization': 'Basic $base64Auth'};
        // For ASCII-only URLs, keep userInfo in the URL so mpv can authenticate
        // using its native HTTP flow. For non-ASCII URLs, userInfo must be
        // stripped because Media/URI normalization will re-encode the path.
        if (hasNonAsciiUrl) {
          targetPath = '${authMatch.group(1)}${authMatch.group(3)}';
        }
      }

      if (targetPath.startsWith('http')) {
        final remoteUrlWithoutUserInfo = authMatch != null
            ? '${authMatch.group(1)}${authMatch.group(3)}'
            : targetPath;
        final matchingEntry = await _findMatchingWebdavEntry(
          remoteUrlWithoutUserInfo,
        );
        final localMountedPath = await _resolveLocalMountedPath(
          remoteUrlWithoutUserInfo: remoteUrlWithoutUserInfo,
          matchingEntry: matchingEntry,
        );
        if (localMountedPath != null) {
          debugPrint(
            '[VideoPlayerPane] Resolved WebDAV URL to mounted local file: $localMountedPath',
          );
          targetPath = localMountedPath;
          headers = null;
        } else if (matchingEntry != null) {
          final resolvedLink = await AlistApiService.instance.resolveSignedLink(
            entry: matchingEntry,
            remoteUrlWithoutUserInfo: remoteUrlWithoutUserInfo,
          );
          if (resolvedLink != null) {
            targetPath = _sanitizeHttpUrlForMpv(resolvedLink.url);
            headers = resolvedLink.headers.isEmpty
                ? null
                : resolvedLink.headers;
          } else if (_needsLocalWebdavFallback(targetPath)) {
            final localPlaybackPath = await _prepareLocalPlaybackFile(
              originalVideoPath: next.videoPath,
              remoteUrlWithoutUserInfo: remoteUrlWithoutUserInfo,
            );
            if (localPlaybackPath != null) {
              targetPath = localPlaybackPath;
              headers = null;
            } else {
              targetPath = _sanitizeHttpUrlForMpv(targetPath);
            }
          } else {
            targetPath = await LocalStreamProxyService.instance.register(
              remoteUrl: _sanitizeHttpUrlForMpv(remoteUrlWithoutUserInfo),
              headers: headers,
            );
            headers = null;
          }
        } else if (_needsLocalWebdavFallback(targetPath)) {
          final localPlaybackPath = await _prepareLocalPlaybackFile(
            originalVideoPath: next.videoPath,
            remoteUrlWithoutUserInfo: remoteUrlWithoutUserInfo,
          );
          if (localPlaybackPath != null) {
            targetPath = localPlaybackPath;
            headers = null;
          } else {
            targetPath = _sanitizeHttpUrlForMpv(targetPath);
          }
        } else {
          targetPath = await LocalStreamProxyService.instance.register(
            remoteUrl: _sanitizeHttpUrlForMpv(remoteUrlWithoutUserInfo),
            headers: headers,
          );
          headers = null;
        }
      }

      if (previous?.videoPath != next.videoPath) {
        debugPrint('[VideoPlayerPane] 🔴 NEW PLAYBACK REQUEST: ===');
        debugPrint('[VideoPlayerPane] 🔗 targetPath: $targetPath');
        debugPrint('[VideoPlayerPane] ⏱ startDuration: $startDuration');
        debugPrint('[VideoPlayerPane] 🔐 injectedHeaders: $headers');
        debugPrint('[VideoPlayerPane] =============================');

        await _configurePlayerForTarget(player, targetPath);
        debugPrint(
          '[VideoPlayerPane] New video detected. Calling player.open(play: true) ...',
        );
        await player.open(
          Media(targetPath, start: startDuration, httpHeaders: headers),
          play: true,
        );
        debugPrint('[VideoPlayerPane] player.open() returned asynchronously!');
        // Explicitly load the subtitle file — mpv cannot auto-discover subtitles for HTTP URLs
        unawaited(_loadSubtitleForEntry(player, next));
      } else {
        debugPrint(
          '[VideoPlayerPane] Same video detected. Calling player.seek($startDuration) ...',
        );
        // 在同一个视频下切字幕时间轴，已经不存在 cold-start，原生管道能极化处理连续跳跃
        // 如果目前不是播放状态，也可以安全拉起
        await player.seek(startDuration);
        debugPrint(
          '[VideoPlayerPane] player.seek() completed. Calling player.play() ...',
        );
        await player.play();
        debugPrint('[VideoPlayerPane] player.play() completed.');
      }
    } catch (e, stack) {
      debugPrint('[VideoPlayerPane] Playback error: $e\n$stack');
    }
  }

  String _sanitizeHttpUrlForMpv(String url) {
    final buffer = StringBuffer();
    for (final rune in url.runes) {
      final ch = String.fromCharCode(rune);
      final isAscii = rune <= 0x7F;
      final isSafeAscii = RegExp(
        r"[A-Za-z0-9\-._~:/?&=;%+@!$,()*\[\]]",
      ).hasMatch(ch);
      if (!isAscii || isSafeAscii) {
        buffer.write(ch);
      } else {
        buffer.write(
          '%${rune.toRadixString(16).toUpperCase().padLeft(2, '0')}',
        );
      }
    }
    return buffer.toString();
  }

  bool _needsLocalWebdavFallback(String url) {
    return url.runes.any((rune) => rune > 0x7F);
  }

  Future<String?> _prepareLocalPlaybackFile({
    required String originalVideoPath,
    required String remoteUrlWithoutUserInfo,
  }) async {
    final cached = _localPlaybackCache[originalVideoPath];
    if (cached != null && await File(cached).exists()) {
      debugPrint('[VideoPlayerPane] Reusing cached local file: $cached');
      return cached;
    }

    final entry = await _findMatchingWebdavEntry(remoteUrlWithoutUserInfo);
    if (entry == null) {
      return null;
    }

    final normalizedRoot = _normalizeComparableUrl(entry.path);
    final normalizedRemote = _normalizeComparableUrl(remoteUrlWithoutUserInfo);
    if (!normalizedRemote.startsWith(normalizedRoot)) {
      return null;
    }

    var relativePath = normalizedRemote.substring(normalizedRoot.length);
    if (!relativePath.startsWith('/')) {
      relativePath = '/$relativePath';
    }

    final decodedName = Uri.decodeFull(relativePath.split('/').last);
    final safeName = decodedName.isEmpty ? 'remote_video.bin' : decodedName;
    final cacheDir = Directory(
      '${Directory.systemTemp.path}/subfinderx_webdav_cache',
    );
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final localPath =
        '${cacheDir.path}/${originalVideoPath.hashCode.abs()}_$safeName';
    final localFile = File(localPath);

    if (!await localFile.exists()) {
      debugPrint(
        '[VideoPlayerPane] Downloading remote video to local cache...',
      );
      debugPrint(
        '[VideoPlayerPane] Downloading WebDAV video $relativePath -> $localPath',
      );
      final client = webdav.newClient(
        entry.path,
        user: entry.username ?? '',
        password: entry.password ?? '',
        debug: false,
      );
      await client.read2File(relativePath, localPath);
    }

    _localPlaybackCache[originalVideoPath] = localPath;
    return localPath;
  }

  Future<void> _configurePlayerForTarget(
    Player player,
    String targetPath,
  ) async {
    final isNetworkTarget =
        targetPath.startsWith('http://') || targetPath.startsWith('https://');
    try {
      final platform = player.platform;
      if (platform == null) {
        return;
      }
      final dynamic nativePlayer = platform;
      if (isNetworkTarget) {
        debugPrint(
          '[VideoPlayerPane] Configuring mpv for network playback (memory cache only).',
        );
        await nativePlayer.setProperty('cache', 'yes');
        await nativePlayer.setProperty('cache-on-disk', 'no');
      } else {
        debugPrint(
          '[VideoPlayerPane] Configuring mpv for local file playback (disable network cache).',
        );
        await nativePlayer.setProperty('cache', 'no');
        await nativePlayer.setProperty('cache-on-disk', 'no');
      }
      // Disable mpv auto subtitle discovery — we load subtitles explicitly via sub-add.
      await nativePlayer.setProperty('sub-auto', 'no');
      // Keep the subtitle track active so media_kit can forward subtitle text to
      // Flutter's SubtitleView. We only hide mpv's own on-video rendering layer.
      await nativePlayer.setProperty('sub-visibility', 'no');
      await _applyBottomGlassFilter(
        player,
        enabled: ref.read(videoBottomMaskVisibleProvider),
      );
    } catch (e) {
      debugPrint('[VideoPlayerPane] Failed to configure mpv cache mode: $e');
    }
  }

  Future<void> _applyBottomGlassFilter(
    Player player, {
    required bool enabled,
  }) async {
    try {
      final platform = player.platform;
      if (platform == null) {
        return;
      }
      final dynamic nativePlayer = platform;
      await nativePlayer.setProperty(
        'vf',
        enabled ? _bottomGlassFilterGraph : '',
      );
      debugPrint(
        '[VideoPlayerPane] ${enabled ? 'Enabled' : 'Disabled'} bottom glass vf.',
      );
    } catch (e) {
      debugPrint('[VideoPlayerPane] Failed to apply bottom glass vf: $e');
    }
  }

  /// Downloads the subtitle (.srt) file if needed, then tells mpv to load it
  /// via the `sub-add` command. Runs concurrently with video startup.
  Future<void> _loadSubtitleForEntry(Player player, SubtitleEntry entry) async {
    try {
      String localSrtPath;

      if (entry.srtPath.startsWith('http')) {
        localSrtPath = await _downloadSrtToLocal(entry.srtPath);
      } else {
        localSrtPath = entry.srtPath;
      }

      if (!await File(localSrtPath).exists()) {
        debugPrint(
          '[VideoPlayerPane] ⚠️ Subtitle file not found: $localSrtPath',
        );
        return;
      }

      // Wait for mpv to have the file loaded before sending sub-add
      for (int i = 0; i < 50; i++) {
        if (player.state.playing || player.state.duration > Duration.zero) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }

      final platform = player.platform;
      if (platform == null) return;
      final dynamic nativePlayer = platform;
      await nativePlayer.command(['sub-add', localSrtPath, 'select']);
      debugPrint('[VideoPlayerPane] ✅ Subtitle loaded: $localSrtPath');
    } catch (e) {
      debugPrint('[VideoPlayerPane] ❌ Failed to load subtitle: $e');
    }
  }

  /// Downloads a remote .srt file from WebDAV to a local temp file.
  /// Results are cached in [_srtLocalCache] for reuse.
  Future<String> _downloadSrtToLocal(String srtUrl) async {
    final cached = _srtLocalCache[srtUrl];
    if (cached != null && await File(cached).exists()) {
      debugPrint('[VideoPlayerPane] Reusing cached subtitle: $cached');
      return cached;
    }

    final authRegex = RegExp(r'^(https?://)([^@]+)@(.+)$');
    final authMatch = authRegex.firstMatch(srtUrl);
    final urlWithoutAuth = authMatch != null
        ? '${authMatch.group(1)}${authMatch.group(3)}'
        : srtUrl;

    final entry = await _findMatchingWebdavEntry(urlWithoutAuth);
    if (entry == null) {
      throw Exception('No matching WebDAV entry found for subtitle: $srtUrl');
    }

    final normalizedRoot = _normalizeComparableUrl(entry.path);
    final normalizedUrl = _normalizeComparableUrl(urlWithoutAuth);
    if (!normalizedUrl.startsWith(normalizedRoot)) {
      throw Exception('Subtitle URL does not match WebDAV root');
    }

    var relativePath = normalizedUrl.substring(normalizedRoot.length);
    if (!relativePath.startsWith('/')) {
      relativePath = '/$relativePath';
    }

    debugPrint(
      '[VideoPlayerPane] Downloading subtitle from WebDAV: $relativePath',
    );
    final client = webdav.newClient(
      entry.path,
      user: entry.username ?? '',
      password: entry.password ?? '',
      debug: false,
    );
    final bytes = await client.read(relativePath);

    final cacheDir = Directory(
      '${Directory.systemTemp.path}/subfinderx_subtitle_cache',
    );
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final decodedName = Uri.decodeFull(srtUrl.split('/').last);
    final safeName = decodedName.isEmpty ? 'subtitle.srt' : decodedName;
    final localPath = '${cacheDir.path}/${srtUrl.hashCode.abs()}_$safeName';
    await File(localPath).writeAsBytes(bytes);

    _srtLocalCache[srtUrl] = localPath;
    debugPrint('[VideoPlayerPane] ✅ Downloaded subtitle to: $localPath');
    return localPath;
  }

  Future<String?> _resolveLocalMountedPath({
    required String remoteUrlWithoutUserInfo,
    required SearchPathEntry? matchingEntry,
  }) async {
    if (matchingEntry == null) {
      return null;
    }

    final normalizedRoot = _normalizeComparableUrl(matchingEntry.path);
    final normalizedRemote = _normalizeComparableUrl(remoteUrlWithoutUserInfo);
    if (!normalizedRemote.startsWith(normalizedRoot)) {
      return null;
    }

    var relativePath = normalizedRemote.substring(normalizedRoot.length);
    if (!relativePath.startsWith('/')) {
      relativePath = '/$relativePath';
    }
    relativePath = Uri.decodeFull(relativePath);

    final prefs = await SharedPreferences.getInstance();
    final rawPaths = prefs.getStringList('search_paths') ?? const [];
    for (final raw in rawPaths) {
      try {
        final entry = raw.startsWith('{')
            ? SearchPathEntry.decode(raw)
            : SearchPathEntry(type: PathEntryType.local, path: raw);
        if (entry.type != PathEntryType.local) {
          continue;
        }
        final localRoot = entry.path.replaceAll(RegExp(r'/$'), '');
        final candidate = '$localRoot$relativePath';
        if (await File(candidate).exists()) {
          return candidate;
        }
      } catch (e) {
        debugPrint(
          '[VideoPlayerPane] Failed to resolve mounted local path candidate: $e',
        );
      }
    }
    return null;
  }

  Future<SearchPathEntry?> _findMatchingWebdavEntry(
    String remoteUrlWithoutUserInfo,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final rawPaths = prefs.getStringList('search_paths') ?? const [];
    SearchPathEntry? bestMatch;
    var bestLength = -1;

    for (final raw in rawPaths) {
      try {
        final entry = raw.startsWith('{')
            ? SearchPathEntry.decode(raw)
            : SearchPathEntry(type: PathEntryType.local, path: raw);
        if (entry.type != PathEntryType.webdav) {
          continue;
        }
        final normalizedRoot = _normalizeComparableUrl(entry.path);
        final normalizedRemote = _normalizeComparableUrl(
          remoteUrlWithoutUserInfo,
        );
        if (normalizedRemote.startsWith(normalizedRoot) &&
            normalizedRoot.length > bestLength) {
          bestMatch = entry;
          bestLength = normalizedRoot.length;
        }
      } catch (e) {
        debugPrint('[VideoPlayerPane] Failed to decode search path: $e');
      }
    }

    return bestMatch;
  }

  String _normalizeComparableUrl(String url) {
    return url
        .replaceAll(RegExp(r'^(https?://)([^@]+)@'), r'$1')
        .replaceAll(RegExp(r'/$'), '');
  }

  @override
  void dispose() {
    ref.read(videoFullscreenContextProvider.notifier).setContext(null);
    ref.read(videoInlineContextProvider.notifier).setContext(null);
    _videoFocusNode.dispose();
    _errorSub?.cancel();
    _logSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 监听后续的更换字幕点击
    ref.listen<SubtitleEntry?>(activeSubtitleProvider, (previous, next) {
      if (next != null) {
        _handlePlayback(previous, next);
      }
    });
    ref.listen<bool>(videoBottomMaskVisibleProvider, (previous, next) {
      if (previous == next) return;
      unawaited(
        _applyBottomGlassFilter(ref.read(playerProvider), enabled: next),
      );
    });

    final activeSub = ref.watch(activeSubtitleProvider);
    // 自定义 controls 闭包：在 MaterialDesktopVideoControls 之上叠加 ActionFeedbackOverlay。
    // media_kit 全屏时会复用此闭包创建新的 controls 实例，所以 overlay 也会出现在全屏路由中。
    Widget controlsBuilder(VideoState state) {
      return Consumer(
        builder: (context, ref, _) {
          final showSubtitles = ref.watch(subtitleVisibleProvider);
          final showVideoBottomMask = ref.watch(videoBottomMaskVisibleProvider);
          final feedbackStream = ref.watch(feedbackBusProvider).stream;
          return Builder(
            builder: (controlsContext) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !controlsContext.mounted) return;
                if (isFullscreen(controlsContext)) {
                  ref
                      .read(videoFullscreenContextProvider.notifier)
                      .setContext(controlsContext);
                } else {
                  ref
                      .read(videoInlineContextProvider.notifier)
                      .setContext(controlsContext);
                  ref
                      .read(videoFullscreenContextProvider.notifier)
                      .setContext(null);
                }
              });

              return Stack(
                fit: StackFit.expand,
                children: [
                  if (showVideoBottomMask)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _BottomVideoMosaicOverlay(
                          player: ref.read(playerProvider),
                        ),
                      ),
                    ),
                  if (showSubtitles)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: SubtitleView(
                          controller: controller,
                          configuration: SubtitleViewConfiguration(
                            style: const TextStyle(
                              height: 1.4,
                              fontSize: 48.0,
                              letterSpacing: 0.0,
                              wordSpacing: 0.0,
                              color: Color(0xffffffff),
                              fontWeight: FontWeight.normal,
                              backgroundColor: Color(0xaa000000),
                            ),
                            padding: EdgeInsets.fromLTRB(
                              16.0,
                              0.0,
                              16.0,
                              MediaQuery.paddingOf(controlsContext).bottom +
                                  32.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  MaterialDesktopVideoControls(state),
                  Positioned(
                    top: 48,
                    bottom: 120,
                    left: 0,
                    right: 0,
                    child: MouseRegion(
                      opaque: false,
                      cursor: MouseCursor.defer,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          _videoFocusNode.requestFocus();
                          final player = ref.read(playerProvider);
                          final willPlay = !player.state.playing;
                          player.playOrPause();
                          ref
                              .read(feedbackBusProvider)
                              .emit(
                                FeedbackEvent(
                                  FeedbackType.playPause,
                                  boolValue: willPlay,
                                ),
                              );
                        },
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  ActionFeedbackOverlay(stream: feedbackStream),
                ],
              );
            },
          );
        },
      );
    }

    return Container(
      color: Colors.black, // 影院级别深色帷幕包裹
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 核心方案1：让 Video 常驻挂载。这样一来底层 Native Texture 从首屏就建立好了，
          // 开播的瞬间画面就能立刻无缝贴花，避免第一遍播放只有声音没有画面的冷启动闪失。
          MaterialDesktopVideoControlsTheme(
            normal: _videoControlsTheme,
            fullscreen: _videoControlsTheme,
            child: Video(
              controller: controller,
              focusNode: _videoFocusNode,
              controls: controlsBuilder,
              subtitleViewConfiguration: const SubtitleViewConfiguration(
                visible: false,
              ),
            ),
          ),
          if (activeSub == null)
            Container(color: Colors.black, child: _buildPlaceholder()),

          Positioned(
            top: 24,
            right: 24,
            child: IconButton(
              focusNode: FocusNode(canRequestFocus: false),
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                ref.read(activeSubtitleProvider.notifier).setActive(null);
                ref.read(playerProvider).stop();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.movie_creation_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            'Search & Click a subtitle to start playing',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 16,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomVideoMosaicOverlay extends StatefulWidget {
  const _BottomVideoMosaicOverlay({required this.player});

  final Player player;

  @override
  State<_BottomVideoMosaicOverlay> createState() =>
      _BottomVideoMosaicOverlayState();
}

class _BottomVideoMosaicOverlayState extends State<_BottomVideoMosaicOverlay> {
  StreamSubscription<int?>? _widthSub;
  StreamSubscription<int?>? _heightSub;
  int? _videoWidth;
  int? _videoHeight;

  @override
  void initState() {
    super.initState();
    _videoWidth = widget.player.state.width;
    _videoHeight = widget.player.state.height;
    _widthSub = widget.player.stream.width.listen((value) {
      if (!mounted) return;
      setState(() {
        _videoWidth = value;
      });
    });
    _heightSub = widget.player.stream.height.listen((value) {
      if (!mounted) return;
      setState(() {
        _videoHeight = value;
      });
    });
  }

  @override
  void dispose() {
    _widthSub?.cancel();
    _heightSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoWidth = _videoWidth;
    final videoHeight = _videoHeight;
    if (videoWidth == null ||
        videoHeight == null ||
        videoWidth <= 0 ||
        videoHeight <= 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth;
        final containerHeight = constraints.maxHeight;
        if (containerWidth <= 0 || containerHeight <= 0) {
          return const SizedBox.shrink();
        }

        final scale = math.min(
          containerWidth / videoWidth,
          containerHeight / videoHeight,
        );
        final displayWidth = videoWidth * scale;
        final displayHeight = videoHeight * scale;
        final offsetX = (containerWidth - displayWidth) / 2;
        final offsetY = (containerHeight - displayHeight) / 2;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: offsetX,
              top: offsetY + displayHeight * 0.85,
              width: displayWidth,
              height: displayHeight * 0.15,
              child: const _BottomVideoGlassOverlay(),
            ),
          ],
        );
      },
    );
  }
}

class _BottomVideoGlassOverlay extends StatelessWidget {
  const _BottomVideoGlassOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x33FFFFFF), Color(0x59FFFFFF), Color(0x4DF8FAFC)],
        ),
        border: Border(top: BorderSide(color: Color(0x88FFFFFF), width: 1)),
      ),
      child: const SizedBox.expand(),
    );
  }
}
