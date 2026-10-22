#import "SFXNativePlaybackInternal.h"

@implementation SFXNativePlaybackPlayer {
    SFXNativePlaybackView *_nativeView;
    SFXNativePlaybackSession *_session;
    NSString *_currentPath;
    NSString *_httpHeaders;
    float _volume;
    float _playbackRate;
    SFXNativePlaybackDecodeMode _decodeMode;
    NSInteger _audioTrackIndex;
    BOOL _didRecycleInitialSoftwareSession;
    NSUInteger _nativeSessionOpenCount;
    NSUInteger _nativeInSessionSeekCount;
    NSUInteger _nativePresentationGeneration;
    NSUInteger _currentPresentationGeneration;
    NSUInteger _lastNotifiedVideoPresentationGeneration;
    BOOL _audioOutputRecoveryScheduled;
    BOOL _audioOutputRecoveryRequested;
    dispatch_queue_t _scrubPreviewQueue;
    NSUInteger _scrubPreviewGeneration;
    NSInteger _lastScrubPreviewFrameMilliseconds;
    CVPixelBufferRef _latestSubmittedPixelBuffer;
    SFXNativePlaybackFrameSnapshot *_latestSubmittedVideoFrameSnapshot;
}

+ (BOOL)isHardwareDecodeSupportedForCodecName:(NSString *)codecName {
    return SFXIsHardwareDecodeSupportedForCodecName(codecName);
}

+ (BOOL)isHardwareDecodeSupportedForCodecName:(NSString *)codecName
                              pixelFormatName:(NSString *)pixelFormatName {
    return SFXIsHardwareDecodeSupportedForCodecNameAndPixelFormatName(codecName, pixelFormatName);
}

- (instancetype)init {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    av_log_set_level(AV_LOG_ERROR);

    _volume = 1.0;
    _playbackRate = 1.0;
    _decodeMode = SFXNativePlaybackDecodeModeAuto;
    _scrubPreviewQueue = dispatch_queue_create("CueSeeker.NativePlayback.ScrubPreview", DISPATCH_QUEUE_SERIAL);
    _lastScrubPreviewFrameMilliseconds = -1;
    _nativeView = [[SFXNativePlaybackView alloc] initWithFrame:NSZeroRect];
    return self;
}

- (void)dealloc {
    if (_latestSubmittedPixelBuffer != NULL) {
        CVPixelBufferRelease(_latestSubmittedPixelBuffer);
        _latestSubmittedPixelBuffer = NULL;
    }
}

- (NSView *)view {
    return _nativeView;
}

- (NSString *)currentPath {
    return _currentPath;
}

- (NSString *)httpHeaders {
    @synchronized (self) {
        return _httpHeaders;
    }
}

- (void)setHttpHeaders:(NSString *)httpHeaders {
    @synchronized (self) {
        _httpHeaders = [httpHeaders copy];
    }
}

- (double)currentTime {
    return _session.currentTime;
}

- (double)duration {
    return _session.duration;
}

- (NSInteger)videoWidth {
    return _session.videoWidth;
}

- (NSInteger)videoHeight {
    return _session.videoHeight;
}

- (BOOL)isPlaying {
    return _session.isPlaying;
}

- (NSUInteger)nativeSessionOpenCount {
    return _nativeSessionOpenCount;
}

- (NSUInteger)nativeInSessionSeekCount {
    return _nativeInSessionSeekCount;
}

- (NSUInteger)nativePresentationGeneration {
    @synchronized (self) {
        return _nativePresentationGeneration;
    }
}

- (NSUInteger)nativeDisplayImageRemovalCount {
    return _nativeView.displayImageRemovalCount;
}

- (NSUInteger)nativePresentedVideoFrameCount {
    return _session.presentedVideoFrameCount;
}

- (NSInteger)nativeLastSubmittedVideoFrameMilliseconds {
    return _session.lastSubmittedVideoFrameMilliseconds;
}

- (SFXNativePlaybackFrameSnapshot *)latestSubmittedVideoFrameSnapshot {
    @synchronized (self) {
        if (_latestSubmittedVideoFrameSnapshot == nil && _latestSubmittedPixelBuffer != NULL) {
            _latestSubmittedVideoFrameSnapshot = [[SFXNativePlaybackFrameSnapshot alloc]
                initWithPixelBuffer:_latestSubmittedPixelBuffer];
        }
        return _latestSubmittedVideoFrameSnapshot;
    }
}

- (NSInteger)nativeLastScheduledAudioStartMilliseconds {
    return _session.lastScheduledAudioStartMilliseconds;
}

- (NSInteger)nativeLastScheduledAudioEndMilliseconds {
    return _session.lastScheduledAudioEndMilliseconds;
}

- (NSUInteger)nativeSegmentFinishNotificationCount {
    return _session.segmentFinishNotificationCount;
}

- (NSInteger)nativeLastFinishedSegmentEndMilliseconds {
    return _session.lastFinishedSegmentEndMilliseconds;
}

- (NSUInteger)nativeRebufferCount {
    return _session.rebufferCount;
}

- (NSInteger)nativeLastRebufferDurationMilliseconds {
    return _session.lastRebufferDurationMilliseconds;
}

- (BOOL)nativeLastRebufferStartedWhileWaitingForPacket {
    return _session.lastRebufferStartedWhileWaitingForPacket;
}

- (NSUInteger)nativeAudioPlayedBackBufferCount {
    return _session.audioPlayedBackBufferCount;
}

- (NSUInteger)nativeUnexpectedAudioDrainCount {
    return _session.unexpectedAudioDrainCount;
}

- (NSUInteger)nativeSegmentAudioDrainCount {
    return _session.segmentAudioDrainCount;
}

- (NSUInteger)nativeAudioOutputRecoveryCount {
    return _session.audioOutputRecoveryCount;
}

- (BOOL)nativeAudioOutputDrained {
    return _session.audioOutputDrained;
}

- (float)volume {
    return _volume;
}

- (float)playbackRate {
    return _playbackRate;
}

- (SFXNativePlaybackDecodeMode)decodeMode {
    return _decodeMode;
}

- (SFXNativePlaybackDecodeMode)activeDecodeMode {
    SFXNativePlaybackSession *session = _session;
    return session != nil ? session.decodeMode : _decodeMode;
}

- (NSInteger)audioTrackIndex {
    return _audioTrackIndex;
}

- (void)setAudioTrackIndex:(NSInteger)audioTrackIndex {
    _audioTrackIndex = MAX(0, audioTrackIndex);
}

- (NSInteger)currentAudioTrackIndex {
    SFXNativePlaybackSession *session = _session;
    return session != nil ? session.audioTrackIndex : -1;
}

- (void)setVolume:(float)volume {
    _volume = fmaxf(0.0, fminf(volume, 1.0));
    [_session setVolume:_volume];
}

- (void)setPlaybackRate:(float)playbackRate {
    _playbackRate = SFXClampedPlaybackRate(playbackRate);
    [_session setPlaybackRate:_playbackRate];
}

- (BOOL)usingHardwareDecode {
    SFXNativePlaybackSession *session = _session;
    return session != nil ? session.usingHardwareDecode : NO;
}

- (void)setDecodeMode:(SFXNativePlaybackDecodeMode)decodeMode {
    SFXNativePlaybackDecodeMode previous = _decodeMode;
    switch (decodeMode) {
    case SFXNativePlaybackDecodeModeHardware:
    case SFXNativePlaybackDecodeModeSoftware:
    case SFXNativePlaybackDecodeModeAuto:
        _decodeMode = decodeMode;
        break;
    default:
        _decodeMode = SFXNativePlaybackDecodeModeAuto;
        break;
    }
    NSLog(@"[Playback] SFXNativePlaybackPlayer.setDecodeMode: %ld -> %ld", (long)previous, (long)_decodeMode);
}

- (NSUInteger)beginPresentationTransition {
    @synchronized (self) {
        _nativePresentationGeneration += 1;
        _currentPresentationGeneration = _nativePresentationGeneration;
        return _nativePresentationGeneration;
    }
}

- (void)restoreCurrentPresentationGeneration:(NSUInteger)previousGeneration
                    ifCurrentGenerationIs:(NSUInteger)failedGeneration {
    @synchronized (self) {
        if (_currentPresentationGeneration == failedGeneration) {
            _currentPresentationGeneration = previousGeneration;
        }
    }
}

- (BOOL)isCurrentPresentationForSession:(SFXNativePlaybackSession *)session
                 presentationGeneration:(NSUInteger)presentationGeneration {
    @synchronized (self) {
        return _session == session
            && _currentPresentationGeneration == presentationGeneration;
    }
}

- (BOOL)enqueueSampleBuffer:(CMSampleBufferRef)sampleBuffer
                 forSession:(SFXNativePlaybackSession *)session
      presentationGeneration:(NSUInteger)presentationGeneration
          flushBeforeEnqueue:(BOOL)flushBeforeEnqueue {
    if (sampleBuffer == NULL) {
        return NO;
    }

    @synchronized (self) {
        if (_session != session
            || _currentPresentationGeneration != presentationGeneration) {
            return NO;
        }

        AVSampleBufferDisplayLayer *displayLayer = _nativeView.displayLayer;
        if (displayLayer == nil) {
            return NO;
        }
        if (flushBeforeEnqueue
            || displayLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
            [displayLayer flush];
        }
        [displayLayer enqueueSampleBuffer:sampleBuffer];
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        if (imageBuffer != NULL && imageBuffer != _latestSubmittedPixelBuffer) {
            CVPixelBufferRetain((CVPixelBufferRef)imageBuffer);
            if (_latestSubmittedPixelBuffer != NULL) {
                CVPixelBufferRelease(_latestSubmittedPixelBuffer);
            }
            _latestSubmittedPixelBuffer = (CVPixelBufferRef)imageBuffer;
            _latestSubmittedVideoFrameSnapshot = nil;
        }
        return YES;
    }
}

- (void)session:(SFXNativePlaybackSession *)session
didPresentVideoFrameAtMilliseconds:(NSInteger)milliseconds
presentationGeneration:(NSUInteger)presentationGeneration {
    id<SFXNativePlaybackPlayerDelegate> delegate = nil;
    @synchronized (self) {
        if (_session != session
            || _currentPresentationGeneration != presentationGeneration
            || _lastNotifiedVideoPresentationGeneration == presentationGeneration) {
            return;
        }
        _lastNotifiedVideoPresentationGeneration = presentationGeneration;
        delegate = self.delegate;
    }

    if ([delegate respondsToSelector:@selector(nativePlaybackPlayer:didPresentVideoFrameAtMilliseconds:presentationGeneration:)]) {
        [delegate nativePlaybackPlayer:self
            didPresentVideoFrameAtMilliseconds:milliseconds
            presentationGeneration:presentationGeneration];
    }
}

- (BOOL)openPath:(NSString *)path
startMilliseconds:(NSInteger)startMilliseconds
           error:(NSError **)error {
    return [self openPath:path
        startMilliseconds:startMilliseconds
          endMilliseconds:SFXNoSegmentEndMilliseconds
                    error:error];
}

- (BOOL)openPath:(NSString *)path
startMilliseconds:(NSInteger)startMilliseconds
 endMilliseconds:(NSInteger)endMilliseconds
           error:(NSError **)error {
    NSUInteger presentationGeneration = [self beginPresentationTransition];
    return [self openPath:path
        startMilliseconds:startMilliseconds
          endMilliseconds:endMilliseconds
       pausesAtSegmentEnd:NO
       presentationGeneration:presentationGeneration
       flushDisplayBeforeStart:NO
      pauseAfterFirstFrame:NO
 allowAutomaticSoftwareRecycle:!_didRecycleInitialSoftwareSession
                    error:error];
}

- (BOOL)openPath:(NSString *)path
startMilliseconds:(NSInteger)startMilliseconds
autoStopAtMilliseconds:(NSInteger)endMilliseconds
                  error:(NSError **)error {
    NSUInteger presentationGeneration = [self beginPresentationTransition];
    return [self openPath:path
        startMilliseconds:startMilliseconds
          endMilliseconds:endMilliseconds
       pausesAtSegmentEnd:YES
       presentationGeneration:presentationGeneration
       flushDisplayBeforeStart:NO
      pauseAfterFirstFrame:NO
 allowAutomaticSoftwareRecycle:!_didRecycleInitialSoftwareSession
                    error:error];
}

- (BOOL)openPath:(NSString *)path
startMilliseconds:(NSInteger)startMilliseconds
 endMilliseconds:(NSInteger)endMilliseconds
pausesAtSegmentEnd:(BOOL)pausesAtSegmentEnd
presentationGeneration:(NSUInteger)presentationGeneration
flushDisplayBeforeStart:(BOOL)flushDisplayBeforeStart
 pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
allowAutomaticSoftwareRecycle:(BOOL)allowAutomaticSoftwareRecycle
           error:(NSError **)error {
    CFTimeInterval openStart = CACurrentMediaTime();
    [self cancelTimelineScrubPreviewRequests];
    CFTimeInterval s2Start = CACurrentMediaTime();
    [self stopAndFlushDisplay:flushDisplayBeforeStart];
    double s2StopPrevMs = (CACurrentMediaTime() - s2Start) * 1000.0;

    SFXNativePlaybackSession *session = [[SFXNativePlaybackSession alloc]
        initWithPath:path
        startMilliseconds:startMilliseconds
        endMilliseconds:endMilliseconds
        pausesAtSegmentEnd:pausesAtSegmentEnd
        layer:_nativeView.displayLayer
        delegate:self.delegate
        owner:self
        volume:_volume
        playbackRate:_playbackRate
        decodeMode:_decodeMode
        audioTrackIndex:_audioTrackIndex
        presentationGeneration:presentationGeneration
        pauseAfterFirstFrame:pauseAfterFirstFrame
        allowAutomaticSoftwareRecycle:allowAutomaticSoftwareRecycle
        error:error
    ];
    if (session == nil) {
        return NO;
    }

    @synchronized (self) {
        _session = session;
        _currentPath = [path copy];
        _nativeSessionOpenCount += 1;
    }
    [session configurePerfOpenStart:openStart stopPrevMs:s2StopPrevMs];
    [_session start];
    return YES;
}

- (BOOL)seekToMilliseconds:(NSInteger)milliseconds error:(NSError **)error {
    return [self seekToMilliseconds:milliseconds
                   endMilliseconds:SFXNoSegmentEndMilliseconds
               pausesAtSegmentEnd:NO
                pauseAfterFirstFrame:NO
                               error:error];
}

- (BOOL)seekToMilliseconds:(NSInteger)milliseconds
      pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
                     error:(NSError **)error {
    return [self seekToMilliseconds:milliseconds
                     endMilliseconds:SFXNoSegmentEndMilliseconds
                 pausesAtSegmentEnd:NO
                pauseAfterFirstFrame:pauseAfterFirstFrame
                               error:error];
}

- (BOOL)seekToMilliseconds:(NSInteger)milliseconds
           endMilliseconds:(NSInteger)endMilliseconds
                     error:(NSError **)error {
    return [self seekToMilliseconds:milliseconds
                     endMilliseconds:endMilliseconds
                 pausesAtSegmentEnd:NO
                pauseAfterFirstFrame:NO
                               error:error];
}

- (BOOL)seekToMilliseconds:(NSInteger)milliseconds
    autoStopAtMilliseconds:(NSInteger)endMilliseconds
                     error:(NSError **)error {
    return [self seekToMilliseconds:milliseconds
             autoStopAtMilliseconds:endMilliseconds
                pauseAfterFirstFrame:NO
                               error:error];
}

- (BOOL)seekToMilliseconds:(NSInteger)milliseconds
    autoStopAtMilliseconds:(NSInteger)endMilliseconds
      pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
                     error:(NSError **)error {
    return [self seekToMilliseconds:milliseconds
                     endMilliseconds:endMilliseconds
                 pausesAtSegmentEnd:YES
                pauseAfterFirstFrame:pauseAfterFirstFrame
                               error:error];
}

- (BOOL)seekToMilliseconds:(NSInteger)milliseconds
           endMilliseconds:(NSInteger)endMilliseconds
      pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
                     error:(NSError **)error {
    return [self seekToMilliseconds:milliseconds
                     endMilliseconds:endMilliseconds
                 pausesAtSegmentEnd:NO
                pauseAfterFirstFrame:pauseAfterFirstFrame
                               error:error];
}

- (BOOL)seekToMilliseconds:(NSInteger)milliseconds
           endMilliseconds:(NSInteger)endMilliseconds
       pausesAtSegmentEnd:(BOOL)pausesAtSegmentEnd
      pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
                     error:(NSError **)error {
    if (_currentPath == nil) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(40, @"Native playback has no current file to seek.");
        }
        return NO;
    }

    if (_session == nil) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(42, @"Native playback has no active session to seek.");
        }
        return NO;
    }

    SFXNativePlaybackSession *session = _session;
    NSUInteger previousPresentationGeneration = session.presentationGeneration;
    [self cancelTimelineScrubPreviewRequests];
    NSUInteger presentationGeneration = [self beginPresentationTransition];
    if (session.isFinished) {
        return [self openPath:_currentPath
            startMilliseconds:milliseconds
              endMilliseconds:endMilliseconds
           pausesAtSegmentEnd:pausesAtSegmentEnd
           presentationGeneration:presentationGeneration
           flushDisplayBeforeStart:NO
          pauseAfterFirstFrame:pauseAfterFirstFrame
     allowAutomaticSoftwareRecycle:!_didRecycleInitialSoftwareSession
                        error:error];
    }

    if (![session seekToMilliseconds:milliseconds
                      endMilliseconds:endMilliseconds
                  pausesAtSegmentEnd:pausesAtSegmentEnd
             presentationGeneration:presentationGeneration
                 pauseAfterFirstFrame:pauseAfterFirstFrame
                                error:error]) {
        [self restoreCurrentPresentationGeneration:previousPresentationGeneration
                           ifCurrentGenerationIs:presentationGeneration];
        return NO;
    }

    @synchronized (self) {
        _nativeInSessionSeekCount += 1;
    }
    BOOL usingHW = session.usingHardwareDecode;
    NSLog(@"[Playback] Seek: path=%@, targetMs=%ld, activeSessionPipeline=%@",
          _currentPath, (long)milliseconds,
          usingHW ? @"Hardware (VideoToolbox)" : @"Software");
    return YES;
}

- (BOOL)setTimelineScrubbing:(BOOL)active error:(NSError **)error {
    if (_session == nil) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(42, @"Native playback has no active session for timeline scrubbing.");
        }
        return NO;
    }

    if (active) {
        _lastScrubPreviewFrameMilliseconds = -1;
        [_session setReadAheadSuspended:YES];
        [_session setPaused:YES];
    } else {
        [self cancelTimelineScrubPreviewRequests];
        [_session setReadAheadSuspended:NO];
    }
    return YES;
}

- (void)requestTimelineScrubPreviewAtMilliseconds:(NSInteger)milliseconds {
    NSString *path = nil;
    NSString *httpHeaders = nil;
    AVSampleBufferDisplayLayer *displayLayer = nil;
    NSUInteger generation = 0;
    @synchronized (self) {
        if (_currentPath == nil) {
            return;
        }
        _scrubPreviewGeneration += 1;
        generation = _scrubPreviewGeneration;
        path = [_currentPath copy];
        httpHeaders = [_httpHeaders copy];
        displayLayer = _nativeView.displayLayer;
    }

    NSInteger targetMilliseconds = MAX(0, milliseconds);
    dispatch_async(_scrubPreviewQueue, ^{
        @autoreleasepool {
            @synchronized (self) {
                if (generation != _scrubPreviewGeneration
                    || _currentPath == nil
                    || ![_currentPath isEqualToString:path]) {
                    return;
                }
            }

            CMTime presentationTime = CMTimeMake(targetMilliseconds, 1000);
            NSInteger frameMilliseconds = -1;
            CVPixelBufferRef pixelBuffer = SFXCopyBGRAKeyframePreviewPixelBuffer(
                path,
                httpHeaders,
                targetMilliseconds,
                &presentationTime,
                &frameMilliseconds
            );
            if (pixelBuffer == NULL) {
                return;
            }

            @synchronized (self) {
                if (generation != _scrubPreviewGeneration
                    || _currentPath == nil
                    || ![_currentPath isEqualToString:path]) {
                    CVPixelBufferRelease(pixelBuffer);
                    return;
                }

                if (frameMilliseconds >= 0 && frameMilliseconds == _lastScrubPreviewFrameMilliseconds) {
                    CVPixelBufferRelease(pixelBuffer);
                    return;
                }
                _lastScrubPreviewFrameMilliseconds = frameMilliseconds;
            }

            CVPixelBufferRetain(pixelBuffer);
            dispatch_async(dispatch_get_main_queue(), ^{
                @synchronized (self) {
                    if (generation != _scrubPreviewGeneration
                        || _currentPath == nil
                        || ![_currentPath isEqualToString:path]) {
                        CVPixelBufferRelease(pixelBuffer);
                        return;
                    }
                }

                CMSampleBufferRef sampleBuffer = SFXSampleBufferForPixelBuffer(
                    pixelBuffer,
                    presentationTime
                );
                if (sampleBuffer != NULL) {
                    [displayLayer flush];
                    [displayLayer enqueueSampleBuffer:sampleBuffer];
                    CFRelease(sampleBuffer);
                }
                CVPixelBufferRelease(pixelBuffer);
            });
            CVPixelBufferRelease(pixelBuffer);
        }
    });
}

- (void)cancelTimelineScrubPreviewRequests {
    @synchronized (self) {
        _scrubPreviewGeneration += 1;
        _lastScrubPreviewFrameMilliseconds = -1;
    }
}

- (void)requestAutomaticSoftwareRecycleForSession:(SFXNativePlaybackSession *)session
                                   atMilliseconds:(NSInteger)milliseconds
                           presentationGeneration:(NSUInteger)presentationGeneration {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![self isCurrentPresentationForSession:session
                            presentationGeneration:presentationGeneration]
            || _currentPath == nil
            || _didRecycleInitialSoftwareSession) {
            return;
        }

        _didRecycleInitialSoftwareSession = YES;
        NSString *path = [_currentPath copy];
        NSError *error = nil;
	        BOOL opened = [self openPath:path
	            startMilliseconds:MAX(0, milliseconds)
	              endMilliseconds:session.segmentEndMilliseconds
	           pausesAtSegmentEnd:session.pausesAtSegmentEnd
	           presentationGeneration:presentationGeneration
	           flushDisplayBeforeStart:NO
	          pauseAfterFirstFrame:NO
     allowAutomaticSoftwareRecycle:NO
                         error:&error];
        if (!opened) {
            NSString *message = error.localizedDescription ?: @"Automatic software playback recycle failed.";
            [self.delegate nativePlaybackPlayer:self didFailWithMessage:message];
        }
    });
}

- (void)requestAudioOutputRecoveryForSession:(SFXNativePlaybackSession *)session {
    BOOL shouldSchedule = NO;
    @synchronized (self) {
        if (_session != session) {
            return;
        }
        _audioOutputRecoveryRequested = YES;
        if (!_audioOutputRecoveryScheduled) {
            _audioOutputRecoveryScheduled = YES;
            shouldSchedule = YES;
        }
    }

    if (shouldSchedule) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performPendingAudioOutputRecovery];
        });
    }
}

- (void)performPendingAudioOutputRecovery {
    SFXNativePlaybackSession *session = nil;
    @synchronized (self) {
        if (!_audioOutputRecoveryScheduled || !_audioOutputRecoveryRequested || _session == nil) {
            _audioOutputRecoveryScheduled = NO;
            return;
        }
        session = _session;
        _audioOutputRecoveryRequested = NO;
    }

    if (session.isFinished) {
        @synchronized (self) {
            if (_session == session) {
                _audioOutputRecoveryScheduled = NO;
            }
        }
        return;
    }

    NSError *error = nil;
    BOOL recovered = [session recoverAudioOutputWithError:&error];

    BOOL shouldRepeat = NO;
    BOOL shouldReportFailure = NO;
    @synchronized (self) {
        if (_session != session) {
            _audioOutputRecoveryScheduled = NO;
            _audioOutputRecoveryRequested = NO;
            return;
        }
        shouldRepeat = _audioOutputRecoveryRequested;
        _audioOutputRecoveryScheduled = shouldRepeat;
        shouldReportFailure = !recovered && !shouldRepeat;
    }

    if (shouldRepeat) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performPendingAudioOutputRecovery];
        });
    } else if (shouldReportFailure) {
        NSString *message = error.localizedDescription ?: @"Audio output recovery failed.";
        [self.delegate nativePlaybackPlayer:self didFailWithMessage:message];
    }
}

- (void)requestAudioOutputRecoveryForTesting {
    SFXNativePlaybackSession *session = nil;
    @synchronized (self) {
        session = _session;
    }
    [session requestAudioOutputRecovery];
}

- (BOOL)setPaused:(BOOL)paused error:(NSError **)error {
    if (_session == nil) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(41, @"Native playback has no active session.");
        }
        return NO;
    }

    [_session setPaused:paused];
    return YES;
}

- (BOOL)selectAudioTrackIndex:(NSInteger)audioTrackIndex error:(NSError **)error {
    self.audioTrackIndex = audioTrackIndex;
    SFXNativePlaybackSession *session = _session;
    NSString *path = [_currentPath copy];
    if (session == nil || path == nil) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(43, @"Native playback has no current file to switch audio tracks.");
        }
        return NO;
    }

    // The session is reopened where it stands, as the automatic software
    // recycle does, under the same presentation so nothing above sees a new
    // one. A finished session stays paused rather than finishing again.
    NSInteger milliseconds = MAX(0, (NSInteger)llround(session.currentTime * 1000.0));
    return [self openPath:path
        startMilliseconds:milliseconds
          endMilliseconds:session.segmentEndMilliseconds
       pausesAtSegmentEnd:session.pausesAtSegmentEnd
       presentationGeneration:session.presentationGeneration
       flushDisplayBeforeStart:NO
      pauseAfterFirstFrame:session.isPaused || session.isFinished
 allowAutomaticSoftwareRecycle:!_didRecycleInitialSoftwareSession
                    error:error];
}

- (void)stop {
    [self beginPresentationTransition];
    [self stopAndFlushDisplay:YES];
}

- (void)stopAndFlushDisplay:(BOOL)flushDisplay {
    [self cancelTimelineScrubPreviewRequests];
    [_session stopAndWait];
    @synchronized (self) {
        _session = nil;
        _currentPath = nil;
        _audioOutputRecoveryScheduled = NO;
        _audioOutputRecoveryRequested = NO;
        if (flushDisplay) {
            if (_latestSubmittedPixelBuffer != NULL) {
                CVPixelBufferRelease(_latestSubmittedPixelBuffer);
                _latestSubmittedPixelBuffer = NULL;
            }
            _latestSubmittedVideoFrameSnapshot = nil;
        }
    }
    if (flushDisplay) {
        [_nativeView flush];
    }
}

@end
