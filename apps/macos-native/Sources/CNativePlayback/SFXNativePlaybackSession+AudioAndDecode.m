#import "SFXNativePlaybackInternal.h"

@implementation SFXNativePlaybackSession (AudioAndDecode)

- (void)decodeLoop {
    atomic_store(&_playing, !atomic_load(&_paused));
    @synchronized (self) {
        _lastVideoOutputHostSeconds = CACurrentMediaTime();
    }
    [self notifyTimeIfNeeded:YES];
    [self startPacketReadAhead];
    [self waitUntilPacketQueueHasStartupWaterline];

	    while (!atomic_load(&_cancelled)
	           && !atomic_load(&_segmentEnding)
	           && !atomic_load(&_finishingForAutomaticRecycle)) {
        [self waitWhileAudioOutputRecoveryRequestedIfNeeded];
        if ([self performPendingSeekIfNeeded]) {
            continue;
        }

        [self waitWhilePausedIfNeeded];
        [self waitWhileAudioOutputRecoveryRequestedIfNeeded];
        if ([self performPendingSeekIfNeeded]) {
            continue;
        }

	        if (atomic_load(&_cancelled) || atomic_load(&_segmentEnding)) {
	            break;
	        }

        SFXQueuedPacket *queuedPacket = [self dequeueVideoPacket];
        if (queuedPacket == NULL) {
            [self waitWhileAudioOutputRecoveryRequestedIfNeeded];
            if ([self performPendingSeekIfNeeded]) {
                continue;
            }
            if ([self waitForAutoStopSeekIfNeeded]) {
                continue;
            }
            break;
        }

        AVPacket *packet = queuedPacket->packet;
        if (packet->stream_index == _videoStreamIndex) {
            if ([self segmentVideoBoundaryReached]) {
                SFXFreeQueuedPacket(queuedPacket);
                continue;
            }
            [self handleVideoPacket:packet];
        }

        SFXFreeQueuedPacket(queuedPacket);
    }

	    BOOL cancelled = atomic_load(&_cancelled);
	    BOOL segmentEnding = atomic_load(&_segmentEnding);
	    BOOL finishingForAutomaticRecycle = atomic_load(&_finishingForAutomaticRecycle);
	    if (!cancelled && !finishingForAutomaticRecycle) {
	        [self resumeFromRebufferIfNeededAtHostSeconds:CACurrentMediaTime()];
	        if ([self hasActiveSegmentEnd] && ![self segmentVideoBoundaryReached]) {
	            [self markSegmentVideoBoundaryReached];
	        }
	        segmentEnding = atomic_load(&_segmentEnding);
	    }
	    BOOL hasActiveSegmentEnd = [self hasActiveSegmentEnd];
	    if (cancelled || segmentEnding || finishingForAutomaticRecycle || hasActiveSegmentEnd) {
	        atomic_store(&_playing, false);
	        if (!cancelled && !segmentEnding && !finishingForAutomaticRecycle) {
	            [self notifyTimeIfNeeded:YES];
	        }
	    }
    [_packetQueueCondition lock];
    BOOL neededAudioDrainUnblock = !_firstVideoFrameDecodedForSeek;
    _firstVideoFrameDecodedForSeek = YES;
    atomic_store(&_decodeLoopFinished, true);
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];
    if (neededAudioDrainUnblock && !cancelled && !finishingForAutomaticRecycle) {
        [self requestAudioDrain];
    }
    [self signalPacingCondition];
}

- (void)waitWhileAudioOutputRecoveryRequestedIfNeeded {
    [_packetQueueCondition lock];
    while (_audioOutputRecoveryRequested
           && ![self hasPendingSeekRequestLocked]
           && !atomic_load(&_cancelled)
           && !atomic_load(&_segmentEnding)
           && !atomic_load(&_finishingForAutomaticRecycle)) {
        [_packetQueueCondition wait];
    }
    [_packetQueueCondition unlock];
}

- (void)waitWhilePausedIfNeeded {
    if (!atomic_load(&_paused)) {
        return;
    }

	    [_packetQueueCondition lock];
	    while (atomic_load(&_paused)
	           && !_audioOutputRecoveryRequested
	           && !atomic_load(&_cancelled)
	           && !atomic_load(&_segmentEnding)
	           && ![self hasPendingSeekRequestLocked]) {
	        [_packetQueueCondition wait];
	    }
	    [_packetQueueCondition unlock];
}

- (void)startStarvationWatchdog {
    [self stopStarvationWatchdog];

    dispatch_source_t timer = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_TIMER,
        0,
        0,
        _starvationQueue
    );
    if (timer == NULL) {
        return;
    }

    dispatch_source_set_timer(
        timer,
        DISPATCH_TIME_FOREVER,
        DISPATCH_TIME_FOREVER,
        0
    );

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(timer, ^{
        [weakSelf checkVideoStarvation];
    });

    _starvationTimer = timer;
    dispatch_resume(timer);
    if (atomic_load(&_decodeWaitingForPacket)) {
        [self armStarvationWatchdog];
    }
}

- (void)armStarvationWatchdog {
    dispatch_source_t timer = _starvationTimer;
    if (timer == NULL) {
        return;
    }
    uint64_t intervalNanoseconds = (uint64_t)(SFXVideoStarvationWatchdogIntervalSeconds * NSEC_PER_SEC);
    dispatch_source_set_timer(
        timer,
        dispatch_time(DISPATCH_TIME_NOW, intervalNanoseconds),
        intervalNanoseconds,
        (uint64_t)(0.01 * NSEC_PER_SEC)
    );
}

- (void)disarmStarvationWatchdog {
    dispatch_source_t timer = _starvationTimer;
    if (timer == NULL) {
        return;
    }
    dispatch_source_set_timer(
        timer,
        DISPATCH_TIME_FOREVER,
        DISPATCH_TIME_FOREVER,
        0
    );
}

- (void)stopStarvationWatchdog {
    if (_starvationTimer != NULL) {
        dispatch_source_cancel(_starvationTimer);
        _starvationTimer = NULL;
    }
}

- (void)checkVideoStarvation {
    if (atomic_load(&_cancelled)
        || atomic_load(&_paused)
        || atomic_load(&_segmentEnding)
        || [self isSegmentBoundaryDrainInProgress]
        || atomic_load(&_finishingForAutomaticRecycle)) {
        return;
    }

    double now = CACurrentMediaTime();
    BOOL waitingForPacket = atomic_load(&_decodeWaitingForPacket);
    if (!waitingForPacket) {
        [self disarmStarvationWatchdog];
        return;
    }
    BOOL shouldPauseAudio = NO;
    double starvationSeconds = 0;
    @synchronized (self) {
        if (_isRebuffering
            || !_audioPlayerStarted
            || !_audioClockInitialized
            || _lastVideoOutputHostSeconds <= 0) {
            return;
        }

        starvationSeconds = now - _lastVideoOutputHostSeconds;
        if (starvationSeconds < SFXVideoStarvationThresholdSeconds) {
            return;
        }

        _isRebuffering = YES;
        _rebufferStartedHostSeconds = now;
        _rebufferCount += 1;
        _lastRebufferStartedWhileWaitingForPacket = waitingForPacket;
        shouldPauseAudio = YES;
    }

    if (shouldPauseAudio) {
        [self disarmStarvationWatchdog];
        dispatch_async(_audioDecodeQueue, ^{
            [_audioPlayer pause];
        });
        printf(
            "Native playback rebuffer: state=start starvation=%.3fs threshold=%.3fs waiting_for_packet=%s\n",
            starvationSeconds,
            SFXVideoStarvationThresholdSeconds,
            waitingForPacket ? "yes" : "no"
        );
    }
}

- (void)resumeFromRebufferIfNeededAtHostSeconds:(double)hostSeconds {
    BOOL shouldResumeAudio = NO;
    double rebufferDuration = 0;
    @synchronized (self) {
        if (!_isRebuffering) {
            return;
        }

        rebufferDuration = fmax(0, hostSeconds - _rebufferStartedHostSeconds);
        if (_audioClockInitialized) {
            _audioStartHostSeconds += rebufferDuration;
        }
        if (_videoClockInitialized) {
            _videoStartHostSeconds += rebufferDuration;
        }
        _isRebuffering = NO;
        _rebufferStartedHostSeconds = 0;
        _lastVideoOutputHostSeconds = hostSeconds;
        _lastRebufferDurationMilliseconds = (NSInteger)llround(rebufferDuration * 1000.0);
        shouldResumeAudio = _audioPlayerStarted && !atomic_load(&_paused);
    }
    [self signalPacingCondition];

    if (shouldResumeAudio) {
        dispatch_async(_audioDecodeQueue, ^{
            if (!atomic_load(&_paused)
                && !atomic_load(&_cancelled)
                && !atomic_load(&_segmentEnding)
                && !atomic_load(&_finishingForAutomaticRecycle)) {
                [_audioPlayer play];
            }
        });
    }

    printf(
        "Native playback rebuffer: state=end duration=%.3fs\n",
        rebufferDuration
    );
}

- (BOOL)ensureSoftwareVideoScalerForFrame:(AVFrame *)frame
                                    width:(int)width
                                   height:(int)height
                             outputFormat:(enum AVPixelFormat)outputFormat {
    enum AVPixelFormat inputFormat = (enum AVPixelFormat)frame->format;
    if (_videoScaler != NULL
        && _videoScalerWidth == width
        && _videoScalerHeight == height
        && _videoScalerInputFormat == inputFormat
        && _videoScalerOutputFormat == outputFormat) {
        return YES;
    }

    sws_freeContext(_videoScaler);
    _videoScaler = sws_getContext(
        width,
        height,
        inputFormat,
        width,
        height,
        outputFormat,
        SWS_BILINEAR,
        NULL,
        NULL,
        NULL
    );

    if (_videoScaler == NULL) {
        _videoScalerWidth = 0;
        _videoScalerHeight = 0;
        _videoScalerInputFormat = AV_PIX_FMT_NONE;
        _videoScalerOutputFormat = AV_PIX_FMT_NONE;
        return NO;
    }

    _videoScalerWidth = width;
    _videoScalerHeight = height;
    _videoScalerInputFormat = inputFormat;
    _videoScalerOutputFormat = outputFormat;
    return YES;
}

- (BOOL)ensureSoftwarePixelBufferPoolWithWidth:(int)width
                                        height:(int)height
                                   pixelFormat:(OSType)pixelFormat {
    if (_softwarePixelBufferPool != NULL
        && _softwarePixelBufferWidth == width
        && _softwarePixelBufferHeight == height
        && _softwarePixelBufferFormatType == pixelFormat) {
        return YES;
    }

    if (_softwarePixelBufferPool != NULL) {
        CVPixelBufferPoolRelease(_softwarePixelBufferPool);
        _softwarePixelBufferPool = NULL;
    }

    int pixelFormatValue = (int)pixelFormat;
    int bufferWidth = width;
    int bufferHeight = height;
    CFNumberRef pixelFormatNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &pixelFormatValue);
    CFNumberRef widthNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bufferWidth);
    CFNumberRef heightNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bufferHeight);
    CFDictionaryRef ioSurfaceProperties = CFDictionaryCreate(
        kCFAllocatorDefault,
        NULL,
        NULL,
        0,
        &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks
    );

    if (pixelFormatNumber == NULL || widthNumber == NULL || heightNumber == NULL || ioSurfaceProperties == NULL) {
        if (pixelFormatNumber != NULL) {
            CFRelease(pixelFormatNumber);
        }
        if (widthNumber != NULL) {
            CFRelease(widthNumber);
        }
        if (heightNumber != NULL) {
            CFRelease(heightNumber);
        }
        if (ioSurfaceProperties != NULL) {
            CFRelease(ioSurfaceProperties);
        }
        return NO;
    }

    const void *keys[] = {
        kCVPixelBufferPixelFormatTypeKey,
        kCVPixelBufferWidthKey,
        kCVPixelBufferHeightKey,
        kCVPixelBufferIOSurfacePropertiesKey
    };
    const void *values[] = {
        pixelFormatNumber,
        widthNumber,
        heightNumber,
        ioSurfaceProperties
    };
    CFDictionaryRef attributes = CFDictionaryCreate(
        kCFAllocatorDefault,
        keys,
        values,
        4,
        &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks
    );

    CFRelease(pixelFormatNumber);
    CFRelease(widthNumber);
    CFRelease(heightNumber);
    CFRelease(ioSurfaceProperties);

    if (attributes == NULL) {
        return NO;
    }

    CVReturn result = CVPixelBufferPoolCreate(
        kCFAllocatorDefault,
        NULL,
        attributes,
        &_softwarePixelBufferPool
    );
    CFRelease(attributes);

    if (result != kCVReturnSuccess || _softwarePixelBufferPool == NULL) {
        _softwarePixelBufferWidth = 0;
        _softwarePixelBufferHeight = 0;
        _softwarePixelBufferFormatType = 0;
        return NO;
    }

    _softwarePixelBufferWidth = width;
    _softwarePixelBufferHeight = height;
    _softwarePixelBufferFormatType = pixelFormat;
    return YES;
}

- (CVPixelBufferRef)copyPixelBufferForSoftwareFrame:(AVFrame *)frame {
    int width = frame->width > 0 ? frame->width : _videoCodecContext->width;
    int height = frame->height > 0 ? frame->height : _videoCodecContext->height;
    enum AVPixelFormat inputFormat = (enum AVPixelFormat)frame->format;
    if (width <= 0
        || height <= 0
        || inputFormat == AV_PIX_FMT_NONE
        || av_pix_fmt_desc_get(inputFormat) == NULL) {
        return NULL;
    }

    BOOL hasEvenDimensions = ((width & 1) == 0 && (height & 1) == 0);
    BOOL canUseNV12 = hasEvenDimensions
        && (inputFormat == AV_PIX_FMT_YUV420P
            || inputFormat == AV_PIX_FMT_YUVJ420P
            || inputFormat == AV_PIX_FMT_NV12);
    BOOL canUseP010 = hasEvenDimensions
        && (inputFormat == AV_PIX_FMT_YUV420P10LE
            || inputFormat == AV_PIX_FMT_P010LE);
    enum AVPixelFormat targetFFmpegFormat = canUseP010
        ? AV_PIX_FMT_P010LE
        : (canUseNV12 ? AV_PIX_FMT_NV12 : AV_PIX_FMT_BGRA);
    AVStream *videoStream = (_formatContext != NULL && _videoStreamIndex >= 0 && _videoStreamIndex < (int)_formatContext->nb_streams)
        ? _formatContext->streams[_videoStreamIndex]
        : NULL;
    BOOL isFullRange = SFXResolveVideoIsFullRange(videoStream, _videoCodecContext, frame, inputFormat);
    OSType targetCVPixelFormat = canUseP010
        ? (isFullRange ? kCVPixelFormatType_420YpCbCr10BiPlanarFullRange : kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        : (canUseNV12
            ? (isFullRange ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
            : kCVPixelFormatType_32BGRA);

    if (![self ensureSoftwarePixelBufferPoolWithWidth:width height:height pixelFormat:targetCVPixelFormat]) {
        return NULL;
    }

    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn createResult = CVPixelBufferPoolCreatePixelBuffer(
        kCFAllocatorDefault,
        _softwarePixelBufferPool,
        &pixelBuffer
    );
    if (createResult != kCVReturnSuccess || pixelBuffer == NULL) {
        return NULL;
    }

    BOOL fastPacked = SFXFastPackSoftwareAVFrameIntoPixelBuffer(frame, pixelBuffer);
    if (!fastPacked) {
        if (![self ensureSoftwareVideoScalerForFrame:frame width:width height:height outputFormat:targetFFmpegFormat]) {
            CVPixelBufferRelease(pixelBuffer);
            return NULL;
        }
        SFXConfigureSwsContextColorSpace(
            _videoScaler,
            videoStream,
            _videoCodecContext,
            frame,
            width,
            height,
            inputFormat,
            targetFFmpegFormat
        );

        CVReturn lockResult = CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        if (lockResult != kCVReturnSuccess) {
            CVPixelBufferRelease(pixelBuffer);
            return NULL;
        }

        uint8_t *destinationData[4] = { NULL, NULL, NULL, NULL };
        int destinationLinesize[4] = { 0, 0, 0, 0 };
        if (CVPixelBufferIsPlanar(pixelBuffer)) {
            destinationData[0] = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
            destinationData[1] = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
            destinationLinesize[0] = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
            destinationLinesize[1] = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
        } else {
            destinationData[0] = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
            destinationLinesize[0] = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
        }

        int convertedHeight = sws_scale(
            _videoScaler,
            (const uint8_t * const *)frame->data,
            frame->linesize,
            0,
            height,
            destinationData,
            destinationLinesize
        );
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

        if (convertedHeight <= 0) {
            CVPixelBufferRelease(pixelBuffer);
            return NULL;
        }
    }

    SFXApplyColorSpaceAttachments(pixelBuffer, videoStream, _videoCodecContext, frame);
    SFXAttachHDRMetadataToPixelBuffer(pixelBuffer, _videoCodecContext, videoStream, frame);
    return pixelBuffer;
}

- (void)handleVideoPacket:(AVPacket *)packet {
    BOOL isKeyframePacket = (packet->flags & AV_PKT_FLAG_KEY) != 0;
    if (!_seenVideoKeyframePacketSinceFlush) {
        if (isKeyframePacket || _skippedNonKeyframePacketsSinceFlush >= 180) {
            _seenVideoKeyframePacketSinceFlush = YES;
        } else {
            _skippedNonKeyframePacketsSinceFlush += 1;
            return;
        }
    }

    if (!_perfFirstVideoDecodedRecorded) {
        if (_perfFirstVideoPacketHostSeconds <= 0) {
            _perfFirstVideoPacketHostSeconds = CACurrentMediaTime();
        }
        _perfVideoPacketsForFirstFrame += 1;
    }

    CFTimeInterval sendPacketStart = CACurrentMediaTime();
    int result = avcodec_send_packet(_videoCodecContext, packet);
    if (result < 0
        && result != AVERROR(EAGAIN)
        && result != AVERROR_EOF
        && isKeyframePacket
        && self.usingHardwareDecode
        && !_perfFirstVideoDecodedRecorded
        && _presentedVideoFrameCount == 0) {
        NSString *sendError = SFXFFmpegErrorString(result);
        NSError *softwareError = nil;
        [self resetVideoDecoderState];
        _allowAutomaticSoftwareRecycle = NO;
        if ([self prepareSoftwareVideoWithError:&softwareError]) {
            const char *decoderName = (_videoCodecContext != NULL && _videoCodecContext->codec != NULL)
                ? _videoCodecContext->codec->name
                : "unknown";
            NSLog(@"[Playback] Gate 2 (First-Packet Software Fallback): hardware video decode failed on initial packet (%@), switched to Software (%s).",
                  sendError,
                  decoderName);
            result = avcodec_send_packet(_videoCodecContext, packet);
        } else {
            NSLog(@"[Playback] Gate 2 (First-Packet Software Fallback) FAILED: hardware error=%@, software error=%@",
                  sendError,
                  softwareError.localizedDescription ?: @"unknown");
        }
    }
    if (result < 0) {
        return;
    }
    double sendPacketDurationMs = (CACurrentMediaTime() - sendPacketStart) * 1000.0;

    AVStream *videoStream = _formatContext->streams[_videoStreamIndex];
    while (YES) {
        CFTimeInterval receiveStart = CACurrentMediaTime();
        result = avcodec_receive_frame(_videoCodecContext, _videoFrame);
        if (result < 0) {
            break;
        }
        double frameDecodeMs = sendPacketDurationMs + (CACurrentMediaTime() - receiveStart) * 1000.0;
        sendPacketDurationMs = 0.0;
        [_packetQueueCondition lock];
        BOOL hasPendingSeek = [self hasPendingSeekRequestLocked] || _audioOutputRecoveryRequested;
        [_packetQueueCondition unlock];
        if (hasPendingSeek) {
            av_frame_unref(_videoFrame);
            break;
        }
        if (!_firstVideoFrameDecodedForSeek
            && SFXFrameBeforeSeekTarget(_videoFrame, videoStream, _seekSeconds, _timelineOriginSeconds)) {
            if (!_perfFirstVideoDecodedRecorded) {
                _perfSkippedVideoFramesForFirstFrame += 1;
            }
            av_frame_unref(_videoFrame);
            continue;
        }
        if (!_perfFirstVideoDecodedRecorded) {
            _perfFirstVideoDecodedRecorded = YES;
            _perfFirstVideoDecodedHostSeconds = CACurrentMediaTime();
        }

        double mediaSeconds = SFXFramePlaybackSeconds(_videoFrame, videoStream, _timelineOriginSeconds);
        if (!_firstVideoFrameDecodedForSeek) {
            @synchronized (self) {
                if (isfinite(mediaSeconds)
                    && mediaSeconds > _seekSeconds + 0.25
                    && (![self hasActiveSegmentEnd] || mediaSeconds < _segmentEndSeconds)) {
                    _seekSeconds = mediaSeconds;
                }
            }
            [_packetQueueCondition lock];
            _firstVideoFrameDecodedForSeek = YES;
            [_packetQueueCondition broadcast];
            [_packetQueueCondition unlock];
            [self requestAudioDrain];
        }
        if ([self mediaSecondsReachedSegmentEnd:mediaSeconds]) {
            if ([self resolveAutoPauseAuthorizationIfNeeded]) {
                [self resumeFromRebufferIfNeededAtHostSeconds:CACurrentMediaTime()];
                [self markSegmentVideoBoundaryReached];
                [self startAudioForDrainAfterVideoDecodeIfNeeded];
                av_frame_unref(_videoFrame);
                break;
            }
        }

        CMTime presentationTime = SFXFramePresentationTime(_videoFrame, videoStream, _timelineOriginSeconds);
        NSInteger frameMilliseconds = mediaSeconds >= 0
            ? (NSInteger)llround(mediaSeconds * 1000.0)
            : -1;
        AVRational frameSAR = SFXVideoSampleAspectRatio(_formatContext, videoStream, _videoCodecContext, _videoFrame);
        SFXVideoOrientation frameOrientation = SFXResolveVideoOrientation(videoStream, _videoFrame);
        int frameWidth = _videoFrame->width > 0 ? _videoFrame->width : _videoCodecContext->width;
        int frameHeight = _videoFrame->height > 0 ? _videoFrame->height : _videoCodecContext->height;
        @synchronized (self) {
            _videoSampleAspectRatio = frameSAR;
            _videoOrientation = frameOrientation;
            if (frameWidth > 0 && frameHeight > 0) {
                _videoFrameWidth = frameWidth;
                _videoFrameHeight = frameHeight;
            }
        }
        NSInteger automaticRecycleMilliseconds = -1;
        BOOL submittedVideoFrame = NO;
        if (_videoFrame->format == AV_PIX_FMT_VIDEOTOOLBOX || _videoFrame->format == SFXHardwarePixelFormat) {
            if (![self paceVideoFrame:_videoFrame stream:videoStream]) {
                av_frame_unref(_videoFrame);
                break;
            }
            CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)_videoFrame->data[3];
            CFTimeInterval metadataStart = CACurrentMediaTime();
            SFXApplyColorSpaceAttachments(pixelBuffer, videoStream, _videoCodecContext, _videoFrame);
            SFXAttachHDRMetadataToPixelBuffer(pixelBuffer, _videoCodecContext, videoStream, _videoFrame);
            SFXApplyPixelAspectRatioAttachment(pixelBuffer, frameSAR);
            SFXApplyVideoOrientationAttachment(pixelBuffer, frameOrientation);
            frameDecodeMs += (CACurrentMediaTime() - metadataStart) * 1000.0;
            @synchronized (self) {
                _lastFrameDecodeDurationMs = frameDecodeMs;
            }
            submittedVideoFrame = [self enqueuePixelBuffer:pixelBuffer
                                          presentationTime:presentationTime
                                         sampleAspectRatio:frameSAR
                                         frameMilliseconds:frameMilliseconds
                              automaticRecycleMilliseconds:automaticRecycleMilliseconds];
        } else {
            if (self.usingHardwareDecode) {
                NSString *formatName = SFXPixelFormatName((enum AVPixelFormat)_videoFrame->format);
                const char *decoderName = (_videoCodecContext != NULL && _videoCodecContext->codec != NULL)
                    ? _videoCodecContext->codec->name
                    : "unknown";
                NSLog(@"[Playback] Gate 2 (First-Frame Software Fallback): decoder=%s produced software frame (%@) while in Hardware mode; switching session to Software rendering.",
                      decoderName,
                      formatName);
                @synchronized (self) {
                    _usingHardwareDecode = NO;
                }
                _allowAutomaticSoftwareRecycle = NO;
            }
            if (![self paceVideoFrame:_videoFrame stream:videoStream]) {
                av_frame_unref(_videoFrame);
                break;
            }
            CFTimeInterval copyStart = CACurrentMediaTime();
            CVPixelBufferRef pixelBuffer = [self copyPixelBufferForSoftwareFrame:_videoFrame];
            if (pixelBuffer == NULL) {
                NSString *formatName = SFXPixelFormatName((enum AVPixelFormat)_videoFrame->format);
                [self notifyFailure:[NSString stringWithFormat:
                    @"Software video frame conversion failed for %@.",
                    formatName
                ]];
                atomic_store(&_cancelled, true);
                av_frame_unref(_videoFrame);
                break;
            }
            SFXApplyPixelAspectRatioAttachment(pixelBuffer, frameSAR);
            SFXApplyVideoOrientationAttachment(pixelBuffer, frameOrientation);
            frameDecodeMs += (CACurrentMediaTime() - copyStart) * 1000.0;
            @synchronized (self) {
                _lastFrameDecodeDurationMs = frameDecodeMs;
            }

            automaticRecycleMilliseconds = [self markAutomaticSoftwareRecycleIfNeededAtMediaSeconds:mediaSeconds];
            submittedVideoFrame = [self enqueuePixelBuffer:pixelBuffer
                                          presentationTime:presentationTime
                                         sampleAspectRatio:frameSAR
                                         frameMilliseconds:frameMilliseconds
                              automaticRecycleMilliseconds:automaticRecycleMilliseconds];
            CVPixelBufferRelease(pixelBuffer);
        }

        if (submittedVideoFrame && mediaSeconds >= 0) {
            [_packetQueueCondition lock];
            BOOL canAdvanceCurrentTime = !_seekRequestPending
                && !_seekRequestInProgress
                && !_audioResetInProgress;
            [_packetQueueCondition unlock];
            if (canAdvanceCurrentTime) {
                @synchronized (self) {
                    _currentTime = mediaSeconds;
                    _lastSubmittedVideoFrameMilliseconds = (NSInteger)floor(mediaSeconds * 1000.0);
                }
                [self notifyTimeIfNeeded:NO];
            }
        }

        BOOL finishForRecycle = atomic_load(&_finishingForAutomaticRecycle);
        if (submittedVideoFrame
            && !finishForRecycle
            && atomic_load(&_pauseAfterFirstFrame)) {
            if (!atomic_load(&_didPauseAfterFirstFrame)) {
                [self setPaused:YES];
                atomic_store(&_didPauseAfterFirstFrame, true);
            }
            av_frame_unref(_videoFrame);
            break;
        }
        av_frame_unref(_videoFrame);
        if (finishForRecycle) {
            break;
        }
    }
}

- (void)handleAudioPacket:(AVPacket *)packet generation:(NSUInteger)generation {
    [_packetQueueCondition lock];
    BOOL generationIsCurrent = generation == _playbackGeneration && !_audioResetInProgress;
    [_packetQueueCondition unlock];
    if (!generationIsCurrent) {
        return;
    }

    int result = avcodec_send_packet(_audioCodecContext, packet);
    if (result < 0) {
        return;
    }

    AVStream *audioStream = _formatContext->streams[_audioStreamIndex];
    while ((result = avcodec_receive_frame(_audioCodecContext, _audioFrame)) >= 0) {
        if (!_firstAudioFrameDecodedForSeek
            && SFXFrameBeforeSeekTarget(_audioFrame, audioStream, _seekSeconds, _timelineOriginSeconds)) {
            av_frame_unref(_audioFrame);
            continue;
        }
        _firstAudioFrameDecodedForSeek = YES;
        SFXEnsureValidChannelLayout(&_audioFrame->ch_layout, _audioCodecContext->ch_layout.nb_channels);

	        double mediaSeconds = SFXFramePlaybackSeconds(_audioFrame, audioStream, _timelineOriginSeconds);
	        const AVFrame *outputFrame = [self outputAudioFrameForFrame:_audioFrame];
	        if (outputFrame != NULL) {
	            SFXAudioScheduleResult scheduleResult = [self scheduleAudioFrame:outputFrame
	                                                               mediaSeconds:mediaSeconds
	                                                                 generation:generation];
	            if (scheduleResult == SFXAudioScheduleResultScheduledFinalSegmentBuffer
	                || scheduleResult == SFXAudioScheduleResultSegmentBoundaryReached) {
	                av_frame_unref(_audioFrame);
	                break;
	            }
	        }

        av_frame_unref(_audioFrame);
    }
}

- (BOOL)waitForAudioPrimeForGeneration:(NSUInteger)generation {
    if (_audioCodecContext == NULL
        || (atomic_load(&_pauseAfterFirstFrame) && !atomic_load(&_didPauseAfterFirstFrame))) {
        return YES;
    }

    [_packetQueueCondition lock];
    while (generation == _playbackGeneration
           && !_audioPrimed
           && !_audioResetInProgress
           && ![self hasPendingSeekRequestLocked]
           && !atomic_load(&_cancelled)
           && !atomic_load(&_segmentEnding)
           && !atomic_load(&_finishingForAutomaticRecycle)) {
        [_packetQueueCondition wait];
    }
    BOOL ready = generation == _playbackGeneration
        && _audioPrimed
        && !_audioResetInProgress
        && ![self hasPendingSeekRequestLocked]
        && !atomic_load(&_cancelled)
        && !atomic_load(&_segmentEnding)
        && !atomic_load(&_finishingForAutomaticRecycle);
    [_packetQueueCondition unlock];
    return ready;
}

- (void)requestAudioPlaybackStartIfReadyForGeneration:(NSUInteger)generation {
    @synchronized (self) {
        if ((atomic_load(&_pauseAfterFirstFrame) && !atomic_load(&_didPauseAfterFirstFrame))
            || _isRebuffering) {
            return;
        }
    }
    BOOL shouldDeferForAutomaticRecycle = _allowAutomaticSoftwareRecycle
        && !self.usingHardwareDecode
        && !atomic_load(&_decodeLoopFinished)
        && ![self segmentVideoBoundaryReached];
    if (_audioCodecContext == NULL
        || shouldDeferForAutomaticRecycle
        || atomic_load(&_paused)
        || atomic_load(&_cancelled)
        || atomic_load(&_segmentEnding)
        || atomic_load(&_finishingForAutomaticRecycle)) {
        return;
    }

    [_packetQueueCondition lock];
    BOOL audioReady = generation == _playbackGeneration
        && _audioPrimed
        && !_audioResetInProgress
        && _audioFirstScheduledMediaSeconds >= 0;
    [_packetQueueCondition unlock];
    if (!audioReady) {
        return;
    }

    @synchronized (self) {
        if (_audioPlayerStarted || _audioStartRequested || !_audioClockInitialized) {
            return;
        }
        _audioStartRequested = YES;
    }

    dispatch_async(_audioDecodeQueue, ^{
        [_packetQueueCondition lock];
        BOOL generationIsCurrent = generation == _playbackGeneration
            && !_audioResetInProgress
            && _audioPrimed;
        double firstAudioMediaSeconds = _audioFirstScheduledMediaSeconds;
        [_packetQueueCondition unlock];

        BOOL shouldPlay = generationIsCurrent
            && firstAudioMediaSeconds >= 0
            && !atomic_load(&_paused)
            && !atomic_load(&_cancelled)
            && !atomic_load(&_segmentEnding)
            && !atomic_load(&_finishingForAutomaticRecycle);
        double targetHostSeconds = 0;
        @synchronized (self) {
            if (_audioPlayerStarted
                || !_audioClockInitialized
                || (atomic_load(&_pauseAfterFirstFrame) && !atomic_load(&_didPauseAfterFirstFrame))
                || _isRebuffering) {
                shouldPlay = NO;
            }
            if (shouldPlay) {
                double rate = fmax((double)atomic_load(&_playbackRate), 0.001);
                targetHostSeconds = _audioStartHostSeconds
                    + ((firstAudioMediaSeconds - _audioFirstMediaSeconds) / rate);
            }
            _audioStartRequested = NO;
        }

        if (!shouldPlay) {
            return;
        }

        double now = CACurrentMediaTime();
        if (targetHostSeconds > now + 0.001 && targetHostSeconds <= now + 5.0) {
            uint64_t hostTime = [AVAudioTime hostTimeForSeconds:targetHostSeconds];
            AVAudioTime *startTime = [[AVAudioTime alloc] initWithHostTime:hostTime];
            [_audioPlayer playAtTime:startTime];
        } else {
            [_audioPlayer play];
        }

        [_packetQueueCondition lock];
        if (generation == _playbackGeneration
            && !_audioResetInProgress
            && !atomic_load(&_cancelled)) {
            @synchronized (self) {
                _audioPlayerStarted = YES;
            }
        }
        [_packetQueueCondition unlock];
    });
}

- (BOOL)paceVideoFrame:(AVFrame *)frame stream:(AVStream *)stream {
    double mediaSeconds = SFXFramePlaybackSeconds(frame, stream, _timelineOriginSeconds);
    if (mediaSeconds < 0) {
        return YES;
    }

    [_packetQueueCondition lock];
    NSUInteger generation = _playbackGeneration;
    BOOL isFirstFrameForPresentation = _lastPresentedPresentationGeneration != _presentationGeneration;
    BOOL audioAlreadyPrimed = _audioPrimed
        || _audioCodecContext == NULL
        || (atomic_load(&_pauseAfterFirstFrame) && !atomic_load(&_didPauseAfterFirstFrame));
    [_packetQueueCondition unlock];
    if (isFirstFrameForPresentation && !audioAlreadyPrimed && !atomic_load(&_paused)) {
        @synchronized (self) {
            _perfAudioPrimeWaitMs = 0.0;
            _lastPacedVideoMediaSeconds = mediaSeconds;
            _lastVideoOutputHostSeconds = CACurrentMediaTime();
        }
        return YES;
    }
    CFTimeInterval audioPrimeWaitStart = CACurrentMediaTime();
    if (![self waitForAudioPrimeForGeneration:generation]) {
        return NO;
    }
    double audioPrimeWaitMs = (CACurrentMediaTime() - audioPrimeWaitStart) * 1000.0;

    double now = CACurrentMediaTime();
    [self resumeFromRebufferIfNeededAtHostSeconds:now];

    double targetHostSeconds = 0;
    BOOL initializedPlaybackClock = NO;
    BOOL recalibratedClockForDiscontinuity = NO;
    @synchronized (self) {
        double rate = fmax((double)atomic_load(&_playbackRate), 0.001);
        if (!_videoClockInitialized) {
            _perfAudioPrimeWaitMs = audioPrimeWaitMs;
            double anchorMediaSeconds = _seekSeconds;
            _videoClockInitialized = YES;
            _videoFirstMediaSeconds = anchorMediaSeconds;
            _videoStartHostSeconds = now;
            if (_audioCodecContext != NULL) {
                _audioClockInitialized = YES;
                _audioFirstMediaSeconds = anchorMediaSeconds;
                _audioStartHostSeconds = now;
            }
            initializedPlaybackClock = YES;
        } else if (_lastPacedVideoMediaSeconds >= 0) {
            double mediaDelta = mediaSeconds - _lastPacedVideoMediaSeconds;
            if (mediaDelta < -1.0 || mediaDelta > 10.0) {
                _videoFirstMediaSeconds = mediaSeconds;
                _videoStartHostSeconds = now;
                if (_audioClockInitialized) {
                    _audioFirstMediaSeconds = mediaSeconds;
                    _audioStartHostSeconds = now;
                }
                _currentTime = mediaSeconds;
                recalibratedClockForDiscontinuity = YES;
            }
        }
        _lastPacedVideoMediaSeconds = mediaSeconds;
        if (_audioClockInitialized) {
            targetHostSeconds = _audioStartHostSeconds + ((mediaSeconds - _audioFirstMediaSeconds) / rate);
        } else {
            targetHostSeconds = _videoStartHostSeconds + ((mediaSeconds - _videoFirstMediaSeconds) / rate);
        }
    }

    if (recalibratedClockForDiscontinuity) {
        [self notifyTimeIfNeeded:YES];
    }

    if (initializedPlaybackClock
        && !(atomic_load(&_pauseAfterFirstFrame) && !atomic_load(&_didPauseAfterFirstFrame))) {
        [self requestAudioPlaybackStartIfReadyForGeneration:generation];
    }

    while (targetHostSeconds > CACurrentMediaTime() || atomic_load(&_paused)) {
        [_pacingCondition lock];
        BOOL waitedForPause = atomic_load(&_paused);
        while (atomic_load(&_paused)
               && generation == _playbackGeneration
               && ![self hasPendingSeekRequestLocked]
               && !atomic_load(&_cancelled)
               && !atomic_load(&_segmentEnding)
               && !atomic_load(&_finishingForAutomaticRecycle)) {
            [_pacingCondition wait];
        }
        BOOL shouldAbort = generation != _playbackGeneration
            || [self hasPendingSeekRequestLocked]
            || atomic_load(&_cancelled)
            || atomic_load(&_segmentEnding)
            || atomic_load(&_finishingForAutomaticRecycle);
        if (!shouldAbort && !waitedForPause) {
            double waitSeconds = fmin(0.25, targetHostSeconds - CACurrentMediaTime());
            if (waitSeconds > 0) {
                [_pacingCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:waitSeconds]];
            }
        }
        [_pacingCondition unlock];
        if (shouldAbort) {
            return NO;
        }
        @synchronized (self) {
            double rate = fmax((double)atomic_load(&_playbackRate), 0.001);
            if (_audioClockInitialized) {
                targetHostSeconds = _audioStartHostSeconds
                    + ((mediaSeconds - _audioFirstMediaSeconds) / rate);
            } else {
                targetHostSeconds = _videoStartHostSeconds
                    + ((mediaSeconds - _videoFirstMediaSeconds) / rate);
            }
        }
    }

    @synchronized (self) {
        _lastVideoOutputHostSeconds = CACurrentMediaTime();
    }
    return YES;
}

- (CMSampleBufferRef)sampleBufferForPixelBuffer:(CVPixelBufferRef)pixelBuffer
                               presentationTime:(CMTime)presentationTime
                              sampleAspectRatio:(AVRational)sampleAspectRatio {
    CFTimeInterval start = SFXPerformanceNow();
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    BOOL validSAR = sampleAspectRatio.num > 0 && sampleAspectRatio.den > 0;
    int sarNum = validSAR ? sampleAspectRatio.num : 1;
    int sarDen = validSAR ? sampleAspectRatio.den : 1;
    uint64_t colorSignature = SFXPixelBufferColorSignature(pixelBuffer);
    if (_cachedVideoFormatDescription == NULL
        || _cachedVideoFormatPixelFormat != pixelFormat
        || _cachedVideoFormatWidth != width
        || _cachedVideoFormatHeight != height
        || _cachedVideoFormatSARNum != sarNum
        || _cachedVideoFormatSARDen != sarDen
        || _cachedVideoFormatColorSignature != colorSignature) {
        if (_cachedVideoFormatDescription != NULL) {
            CFRelease(_cachedVideoFormatDescription);
            _cachedVideoFormatDescription = NULL;
        }
        OSStatus descStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            kCFAllocatorDefault,
            pixelBuffer,
            &_cachedVideoFormatDescription
        );
        if (descStatus != noErr || _cachedVideoFormatDescription == NULL) {
            _cachedVideoFormatDescription = NULL;
            return NULL;
        }
        _cachedVideoFormatPixelFormat = pixelFormat;
        _cachedVideoFormatWidth = width;
        _cachedVideoFormatHeight = height;
        _cachedVideoFormatSARNum = sarNum;
        _cachedVideoFormatSARDen = sarDen;
        _cachedVideoFormatColorSignature = colorSignature;
    }

    CMSampleTimingInfo timing = {
        .duration = CMTimeMake(1, 60),
        .presentationTimeStamp = presentationTime,
        .decodeTimeStamp = kCMTimeInvalid
    };
    CMSampleBufferRef sampleBuffer = NULL;
    OSStatus status = CMSampleBufferCreateReadyWithImageBuffer(
        kCFAllocatorDefault,
        pixelBuffer,
        _cachedVideoFormatDescription,
        &timing,
        &sampleBuffer
    );

    if (status != noErr || sampleBuffer == NULL) {
        return NULL;
    }

    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    if (attachments != NULL && CFArrayGetCount(attachments) > 0) {
        CFMutableDictionaryRef attachment = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFDictionarySetValue(attachment, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
    }

    SFXLogIfSlow(@"SFXNativePlaybackSession.sampleBufferForPixelBuffer", start, 8);
    return sampleBuffer;
}

- (BOOL)enqueuePixelBuffer:(CVPixelBufferRef)pixelBuffer
          presentationTime:(CMTime)presentationTime
         sampleAspectRatio:(AVRational)sampleAspectRatio
         frameMilliseconds:(NSInteger)frameMilliseconds
automaticRecycleMilliseconds:(NSInteger)automaticRecycleMilliseconds {
    if (pixelBuffer == NULL) {
        return NO;
    }
    CFTimeInterval start = SFXPerformanceNow();
    if (_perfFirstFrameEnqueuedHostSeconds <= 0) {
        _perfFirstFrameEnqueuedHostSeconds = CACurrentMediaTime();
    }

    if (atomic_load(&_cancelled) || _displayLayer == nil) {
        return NO;
    }

    [_packetQueueCondition lock];
    BOOL sessionPresentationIsCurrent = !_seekRequestPending
        && !_seekRequestInProgress
        && !_audioResetInProgress
        && !atomic_load(&_cancelled);
    NSUInteger presentationGeneration = _presentationGeneration;
    BOOL firstFrameForPresentation = sessionPresentationIsCurrent
        && _lastPresentedPresentationGeneration != presentationGeneration;
    [_packetQueueCondition unlock];
    if (!sessionPresentationIsCurrent) {
        return NO;
    }

    @synchronized (self) {
        if (_latestSourceVideoPixelBuffer != NULL) {
            CVPixelBufferRelease(_latestSourceVideoPixelBuffer);
        }
        _latestSourceVideoPixelBuffer = CVPixelBufferRetain(pixelBuffer);
        _latestSourcePresentationTime = presentationTime;
        _latestSourceSampleAspectRatio = sampleAspectRatio;
        _latestSourceFrameMilliseconds = frameMilliseconds;
    }

    SFXNativePlaybackPlayer *owner = _owner;
    SFXNativePlaybackView *ownerView = owner.playbackView;
    BOOL streamIsHDR = SFXPixelBufferIsHDR(pixelBuffer);
    uint64_t sourceColorSig = SFXPixelBufferColorSignature(pixelBuffer);
    BOOL colorStateChanged = NO;
    BOOL isFirstColorStateLog = NO;
    @synchronized (self) {
        if (!_hasLoggedInitialColorState || _activeStreamColorSignature != sourceColorSig) {
            isFirstColorStateLog = !_hasLoggedInitialColorState;
            colorStateChanged = YES;
            _hasLoggedInitialColorState = YES;
            _activeStreamColorSignature = sourceColorSig;
            _activeStreamIsHDR = streamIsHDR;
        }
    }
    if (colorStateChanged && ownerView != nil) {
        [ownerView updateForStreamHDRState:streamIsHDR];
    }
    BOOL displayHDRActive = ownerView != nil ? ownerView.isDisplayHDRActive : NO;
    CGFloat edrHeadroom = ownerView != nil ? ownerView.displayEDRHeadroom : 1.0;
#if DEBUG
    if (colorStateChanged) {
        NSString *decodePipeline = self.usingHardwareDecode ? @"Hardware" : @"Software";
        NSString *toneMapDesc = (!streamIsHDR)
            ? @"sdr_passthrough_gamma22"
            : (displayHDRActive ? @"hdr_edr_pq" : @"libplacebo_spline_to_sdr");
        SFXEmitDebugTelemetryLog(
            @"playback.stream.color_state",
            [NSString stringWithFormat:
                @"trigger=%@ path=\"%@\" decode_pipeline=%@ stream_color=\"%@\" display_hdr_active=%@ edr_headroom=%.2f tone_map=%@",
                isFirstColorStateLog ? @"open" : @"mid_stream_switch",
                _path.lastPathComponent ?: @"unknown",
                decodePipeline,
                SFXDescribePixelBufferColorSummary(pixelBuffer),
                displayHDRActive ? @"true" : @"false",
                edrHeadroom,
                toneMapDesc
            ]
        );
    }
#endif

    double renderMs = 0.0;
    CVPixelBufferRef displayPixelBuffer = SFXCreateDisplayPixelBufferForPlayback(
        pixelBuffer,
        displayHDRActive,
        edrHeadroom,
        &renderMs
    );
    if (displayPixelBuffer == NULL) {
        displayPixelBuffer = CVPixelBufferRetain(pixelBuffer);
    }

    BOOL enqueued = NO;
    CMSampleBufferRef sampleBuffer = [self sampleBufferForPixelBuffer:displayPixelBuffer
                                                     presentationTime:presentationTime
                                                    sampleAspectRatio:sampleAspectRatio];
    CVPixelBufferRelease(displayPixelBuffer);
    if (sampleBuffer != NULL) {
        enqueued = [owner enqueueSampleBuffer:sampleBuffer
                                   forSession:self
                       presentationGeneration:presentationGeneration
                           flushBeforeEnqueue:firstFrameForPresentation];
        CFRelease(sampleBuffer);
    }

    if (enqueued) {
        [_packetQueueCondition lock];
        if (presentationGeneration == _presentationGeneration) {
            _lastPresentedPresentationGeneration = presentationGeneration;
        }
        BOOL presentationIsStillCurrent = presentationGeneration == _presentationGeneration
            && !_seekRequestPending
            && !_seekRequestInProgress
            && !_audioResetInProgress;
        [_packetQueueCondition unlock];
        double presentedSeconds = CMTIME_IS_NUMERIC(presentationTime)
            ? CMTimeGetSeconds(presentationTime)
            : -1.0;
        @synchronized (self) {
            _presentedVideoFrameCount += 1;
            if (presentationIsStillCurrent) {
                if (isfinite(presentedSeconds) && presentedSeconds >= 0) {
                    _currentTime = presentedSeconds;
                    _lastSubmittedVideoFrameMilliseconds = (NSInteger)floor(presentedSeconds * 1000.0);
                } else if (frameMilliseconds >= 0) {
                    _lastSubmittedVideoFrameMilliseconds = frameMilliseconds;
                }
            }
        }
        if (presentationIsStillCurrent
            && atomic_load(&_pauseAfterFirstFrame)
            && !atomic_load(&_didPauseAfterFirstFrame)) {
            [self setPaused:YES];
            atomic_store(&_didPauseAfterFirstFrame, true);
        }
        if (firstFrameForPresentation && automaticRecycleMilliseconds < 0) {
            CFTimeInterval presentNow = CACurrentMediaTime();
            double totalNativeMs = _perfOpenStartHostSeconds > 0
                ? (presentNow - _perfOpenStartHostSeconds) * 1000.0
                : (presentNow - _perfStartHostSeconds) * 1000.0;
            double s7StartToPresentMs = _perfStartHostSeconds > 0
                ? (presentNow - _perfStartHostSeconds) * 1000.0
                : -1.0;
            double s71FirstPacketMs = (_perfFirstPacketHostSeconds > 0 && _perfStartHostSeconds > 0)
                ? (_perfFirstPacketHostSeconds - _perfStartHostSeconds) * 1000.0
                : -1.0;
            double s72VideoDecodeMs = (_perfFirstVideoDecodedHostSeconds > 0 && _perfFirstVideoPacketHostSeconds > 0)
                ? (_perfFirstVideoDecodedHostSeconds - _perfFirstVideoPacketHostSeconds) * 1000.0
                : -1.0;
            double s73AudioPrimeWaitMs = _perfAudioPrimeWaitMs;
            double s74MainPresentMs = _perfFirstFrameEnqueuedHostSeconds > 0
                ? (presentNow - _perfFirstFrameEnqueuedHostSeconds) * 1000.0
                : -1.0;
            NSLog(@"[PlaybackPerf] FIRST_FRAME gen=%lu frameMs=%ld totalNativeOpenToPresent=%.1fms | S7_startToPresent=%.1fms (S7.1_firstPacket=%.1fms S7.2_videoDecode=%.1fms[packets=%lu,skippedFrames=%lu] S7.3_audioPrimeWait=%.1fms S7.4_mainPresent=%.1fms)",
                  (unsigned long)presentationGeneration,
                  (long)frameMilliseconds,
                  totalNativeMs,
                  s7StartToPresentMs,
                  s71FirstPacketMs,
                  s72VideoDecodeMs,
                  (unsigned long)_perfVideoPacketsForFirstFrame,
                  (unsigned long)_perfSkippedVideoFramesForFirstFrame,
                  s73AudioPrimeWaitMs,
                  s74MainPresentMs);
            SFXNativePlaybackPlayer *owner = _owner;
            dispatch_async(dispatch_get_main_queue(), ^{
                [owner session:self
                    didPresentVideoFrameAtMilliseconds:frameMilliseconds
                    presentationGeneration:presentationGeneration];
            });
        }
        if (automaticRecycleMilliseconds >= 0) {
            SFXNativePlaybackPlayer *owner = _owner;
            [owner requestAutomaticSoftwareRecycleForSession:self
                                              atMilliseconds:automaticRecycleMilliseconds
                                      presentationGeneration:presentationGeneration];
        }
    } else if (automaticRecycleMilliseconds >= 0
               && atomic_load(&_finishingForAutomaticRecycle)
               && !atomic_load(&_cancelled)) {
        SFXNativePlaybackPlayer *owner = _owner;
        [owner requestAutomaticSoftwareRecycleForSession:self
                                           atMilliseconds:automaticRecycleMilliseconds
                                   presentationGeneration:presentationGeneration];
    }
#if DEBUG
    if (enqueued) {
        double nowHost = CACurrentMediaTime();
        double decodeMs = 0.0;
        double avDriftMs = 0.0;
        @synchronized (self) {
            decodeMs = _lastFrameDecodeDurationMs;
            if (_telemetryLastHeartbeatHostSeconds <= 0) {
                _telemetryLastHeartbeatHostSeconds = nowHost;
            }
            _telemetryWindowFrameCount += 1;
            _telemetryWindowDecodeSumMs += decodeMs;
            if (decodeMs > _telemetryWindowDecodeMaxMs) {
                _telemetryWindowDecodeMaxMs = decodeMs;
            }
            _telemetryWindowRenderSumMs += renderMs;
            if (renderMs > _telemetryWindowRenderMaxMs) {
                _telemetryWindowRenderMaxMs = renderMs;
            }
            if (_audioClockInitialized && CMTIME_IS_NUMERIC(presentationTime)) {
                double rate = fmax((double)atomic_load(&_playbackRate), 0.001);
                double audioNowMedia = _audioFirstMediaSeconds + ((nowHost - _audioStartHostSeconds) * rate);
                double videoMedia = CMTimeGetSeconds(presentationTime);
                if (isfinite(audioNowMedia) && isfinite(videoMedia)) {
                    avDriftMs = (videoMedia - audioNowMedia) * 1000.0;
                }
            }
        }
        double totalFrameWorkMs = decodeMs + renderMs;
        if (totalFrameWorkMs > 28.0 || fabs(avDriftMs) > 65.0) {
            SFXEmitDebugTelemetryLog(
                @"playback.diagnostics.slow_frame",
                [NSString stringWithFormat:
                    @"path=\"%@\" frame_ms=%ld decode_ms=%.2f render_ms=%.2f total_work_ms=%.2f av_drift_ms=%.2f",
                    _path.lastPathComponent ?: @"unknown",
                    (long)frameMilliseconds,
                    decodeMs,
                    renderMs,
                    totalFrameWorkMs,
                    avDriftMs
                ]
            );
        }
        double elapsedWindow = 0.0;
        @synchronized (self) {
            elapsedWindow = nowHost - _telemetryLastHeartbeatHostSeconds;
        }
        if (elapsedWindow >= 1.0) {
            [self emitDebugHeartbeatWithReason:@"periodic"];
        }
    }
#endif
    SFXLogIfSlow(@"SFXNativePlaybackSession.enqueuePixelBuffer", start, 8);
    return enqueued;
}

- (void)clearPendingPixelBufferSubmission {
    [_displaySubmissionLock lock];
    if (_pendingDisplayPixelBuffer != NULL) {
        CVPixelBufferRelease(_pendingDisplayPixelBuffer);
        _pendingDisplayPixelBuffer = NULL;
    }
    _pendingDisplayPresentationTime = kCMTimeInvalid;
    _pendingDisplayAutomaticRecycleMilliseconds = -1;
    _pendingDisplayFrameMilliseconds = -1;
    _pendingDisplayPresentationGeneration = 0;
    _displaySubmissionScheduled = NO;
    [_displaySubmissionLock unlock];
}

- (NSInteger)markAutomaticSoftwareRecycleIfNeededAtMediaSeconds:(double)mediaSeconds {
    if (!_allowAutomaticSoftwareRecycle
        || _automaticSoftwareRecycleRequested
        || self.usingHardwareDecode
        || atomic_load(&_cancelled)) {
        return -1;
    }

    _automaticSoftwareRecycleRequested = YES;
    atomic_store(&_finishingForAutomaticRecycle, true);
    double recycleSeconds = isfinite(mediaSeconds) && mediaSeconds >= 0 ? mediaSeconds : _seekSeconds;
    return (NSInteger)llround(recycleSeconds * 1000.0);
}

- (int)audioFrameSampleRate:(const AVFrame *)frame {
    if (frame->sample_rate > 0) {
        return frame->sample_rate;
    }
    return _audioCodecContext->sample_rate > 0 ? _audioCodecContext->sample_rate : _audioOutputSampleRate;
}

- (int)audioFrameChannelCount:(const AVFrame *)frame {
    if (frame->ch_layout.nb_channels > 0) {
        return frame->ch_layout.nb_channels;
    }
    return _audioCodecContext->ch_layout.nb_channels;
}

- (BOOL)audioFrameMatchesOutput:(const AVFrame *)frame {
    return frame->format == AV_SAMPLE_FMT_FLTP
        && [self audioFrameSampleRate:frame] == _audioOutputSampleRate
        && [self audioFrameChannelCount:frame] == _audioOutputChannels;
}

- (BOOL)ensureResamplerForFrame:(const AVFrame *)frame {
    int inputSampleRate = [self audioFrameSampleRate:frame];
    int inputChannels = [self audioFrameChannelCount:frame];
    enum AVSampleFormat inputFormat = (enum AVSampleFormat)frame->format;
    if (inputSampleRate <= 0 || inputChannels <= 0 || inputFormat == AV_SAMPLE_FMT_NONE) {
        return NO;
    }

    if (_resampler != NULL
        && _resamplerInputSampleRate == inputSampleRate
        && _resamplerInputChannels == inputChannels
        && _resamplerInputFormat == inputFormat) {
        return YES;
    }

    swr_free(&_resampler);

    AVChannelLayout inputLayout = {0};
    BOOL ownsInputLayout = NO;
    const AVChannelLayout *inputLayoutRef = &frame->ch_layout;
    if (frame->ch_layout.nb_channels <= 0
        || frame->ch_layout.order == AV_CHANNEL_ORDER_UNSPEC
        || !av_channel_layout_check(&frame->ch_layout)) {
        av_channel_layout_default(&inputLayout, inputChannels);
        inputLayoutRef = &inputLayout;
        ownsInputLayout = YES;
    }

    int result = swr_alloc_set_opts2(
        &_resampler,
        &_outputLayout,
        AV_SAMPLE_FMT_FLTP,
        _audioOutputSampleRate,
        inputLayoutRef,
        inputFormat,
        inputSampleRate,
        0,
        NULL
    );

    if (ownsInputLayout) {
        av_channel_layout_uninit(&inputLayout);
    }

    if (result < 0 || _resampler == NULL) {
        swr_free(&_resampler);
        return NO;
    }

    result = swr_init(_resampler);
    if (result < 0) {
        swr_free(&_resampler);
        return NO;
    }

    _resamplerInputSampleRate = inputSampleRate;
    _resamplerInputChannels = inputChannels;
    _resamplerInputFormat = inputFormat;
    return YES;
}

- (const AVFrame *)outputAudioFrameForFrame:(const AVFrame *)frame {
    if ([self audioFrameMatchesOutput:frame]) {
        return frame;
    }

    if (![self ensureResamplerForFrame:frame]) {
        return NULL;
    }

    av_frame_unref(_convertedAudioFrame);
    if (av_channel_layout_copy(&_convertedAudioFrame->ch_layout, &_outputLayout) < 0) {
        return NULL;
    }

    int inputSampleRate = [self audioFrameSampleRate:frame];
    _convertedAudioFrame->format = AV_SAMPLE_FMT_FLTP;
    _convertedAudioFrame->sample_rate = _audioOutputSampleRate;
    _convertedAudioFrame->nb_samples = (int)av_rescale_rnd(
        frame->nb_samples,
        _audioOutputSampleRate,
        inputSampleRate,
        AV_ROUND_UP
    ) + 256;

    int result = swr_convert_frame(_resampler, _convertedAudioFrame, frame);
    if (result < 0) {
        av_frame_unref(_convertedAudioFrame);
        return NULL;
    }

    return _convertedAudioFrame;
}

- (void)audioBufferDidPlayForGeneration:(NSUInteger)generation
                          mediaDuration:(double)mediaDuration
    finalSegmentBuffer:(BOOL)finalSegmentBuffer {
    [_packetQueueCondition lock];
    if (generation != _playbackGeneration) {
        [_packetQueueCondition unlock];
        return;
    }

    if (_outstandingAudioBufferCount > 0) {
        _outstandingAudioBufferCount -= 1;
    }
    _queuedAudioMediaSeconds = fmax(0, _queuedAudioMediaSeconds - mediaDuration);
    BOOL reachedZero = _outstandingAudioBufferCount == 0;
    BOOL inputEnded = _audioInputEnded;
    BOOL segmentDrainWaiting = NO;
    BOOL shouldCountUnexpectedDrain = NO;
    @synchronized (self) {
        _audioPlayedBackBufferCount += 1;
        segmentDrainWaiting = _segmentWaitingForAudioCompletion;
        BOOL continuousPlayback = _audioPlayerStarted
            && !_isRebuffering
            && !atomic_load(&_segmentAudioBoundaryReached);
        shouldCountUnexpectedDrain = !_audioResetInProgress
            && reachedZero
            && !finalSegmentBuffer
            && !inputEnded
            && continuousPlayback
            && !atomic_load(&_paused)
            && !atomic_load(&_cancelled)
            && !atomic_load(&_segmentEnding)
            && !atomic_load(&_finishingForAutomaticRecycle);
        if (shouldCountUnexpectedDrain) {
            _unexpectedAudioDrainCount += 1;
        }
    }
    BOOL shouldCompleteSegment = finalSegmentBuffer || (reachedZero && segmentDrainWaiting);
    BOOL needsCompletionRecordOnAudioQueue = shouldCompleteSegment || inputEnded;
    if (needsCompletionRecordOnAudioQueue) {
        _pendingAudioCompletionRecordCount += 1;
    }
    BOOL shouldRequestDrain = !_audioResetInProgress
        && !finalSegmentBuffer
        && !inputEnded
        && [self queuedAudioWallSecondsLocked] <= SFXAudioQueueLowWaterWallSeconds;
    if (reachedZero || finalSegmentBuffer || inputEnded || segmentDrainWaiting) {
        [_packetQueueCondition broadcast];
    }
    [_packetQueueCondition unlock];

    if (needsCompletionRecordOnAudioQueue) {
        dispatch_async(_audioDecodeQueue, ^{
            [_packetQueueCondition lock];
            BOOL generationIsCurrent = generation == _playbackGeneration;
            BOOL shouldRecordCompletion = generationIsCurrent
                && !_audioResetInProgress
                && !atomic_load(&_cancelled);
            if (!shouldRecordCompletion && generationIsCurrent) {
                if (_pendingAudioCompletionRecordCount > 0) {
                    _pendingAudioCompletionRecordCount -= 1;
                }
                if (_audioInputEnded
                    && _outstandingAudioBufferCount == 0
                    && _pendingAudioCompletionRecordCount == 0) {
                    _audioOutputDrained = YES;
                }
                [_packetQueueCondition broadcast];
            }
            [_packetQueueCondition unlock];
            if (!shouldRecordCompletion) {
                return;
            }

            if (shouldCompleteSegment) {
                [self markSegmentAudioDrainCompleted];
                [self notifySegmentFinishedIfNeeded];
            }
            [_packetQueueCondition lock];
            BOOL becameDrained = NO;
            if (generation == _playbackGeneration) {
                if (_pendingAudioCompletionRecordCount > 0) {
                    _pendingAudioCompletionRecordCount -= 1;
                }
                if (_audioInputEnded
                    && _outstandingAudioBufferCount == 0
                    && _pendingAudioCompletionRecordCount == 0) {
                    _audioOutputDrained = YES;
                    becameDrained = YES;
                }
            }
            if (becameDrained || shouldCompleteSegment) {
                [_packetQueueCondition broadcast];
            }
            [_packetQueueCondition unlock];
        });
    }

    if (shouldRequestDrain) {
        [self requestAudioDrain];
    }
}

- (BOOL)flushPendingCoalescedAudioForGeneration:(NSUInteger)generation
                             finalSegmentBuffer:(BOOL)isFinalSegmentBuffer {
    AVAudioPCMBuffer *buffer = _pendingCoalescedAudioBuffer;
    if (buffer == nil || buffer.frameLength == 0) {
        _pendingCoalescedAudioBuffer = nil;
        _pendingCoalescedAudioStartMediaSeconds = -1;
        _pendingCoalescedAudioEndMediaSeconds = -1;
        return YES;
    }

    double startMediaSeconds = _pendingCoalescedAudioStartMediaSeconds;
    double endMediaSeconds = _pendingCoalescedAudioEndMediaSeconds;
    int sampleRate = _pendingCoalescedAudioSampleRate > 0 ? _pendingCoalescedAudioSampleRate : _audioOutputSampleRate;
    NSUInteger bufferGeneration = _pendingCoalescedAudioGeneration;
    _pendingCoalescedAudioBuffer = nil;
    _pendingCoalescedAudioStartMediaSeconds = -1;
    _pendingCoalescedAudioEndMediaSeconds = -1;

    if (bufferGeneration != generation || sampleRate <= 0) {
        return NO;
    }

    double scheduledDurationSeconds = (double)buffer.frameLength / (double)sampleRate;
    if (startMediaSeconds >= 0) {
        double scheduledEndSeconds = endMediaSeconds >= startMediaSeconds
            ? endMediaSeconds
            : (startMediaSeconds + scheduledDurationSeconds);
        @synchronized (self) {
            _lastScheduledAudioStartMilliseconds = (NSInteger)llround(startMediaSeconds * 1000.0);
            _lastScheduledAudioEndMilliseconds = (NSInteger)llround(scheduledEndSeconds * 1000.0);
        }
    }

    [_packetQueueCondition lock];
    BOOL canSchedule = generation == _playbackGeneration
        && !_audioResetInProgress
        && !atomic_load(&_cancelled)
        && !atomic_load(&_finishingForAutomaticRecycle);
    if (canSchedule) {
        if (_audioFirstScheduledMediaSeconds < 0 && startMediaSeconds >= 0) {
            _audioFirstScheduledMediaSeconds = startMediaSeconds;
        }
        _queuedAudioMediaSeconds += scheduledDurationSeconds;
        _outstandingAudioBufferCount += 1;
        BOOL wasPrimed = _audioPrimed;
        if ([self queuedAudioWallSecondsLocked] >= SFXAudioPrimeWallSeconds || isFinalSegmentBuffer) {
            _audioPrimed = YES;
        }
        BOOL becamePrimed = !wasPrimed && _audioPrimed;
        if (becamePrimed || isFinalSegmentBuffer) {
            [_packetQueueCondition broadcast];
        }
        if (becamePrimed) {
            dispatch_async(_audioDecodeQueue, ^{
                [self requestAudioPlaybackStartIfReadyForGeneration:generation];
            });
        }
    }
    [_packetQueueCondition unlock];
    if (!canSchedule) {
        return NO;
    }

    if (isFinalSegmentBuffer) {
        [self markSegmentAudioBoundaryReached];
    }

    __weak typeof(self) weakSelf = self;
    [_audioPlayer scheduleBuffer:buffer
           completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack
                 completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
        (void)callbackType;
        typeof(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        [strongSelf audioBufferDidPlayForGeneration:generation
                                     mediaDuration:scheduledDurationSeconds
                                finalSegmentBuffer:isFinalSegmentBuffer];
    }];

    return YES;
}

- (SFXAudioScheduleResult)scheduleAudioFrame:(const AVFrame *)frame
                                mediaSeconds:(double)mediaSeconds
                                  generation:(NSUInteger)generation {
    if (_audioPlayer == nil || _audioFormat == nil || frame->format != AV_SAMPLE_FMT_FLTP) {
        return SFXAudioScheduleResultNotScheduled;
    }

    int channels = frame->ch_layout.nb_channels;
    if (channels <= 0 || channels > (int)_audioFormat.channelCount) {
        return SFXAudioScheduleResultNotScheduled;
    }

    int sampleRate = [self audioFrameSampleRate:frame];
    if (sampleRate <= 0) {
        return SFXAudioScheduleResultNotScheduled;
    }

    int scheduledSampleCount = frame->nb_samples;
    BOOL isFinalSegmentBuffer = NO;
    if ([self hasActiveSegmentEnd] && [self segmentAudioBoundaryReached]) {
        [self flushPendingCoalescedAudioForGeneration:generation finalSegmentBuffer:NO];
        return SFXAudioScheduleResultSegmentBoundaryReached;
    }

    if ([self hasActiveSegmentEnd] && mediaSeconds >= 0) {
        double remainingSeconds = _segmentEndSeconds - mediaSeconds;
        double frameDuration = sampleRate > 0 ? (double)frame->nb_samples / (double)sampleRate : 0;
        BOOL reachesSegmentEnd = remainingSeconds <= SFXSegmentBoundaryEpsilonSeconds
            || mediaSeconds + frameDuration + SFXSegmentBoundaryEpsilonSeconds >= _segmentEndSeconds;
        if (reachesSegmentEnd && [self resolveAutoPauseAuthorizationIfNeeded]) {
            if (remainingSeconds <= SFXSegmentBoundaryEpsilonSeconds) {
                [self flushPendingCoalescedAudioForGeneration:generation finalSegmentBuffer:NO];
                [self markSegmentAudioBoundaryReached];
                return SFXAudioScheduleResultSegmentBoundaryReached;
            }

            if (mediaSeconds + frameDuration + SFXSegmentBoundaryEpsilonSeconds >= _segmentEndSeconds) {
                int segmentSampleCount = (int)floor(remainingSeconds * (double)sampleRate + SFXSegmentBoundaryEpsilonSeconds);
                if (segmentSampleCount <= 0) {
                    [self flushPendingCoalescedAudioForGeneration:generation finalSegmentBuffer:NO];
                    [self markSegmentAudioBoundaryReached];
                    return SFXAudioScheduleResultSegmentBoundaryReached;
                }
                scheduledSampleCount = MIN(frame->nb_samples, segmentSampleCount);
                isFinalSegmentBuffer = YES;
            }
        }
    }

    AVAudioFrameCount targetCapacity = _audioPrimed
        ? SFXAudioCoalesceSteadySamples
        : SFXAudioCoalesceStartupSamples;
    if (_pendingCoalescedAudioBuffer != nil
        && (_pendingCoalescedAudioGeneration != generation
            || _pendingCoalescedAudioSampleRate != sampleRate
            || _pendingCoalescedAudioBuffer.frameLength + (AVAudioFrameCount)scheduledSampleCount > _pendingCoalescedAudioBuffer.frameCapacity)) {
        if (![self flushPendingCoalescedAudioForGeneration:_pendingCoalescedAudioGeneration
                                        finalSegmentBuffer:NO]) {
            return SFXAudioScheduleResultNotScheduled;
        }
    }

    if (_pendingCoalescedAudioBuffer == nil) {
        AVAudioFrameCount capacity = MAX(targetCapacity, (AVAudioFrameCount)scheduledSampleCount);
        _pendingCoalescedAudioBuffer = [[AVAudioPCMBuffer alloc]
            initWithPCMFormat:_audioFormat
            frameCapacity:capacity
        ];
        if (_pendingCoalescedAudioBuffer == nil || _pendingCoalescedAudioBuffer.floatChannelData == NULL) {
            _pendingCoalescedAudioBuffer = nil;
            return SFXAudioScheduleResultNotScheduled;
        }
        _pendingCoalescedAudioBuffer.frameLength = 0;
        _pendingCoalescedAudioStartMediaSeconds = mediaSeconds;
        _pendingCoalescedAudioEndMediaSeconds = -1;
        _pendingCoalescedAudioSampleRate = sampleRate;
        _pendingCoalescedAudioGeneration = generation;
    }

    AVAudioFrameCount dstOffset = _pendingCoalescedAudioBuffer.frameLength;
    for (int channel = 0; channel < channels; channel++) {
        memcpy(
            _pendingCoalescedAudioBuffer.floatChannelData[channel] + dstOffset,
            frame->extended_data[channel],
            sizeof(float) * (size_t)scheduledSampleCount
        );
    }
    _pendingCoalescedAudioBuffer.frameLength = dstOffset + (AVAudioFrameCount)scheduledSampleCount;
    if (_pendingCoalescedAudioStartMediaSeconds < 0 && mediaSeconds >= 0) {
        _pendingCoalescedAudioStartMediaSeconds = mediaSeconds;
    }
    if (mediaSeconds >= 0) {
        _pendingCoalescedAudioEndMediaSeconds = mediaSeconds
            + ((double)scheduledSampleCount / (double)sampleRate);
    }

    if (isFinalSegmentBuffer || _pendingCoalescedAudioBuffer.frameLength >= targetCapacity) {
        if (![self flushPendingCoalescedAudioForGeneration:generation
                                        finalSegmentBuffer:isFinalSegmentBuffer]) {
            return SFXAudioScheduleResultNotScheduled;
        }
    }

    return isFinalSegmentBuffer
        ? SFXAudioScheduleResultScheduledFinalSegmentBuffer
        : SFXAudioScheduleResultScheduled;
}

- (void)notifyTimeIfNeeded:(BOOL)force {
    double now = CACurrentMediaTime();
    @synchronized (self) {
        if (!force && now - _lastDelegateUpdateHostSeconds < 0.25) {
            return;
        }
        _lastDelegateUpdateHostSeconds = now;
    }

    double currentTime = self.currentTime;
    double duration = _duration;
    BOOL playing = self.isPlaying;
    [_packetQueueCondition lock];
    NSUInteger presentationGeneration = _presentationGeneration;
    [_packetQueueCondition unlock];
    id<SFXNativePlaybackPlayerDelegate> delegate = _delegate;
    SFXNativePlaybackPlayer *owner = _owner;
    CFTimeInterval scheduledAt = SFXPerformanceNow();

    dispatch_async(dispatch_get_main_queue(), ^{
        SFXLogIfSlow(@"SFXNativePlaybackSession.timeDelegate.mainDelay", scheduledAt, 50);
        if (![owner isCurrentPresentationForSession:self
                             presentationGeneration:presentationGeneration]) {
            return;
        }
        if ([delegate respondsToSelector:@selector(nativePlaybackPlayer:didUpdateTime:duration:playing:presentationGeneration:)]) {
            [delegate nativePlaybackPlayer:owner
                             didUpdateTime:currentTime
                                  duration:duration
                                   playing:playing
                    presentationGeneration:presentationGeneration];
        } else {
            [delegate nativePlaybackPlayer:owner
                             didUpdateTime:currentTime
                                  duration:duration
                                   playing:playing];
        }
    });
}

- (void)notifyFailure:(NSString *)message {
    id<SFXNativePlaybackPlayerDelegate> delegate = _delegate;
    SFXNativePlaybackPlayer *owner = _owner;
    dispatch_async(dispatch_get_main_queue(), ^{
        [delegate nativePlaybackPlayer:owner didFailWithMessage:message];
    });
}

- (void)refreshDisplayForHDRModeChange:(BOOL)isHDRActive
                           edrHeadroom:(CGFloat)edrHeadroom
                       switchStartedMs:(double)switchStartedMs {
    CVPixelBufferRef sourceBuffer = NULL;
    CMTime presentationTime = kCMTimeInvalid;
    AVRational sar = (AVRational){1, 1};
    @synchronized (self) {
        if (_latestSourceVideoPixelBuffer != NULL) {
            sourceBuffer = CVPixelBufferRetain(_latestSourceVideoPixelBuffer);
            presentationTime = _latestSourcePresentationTime;
            sar = _latestSourceSampleAspectRatio;
        }
    }
    if (sourceBuffer == NULL) {
        return;
    }

    BOOL streamIsHDR = SFXPixelBufferIsHDR(sourceBuffer);
    double renderMs = 0.0;
    if (self.isPaused && !atomic_load(&_cancelled)) {
        [_packetQueueCondition lock];
        NSUInteger presentationGeneration = _presentationGeneration;
        [_packetQueueCondition unlock];
        CVPixelBufferRef displayPixelBuffer = SFXCreateDisplayPixelBufferForPlayback(
            sourceBuffer,
            isHDRActive,
            edrHeadroom,
            &renderMs
        );
        if (displayPixelBuffer == NULL) {
            displayPixelBuffer = CVPixelBufferRetain(sourceBuffer);
        }
        CMSampleBufferRef sampleBuffer = [self sampleBufferForPixelBuffer:displayPixelBuffer
                                                         presentationTime:presentationTime
                                                        sampleAspectRatio:sar];
        CVPixelBufferRelease(displayPixelBuffer);
        if (sampleBuffer != NULL) {
            SFXNativePlaybackPlayer *owner = _owner;
            [owner enqueueSampleBuffer:sampleBuffer
                            forSession:self
                presentationGeneration:presentationGeneration
                    flushBeforeEnqueue:YES];
            CFRelease(sampleBuffer);
        }
    }
#if DEBUG
    double switchDurationMs = switchStartedMs > 0 ? fmax(0.0, SFXMonotonicMilliseconds() - switchStartedMs) : renderMs;
    NSString *toneMapDesc = (!streamIsHDR)
        ? @"sdr_passthrough_gamma22"
        : (isHDRActive ? @"hdr_edr_pq" : @"libplacebo_spline_to_sdr");
    SFXEmitDebugTelemetryLog(
        @"playback.stream.color_state",
        [NSString stringWithFormat:
            @"trigger=display_hdr_change path=\"%@\" decode_pipeline=%@ stream_color=\"%@\" display_hdr_active=%@ edr_headroom=%.2f tone_map=%@ switch_duration_ms=%.2f",
            _path.lastPathComponent ?: @"unknown",
            self.usingHardwareDecode ? @"Hardware" : @"Software",
            SFXDescribePixelBufferColorSummary(sourceBuffer),
            isHDRActive ? @"true" : @"false",
            edrHeadroom,
            toneMapDesc,
            switchDurationMs
        ]
    );
#endif
    CVPixelBufferRelease(sourceBuffer);
}

- (void)emitDebugHeartbeatWithReason:(NSString *)reason {
#if DEBUG
    double nowHost = CACurrentMediaTime();
    NSUInteger frameCount = 0;
    double elapsedSeconds = 0.0;
    double decodeAvgMs = 0.0;
    double decodeMaxMs = 0.0;
    double renderAvgMs = 0.0;
    double renderMaxMs = 0.0;
    double packetWaitAvgMs = 0.0;
    double packetWaitMaxMs = 0.0;
    NSUInteger droppedFrames = 0;
    double avDriftMs = 0.0;
    @synchronized (self) {
        frameCount = _telemetryWindowFrameCount;
        if (_telemetryLastHeartbeatHostSeconds > 0 && nowHost > _telemetryLastHeartbeatHostSeconds) {
            elapsedSeconds = nowHost - _telemetryLastHeartbeatHostSeconds;
        }
        if (frameCount > 0) {
            decodeAvgMs = _telemetryWindowDecodeSumMs / (double)frameCount;
            decodeMaxMs = _telemetryWindowDecodeMaxMs;
            renderAvgMs = _telemetryWindowRenderSumMs / (double)frameCount;
            renderMaxMs = _telemetryWindowRenderMaxMs;
            packetWaitAvgMs = _telemetryWindowPacketWaitSumMs / (double)frameCount;
            packetWaitMaxMs = _telemetryWindowPacketWaitMaxMs;
        }
        droppedFrames = _telemetryWindowDroppedFrames;
        if (_audioClockInitialized && _lastPacedVideoMediaSeconds >= 0 && !atomic_load(&_paused)) {
            double rate = fmax((double)atomic_load(&_playbackRate), 0.001);
            double audioNowMedia = _audioFirstMediaSeconds + ((nowHost - _audioStartHostSeconds) * rate);
            avDriftMs = (_lastPacedVideoMediaSeconds - audioNowMedia) * 1000.0;
        }
        _telemetryLastHeartbeatHostSeconds = nowHost;
        _telemetryWindowFrameCount = 0;
        _telemetryWindowDroppedFrames = 0;
        _telemetryWindowDecodeSumMs = 0.0;
        _telemetryWindowDecodeMaxMs = 0.0;
        _telemetryWindowRenderSumMs = 0.0;
        _telemetryWindowRenderMaxMs = 0.0;
        _telemetryWindowPacketWaitSumMs = 0.0;
        _telemetryWindowPacketWaitMaxMs = 0.0;
    }
    if (frameCount == 0 && [reason isEqualToString:@"periodic"]) {
        return;
    }
    double fps = elapsedSeconds > 0.001 ? ((double)frameCount / elapsedSeconds) : 0.0;
    double bufferedSeconds = 0.0;
    size_t bufferedBytes = 0;
    [_packetQueueCondition lock];
    bufferedSeconds = [self packetQueueBufferedSecondsLocked];
    bufferedBytes = _packetQueueBytes;
    [_packetQueueCondition unlock];

    SFXEmitDebugTelemetryLog(
        @"playback.diagnostics.heartbeat",
        [NSString stringWithFormat:
            @"reason=%@ path=\"%@\" fps=%.1f frames=%lu decode_avg_ms=%.2f decode_max_ms=%.2f render_avg_ms=%.2f render_max_ms=%.2f packet_wait_avg_ms=%.2f packet_wait_max_ms=%.2f dropped_frames=%lu av_drift_ms=%.2f buffer_sec=%.2f buffer_kb=%zu",
            reason ?: @"periodic",
            _path.lastPathComponent ?: @"unknown",
            fps,
            (unsigned long)frameCount,
            decodeAvgMs,
            decodeMaxMs,
            renderAvgMs,
            renderMaxMs,
            packetWaitAvgMs,
            packetWaitMaxMs,
            (unsigned long)droppedFrames,
            avDriftMs,
            bufferedSeconds,
            bufferedBytes / 1024
        ]
    );
#else
    (void)reason;
#endif
}

- (void)teardown {
    [self stopStarvationWatchdog];

    [_packetQueueCondition lock];
    _audioResetInProgress = YES;
    _playbackGeneration += 1;
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];
    [self signalPacingCondition];

    [self stopPacketReadAheadAndClear];
    [self clearPendingPixelBufferSubmission];
    @synchronized (self) {
        if (_latestSourceVideoPixelBuffer != NULL) {
            CVPixelBufferRelease(_latestSourceVideoPixelBuffer);
            _latestSourceVideoPixelBuffer = NULL;
        }
    }

    if (_audioDecodeQueue != NULL) {
        dispatch_sync(_audioDecodeQueue, ^{
            [self teardownAudioOutput];
        });
    }

    [_packetQueueCondition lock];
    _audioDrainScheduled = NO;
    _queuedAudioMediaSeconds = 0;
    _outstandingAudioBufferCount = 0;
    _pendingAudioCompletionRecordCount = 0;
    _audioInputEnded = YES;
    _audioOutputDrained = YES;
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];
    [self signalPacingCondition];

    swr_free(&_resampler);
    sws_freeContext(_videoScaler);
    _videoScaler = NULL;
    if (_cachedVideoFormatDescription != NULL) {
        CFRelease(_cachedVideoFormatDescription);
        _cachedVideoFormatDescription = NULL;
    }
    if (_softwarePixelBufferPool != NULL) {
        CVPixelBufferPoolRelease(_softwarePixelBufferPool);
        _softwarePixelBufferPool = NULL;
    }
    av_channel_layout_uninit(&_outputLayout);
    av_frame_free(&_convertedAudioFrame);
    av_frame_free(&_audioFrame);
    av_frame_free(&_videoFrame);
    av_packet_free(&_packet);
    avcodec_free_context(&_audioCodecContext);
    avcodec_free_context(&_videoCodecContext);
    av_buffer_unref(&_hardwareDeviceContext);
    avformat_close_input(&_formatContext);
    @synchronized (self) {
        if (_keyframeStreamTimestamps != NULL) {
            free(_keyframeStreamTimestamps);
            _keyframeStreamTimestamps = NULL;
        }
        _keyframeStreamTimestampCount = 0;
    }

}

@end
