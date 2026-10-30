#import "SFXNativePlaybackInternal.h"

static int SFXFFmpegInterruptCallback(void *opaque) {
    if (opaque == NULL) {
        return 0;
    }
    SFXNativePlaybackSession *session = (__bridge SFXNativePlaybackSession *)opaque;
    return [session isCancelledForIOInterrupt] ? 1 : 0;
}

@implementation SFXNativePlaybackSession

- (instancetype)initWithPath:(NSString *)path
	           startMilliseconds:(NSInteger)startMilliseconds
	             endMilliseconds:(NSInteger)endMilliseconds
	       pausesAtSegmentEnd:(BOOL)pausesAtSegmentEnd
	                       layer:(AVSampleBufferDisplayLayer *)displayLayer
	                    delegate:(id<SFXNativePlaybackPlayerDelegate>)delegate
	                      owner:(SFXNativePlaybackPlayer *)owner
	                      volume:(float)volume
	                playbackRate:(float)playbackRate
	                  decodeMode:(SFXNativePlaybackDecodeMode)decodeMode
	             audioTrackIndex:(NSInteger)audioTrackIndex
	      presentationGeneration:(NSUInteger)presentationGeneration
	         pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
 allowAutomaticSoftwareRecycle:(BOOL)allowAutomaticSoftwareRecycle
                       error:(NSError **)error {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    _path = [path copy];
    _displayLayer = displayLayer;
    _delegate = delegate;
    _owner = owner;
    _volume = volume;
    atomic_init(&_playbackRate, SFXClampedPlaybackRate(playbackRate));
    _decodeMode = decodeMode;
    _presentationGeneration = presentationGeneration;
    atomic_init(&_pauseAfterFirstFrame, pauseAfterFirstFrame);
    atomic_init(&_didPauseAfterFirstFrame, false);
	    _allowAutomaticSoftwareRecycle = allowAutomaticSoftwareRecycle;
	    _seekSeconds = MAX(0, (double)startMilliseconds / 1000.0);
	    NSInteger safeEndMilliseconds = SFXSanitizedSegmentEndMilliseconds(startMilliseconds, endMilliseconds);
	    _segmentEndSeconds = safeEndMilliseconds >= 0 ? (double)safeEndMilliseconds / 1000.0 : -1;
	    _pausesAtSegmentEnd = pausesAtSegmentEnd && safeEndMilliseconds >= 0;
	    _autoPauseAuthorizationResolved = NO;
	    _autoPauseAuthorized = NO;
	    _currentTime = _seekSeconds;
    _videoStreamIndex = -1;
    _audioStreamIndex = -1;
    _requestedAudioTrackIndex = audioTrackIndex;
    _audioTrackIndex = -1;
    _videoOrientation = SFXVideoOrientationUp;
    _decodeQueue = dispatch_queue_create("CueSeeker.NativePlayback.Decode", DISPATCH_QUEUE_SERIAL);
    _demuxQueue = dispatch_queue_create("CueSeeker.NativePlayback.Demux", DISPATCH_QUEUE_SERIAL);
    _audioDecodeQueue = dispatch_queue_create("CueSeeker.NativePlayback.AudioDecode", DISPATCH_QUEUE_SERIAL);
    _starvationQueue = dispatch_queue_create("CueSeeker.NativePlayback.Starvation", DISPATCH_QUEUE_SERIAL);
    _displaySubmissionLock = [[NSLock alloc] init];
    _pendingDisplayPresentationTime = kCMTimeInvalid;
    _pendingDisplayAutomaticRecycleMilliseconds = -1;
    _pendingDisplayFrameMilliseconds = -1;
    _lastSubmittedVideoFrameMilliseconds = -1;
    _lastScheduledAudioStartMilliseconds = -1;
    _lastScheduledAudioEndMilliseconds = -1;
    _lastFinishedSegmentEndMilliseconds = -1;
    _lastRebufferDurationMilliseconds = -1;
    _audioFirstScheduledMediaSeconds = -1;
    _pendingCoalescedAudioStartMediaSeconds = -1;
    _playbackGeneration = 1;
    _audioOutputDrained = YES;
    _packetQueueCondition = [[NSCondition alloc] init];
    _pacingCondition = [[NSCondition alloc] init];
    atomic_init(&_segmentAudioBoundaryReached, false);
    atomic_init(&_segmentVideoBoundaryReached, false);
    _segmentWaitingForAudioCompletion = NO;
    _segmentAudioPlaybackCompleted = NO;
	    atomic_init(&_cancelled, false);
	    atomic_init(&_segmentEnding, false);
	    atomic_init(&_finishingForAutomaticRecycle, false);
    atomic_init(&_decodeLoopFinished, false);
    atomic_init(&_decodeWaitingForPacket, false);
    atomic_init(&_paused, false);
    atomic_init(&_playing, false);

    if (!SFXIsHTTPMediaPath(_path.UTF8String)) {
        if (![self prepareWithError:error]) {
            [self teardown];
            return nil;
        }
    }

    return self;
}

- (NSString *)path {
    return _path;
}

- (double)currentTime {
    @synchronized (self) {
        return _currentTime;
    }
}

- (double)duration {
    return _duration;
}

- (void)getDisplayVideoWidth:(NSInteger *)widthOut height:(NSInteger *)heightOut {
    int storageWidth = 0;
    int storageHeight = 0;
    AVRational sar = (AVRational){1, 1};
    SFXVideoOrientation orientation = SFXVideoOrientationUp;
    @synchronized (self) {
        storageWidth = _videoFrameWidth;
        storageHeight = _videoFrameHeight;
        sar = _videoSampleAspectRatio;
        orientation = _videoOrientation;
    }
    NSInteger unrotatedWidth = SFXDisplayVideoWidthForDimensionsAndSAR(storageWidth, storageHeight, sar);
    NSInteger unrotatedHeight = storageHeight > 0 ? storageHeight : 0;
    BOOL swaps = SFXVideoOrientationSwapsDimensions(orientation);
    if (widthOut != NULL) {
        *widthOut = swaps ? unrotatedHeight : unrotatedWidth;
    }
    if (heightOut != NULL) {
        *heightOut = swaps ? unrotatedWidth : unrotatedHeight;
    }
}

- (NSInteger)videoWidth {
    NSInteger width = 0;
    [self getDisplayVideoWidth:&width height:NULL];
    return width;
}

- (NSInteger)videoHeight {
    NSInteger height = 0;
    [self getDisplayVideoWidth:NULL height:&height];
    return height;
}

- (SFXVideoOrientation)videoOrientation {
    @synchronized (self) {
        return _videoOrientation;
    }
}

- (BOOL)isPlaying {
    if (atomic_load(&_pauseAfterFirstFrame) && !atomic_load(&_didPauseAfterFirstFrame)) {
        return NO;
    }
    return atomic_load(&_playing);
}

- (NSUInteger)presentationGeneration {
    [_packetQueueCondition lock];
    NSUInteger generation = _presentationGeneration;
    [_packetQueueCondition unlock];
    return generation;
}

- (NSUInteger)presentedVideoFrameCount {
    @synchronized (self) {
        return _presentedVideoFrameCount;
    }
}

- (NSInteger)lastSubmittedVideoFrameMilliseconds {
    @synchronized (self) {
        return _lastSubmittedVideoFrameMilliseconds;
    }
}

- (NSInteger)lastScheduledAudioStartMilliseconds {
    @synchronized (self) {
        return _lastScheduledAudioStartMilliseconds;
    }
}

- (NSInteger)lastScheduledAudioEndMilliseconds {
    @synchronized (self) {
        return _lastScheduledAudioEndMilliseconds;
    }
}

- (NSUInteger)segmentFinishNotificationCount {
    @synchronized (self) {
        return _segmentFinishNotificationCount;
    }
}

- (NSInteger)lastFinishedSegmentEndMilliseconds {
    @synchronized (self) {
        return _lastFinishedSegmentEndMilliseconds;
    }
}

- (NSUInteger)rebufferCount {
    @synchronized (self) {
        return _rebufferCount;
    }
}

- (NSInteger)lastRebufferDurationMilliseconds {
    @synchronized (self) {
        return _lastRebufferDurationMilliseconds;
    }
}

- (BOOL)lastRebufferStartedWhileWaitingForPacket {
    @synchronized (self) {
        return _lastRebufferStartedWhileWaitingForPacket;
    }
}

- (NSUInteger)audioPlayedBackBufferCount {
    @synchronized (self) {
        return _audioPlayedBackBufferCount;
    }
}

- (NSUInteger)unexpectedAudioDrainCount {
    @synchronized (self) {
        return _unexpectedAudioDrainCount;
    }
}

- (NSUInteger)segmentAudioDrainCount {
    @synchronized (self) {
        return _segmentAudioDrainCount;
    }
}

- (NSUInteger)audioOutputRecoveryCount {
    @synchronized (self) {
        return _audioOutputRecoveryCount;
    }
}

- (BOOL)audioOutputDrained {
    [_packetQueueCondition lock];
    BOOL drained = _audioOutputDrained;
    [_packetQueueCondition unlock];
    return drained;
}

- (BOOL)isFinished {
    return atomic_load(&_decodeLoopFinished);
}

- (BOOL)isPaused {
    return atomic_load(&_paused)
        || (atomic_load(&_pauseAfterFirstFrame) && !atomic_load(&_didPauseAfterFirstFrame));
}

- (NSInteger)audioTrackIndex {
    return _audioTrackIndex;
}

- (SFXNativePlaybackDecodeMode)decodeMode {
    return _decodeMode;
}

- (BOOL)usingHardwareDecode {
    @synchronized (self) {
        return _usingHardwareDecode;
    }
}

- (BOOL)hasActiveSegmentEnd {
    return isfinite(_segmentEndSeconds) && _segmentEndSeconds >= 0;
}

- (BOOL)mediaSecondsReachedSegmentEnd:(double)mediaSeconds {
    return [self hasActiveSegmentEnd]
        && mediaSeconds >= 0
        && mediaSeconds + SFXSegmentBoundaryEpsilonSeconds >= _segmentEndSeconds;
}

- (NSInteger)segmentEndMilliseconds {
    if (![self hasActiveSegmentEnd]) {
        return SFXNoSegmentEndMilliseconds;
    }
    return (NSInteger)llround(_segmentEndSeconds * 1000.0);
}

- (BOOL)pausesAtSegmentEnd {
    @synchronized (self) {
        return _pausesAtSegmentEnd;
    }
}

- (BOOL)resolveAutoPauseAuthorizationIfNeeded {
    BOOL rejectedAutoPause = NO;
    BOOL authorized = YES;
    @synchronized (self) {
        if (!_pausesAtSegmentEnd) {
            return YES;
        }
        if (_autoPauseAuthorizationResolved) {
            return _autoPauseAuthorized;
        }

        id<SFXNativePlaybackPlayerDelegate> delegate = _delegate;
        SFXNativePlaybackPlayer *owner = _owner;
        NSInteger endMilliseconds = [self segmentEndMilliseconds];
        if (delegate != nil
            && owner != nil
            && [delegate respondsToSelector:@selector(nativePlaybackPlayer:shouldPauseAtAutoStopBoundaryAtMilliseconds:presentationGeneration:)]) {
            authorized = [delegate nativePlaybackPlayer:owner
                shouldPauseAtAutoStopBoundaryAtMilliseconds:endMilliseconds
                presentationGeneration:_presentationGeneration];
        }
        _autoPauseAuthorizationResolved = YES;
        _autoPauseAuthorized = authorized;
        if (!authorized) {
            _segmentEndSeconds = -1;
            _pausesAtSegmentEnd = NO;
            _segmentWaitingForAudioCompletion = NO;
            _segmentAudioPlaybackCompleted = NO;
            atomic_store(&_segmentAudioBoundaryReached, false);
            atomic_store(&_segmentVideoBoundaryReached, false);
            rejectedAutoPause = YES;
        }
    }

    if (rejectedAutoPause) {
        [_packetQueueCondition lock];
        [_packetQueueCondition broadcast];
        [_packetQueueCondition unlock];
        [self requestAudioDrain];
    }
    return authorized;
}

- (void)signalPacingCondition {
    [_pacingCondition lock];
    [_pacingCondition broadcast];
    [_pacingCondition unlock];
}

- (BOOL)segmentAudioBoundarySatisfiedLocked {
    return atomic_load(&_segmentAudioBoundaryReached)
        || _audioCodecContext == NULL
        || atomic_load(&_pauseAfterFirstFrame);
}

- (BOOL)segmentVideoBoundarySatisfiedLocked {
    return atomic_load(&_segmentVideoBoundaryReached) || _videoCodecContext == NULL;
}

- (BOOL)segmentAudioBoundaryReached {
    return atomic_load(&_segmentAudioBoundaryReached);
}

- (BOOL)segmentVideoBoundaryReached {
    return atomic_load(&_segmentVideoBoundaryReached);
}

- (BOOL)isSegmentBoundaryDrainInProgress {
    return atomic_load(&_segmentAudioBoundaryReached)
        || atomic_load(&_segmentVideoBoundaryReached);
}

- (void)markSegmentAudioBoundaryReached {
    if (![self hasActiveSegmentEnd]
        || atomic_load(&_cancelled)
        || ![self resolveAutoPauseAuthorizationIfNeeded]) {
        return;
    }

    @synchronized (self) {
        if (atomic_load(&_segmentAudioBoundaryReached)) {
            return;
        }
        _segmentWaitingForAudioCompletion = YES;
        _segmentAudioPlaybackCompleted = NO;
        atomic_store(&_segmentAudioBoundaryReached, true);
    }

    [_packetQueueCondition lock];
    BOOL hasOutstandingAudio = _outstandingAudioBufferCount > 0;
    [self clearAudioPacketQueueLocked];
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];

    if (!hasOutstandingAudio) {
        [self markSegmentAudioDrainCompleted];
        return;
    }
    [self finishSegmentBoundaryIfReadySchedulingClockNotification:NO];
}

- (void)markSegmentVideoBoundaryReached {
    if (![self hasActiveSegmentEnd]
        || atomic_load(&_cancelled)
        || ![self resolveAutoPauseAuthorizationIfNeeded]) {
        return;
    }

    @synchronized (self) {
        if (atomic_load(&_segmentVideoBoundaryReached)) {
            return;
        }
        atomic_store(&_segmentVideoBoundaryReached, true);
    }

    [_packetQueueCondition lock];
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];
    [self finishSegmentBoundaryIfReadySchedulingClockNotification:YES];
}

- (void)markSegmentAudioDrainCompleted {
    @synchronized (self) {
        if (_segmentWaitingForAudioCompletion && !_segmentAudioPlaybackCompleted) {
            _segmentAudioDrainCount += 1;
        }
        _segmentAudioPlaybackCompleted = YES;
        _segmentWaitingForAudioCompletion = NO;
    }

    [_packetQueueCondition lock];
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];
    [self finishSegmentBoundaryIfReadySchedulingClockNotification:NO];
}

- (void)resetSegmentBoundaryState {
    @synchronized (self) {
        _segmentWaitingForAudioCompletion = NO;
        _segmentAudioPlaybackCompleted = NO;
        atomic_store(&_segmentAudioBoundaryReached, false);
        atomic_store(&_segmentVideoBoundaryReached, false);
    }

    [_packetQueueCondition lock];
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];
}

- (void)finishSegmentBoundaryIfReadySchedulingClockNotification:(BOOL)scheduleClockNotification {
    if (![self hasActiveSegmentEnd] || atomic_load(&_cancelled)) {
        return;
    }

    BOOL shouldNotify = NO;
    BOOL pausesAtSegmentEnd = NO;
    @synchronized (self) {
        if (_segmentEndReached || _segmentFinishNotified) {
            return;
        }
        if (![self segmentAudioBoundarySatisfiedLocked]
            || ![self segmentVideoBoundarySatisfiedLocked]
            || (_segmentWaitingForAudioCompletion && !_segmentAudioPlaybackCompleted)) {
            return;
        }

        pausesAtSegmentEnd = _pausesAtSegmentEnd;
        _segmentEndReached = YES;
        _currentTime = _segmentEndSeconds;
        shouldNotify = YES;
    }

    if (pausesAtSegmentEnd) {
        double now = CACurrentMediaTime();
        @synchronized (self) {
            _isPausedInsideLoop = YES;
            _pauseStartedHostSeconds = now;
        }
        atomic_store(&_paused, true);
    } else {
        atomic_store(&_segmentEnding, true);
    }
    atomic_store(&_playing, false);
    [_packetQueueCondition lock];
    if (pausesAtSegmentEnd) {
        _readAheadSuspended = YES;
    }
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];
    [self signalPacingCondition];

    if (!shouldNotify) {
        return;
    }

    if (scheduleClockNotification) {
        [self notifySegmentFinishedAfterMediaClockDelay];
    } else {
        [self notifySegmentFinishedIfNeeded];
    }
}

- (void)waitForSegmentAudioDrainIfNeeded {
    if (![self hasActiveSegmentEnd]) {
        return;
    }
    [_packetQueueCondition lock];
    while (!atomic_load(&_cancelled)
           && !atomic_load(&_finishingForAutomaticRecycle)) {
        BOOL shouldWait = NO;
        @synchronized (self) {
            shouldWait = ![self segmentAudioBoundarySatisfiedLocked]
                || (_segmentWaitingForAudioCompletion && !_segmentAudioPlaybackCompleted);
        }
        if (!shouldWait) {
            break;
        }
        [_packetQueueCondition wait];
    }
    [_packetQueueCondition unlock];
}

- (void)waitForNaturalAudioDrainIfNeeded {
    if (_audioCodecContext == NULL || [self hasActiveSegmentEnd]) {
        return;
    }

    [_packetQueueCondition lock];
    while (!atomic_load(&_cancelled)
           && !atomic_load(&_finishingForAutomaticRecycle)
           && _packetQueueEOF
           && (!_audioInputEnded || !_audioOutputDrained)) {
        [_packetQueueCondition wait];
    }
    [_packetQueueCondition unlock];
}

- (void)waitForSegmentFinishNotificationIfNeeded {
    if (![self hasActiveSegmentEnd]) {
        return;
    }

    [_packetQueueCondition lock];
    while (!atomic_load(&_cancelled)
           && !atomic_load(&_finishingForAutomaticRecycle)) {
        BOOL shouldWait = NO;
        @synchronized (self) {
            shouldWait = _segmentEndReached && !_segmentFinishNotified;
        }
        if (!shouldWait) {
            break;
        }
        [_packetQueueCondition wait];
    }
    [_packetQueueCondition unlock];
}

- (void)startAudioForDrainAfterVideoDecodeIfNeeded {
    if (_audioCodecContext == NULL
        || atomic_load(&_cancelled)
        || atomic_load(&_finishingForAutomaticRecycle)) {
        return;
    }

    [_packetQueueCondition lock];
    NSUInteger generation = _playbackGeneration;
    [_packetQueueCondition unlock];
    if (![self waitForAudioPrimeForGeneration:generation]) {
        return;
    }

    @synchronized (self) {
        if (!_audioClockInitialized) {
            _audioClockInitialized = YES;
            _audioFirstMediaSeconds = _seekSeconds;
            _audioStartHostSeconds = CACurrentMediaTime();
        }
    }
    [self requestAudioPlaybackStartIfReadyForGeneration:generation];
}

- (void)notifySegmentFinishedAfterMediaClockDelay {
    double delaySeconds = 0;
    @synchronized (self) {
        double rate = fmax((double)atomic_load(&_playbackRate), 0.001);
        double targetHostSeconds = 0;
        if (_audioClockInitialized) {
            targetHostSeconds = _audioStartHostSeconds + ((_segmentEndSeconds - _audioFirstMediaSeconds) / rate);
        } else if (_videoClockInitialized) {
            targetHostSeconds = _videoStartHostSeconds + ((_segmentEndSeconds - _videoFirstMediaSeconds) / rate);
        }
        if (targetHostSeconds > 0) {
            delaySeconds = fmax(0, targetHostSeconds - CACurrentMediaTime());
        }
    }

    [_packetQueueCondition lock];
    NSUInteger generation = _playbackGeneration;
    [_packetQueueCondition unlock];
    int64_t delayNanoseconds = (int64_t)llround(delaySeconds * (double)NSEC_PER_SEC);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delayNanoseconds), dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [_packetQueueCondition lock];
        BOOL generationIsCurrent = generation == _playbackGeneration && !_audioResetInProgress;
        [_packetQueueCondition unlock];
        if (!generationIsCurrent) {
            return;
        }
        [self notifySegmentFinishedIfNeeded];
    });
}

- (void)notifySegmentFinishedIfNeeded {
    if (atomic_load(&_cancelled) || ![self hasActiveSegmentEnd]) {
        return;
    }

    NSInteger endMilliseconds = SFXNoSegmentEndMilliseconds;
    BOOL pausesAtSegmentEnd = NO;
    @synchronized (self) {
        if (!_segmentEndReached || _segmentFinishNotified) {
            return;
        }
        _segmentFinishNotified = YES;
        _currentTime = _segmentEndSeconds;
        endMilliseconds = [self segmentEndMilliseconds];
        pausesAtSegmentEnd = _pausesAtSegmentEnd;
        _segmentFinishNotificationCount += 1;
        _lastFinishedSegmentEndMilliseconds = endMilliseconds;
    }

    atomic_store(&_playing, false);
    atomic_store(&_paused, true);
    [_packetQueueCondition lock];
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];
    [self signalPacingCondition];
    [self notifyTimeIfNeeded:YES];

    id<SFXNativePlaybackPlayerDelegate> delegate = _delegate;
    SFXNativePlaybackPlayer *owner = _owner;
    if (delegate == nil || owner == nil) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (pausesAtSegmentEnd
            && [delegate respondsToSelector:@selector(nativePlaybackPlayer:didReachAutoStopBoundaryAtMilliseconds:)]) {
            [delegate nativePlaybackPlayer:owner didReachAutoStopBoundaryAtMilliseconds:endMilliseconds];
        } else if (!pausesAtSegmentEnd
                   && [delegate respondsToSelector:@selector(nativePlaybackPlayer:didFinishSegmentAtMilliseconds:)]) {
            [delegate nativePlaybackPlayer:owner didFinishSegmentAtMilliseconds:endMilliseconds];
        }
    });
}

- (void)notifyPlaybackFinishedIfNeeded {
    if (atomic_load(&_cancelled)
        || atomic_load(&_finishingForAutomaticRecycle)
        || [self hasActiveSegmentEnd]) {
        atomic_store(&_playing, false);
        return;
    }

    @synchronized (self) {
        if (_playbackFinishNotified) {
            return;
        }
        _playbackFinishNotified = YES;
        if (isfinite(_duration) && _duration > 0) {
            _currentTime = fmax(_currentTime, _duration);
        }
    }
    atomic_store(&_playing, false);
    [self notifyTimeIfNeeded:YES];

    id<SFXNativePlaybackPlayerDelegate> delegate = _delegate;
    SFXNativePlaybackPlayer *owner = _owner;
    NSUInteger presentationGeneration = _presentationGeneration;
    if (delegate == nil || owner == nil) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (![owner isCurrentPresentationForSession:self
                             presentationGeneration:presentationGeneration]) {
            return;
        }
        if ([delegate respondsToSelector:@selector(nativePlaybackPlayerDidFinishPlayback:)]) {
            [delegate nativePlaybackPlayerDidFinishPlayback:owner];
        }
    });
}

- (BOOL)prepareWithError:(NSError **)error {
    if (atomic_load(&_cancelled)) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(10, @"Native playback session was cancelled before open.");
        }
        return NO;
    }
    if (_formatContext == NULL) {
        _formatContext = avformat_alloc_context();
        if (_formatContext != NULL) {
            _formatContext->interrupt_callback.callback = SFXFFmpegInterruptCallback;
            _formatContext->interrupt_callback.opaque = (__bridge void *)self;
        }
    }
    CFTimeInterval s3Start = CACurrentMediaTime();
    int result = SFXOpenMediaInput(&_formatContext, _path.UTF8String, _owner.httpHeaders);
    _perfAvformatOpenMs = (CACurrentMediaTime() - s3Start) * 1000.0;
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(10, [NSString stringWithFormat:@"avformat_open_input failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    CFTimeInterval s4Start = CACurrentMediaTime();
    result = avformat_find_stream_info(_formatContext, NULL);
    _perfFindStreamInfoMs = (CACurrentMediaTime() - s4Start) * 1000.0;
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(11, [NSString stringWithFormat:@"avformat_find_stream_info failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    if (_formatContext->duration != AV_NOPTS_VALUE) {
        _duration = (double)_formatContext->duration / AV_TIME_BASE;
    }
    _timelineOriginSeconds = SFXMediaTimelineOriginSeconds(_formatContext);

    // Audio tracks are counted among the audio streams alone, in file order,
    // the way Index lists them. A track the file does not have falls back to
    // the first.
    int firstAudioStreamIndex = -1;
    NSInteger audioTrackCount = 0;
    for (unsigned int index = 0; index < _formatContext->nb_streams; index++) {
        AVStream *stream = _formatContext->streams[index];
        if (_videoStreamIndex < 0 && stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            _videoStreamIndex = (int)index;
        } else if (stream->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            if (firstAudioStreamIndex < 0) {
                firstAudioStreamIndex = (int)index;
            }
            if (audioTrackCount == _requestedAudioTrackIndex) {
                _audioStreamIndex = (int)index;
                _audioTrackIndex = audioTrackCount;
            }
            audioTrackCount += 1;
        }
    }
    if (_audioStreamIndex < 0 && firstAudioStreamIndex >= 0) {
        _audioStreamIndex = firstAudioStreamIndex;
        _audioTrackIndex = 0;
    }

    if (_videoStreamIndex < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(12, @"No video stream found.");
        }
        return NO;
    }

    CFTimeInterval s5Start = CACurrentMediaTime();
    if (![self prepareVideoWithError:error]) {
        return NO;
    }

    if (_audioStreamIndex >= 0 && ![self prepareAudioWithError:error]) {
        return NO;
    }
    _perfInitCodecAudioMs = (CACurrentMediaTime() - s5Start) * 1000.0;
    _audioPrimed = _audioCodecContext == NULL;
    _audioOutputDrained = _audioCodecContext == NULL;

    _packet = av_packet_alloc();
    _videoFrame = av_frame_alloc();
    if (_packet == NULL || _videoFrame == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(13, @"Could not allocate native playback packet or frame.");
        }
        return NO;
    }

    [_packetQueueCondition lock];
    if (_seekRequestPending) {
        _seekSeconds = _pendingSeekSeconds;
        _segmentEndSeconds = _pendingSeekSegmentEndSeconds;
        _pausesAtSegmentEnd = _pendingSeekPausesAtSegmentEnd;
        _presentationGeneration = _pendingSeekPresentationGeneration;
        atomic_store(&_pauseAfterFirstFrame, _pendingSeekPauseAfterFirstFrame);
        atomic_store(&_didPauseAfterFirstFrame, false);
        @synchronized (self) {
            _currentTime = _seekSeconds;
        }
        _seekRequestPending = NO;
        _pendingSeekRebuildsAudioOutput = NO;
        _seekRequestSucceeded = YES;
        _seekRequestError = nil;
        _completedSeekRequestGeneration = _seekRequestGeneration;
        [_packetQueueCondition broadcast];
    }
    [_packetQueueCondition unlock];

    CFTimeInterval s6Start = CACurrentMediaTime();
    if (!SFXSeekToStartPosition(_formatContext, _videoStreamIndex, _seekSeconds, _timelineOriginSeconds, error)) {
        return NO;
    }
    [self populateKeyframeStreamTimestamps];

    avcodec_flush_buffers(_videoCodecContext);
    if (_audioCodecContext != NULL) {
        avcodec_flush_buffers(_audioCodecContext);
    }
    _perfInitialSeekMs = (CACurrentMediaTime() - s6Start) * 1000.0;

    return YES;
}

- (void)populateKeyframeStreamTimestamps {
    if (_keyframeStreamTimestamps != NULL) {
        free(_keyframeStreamTimestamps);
        _keyframeStreamTimestamps = NULL;
    }
    _keyframeStreamTimestampCount = 0;
    _videoStreamTimeBase = (AVRational){0, 1};

    if (_formatContext == NULL
        || _videoStreamIndex < 0
        || _videoStreamIndex >= (int)_formatContext->nb_streams) {
        return;
    }

    AVStream *videoStream = _formatContext->streams[_videoStreamIndex];
    if (videoStream == NULL || videoStream->time_base.num <= 0 || videoStream->time_base.den <= 0) {
        return;
    }
    _videoStreamTimeBase = videoStream->time_base;

    int entryCount = avformat_index_get_entries_count(videoStream);
    if (entryCount <= 0) {
        return;
    }

    int64_t *timestamps = calloc((size_t)entryCount, sizeof(int64_t));
    if (timestamps == NULL) {
        return;
    }

    NSUInteger count = 0;
    for (int index = 0; index < entryCount; index++) {
        const AVIndexEntry *entry = avformat_index_get_entry(videoStream, index);
        if (entry == NULL
            || (entry->flags & AVINDEX_KEYFRAME) == 0
            || entry->timestamp == AV_NOPTS_VALUE) {
            continue;
        }
        if (count > 0 && entry->timestamp <= timestamps[count - 1]) {
            continue;
        }
        timestamps[count] = entry->timestamp;
        count += 1;
    }

    if (count == 0) {
        free(timestamps);
        return;
    }

    _keyframeStreamTimestamps = timestamps;
    _keyframeStreamTimestampCount = count;
}

- (NSInteger)keyframeTimestampMillisecondsForTargetMilliseconds:(NSInteger)milliseconds {
    if (_keyframeStreamTimestamps == NULL
        || _keyframeStreamTimestampCount == 0
        || _videoStreamTimeBase.num <= 0
        || _videoStreamTimeBase.den <= 0) {
        return -1;
    }

    double timeBaseSeconds = av_q2d(_videoStreamTimeBase);
    if (!isfinite(timeBaseSeconds) || timeBaseSeconds <= 0) {
        return -1;
    }

    double targetSeconds = fmax(0.0, (double)milliseconds / 1000.0);
    int64_t targetStreamTimestamp = (int64_t)llround((targetSeconds + _timelineOriginSeconds) / timeBaseSeconds);

    NSUInteger matchedIndex = 0;
    if (targetStreamTimestamp > _keyframeStreamTimestamps[0]) {
        NSUInteger low = 0;
        NSUInteger high = _keyframeStreamTimestampCount;
        while (low < high) {
            NSUInteger mid = low + (high - low) / 2;
            if (_keyframeStreamTimestamps[mid] <= targetStreamTimestamp) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        matchedIndex = low > 0 ? (low - 1) : 0;
    }

    double keyframeSeconds = (double)_keyframeStreamTimestamps[matchedIndex] * timeBaseSeconds - _timelineOriginSeconds;
    if (!isfinite(keyframeSeconds)) {
        return -1;
    }
    return MAX(0, (NSInteger)llround(keyframeSeconds * 1000.0));
}

- (BOOL)prepareVideoWithError:(NSError **)error {
    AVStream *videoStream = _videoStreamIndex >= 0 ? _formatContext->streams[_videoStreamIndex] : NULL;
    AVCodecParameters *parameters = videoStream != NULL ? videoStream->codecpar : NULL;
    const char *codecName = (parameters != NULL && parameters->codec_id != AV_CODEC_ID_NONE)
        ? avcodec_get_name(parameters->codec_id)
        : "unknown";

    NSString *settingName = @"Auto";
    if (_decodeMode == SFXNativePlaybackDecodeModeHardware) {
        settingName = @"Hardware";
    } else if (_decodeMode == SFXNativePlaybackDecodeModeSoftware) {
        settingName = @"Software";
    }

    BOOL prepared = NO;
    NSString *fallbackReason = nil;

    switch (_decodeMode) {
    case SFXNativePlaybackDecodeModeSoftware:
        prepared = [self prepareSoftwareVideoWithError:error];
        break;
    case SFXNativePlaybackDecodeModeHardware:
    case SFXNativePlaybackDecodeModeAuto: {
        NSError *hardwareError = nil;
        if ([self prepareHardwareVideoWithError:&hardwareError]) {
            prepared = YES;
            break;
        }

        fallbackReason = hardwareError.localizedDescription ?: @"Hardware decode unavailable";
        NSLog(@"[Playback] Gate 2 (Runtime Fallback): %@", fallbackReason);
        [self resetVideoDecoderState];

        NSError *softwareError = nil;
        if ([self prepareSoftwareVideoWithError:&softwareError]) {
            prepared = YES;
            break;
        }

        if (error != NULL) {
            NSString *hardwareMessage = hardwareError.localizedDescription ?: @"unknown hardware decoder error";
            NSString *softwareMessage = softwareError.localizedDescription ?: @"unknown software decoder error";
            *error = SFXNativePlaybackError(
                27,
                [NSString stringWithFormat:
                    @"Video decoder failed. Hardware: %@ Software: %@",
                    hardwareMessage,
                    softwareMessage
                ]
            );
        }
        prepared = NO;
        break;
    }
    }

    if (prepared) {
        const char *decoderName = (_videoCodecContext != NULL && _videoCodecContext->codec != NULL)
            ? _videoCodecContext->codec->name
            : "unknown";
        NSString *activePipeline = _usingHardwareDecode
            ? [NSString stringWithFormat:@"Hardware (VideoToolbox, %s)", decoderName]
            : [NSString stringWithFormat:@"Software (%s)", decoderName];

        if (fallbackReason != nil) {
            NSLog(@"[Playback] Open: path=%@, codec=%s, setting=%@, active=%@, fallbackReason=%@",
                  _path, codecName, settingName, activePipeline, fallbackReason);
        } else {
            NSLog(@"[Playback] Open: path=%@, codec=%s, setting=%@, active=%@",
                  _path, codecName, settingName, activePipeline);
        }
    } else {
        NSLog(@"[Playback] Open FAILED: path=%@, codec=%s, setting=%@, error=%@",
              _path, codecName, settingName, (error != NULL && *error != nil) ? [*error localizedDescription] : @"unknown");
    }

    return prepared;
}

- (void)resetVideoDecoderState {
    avcodec_free_context(&_videoCodecContext);
    av_buffer_unref(&_hardwareDeviceContext);
    SFXHardwarePixelFormat = AV_PIX_FMT_NONE;
    @synchronized (self) {
        _usingHardwareDecode = NO;
    }
}

- (BOOL)prepareHardwareVideoWithError:(NSError **)error {
    AVStream *videoStream = _formatContext->streams[_videoStreamIndex];
    AVCodecParameters *parameters = videoStream->codecpar;
    NSString *unsupportedReason = nil;
    if (!SFXIsHardwareDecodeSupportedForParameters(parameters, &unsupportedReason)) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(
                20,
                unsupportedReason ?: [NSString stringWithFormat:
                    @"Hardware decode is not supported by current device for %@.",
                    [NSString stringWithUTF8String:avcodec_get_name(parameters->codec_id)]
                ]
            );
        }
        return NO;
    }

    const AVCodecHWConfig *hardwareConfig = NULL;
    const AVCodec *decoder = SFXFindVideoToolboxDecoder(parameters->codec_id, &hardwareConfig);
    if (decoder == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(20, @"No FFmpeg video decoder found.");
        }
        return NO;
    }

    if (hardwareConfig == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(
                21,
                [NSString stringWithFormat:
                    @"No VideoToolbox-capable FFmpeg video decoder found for %@.",
                    [NSString stringWithUTF8String:avcodec_get_name(parameters->codec_id)]
                ]
            );
        }
        return NO;
    }
    SFXHardwarePixelFormat = hardwareConfig->pix_fmt;

    int result = av_hwdevice_ctx_create(
        &_hardwareDeviceContext,
        AV_HWDEVICE_TYPE_VIDEOTOOLBOX,
        NULL,
        NULL,
        0
    );
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(22, [NSString stringWithFormat:@"VideoToolbox device creation failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    _videoCodecContext = avcodec_alloc_context3(decoder);
    if (_videoCodecContext == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(23, @"Could not allocate video decoder context.");
        }
        return NO;
    }

    result = avcodec_parameters_to_context(_videoCodecContext, parameters);
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(24, [NSString stringWithFormat:@"Video codec parameter copy failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    _videoCodecContext->get_format = SFXChooseHardwareFormat;
    _videoCodecContext->hw_device_ctx = av_buffer_ref(_hardwareDeviceContext);
    if (_videoCodecContext->hw_device_ctx == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(25, @"Could not attach VideoToolbox device context.");
        }
        return NO;
    }

    result = avcodec_open2(_videoCodecContext, decoder, NULL);
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(26, [NSString stringWithFormat:@"Video decoder open failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    AVRational initialSAR = SFXVideoSampleAspectRatio(_formatContext, videoStream, _videoCodecContext, NULL);
    SFXVideoOrientation initialOrientation = SFXResolveVideoOrientation(videoStream, NULL);
    @synchronized (self) {
        _usingHardwareDecode = YES;
        _videoSampleAspectRatio = initialSAR;
        _videoOrientation = initialOrientation;
        _videoFrameWidth = _videoCodecContext->width;
        _videoFrameHeight = _videoCodecContext->height;
    }
    return YES;
}

- (BOOL)prepareSoftwareVideoWithError:(NSError **)error {
    AVStream *videoStream = _formatContext->streams[_videoStreamIndex];
    AVCodecParameters *parameters = videoStream->codecpar;
    const AVCodec *decoder = SFXFindSoftwareVideoDecoder(parameters->codec_id);
    if (decoder == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(
                28,
                [NSString stringWithFormat:
                    @"No FFmpeg software video decoder found for %@.",
                    [NSString stringWithUTF8String:avcodec_get_name(parameters->codec_id)]
                ]
            );
        }
        return NO;
    }

    _videoCodecContext = avcodec_alloc_context3(decoder);
    if (_videoCodecContext == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(23, @"Could not allocate video decoder context.");
        }
        return NO;
    }

    int result = avcodec_parameters_to_context(_videoCodecContext, parameters);
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(24, [NSString stringWithFormat:@"Video codec parameter copy failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    _videoCodecContext->thread_count = 0;
    _videoCodecContext->thread_type = FF_THREAD_FRAME | FF_THREAD_SLICE;

    result = avcodec_open2(_videoCodecContext, decoder, NULL);
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(26, [NSString stringWithFormat:@"Software video decoder open failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    AVRational initialSAR = SFXVideoSampleAspectRatio(_formatContext, videoStream, _videoCodecContext, NULL);
    SFXVideoOrientation initialOrientation = SFXResolveVideoOrientation(videoStream, NULL);
    @synchronized (self) {
        _usingHardwareDecode = NO;
        _videoSampleAspectRatio = initialSAR;
        _videoOrientation = initialOrientation;
        _videoFrameWidth = _videoCodecContext->width;
        _videoFrameHeight = _videoCodecContext->height;
    }
    SFXHardwarePixelFormat = AV_PIX_FMT_NONE;
    return YES;
}

- (BOOL)prepareAudioWithError:(NSError **)error {
    AVStream *audioStream = _formatContext->streams[_audioStreamIndex];
    AVCodecParameters *parameters = audioStream->codecpar;
    const AVCodec *decoder = avcodec_find_decoder(parameters->codec_id);
    if (decoder == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(30, @"No FFmpeg audio decoder found.");
        }
        return NO;
    }

    _audioCodecContext = avcodec_alloc_context3(decoder);
    _audioFrame = av_frame_alloc();
    _convertedAudioFrame = av_frame_alloc();
    if (_audioCodecContext == NULL || _audioFrame == NULL || _convertedAudioFrame == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(31, @"Could not allocate audio decoder context.");
        }
        return NO;
    }

    int result = avcodec_parameters_to_context(_audioCodecContext, parameters);
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(32, [NSString stringWithFormat:@"Audio codec parameter copy failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    result = avcodec_open2(_audioCodecContext, decoder, NULL);
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(33, [NSString stringWithFormat:@"Audio decoder open failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    int inputChannels = _audioCodecContext->ch_layout.nb_channels;
    _audioOutputChannels = SFXOutputChannelCount(inputChannels);
    _audioOutputSampleRate = _audioCodecContext->sample_rate > 0 ? _audioCodecContext->sample_rate : 48000;
    if (_audioOutputChannels <= 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(34, @"Could not determine native audio output channel count.");
        }
        return NO;
    }
    av_channel_layout_default(&_outputLayout, _audioOutputChannels);

    return [self prepareAudioOutputWithError:error];
}

- (BOOL)prepareAudioOutputWithError:(NSError **)error {
    [self teardownAudioOutput];

    _audioEngine = [[AVAudioEngine alloc] init];
    _audioPlayer = [[AVAudioPlayerNode alloc] init];
    _audioTimePitch = [[AVAudioUnitTimePitch alloc] init];
    _audioPlayer.volume = _volume;
    float initialRate = atomic_load(&_playbackRate);
    _audioTimePitch.rate = initialRate;
    _audioTimePitch.bypass = fabsf(initialRate - 1.0f) < 0.0005f;
    _audioFormat = [[AVAudioFormat alloc]
        initStandardFormatWithSampleRate:(double)_audioOutputSampleRate
        channels:(AVAudioChannelCount)_audioOutputChannels
    ];

    if (_audioEngine == nil || _audioPlayer == nil || _audioTimePitch == nil || _audioFormat == nil) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(35, @"Could not create AVAudioEngine output objects.");
        }
        [self teardownAudioOutput];
        return NO;
    }

    [_audioEngine attachNode:_audioPlayer];
    [_audioEngine attachNode:_audioTimePitch];
    [_audioEngine connect:_audioPlayer to:_audioTimePitch format:_audioFormat];
    [_audioEngine connect:_audioTimePitch to:_audioEngine.mainMixerNode format:_audioFormat];

    NSError *audioError = nil;
    if (![_audioEngine startAndReturnError:&audioError]) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(
                36,
                [NSString stringWithFormat:@"AVAudioEngine start failed: %@", audioError.localizedDescription]
            );
        }
        [self teardownAudioOutput];
        return NO;
    }

    __weak typeof(self) weakSelf = self;
    _audioEngineConfigurationObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:AVAudioEngineConfigurationChangeNotification
                    object:_audioEngine
                     queue:nil
                usingBlock:^(NSNotification *notification) {
        (void)notification;
        [weakSelf requestAudioOutputRecovery];
    }];

    return YES;
}

- (void)teardownAudioOutput {
    if (_audioEngineConfigurationObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:_audioEngineConfigurationObserver];
        _audioEngineConfigurationObserver = nil;
    }
    _pendingCoalescedAudioBuffer = nil;
    _pendingCoalescedAudioStartMediaSeconds = -1;
    [_audioPlayer stop];
    [_audioEngine stop];
    _audioPlayer = nil;
    _audioTimePitch = nil;
    _audioEngine = nil;
    _audioFormat = nil;
}

- (void)requestAudioOutputRecovery {
    BOOL shouldRequestRecovery = NO;
    [_packetQueueCondition lock];
    if (!_audioOutputRecoveryRequested
        && !atomic_load(&_cancelled)
        && !atomic_load(&_segmentEnding)
        && !atomic_load(&_decodeLoopFinished)) {
        _audioOutputRecoveryRequested = YES;
        _audioResetInProgress = YES;
        _audioDrainScheduled = NO;
        _playbackGeneration += 1;
        shouldRequestRecovery = YES;
        [_packetQueueCondition broadcast];
    }
    [_packetQueueCondition unlock];
    if (shouldRequestRecovery) {
        [self signalPacingCondition];
    }

    if (!shouldRequestRecovery) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        SFXNativePlaybackPlayer *owner = strongSelf->_owner;
        if (owner != nil) {
            [owner requestAudioOutputRecoveryForSession:strongSelf];
        }
    });
}

- (void)configurePerfOpenStart:(CFTimeInterval)openStart stopPrevMs:(double)stopPrevMs {
    _perfOpenStartHostSeconds = openStart;
    _perfStopPrevMs = stopPrevMs;
}

- (void)start {
    BOOL deferPrepareToDecodeQueue = (_formatContext == NULL && SFXIsHTTPMediaPath(_path.UTF8String));
    if (!deferPrepareToDecodeQueue) {
        _perfStartHostSeconds = CACurrentMediaTime();
        double totalPrepareMs = _perfOpenStartHostSeconds > 0
            ? (_perfStartHostSeconds - _perfOpenStartHostSeconds) * 1000.0
            : (_perfStopPrevMs + _perfAvformatOpenMs + _perfFindStreamInfoMs + _perfInitCodecAudioMs + _perfInitialSeekMs);
        NSLog(@"[PlaybackPerf] OPEN_PREPARE gen=%lu startMs=%ld totalPrepare=%.1fms | S2_stopPrev=%.1fms S3_avformatOpen=%.1fms S4_findStreamInfo=%.1fms S5_initCodecAudio=%.1fms S6_initialSeek=%.1fms hwDecode=%d",
              (unsigned long)_presentationGeneration,
              (long)llround(_seekSeconds * 1000.0),
              totalPrepareMs,
              _perfStopPrevMs,
              _perfAvformatOpenMs,
              _perfFindStreamInfoMs,
              _perfInitCodecAudioMs,
              _perfInitialSeekMs,
              _usingHardwareDecode ? 1 : 0);
    }
    [self startStarvationWatchdog];
    dispatch_async(_decodeQueue, ^{
        @autoreleasepool {
            if (deferPrepareToDecodeQueue) {
                NSError *prepareError = nil;
                if (![self prepareWithError:&prepareError]) {
                    atomic_store(&_decodeLoopFinished, true);
                    [_packetQueueCondition lock];
                    [_packetQueueCondition broadcast];
                    [_packetQueueCondition unlock];
                    [self teardown];
                    if (!atomic_load(&_cancelled)) {
                        SFXNativePlaybackPlayer *owner = _owner;
                        [owner session:self
                            didFailToOpenWithError:prepareError
                            presentationGeneration:_presentationGeneration];
                    }
                    return;
                }
                _perfStartHostSeconds = CACurrentMediaTime();
                double totalPrepareMs = _perfOpenStartHostSeconds > 0
                    ? (_perfStartHostSeconds - _perfOpenStartHostSeconds) * 1000.0
                    : (_perfStopPrevMs + _perfAvformatOpenMs + _perfFindStreamInfoMs + _perfInitCodecAudioMs + _perfInitialSeekMs);
                NSLog(@"[PlaybackPerf] OPEN_PREPARE gen=%lu startMs=%ld totalPrepare=%.1fms | S2_stopPrev=%.1fms S3_avformatOpen=%.1fms S4_findStreamInfo=%.1fms S5_initCodecAudio=%.1fms S6_initialSeek=%.1fms hwDecode=%d",
                      (unsigned long)_presentationGeneration,
                      (long)llround(_seekSeconds * 1000.0),
                      totalPrepareMs,
                      _perfStopPrevMs,
                      _perfAvformatOpenMs,
                      _perfFindStreamInfoMs,
                      _perfInitCodecAudioMs,
                      _perfInitialSeekMs,
                      _usingHardwareDecode ? 1 : 0);
            }
            [self decodeLoop];
            [self startAudioForDrainAfterVideoDecodeIfNeeded];
            [self waitForSegmentAudioDrainIfNeeded];
            [self waitForNaturalAudioDrainIfNeeded];
            [self notifyPlaybackFinishedIfNeeded];
            [self waitForSegmentFinishNotificationIfNeeded];
            [self teardown];
        }
    });
}

- (BOOL)isCancelledForIOInterrupt {
    return atomic_load(&_cancelled);
}

- (void)cancelAsync {
    atomic_store(&_cancelled, true);
    atomic_store(&_paused, false);
    [_packetQueueCondition lock];
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];
    [self signalPacingCondition];
}

- (void)stopAndWait {
    [self cancelAsync];

    if (_decodeQueue != NULL) {
        dispatch_sync(_decodeQueue, ^{});
    }
}

- (BOOL)seekToMilliseconds:(NSInteger)milliseconds
           endMilliseconds:(NSInteger)endMilliseconds
	       pausesAtSegmentEnd:(BOOL)pausesAtSegmentEnd
	 presentationGeneration:(NSUInteger)presentationGeneration
		      pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
		                     error:(NSError **)error {
	return [self requestSeekToMilliseconds:milliseconds
	                         endMilliseconds:endMilliseconds
	                     pausesAtSegmentEnd:pausesAtSegmentEnd
	                presentationGeneration:presentationGeneration
	                    pauseAfterFirstFrame:pauseAfterFirstFrame
	                 rebuildsAudioOutput:NO
	                                    error:error];
}

- (BOOL)requestSeekToMilliseconds:(NSInteger)milliseconds
                  endMilliseconds:(NSInteger)endMilliseconds
	              pausesAtSegmentEnd:(BOOL)pausesAtSegmentEnd
	         presentationGeneration:(NSUInteger)presentationGeneration
	             pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
	          rebuildsAudioOutput:(BOOL)rebuildsAudioOutput
	                            error:(NSError **)error {
	    double seekSeconds = MAX(0, (double)milliseconds / 1000.0);
	    NSInteger safeEndMilliseconds = SFXSanitizedSegmentEndMilliseconds(milliseconds, endMilliseconds);
	    double segmentEndSeconds = safeEndMilliseconds >= 0 ? (double)safeEndMilliseconds / 1000.0 : -1;
    BOOL isAsyncHTTPSeek = !rebuildsAudioOutput && SFXIsHTTPMediaPath(_path.UTF8String);

    [_packetQueueCondition lock];
    if (!isAsyncHTTPSeek) {
        while ((_seekRequestPending || _seekRequestInProgress)
               && !atomic_load(&_cancelled)
               && !atomic_load(&_decodeLoopFinished)) {
            [_packetQueueCondition wait];
        }
    }

    if (atomic_load(&_cancelled) || atomic_load(&_decodeLoopFinished)) {
        [_packetQueueCondition unlock];
        if (error != NULL) {
            *error = SFXNativePlaybackError(41, @"Native playback session is not active for seek.");
        }
        return NO;
    }

    NSUInteger generation = _seekRequestGeneration + 1;
	    _seekRequestGeneration = generation;
	    _pendingSeekSeconds = seekSeconds;
	    _pendingSeekSegmentEndSeconds = segmentEndSeconds;
	    _pendingSeekPausesAtSegmentEnd = pausesAtSegmentEnd && safeEndMilliseconds >= 0;
	    _pendingSeekPresentationGeneration = presentationGeneration;
	    _pendingSeekPauseAfterFirstFrame = pauseAfterFirstFrame;
	    _pendingSeekRebuildsAudioOutput = rebuildsAudioOutput;
	    if (rebuildsAudioOutput) {
	        _audioOutputRecoveryRequested = NO;
	    }
    _seekRequestPending = YES;
    _seekRequestSucceeded = NO;
    _seekRequestError = nil;
    [_packetQueueCondition broadcast];
    [self signalPacingCondition];

    if (isAsyncHTTPSeek) {
        [_packetQueueCondition unlock];
        @synchronized (self) {
            _currentTime = seekSeconds;
        }
        return YES;
    }

    while (_completedSeekRequestGeneration < generation
           && !atomic_load(&_cancelled)
           && !atomic_load(&_decodeLoopFinished)) {
        [_packetQueueCondition wait];
    }

    BOOL succeeded = _completedSeekRequestGeneration >= generation && _seekRequestSucceeded;
    NSError *seekError = _seekRequestError;
    [_packetQueueCondition unlock];

    if (!succeeded && error != NULL) {
        *error = seekError ?: SFXNativePlaybackError(41, @"Native playback in-session seek did not complete.");
    }
    return succeeded;
}

- (BOOL)recoverAudioOutputWithError:(NSError **)error {
    NSInteger currentMilliseconds = MAX(0, (NSInteger)llround(self.currentTime * 1000.0));
    NSInteger endMilliseconds = self.segmentEndMilliseconds;
    BOOL pausesAtSegmentEnd = self.pausesAtSegmentEnd;
    BOOL pauseAfterFirstFrame = self.isPaused;

    return [self requestSeekToMilliseconds:currentMilliseconds
                           endMilliseconds:endMilliseconds
                       pausesAtSegmentEnd:pausesAtSegmentEnd
                  presentationGeneration:self.presentationGeneration
                      pauseAfterFirstFrame:pauseAfterFirstFrame
                   rebuildsAudioOutput:YES
                                      error:error];
}

- (void)setPaused:(BOOL)paused {
    if (!paused) {
        atomic_store(&_pauseAfterFirstFrame, false);
        atomic_store(&_didPauseAfterFirstFrame, true);
    }
    BOOL wasPaused = atomic_exchange(&_paused, paused);
    atomic_store(&_playing, !paused);

    if (wasPaused != paused) {
        double now = CACurrentMediaTime();
        @synchronized (self) {
            if (paused) {
                _isPausedInsideLoop = YES;
                _pauseStartedHostSeconds = now;
            } else if (_isPausedInsideLoop) {
                double pauseDuration = fmax(0, now - _pauseStartedHostSeconds);
                if (_audioClockInitialized) {
                    _audioStartHostSeconds += pauseDuration;
                }
                if (_videoClockInitialized) {
                    _videoStartHostSeconds += pauseDuration;
                }
                _isPausedInsideLoop = NO;
                _pauseStartedHostSeconds = 0;
            }
        }
    }

    dispatch_async(_audioDecodeQueue, ^{
        if (paused) {
            if (atomic_load(&_paused)) {
                [_audioPlayer pause];
            }
            return;
        }

        BOOL shouldPlayAudio = NO;
        @synchronized (self) {
            shouldPlayAudio = _audioPlayerStarted && !_isRebuffering;
        }
        if (shouldPlayAudio
            && !atomic_load(&_paused)
            && !atomic_load(&_cancelled)
            && !atomic_load(&_segmentEnding)) {
            [_audioPlayer play];
        }
    });

    [_packetQueueCondition lock];
    if (!paused) {
        _pendingSeekPauseAfterFirstFrame = NO;
    }
    [_packetQueueCondition broadcast];
    NSUInteger generation = _playbackGeneration;
    [_packetQueueCondition unlock];
    [self signalPacingCondition];

    if (!paused) {
        [self requestAudioPlaybackStartIfReadyForGeneration:generation];
    }

    [self notifyTimeIfNeeded:YES];
}

- (void)setReadAheadSuspended:(BOOL)suspended {
    [_packetQueueCondition lock];
    _readAheadSuspended = suspended;
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];
    if (!suspended) {
        [self requestAudioDrain];
    }
}

- (void)setVolume:(float)volume {
    _volume = volume;
    dispatch_async(_audioDecodeQueue, ^{
        _audioPlayer.volume = volume;
    });
}

- (void)setPlaybackRate:(float)playbackRate {
    float clampedRate = SFXClampedPlaybackRate(playbackRate);
    double hostSeconds = CACurrentMediaTime();

    @synchronized (self) {
        [self rebasePlaybackClocksLockedAtHostSeconds:hostSeconds];
        atomic_store(&_playbackRate, clampedRate);
        if (_isPausedInsideLoop) {
            _pauseStartedHostSeconds = hostSeconds;
        }
    }

    dispatch_async(_audioDecodeQueue, ^{
        _audioTimePitch.rate = clampedRate;
        _audioTimePitch.bypass = fabsf(clampedRate - 1.0f) < 0.0005f;
    });
    [self signalPacingCondition];
    [self requestAudioDrain];
}

- (void)rebasePlaybackClocksLockedAtHostSeconds:(double)hostSeconds {
    if (_audioClockInitialized) {
        _audioFirstMediaSeconds = [self mediaSecondsForClockLockedWithFirstMediaSeconds:_audioFirstMediaSeconds
                                                                      startHostSeconds:_audioStartHostSeconds
                                                                            hostSeconds:hostSeconds];
        _audioStartHostSeconds = hostSeconds;
    }

    if (_videoClockInitialized) {
        _videoFirstMediaSeconds = [self mediaSecondsForClockLockedWithFirstMediaSeconds:_videoFirstMediaSeconds
                                                                      startHostSeconds:_videoStartHostSeconds
                                                                            hostSeconds:hostSeconds];
        _videoStartHostSeconds = hostSeconds;
    }
}

- (double)mediaSecondsForClockLockedWithFirstMediaSeconds:(double)firstMediaSeconds
                                         startHostSeconds:(double)startHostSeconds
                                              hostSeconds:(double)hostSeconds {
    if (atomic_load(&_paused) || _isPausedInsideLoop) {
        return _currentTime;
    }

    double elapsedHostSeconds = fmax(0, hostSeconds - startHostSeconds);
    return firstMediaSeconds + (elapsedHostSeconds * atomic_load(&_playbackRate));
}

- (void)startPacketReadAhead {
    [_packetQueueCondition lock];
    if (_packetQueueDemuxStarted) {
        [_packetQueueCondition unlock];
        return;
    }
    _packetQueueDemuxStarted = YES;
    [_packetQueueCondition unlock];

    dispatch_async(_demuxQueue, ^{
        @autoreleasepool {
            [self demuxLoop];
        }
    });
}

- (void)stopPacketReadAheadAndClear {
    [_packetQueueCondition lock];
    _packetQueueEOF = YES;
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];

    if (_demuxQueue != NULL && _packetQueueDemuxStarted) {
        dispatch_sync(_demuxQueue, ^{});
    }

    [_packetQueueCondition lock];
    [self clearPacketQueueLocked];
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];
}

- (void)stopPacketReadAheadForSeekAndClear {
    [_packetQueueCondition lock];
    _packetQueueEOF = YES;
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];

    if (_demuxQueue != NULL && _packetQueueDemuxStarted) {
        dispatch_sync(_demuxQueue, ^{});
    }

    [_packetQueueCondition lock];
    [self clearPacketQueueLocked];
    _packetQueueEOF = NO;
    _packetQueueDemuxStarted = NO;
    _packetQueueAtHighWater = NO;
    _readAheadSuspended = NO;
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];
}

- (BOOL)hasPendingSeekRequestLocked {
    return _seekRequestPending;
}

- (BOOL)isPacketQueueAtHighWaterLocked {
    if (_packetQueueBytes >= SFXReadAheadMaxBytes) {
        _packetQueueAtHighWater = YES;
        return YES;
    }
    if (_packetQueueAtHighWater && _packetQueueBytes >= SFXReadAheadLowWaterBytes) {
        return YES;
    }
    double thresholdSeconds = _packetQueueAtHighWater
        ? SFXReadAheadLowWaterSeconds
        : SFXReadAheadTargetSeconds;
    BOOL videoReady = [self packetQueueBufferedSecondsLocked] >= thresholdSeconds;
    BOOL audioReady = _audioCodecContext == NULL
        || atomic_load(&_segmentAudioBoundaryReached)
        || [self audioPacketQueueBufferedSecondsLocked] >= thresholdSeconds;
    _packetQueueAtHighWater = videoReady && audioReady;
    return _packetQueueAtHighWater;
}

- (double)packetQueueBufferedSecondsForHeadLocked:(SFXQueuedPacket *)head
                                             tail:(SFXQueuedPacket *)tail {
    if (head == NULL) {
        return 0;
    }
    if (tail != NULL
        && isfinite(head->mediaSeconds) && head->mediaSeconds >= 0
        && isfinite(tail->mediaSeconds) && tail->mediaSeconds >= head->mediaSeconds) {
        return tail->mediaSeconds - head->mediaSeconds;
    }

    double earliestSeconds = DBL_MAX;
    double latestSeconds = -DBL_MAX;
    BOOL hasTimestamp = NO;

    for (SFXQueuedPacket *node = head; node != NULL; node = node->next) {
        if (!isfinite(node->mediaSeconds) || node->mediaSeconds < 0) {
            continue;
        }
        earliestSeconds = fmin(earliestSeconds, node->mediaSeconds);
        latestSeconds = fmax(latestSeconds, node->mediaSeconds);
        hasTimestamp = YES;
    }

    if (!hasTimestamp) {
        return 0;
    }
    return fmax(0, latestSeconds - earliestSeconds);
}

- (double)packetQueueBufferedSecondsLocked {
    return [self packetQueueBufferedSecondsForHeadLocked:_packetQueueHead tail:_packetQueueTail];
}

- (double)audioPacketQueueBufferedSecondsLocked {
    return [self packetQueueBufferedSecondsForHeadLocked:_audioPacketQueueHead tail:_audioPacketQueueTail];
}

- (void)clearAudioPacketQueueLocked {
    SFXQueuedPacket *node = _audioPacketQueueHead;
    while (node != NULL) {
        SFXQueuedPacket *next = node->next;
        if (_packetQueueBytes >= node->bytes) {
            _packetQueueBytes -= node->bytes;
        } else {
            _packetQueueBytes = 0;
        }
        if (_packetQueueCount > 0) {
            _packetQueueCount -= 1;
        }
        SFXFreeQueuedPacket(node);
        node = next;
    }
    _audioPacketQueueHead = NULL;
    _audioPacketQueueTail = NULL;
}

- (void)clearPacketQueueLocked {
    SFXQueuedPacket *node = _packetQueueHead;
    while (node != NULL) {
        SFXQueuedPacket *next = node->next;
        SFXFreeQueuedPacket(node);
        node = next;
    }
    _packetQueueHead = NULL;
    _packetQueueTail = NULL;
    [self clearAudioPacketQueueLocked];
    _packetQueueBytes = 0;
    _packetQueueCount = 0;
    _packetQueueAtHighWater = NO;
}

- (size_t)packetMemoryBytes:(const AVPacket *)packet {
    if (packet == NULL) {
        return 0;
    }

    size_t bytes = packet->size > 0 ? (size_t)packet->size : 0;
    for (int index = 0; index < packet->side_data_elems; index++) {
        bytes += packet->side_data[index].size;
    }
    return bytes;
}

- (double)queuedAudioWallSecondsLocked {
    double rate = fmax((double)atomic_load(&_playbackRate), 0.001);
    return _queuedAudioMediaSeconds / rate;
}

- (SFXQueuedPacket *)dequeueAudioPacketLocked {
    SFXQueuedPacket *queuedPacket = _audioPacketQueueHead;
    if (queuedPacket == NULL) {
        return NULL;
    }

    _audioPacketQueueHead = queuedPacket->next;
    if (_audioPacketQueueHead == NULL) {
        _audioPacketQueueTail = NULL;
    }
    queuedPacket->next = NULL;
    if (_packetQueueBytes >= queuedPacket->bytes) {
        _packetQueueBytes -= queuedPacket->bytes;
    } else {
        _packetQueueBytes = 0;
    }
    if (_packetQueueCount > 0) {
        _packetQueueCount -= 1;
    }
    BOOL wasAtHighWater = _packetQueueAtHighWater;
    BOOL nowAtHighWater = wasAtHighWater ? [self isPacketQueueAtHighWaterLocked] : NO;
    if ((wasAtHighWater && !nowAtHighWater) || _audioPacketQueueHead == NULL) {
        [_packetQueueCondition broadcast];
    }
    return queuedPacket;
}

- (void)requestAudioDrain {
    if (_audioDecodeQueue == NULL || _audioCodecContext == NULL) {
        return;
    }

    [_packetQueueCondition lock];
    BOOL shouldSchedule = !_audioDrainScheduled
        && !_audioResetInProgress
        && !_audioInputEnded
        && !_readAheadSuspended
        && !atomic_load(&_segmentAudioBoundaryReached)
        && !atomic_load(&_cancelled)
        && !atomic_load(&_segmentEnding)
        && !atomic_load(&_finishingForAutomaticRecycle)
        && (_audioPacketQueueHead != NULL || _packetQueueEOF)
        && [self queuedAudioWallSecondsLocked] < SFXAudioQueueHighWaterWallSeconds;
    NSUInteger generation = _playbackGeneration;
    if (shouldSchedule) {
        _audioDrainScheduled = YES;
    }
    [_packetQueueCondition unlock];

    if (!shouldSchedule) {
        return;
    }

    dispatch_async(_audioDecodeQueue, ^{
        @autoreleasepool {
            [self drainAudioPacketsForGeneration:generation];
        }

        [_packetQueueCondition lock];
        if (generation == _playbackGeneration) {
            _audioDrainScheduled = NO;
        }
        BOOL shouldRequestAgain = generation == _playbackGeneration
            && !_audioResetInProgress
            && !_audioInputEnded
            && !_readAheadSuspended
            && !atomic_load(&_segmentAudioBoundaryReached)
            && (_audioPacketQueueHead != NULL || _packetQueueEOF)
            && [self queuedAudioWallSecondsLocked] < SFXAudioQueueHighWaterWallSeconds
            && !atomic_load(&_cancelled)
            && !atomic_load(&_segmentEnding)
            && !atomic_load(&_finishingForAutomaticRecycle);
        [_packetQueueCondition unlock];

        if (shouldRequestAgain) {
            [self requestAudioDrain];
        }
    });
}

- (void)drainAudioPacketsForGeneration:(NSUInteger)generation {
    while (YES) {
        [_packetQueueCondition lock];
        BOOL shouldStop = generation != _playbackGeneration
            || _audioResetInProgress
            || _readAheadSuspended
            || _audioInputEnded
            || atomic_load(&_segmentAudioBoundaryReached)
            || atomic_load(&_cancelled)
            || atomic_load(&_segmentEnding)
            || atomic_load(&_finishingForAutomaticRecycle)
            || [self queuedAudioWallSecondsLocked] >= SFXAudioQueueHighWaterWallSeconds;
        if (shouldStop) {
            [_packetQueueCondition unlock];
            [self flushPendingCoalescedAudioForGeneration:generation finalSegmentBuffer:NO];
            return;
        }

        SFXQueuedPacket *queuedPacket = [self dequeueAudioPacketLocked];
        BOOL reachedEOF = queuedPacket == NULL && _packetQueueEOF;
        [_packetQueueCondition unlock];

        if (queuedPacket != NULL) {
            [self handleAudioPacket:queuedPacket->packet generation:generation];
            SFXFreeQueuedPacket(queuedPacket);
            continue;
        }

        if (!reachedEOF) {
            [self flushPendingCoalescedAudioForGeneration:generation finalSegmentBuffer:NO];
            return;
        }

        [self handleAudioPacket:NULL generation:generation];
        [self flushPendingCoalescedAudioForGeneration:generation finalSegmentBuffer:NO];

        [_packetQueueCondition lock];
        if (generation != _playbackGeneration || _audioResetInProgress) {
            [_packetQueueCondition unlock];
            return;
        }
        _audioInputEnded = YES;
        _audioPrimed = YES;
        BOOL hasOutstandingAudio = _outstandingAudioBufferCount > 0;
        BOOL hasPendingCompletionRecords = _pendingAudioCompletionRecordCount > 0;
        _audioOutputDrained = !hasOutstandingAudio && !hasPendingCompletionRecords;
        [_packetQueueCondition broadcast];
        [_packetQueueCondition unlock];

        if ([self hasActiveSegmentEnd] && ![self segmentAudioBoundaryReached]) {
            [self markSegmentAudioBoundaryReached];
        }
        if (hasOutstandingAudio) {
            [self requestAudioPlaybackStartIfReadyForGeneration:generation];
        }
        return;
    }
}

- (void)demuxLoop {
    while (!atomic_load(&_cancelled)
           && !atomic_load(&_segmentEnding)
           && !atomic_load(&_finishingForAutomaticRecycle)) {
	        [_packetQueueCondition lock];
	        while (!atomic_load(&_cancelled)
	               && !atomic_load(&_segmentEnding)
	               && !atomic_load(&_finishingForAutomaticRecycle)
	               && !_packetQueueEOF
	               && (_readAheadSuspended || [self isPacketQueueAtHighWaterLocked])) {
            [_packetQueueCondition wait];
        }
	        BOOL shouldStop = atomic_load(&_cancelled)
	            || atomic_load(&_segmentEnding)
	            || atomic_load(&_finishingForAutomaticRecycle)
	            || _packetQueueEOF;
        [_packetQueueCondition unlock];
        if (shouldStop) {
            break;
        }

        int result = av_read_frame(_formatContext, _packet);
        if (result < 0) {
            [_packetQueueCondition lock];
            _packetQueueEOF = YES;
            [_packetQueueCondition broadcast];
            [_packetQueueCondition unlock];
            break;
        }

        BOOL audioBoundaryReached = atomic_load(&_segmentAudioBoundaryReached);
        BOOL videoBoundaryReached = atomic_load(&_segmentVideoBoundaryReached);
        BOOL relevantPacket = (_packet->stream_index == _videoStreamIndex && !videoBoundaryReached)
            || (_packet->stream_index == _audioStreamIndex
                && _audioCodecContext != NULL
                && !audioBoundaryReached);
        if (!relevantPacket) {
            av_packet_unref(_packet);
            continue;
        }
        if (!_perfFirstPacketRecorded) {
            _perfFirstPacketRecorded = YES;
            _perfFirstPacketHostSeconds = CACurrentMediaTime();
        }

        AVPacket *packetCopy = av_packet_alloc();
        if (packetCopy == NULL) {
            av_packet_unref(_packet);
            [self notifyFailure:@"Could not allocate native playback read-ahead packet."];
            atomic_store(&_cancelled, true);
            [_packetQueueCondition lock];
            _packetQueueEOF = YES;
            [_packetQueueCondition broadcast];
            [_packetQueueCondition unlock];
            [self signalPacingCondition];
            break;
        }

        result = av_packet_ref(packetCopy, _packet);
        av_packet_unref(_packet);
        if (result < 0) {
            av_packet_free(&packetCopy);
            [self notifyFailure:[NSString stringWithFormat:
                @"Native playback read-ahead packet copy failed: %@",
                SFXFFmpegErrorString(result)
            ]];
            atomic_store(&_cancelled, true);
            [_packetQueueCondition lock];
            _packetQueueEOF = YES;
            [_packetQueueCondition broadcast];
            [_packetQueueCondition unlock];
            [self signalPacingCondition];
            break;
        }

        SFXQueuedPacket *queuedPacket = (SFXQueuedPacket *)calloc(1, sizeof(SFXQueuedPacket));
        if (queuedPacket == NULL) {
            av_packet_free(&packetCopy);
            [self notifyFailure:@"Could not allocate native playback read-ahead queue node."];
            atomic_store(&_cancelled, true);
            [_packetQueueCondition lock];
            _packetQueueEOF = YES;
            [_packetQueueCondition broadcast];
            [_packetQueueCondition unlock];
            [self signalPacingCondition];
            break;
        }

        AVStream *stream = _formatContext->streams[packetCopy->stream_index];
        queuedPacket->packet = packetCopy;
        queuedPacket->bytes = [self packetMemoryBytes:packetCopy];
        queuedPacket->mediaSeconds = SFXPacketPlaybackSeconds(packetCopy, stream, _timelineOriginSeconds);

        [_packetQueueCondition lock];
	        if (atomic_load(&_cancelled)
	            || atomic_load(&_segmentEnding)
	            || atomic_load(&_finishingForAutomaticRecycle)
	            || _packetQueueEOF) {
	            [_packetQueueCondition unlock];
	            SFXFreeQueuedPacket(queuedPacket);
	            break;
        }

        BOOL isAudioPacket = packetCopy->stream_index == _audioStreamIndex;
        if (isAudioPacket && _audioPacketQueueTail != NULL) {
            _audioPacketQueueTail->next = queuedPacket;
        } else if (!isAudioPacket && _packetQueueTail != NULL) {
            _packetQueueTail->next = queuedPacket;
        } else if (isAudioPacket) {
            _audioPacketQueueHead = queuedPacket;
        } else {
            _packetQueueHead = queuedPacket;
        }
        if (isAudioPacket) {
            _audioPacketQueueTail = queuedPacket;
        } else {
            _packetQueueTail = queuedPacket;
        }
        _packetQueueBytes += queuedPacket->bytes;
        _packetQueueCount += 1;
        BOOL wasEmpty = isAudioPacket
            ? (_audioPacketQueueHead == queuedPacket)
            : (_packetQueueHead == queuedPacket);
        if (wasEmpty
            || atomic_load(&_decodeWaitingForPacket)
            || !_audioPrimed
            || !_perfFirstVideoDecodedRecorded) {
            [_packetQueueCondition broadcast];
        }
        [_packetQueueCondition unlock];
        if (isAudioPacket) {
            [self requestAudioDrain];
        }
    }

    [self requestAudioDrain];
}

- (void)waitUntilPacketQueueHasStartupWaterline {
    [_packetQueueCondition lock];
	    while (!atomic_load(&_cancelled)
	           && !atomic_load(&_segmentEnding)
	           && !atomic_load(&_finishingForAutomaticRecycle)
	           && !_packetQueueEOF
	           && ![self hasPendingSeekRequestLocked]
	           && _packetQueueBytes < SFXReadAheadMaxBytes
           && [self packetQueueBufferedSecondsLocked] < SFXReadAheadStartupSeconds) {
        [_packetQueueCondition wait];
    }

    double bufferedSeconds = [self packetQueueBufferedSecondsLocked];
    size_t queuedBytes = _packetQueueBytes;
	    BOOL shouldLog = !atomic_load(&_cancelled)
	        && !atomic_load(&_segmentEnding)
	        && !atomic_load(&_finishingForAutomaticRecycle)
	        && _packetQueueHead != NULL;
    [_packetQueueCondition unlock];

    if (shouldLog) {
        printf(
            "Native playback read-ahead: startup buffered=%.3fs bytes=%zu target=%.3fs cap=%zu\n",
            bufferedSeconds,
            queuedBytes,
            SFXReadAheadTargetSeconds,
            SFXReadAheadMaxBytes
        );
    }
}

- (SFXQueuedPacket *)dequeueVideoPacket {
    [_packetQueueCondition lock];
    BOOL armedStarvationWatchdog = NO;
	    while (!atomic_load(&_cancelled)
	           && !atomic_load(&_segmentEnding)
	           && !atomic_load(&_finishingForAutomaticRecycle)
	           && !_packetQueueEOF
	           && ![self hasPendingSeekRequestLocked]
           && _packetQueueHead == NULL) {
        if (!armedStarvationWatchdog) {
            atomic_store(&_decodeWaitingForPacket, true);
            [self armStarvationWatchdog];
            armedStarvationWatchdog = YES;
        }
        [_packetQueueCondition wait];
    }
    if (armedStarvationWatchdog) {
        atomic_store(&_decodeWaitingForPacket, false);
        [self disarmStarvationWatchdog];
    }

    if ([self hasPendingSeekRequestLocked]) {
        [_packetQueueCondition unlock];
        return NULL;
    }

	    if (atomic_load(&_cancelled)
	        || atomic_load(&_segmentEnding)
	        || atomic_load(&_finishingForAutomaticRecycle)) {
	        [_packetQueueCondition unlock];
	        return NULL;
	    }

    SFXQueuedPacket *queuedPacket = _packetQueueHead;
    if (queuedPacket == NULL) {
        [_packetQueueCondition unlock];
        return NULL;
    }

    _packetQueueHead = queuedPacket->next;
    if (_packetQueueHead == NULL) {
        _packetQueueTail = NULL;
    }
    queuedPacket->next = NULL;
    if (_packetQueueBytes >= queuedPacket->bytes) {
        _packetQueueBytes -= queuedPacket->bytes;
    } else {
        _packetQueueBytes = 0;
    }
    if (_packetQueueCount > 0) {
        _packetQueueCount -= 1;
    }
    BOOL wasAtHighWater = _packetQueueAtHighWater;
    BOOL nowAtHighWater = wasAtHighWater ? [self isPacketQueueAtHighWaterLocked] : NO;
    if ((wasAtHighWater && !nowAtHighWater) || _packetQueueHead == NULL) {
        [_packetQueueCondition broadcast];
    }
    [_packetQueueCondition unlock];
    return queuedPacket;
}

- (BOOL)performPendingSeekIfNeeded {
    [_packetQueueCondition lock];
    if (!_seekRequestPending) {
        [_packetQueueCondition unlock];
        return NO;
    }

	    NSUInteger generation = _seekRequestGeneration;
	    double seekSeconds = _pendingSeekSeconds;
	    double segmentEndSeconds = _pendingSeekSegmentEndSeconds;
	    BOOL pausesAtSegmentEnd = _pendingSeekPausesAtSegmentEnd;
	    NSUInteger presentationGeneration = _pendingSeekPresentationGeneration;
	    BOOL pauseAfterFirstFrame = _pendingSeekPauseAfterFirstFrame;
	    BOOL rebuildsAudioOutput = _pendingSeekRebuildsAudioOutput;
    _seekRequestPending = NO;
	    _pendingSeekRebuildsAudioOutput = NO;
    _seekRequestInProgress = YES;
    [_packetQueueCondition unlock];

    NSError *seekError = nil;
	    BOOL succeeded = [self applyInSessionSeekToSeconds:seekSeconds
	                                  segmentEndSeconds:segmentEndSeconds
	                              pausesAtSegmentEnd:pausesAtSegmentEnd
	                             presentationGeneration:presentationGeneration
	                                  pauseAfterFirstFrame:pauseAfterFirstFrame
	                               rebuildsAudioOutput:rebuildsAudioOutput
	                                                 error:&seekError];
	if (succeeded && rebuildsAudioOutput) {
	    @synchronized (self) {
	        _audioOutputRecoveryCount += 1;
	    }
	}

    [_packetQueueCondition lock];
    _seekRequestSucceeded = succeeded;
    _seekRequestError = seekError;
    _completedSeekRequestGeneration = generation;
    _seekRequestInProgress = NO;
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];

    return YES;
}

- (BOOL)waitForAutoStopSeekIfNeeded {
    BOOL shouldKeepSessionAlive = NO;
    @synchronized (self) {
        shouldKeepSessionAlive = _pausesAtSegmentEnd
            && atomic_load(&_segmentVideoBoundaryReached);
    }
    if (!shouldKeepSessionAlive) {
        return NO;
    }

    [_packetQueueCondition lock];
    while (!atomic_load(&_cancelled)
           && !atomic_load(&_segmentEnding)
           && !atomic_load(&_finishingForAutomaticRecycle)
           && ![self hasPendingSeekRequestLocked]) {
        [_packetQueueCondition wait];
    }
    BOOL hasPendingSeek = [self hasPendingSeekRequestLocked];
    [_packetQueueCondition unlock];
    return hasPendingSeek;
}

- (BOOL)applyInSessionSeekToSeconds:(double)seekSeconds
                  segmentEndSeconds:(double)segmentEndSeconds
	              pausesAtSegmentEnd:(BOOL)pausesAtSegmentEnd
	         presentationGeneration:(NSUInteger)presentationGeneration
	              pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
	           rebuildsAudioOutput:(BOOL)rebuildsAudioOutput
	                             error:(NSError **)error {
    if (_formatContext == NULL || _videoCodecContext == NULL || _videoStreamIndex < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(41, @"Native playback session is not prepared for seek.");
        }
        return NO;
    }

    CFTimeInterval seekStart = CACurrentMediaTime();
    [_packetQueueCondition lock];
    NSUInteger resetGeneration = _playbackGeneration;
    _audioResetInProgress = YES;
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];

    CFTimeInterval stopReadAheadStart = CACurrentMediaTime();
    [self stopPacketReadAheadForSeekAndClear];
    if (_audioDecodeQueue != NULL) {
        dispatch_sync(_audioDecodeQueue, ^{});
    }
    double stopReadAheadMs = (CACurrentMediaTime() - stopReadAheadStart) * 1000.0;

    CFTimeInterval avSeekStart = CACurrentMediaTime();
    if (!SFXSeekToStartPosition(_formatContext, _videoStreamIndex, seekSeconds, _timelineOriginSeconds, error)) {
        [_packetQueueCondition lock];
        _audioResetInProgress = NO;
        [_packetQueueCondition broadcast];
        [_packetQueueCondition unlock];
        if (_audioDecodeQueue != NULL) {
            dispatch_sync(_audioDecodeQueue, ^{});
        }

        [_packetQueueCondition lock];
        BOOL shouldCompleteSegmentDrain = resetGeneration == _playbackGeneration
            && !_audioResetInProgress
            && _outstandingAudioBufferCount == 0
            && _pendingAudioCompletionRecordCount == 0;
        if (shouldCompleteSegmentDrain) {
            @synchronized (self) {
                shouldCompleteSegmentDrain = _segmentWaitingForAudioCompletion
                    && !_segmentAudioPlaybackCompleted;
            }
        }
        [_packetQueueCondition unlock];
        if (shouldCompleteSegmentDrain) {
            [self markSegmentAudioDrainCompleted];
        }
        [self startPacketReadAhead];
        [self requestAudioDrain];
        return NO;
    }
    double avSeekMs = (CACurrentMediaTime() - avSeekStart) * 1000.0;

    [_packetQueueCondition lock];
    _playbackGeneration += 1;
    NSUInteger generation = _playbackGeneration;
    _presentationGeneration = presentationGeneration;
    _audioDrainScheduled = NO;
    _audioPrimed = _audioCodecContext == NULL;
    _audioInputEnded = NO;
    _audioOutputDrained = _audioCodecContext == NULL;
    _audioFirstScheduledMediaSeconds = -1;
    _queuedAudioMediaSeconds = 0;
    _outstandingAudioBufferCount = 0;
    _pendingAudioCompletionRecordCount = 0;
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];
    [self signalPacingCondition];

    __block BOOL audioOutputReady = YES;
    __block NSError *audioOutputError = nil;
    if (_audioDecodeQueue != NULL) {
        dispatch_sync(_audioDecodeQueue, ^{
            _pendingCoalescedAudioBuffer = nil;
            _pendingCoalescedAudioStartMediaSeconds = -1;
            if (rebuildsAudioOutput) {
                [self teardownAudioOutput];
                audioOutputReady = [self prepareAudioOutputWithError:&audioOutputError];
            } else {
                [_audioPlayer stop];
            }
            if (_audioCodecContext != NULL) {
                avcodec_flush_buffers(_audioCodecContext);
            }
            if (_audioFrame != NULL) {
                av_frame_unref(_audioFrame);
            }
            if (_convertedAudioFrame != NULL) {
                av_frame_unref(_convertedAudioFrame);
            }
            if (_resampler != NULL) {
                swr_close(_resampler);
                swr_init(_resampler);
            }
        });
    }

    avcodec_flush_buffers(_videoCodecContext);
    av_packet_unref(_packet);
    av_frame_unref(_videoFrame);

    [self clearPendingPixelBufferSubmission];
    [self resetSegmentBoundaryState];

    double now = CACurrentMediaTime();
	    @synchronized (self) {
	        _seekSeconds = seekSeconds;
	        _segmentEndSeconds = segmentEndSeconds;
	        _pausesAtSegmentEnd = pausesAtSegmentEnd && segmentEndSeconds >= 0;
	        _autoPauseAuthorizationResolved = NO;
	        _autoPauseAuthorized = NO;
	        _segmentEndReached = NO;
	        _segmentFinishNotified = NO;
	        _currentTime = seekSeconds;
        _audioClockInitialized = NO;
        _audioPlayerStarted = NO;
        _audioStartRequested = NO;
        _videoClockInitialized = NO;
        _isRebuffering = NO;
        _isPausedInsideLoop = NO;
        _rebufferStartedHostSeconds = 0;
        _pauseStartedHostSeconds = 0;
        _lastVideoOutputHostSeconds = now;
        _lastDelegateUpdateHostSeconds = 0;
    }

    _perfOpenStartHostSeconds = seekStart;
    _perfStartHostSeconds = now;
    _perfFirstPacketHostSeconds = 0;
    _perfFirstVideoPacketHostSeconds = 0;
    _perfFirstVideoDecodedHostSeconds = 0;
    _perfAudioPrimeWaitMs = 0;
    _perfFirstFrameEnqueuedHostSeconds = 0;
    _perfVideoPacketsForFirstFrame = 0;
    _perfSkippedVideoFramesForFirstFrame = 0;
    _perfFirstPacketRecorded = NO;
    _perfFirstVideoDecodedRecorded = NO;
    NSLog(@"[PlaybackPerf] IN_SESSION_SEEK_PREPARE gen=%lu targetMs=%ld totalSeekPrepare=%.1fms | stopReadAhead=%.1fms avSeekFrame=%.1fms",
          (unsigned long)presentationGeneration,
          (long)llround(seekSeconds * 1000.0),
          (now - seekStart) * 1000.0,
          stopReadAheadMs,
          avSeekMs);

	    atomic_store(&_pauseAfterFirstFrame, pauseAfterFirstFrame);
	    atomic_store(&_didPauseAfterFirstFrame, false);
	    atomic_store(&_segmentEnding, false);
	    atomic_store(&_paused, !audioOutputReady);
    atomic_store(&_playing, audioOutputReady && !pauseAfterFirstFrame);
    [_packetQueueCondition lock];
    if (generation == _playbackGeneration) {
        _audioResetInProgress = NO;
    }
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];
    [self signalPacingCondition];
    [self notifyTimeIfNeeded:YES];
    if (!audioOutputReady) {
        if (error != NULL) {
            *error = audioOutputError ?: SFXNativePlaybackError(37, @"Audio output recovery failed.");
        }
        return NO;
    }
    [self startPacketReadAhead];
    [self requestAudioDrain];
    return YES;
}

@end
