#import "SFXNativePlaybackPlayer.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <VideoToolbox/VideoToolbox.h>
#import <QuartzCore/QuartzCore.h>
#import <dispatch/dispatch.h>
#import <os/log.h>

#include <libavcodec/avcodec.h>
#include <libavcodec/packet.h>
#include <libavformat/avformat.h>
#include <libavutil/channel_layout.h>
#include <libavutil/dict.h>
#include <libavutil/error.h>
#include <libavutil/hwcontext.h>
#include <libavutil/log.h>
#include <libavutil/mathematics.h>
#include <libavutil/pixdesc.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>

#include <float.h>
#include <math.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

NS_ASSUME_NONNULL_BEGIN

extern enum AVPixelFormat SFXHardwarePixelFormat;
extern const float SFXMinimumPlaybackRate;
extern const float SFXMaximumPlaybackRate;
extern const double SFXVideoStarvationThresholdSeconds;
extern const double SFXVideoStarvationWatchdogIntervalSeconds;
extern const double SFXAudioPrimeWallSeconds;
extern const double SFXAudioQueueLowWaterWallSeconds;
extern const double SFXAudioQueueHighWaterWallSeconds;
extern const AVAudioFrameCount SFXAudioCoalesceStartupSamples;
extern const AVAudioFrameCount SFXAudioCoalesceSteadySamples;
extern const double SFXReadAheadStartupSeconds;
extern const double SFXReadAheadLowWaterSeconds;
extern const double SFXReadAheadTargetSeconds;
extern const size_t SFXReadAheadLowWaterBytes;
extern const size_t SFXReadAheadMaxBytes;
extern const NSInteger SFXNoSegmentEndMilliseconds;
extern const double SFXSegmentBoundaryEpsilonSeconds;

typedef NS_ENUM(NSInteger, SFXAudioScheduleResult) {
    SFXAudioScheduleResultNotScheduled = 0,
    SFXAudioScheduleResultScheduled = 1,
    SFXAudioScheduleResultScheduledFinalSegmentBuffer = 2,
    SFXAudioScheduleResultSegmentBoundaryReached = 3
};

typedef struct SFXQueuedPacket {
    AVPacket * _Nullable packet;
    size_t bytes;
    double mediaSeconds;
    struct SFXQueuedPacket * _Nullable next;
} SFXQueuedPacket;

os_log_t SFXPerformanceLog(void);
BOOL SFXPerformanceLoggingEnabled(void);
NSInteger SFXSanitizedSegmentEndMilliseconds(NSInteger startMilliseconds, NSInteger endMilliseconds);
CFTimeInterval SFXPerformanceNow(void);
void SFXLogIfSlow(NSString *name, CFTimeInterval start, double thresholdMilliseconds);
void SFXFreeQueuedPacket(SFXQueuedPacket * _Nullable queuedPacket);
float SFXClampedPlaybackRate(float playbackRate);
NSString *SFXFFmpegErrorString(int code);
BOOL SFXIsHTTPMediaPath(const char * _Nullable path);
int SFXOpenMediaInput(
    AVFormatContext * _Nullable * _Nonnull formatContext,
    const char *path,
    NSString * _Nullable httpHeaders
);
NSString *SFXPixelFormatName(enum AVPixelFormat pixelFormat);
NSError *SFXNativePlaybackError(NSInteger code, NSString *message);
BOOL SFXIsHardwareDecodeSupported(enum AVCodecID codecID);
enum AVCodecID SFXCodecIDForName(NSString * _Nullable codecName);
BOOL SFXIsHardwareDecodeSupportedForCodecName(NSString *codecName);
BOOL SFXIsHardwareDecodeSupportedForCodecAndPixelFormat(
    enum AVCodecID codecID,
    enum AVPixelFormat pixelFormat,
    int bitsPerRawSample,
    int profile,
    NSString * _Nullable * _Nullable unsupportedReasonOut
);
BOOL SFXIsHardwareDecodeSupportedForParameters(
    const AVCodecParameters * _Nullable parameters,
    NSString * _Nullable * _Nullable unsupportedReasonOut
);
BOOL SFXIsHardwareDecodeSupportedForCodecNameAndPixelFormatName(
    NSString *codecName,
    NSString * _Nullable pixelFormatName
);
const AVCodecHWConfig * _Nullable SFXFindVideoToolboxConfig(const AVCodec *decoder);
const AVCodec * _Nullable SFXFindVideoToolboxDecoder(
    enum AVCodecID codecID,
    const AVCodecHWConfig * _Nullable * _Nullable hardwareConfig
);
const AVCodec * _Nullable SFXFindSoftwareVideoDecoder(enum AVCodecID codecID);
enum AVPixelFormat SFXChooseHardwareFormat(
    AVCodecContext *context,
    const enum AVPixelFormat *pixelFormats
);
double SFXStreamStartSeconds(AVStream *stream);
BOOL SFXStreamParticipatesInMediaTimeline(AVStream *stream);
double SFXMediaTimelineOriginSeconds(AVFormatContext * _Nullable formatContext);
double SFXFramePlaybackSeconds(const AVFrame *frame, AVStream *stream, double timelineOriginSeconds);
double SFXPacketPlaybackSeconds(const AVPacket *packet, AVStream *stream, double timelineOriginSeconds);
int64_t SFXSeekTimestamp(double seconds, AVStream *stream, double timelineOriginSeconds);
int64_t SFXGlobalSeekTimestamp(double seconds, double timelineOriginSeconds);
BOOL SFXSeekToStartPosition(
    AVFormatContext *formatContext,
    int videoStreamIndex,
    double seconds,
    double timelineOriginSeconds,
    NSError * _Nullable * _Nullable error
);
BOOL SFXFrameBeforeSeekTarget(
    const AVFrame *frame,
    AVStream *stream,
    double seekSeconds,
    double timelineOriginSeconds
);
CMTime SFXFramePresentationTime(const AVFrame *frame, AVStream *stream, double timelineOriginSeconds);
CMSampleBufferRef _Nullable SFXSampleBufferForPixelBuffer(
    CVPixelBufferRef _Nullable pixelBuffer,
    CMTime presentationTime
);
int SFXOutputChannelCount(int inputChannels);
AVRational SFXVideoSampleAspectRatio(
    AVFormatContext * _Nullable formatContext,
    AVStream * _Nullable videoStream,
    const AVCodecContext * _Nullable codecContext,
    const AVFrame * _Nullable frame
);
NSInteger SFXDisplayVideoWidthForDimensionsAndSAR(
    NSInteger storageWidth,
    NSInteger storageHeight,
    AVRational sampleAspectRatio
);
void SFXApplyPixelAspectRatioAttachment(
    CVPixelBufferRef _Nullable pixelBuffer,
    AVRational sampleAspectRatio,
    BOOL removeWhenSquare
);

@interface SFXKeyframeThumbnailDecoder : NSObject
- (nullable CGImageRef)copyThumbnailImageForPath:(NSString *)path
                                     httpHeaders:(nullable NSString *)httpHeaders
                                  atMilliseconds:(NSInteger)milliseconds
                                targetPixelWidth:(NSInteger)targetPixelWidth
                         keyframeMillisecondsOut:(nullable NSInteger *)keyframeMillisecondsOut
                                   videoWidthOut:(nullable NSInteger *)videoWidthOut
                                  videoHeightOut:(nullable NSInteger *)videoHeightOut CF_RETURNS_RETAINED;
- (void)invalidate;
@end

@interface SFXNativePlaybackView : NSView
@property (nonatomic, strong, readonly) AVSampleBufferDisplayLayer *displayLayer;
@property (nonatomic, readonly) NSUInteger displayImageRemovalCount;
- (void)updateDisplayLayerFrameWithLogName:(NSString *)logName;
- (void)flush;
@end

@interface SFXNativePlaybackFrameSnapshot ()
- (instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer;
@end

@class SFXNativePlaybackSession;

@interface SFXNativePlaybackPlayer ()
- (BOOL)openPath:(NSString *)path
startMilliseconds:(NSInteger)startMilliseconds
 endMilliseconds:(NSInteger)endMilliseconds
pausesAtSegmentEnd:(BOOL)pausesAtSegmentEnd
presentationGeneration:(NSUInteger)presentationGeneration
flushDisplayBeforeStart:(BOOL)flushDisplayBeforeStart
 pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
allowAutomaticSoftwareRecycle:(BOOL)allowAutomaticSoftwareRecycle
           error:(NSError **)error;
- (BOOL)seekToMilliseconds:(NSInteger)milliseconds
           endMilliseconds:(NSInteger)endMilliseconds
       pausesAtSegmentEnd:(BOOL)pausesAtSegmentEnd
      pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
                     error:(NSError **)error;
- (void)requestAutomaticSoftwareRecycleForSession:(SFXNativePlaybackSession *)session
                                   atMilliseconds:(NSInteger)milliseconds
                           presentationGeneration:(NSUInteger)presentationGeneration;
- (void)requestAudioOutputRecoveryForSession:(SFXNativePlaybackSession *)session;
- (void)performPendingAudioOutputRecovery;
- (void)cancelTimelineThumbnailRequests;
- (NSUInteger)beginPresentationTransition;
- (void)restoreCurrentPresentationGeneration:(NSUInteger)previousGeneration
                    ifCurrentGenerationIs:(NSUInteger)failedGeneration;
- (BOOL)isCurrentPresentationForSession:(SFXNativePlaybackSession *)session
                 presentationGeneration:(NSUInteger)presentationGeneration;
- (BOOL)enqueueSampleBuffer:(CMSampleBufferRef)sampleBuffer
                 forSession:(SFXNativePlaybackSession *)session
      presentationGeneration:(NSUInteger)presentationGeneration
          flushBeforeEnqueue:(BOOL)flushBeforeEnqueue;
- (void)session:(SFXNativePlaybackSession *)session
didPresentVideoFrameAtMilliseconds:(NSInteger)milliseconds
presentationGeneration:(NSUInteger)presentationGeneration;
@end

@interface SFXNativePlaybackSession : NSObject {
@package
    NSString *_path;
    __weak AVSampleBufferDisplayLayer *_displayLayer;
    __weak id<SFXNativePlaybackPlayerDelegate> _delegate;
    __weak SFXNativePlaybackPlayer *_owner;
    dispatch_queue_t _decodeQueue;
    dispatch_queue_t _demuxQueue;
    dispatch_queue_t _audioDecodeQueue;
    dispatch_queue_t _starvationQueue;
    dispatch_source_t _starvationTimer;
    NSLock *_displaySubmissionLock;
    NSCondition *_packetQueueCondition;
    NSCondition *_pacingCondition;
    SFXQueuedPacket *_packetQueueHead;
    SFXQueuedPacket *_packetQueueTail;
    SFXQueuedPacket *_audioPacketQueueHead;
    SFXQueuedPacket *_audioPacketQueueTail;
    size_t _packetQueueBytes;
    int _packetQueueCount;
    BOOL _packetQueueEOF;
    BOOL _packetQueueDemuxStarted;
    BOOL _packetQueueAtHighWater;
    BOOL _readAheadSuspended;

    AVFormatContext *_formatContext;
    AVCodecContext *_videoCodecContext;
    AVCodecContext *_audioCodecContext;
    AVBufferRef *_hardwareDeviceContext;
    AVPacket *_packet;
    AVFrame *_videoFrame;
    AVFrame *_audioFrame;
    AVFrame *_convertedAudioFrame;
    struct SwrContext *_resampler;
    struct SwsContext *_videoScaler;
    AVChannelLayout _outputLayout;
    CVPixelBufferPoolRef _softwarePixelBufferPool;
    CMVideoFormatDescriptionRef _cachedVideoFormatDescription;
    OSType _cachedVideoFormatPixelFormat;
    size_t _cachedVideoFormatWidth;
    size_t _cachedVideoFormatHeight;
    int _cachedVideoFormatSARNum;
    int _cachedVideoFormatSARDen;
    AVRational _videoSampleAspectRatio;
    int _videoFrameWidth;
    int _videoFrameHeight;

    AVAudioEngine *_audioEngine;
    AVAudioPlayerNode *_audioPlayer;
    AVAudioUnitTimePitch *_audioTimePitch;
    AVAudioFormat *_audioFormat;
    AVAudioPCMBuffer *_pendingCoalescedAudioBuffer;
    double _pendingCoalescedAudioStartMediaSeconds;
    double _pendingCoalescedAudioEndMediaSeconds;
    int _pendingCoalescedAudioSampleRate;
    NSUInteger _pendingCoalescedAudioGeneration;
    id _audioEngineConfigurationObserver;

    int _videoStreamIndex;
    int _audioStreamIndex;
    int64_t * _Nullable _keyframeStreamTimestamps;
    NSUInteger _keyframeStreamTimestampCount;
    AVRational _videoStreamTimeBase;
    NSInteger _requestedAudioTrackIndex;
    NSInteger _audioTrackIndex;
    int _audioOutputSampleRate;
    int _audioOutputChannels;
    int _resamplerInputSampleRate;
    int _resamplerInputChannels;
    enum AVSampleFormat _resamplerInputFormat;
    int _videoScalerWidth;
    int _videoScalerHeight;
    enum AVPixelFormat _videoScalerInputFormat;
    enum AVPixelFormat _videoScalerOutputFormat;
    int _softwarePixelBufferWidth;
    int _softwarePixelBufferHeight;
    OSType _softwarePixelBufferFormatType;

	    double _seekSeconds;
	    double _segmentEndSeconds;
	    double _duration;
    double _timelineOriginSeconds;
    double _currentTime;
    double _audioFirstMediaSeconds;
    double _audioStartHostSeconds;
    double _audioFirstScheduledMediaSeconds;
    double _queuedAudioMediaSeconds;
    double _videoFirstMediaSeconds;
    double _videoStartHostSeconds;
    double _lastDelegateUpdateHostSeconds;
    double _lastVideoOutputHostSeconds;
    double _rebufferStartedHostSeconds;
    double _pauseStartedHostSeconds;
    float _volume;
    _Atomic(float) _playbackRate;
    SFXNativePlaybackDecodeMode _decodeMode;
    CVPixelBufferRef _pendingDisplayPixelBuffer;
    CMTime _pendingDisplayPresentationTime;
    NSInteger _pendingDisplayAutomaticRecycleMilliseconds;
    NSInteger _pendingDisplayFrameMilliseconds;
    NSUInteger _pendingDisplayPresentationGeneration;
    NSUInteger _lastPresentedPresentationGeneration;
    NSUInteger _presentedVideoFrameCount;
    NSInteger _lastSubmittedVideoFrameMilliseconds;
    NSInteger _lastScheduledAudioStartMilliseconds;
    NSInteger _lastScheduledAudioEndMilliseconds;
    NSUInteger _segmentFinishNotificationCount;
    NSInteger _lastFinishedSegmentEndMilliseconds;
    NSUInteger _rebufferCount;
    NSInteger _lastRebufferDurationMilliseconds;
    BOOL _lastRebufferStartedWhileWaitingForPacket;
    NSUInteger _audioPlayedBackBufferCount;
    NSUInteger _unexpectedAudioDrainCount;
    NSUInteger _segmentAudioDrainCount;
    NSUInteger _audioOutputRecoveryCount;
    NSUInteger _outstandingAudioBufferCount;
    NSUInteger _pendingAudioCompletionRecordCount;
    NSUInteger _playbackGeneration;
    NSUInteger _presentationGeneration;

    atomic_bool _pauseAfterFirstFrame;
    atomic_bool _didPauseAfterFirstFrame;
    BOOL _displaySubmissionScheduled;
    BOOL _usingHardwareDecode;
    BOOL _allowAutomaticSoftwareRecycle;
    BOOL _automaticSoftwareRecycleRequested;
    BOOL _audioClockInitialized;
    BOOL _audioPlayerStarted;
    BOOL _audioStartRequested;
    BOOL _audioDrainScheduled;
    BOOL _audioResetInProgress;
    BOOL _audioPrimed;
    BOOL _audioInputEnded;
    BOOL _audioOutputDrained;
    BOOL _videoClockInitialized;
    BOOL _isRebuffering;
    BOOL _isPausedInsideLoop;
	    BOOL _seekRequestPending;
	    BOOL _seekRequestInProgress;
	    BOOL _pendingSeekRebuildsAudioOutput;
	    BOOL _audioOutputRecoveryRequested;
	    BOOL _pendingSeekPauseAfterFirstFrame;
	    NSUInteger _pendingSeekPresentationGeneration;
	    double _pendingSeekSeconds;
	    double _pendingSeekSegmentEndSeconds;
	    BOOL _pendingSeekPausesAtSegmentEnd;
	    NSUInteger _seekRequestGeneration;
	    NSUInteger _completedSeekRequestGeneration;
	    BOOL _seekRequestSucceeded;
	    NSError *_seekRequestError;
	    BOOL _segmentEndReached;
	    BOOL _segmentFinishNotified;
	    BOOL _playbackFinishNotified;
	    BOOL _pausesAtSegmentEnd;
    BOOL _autoPauseAuthorizationResolved;
    BOOL _autoPauseAuthorized;
    atomic_bool _segmentAudioBoundaryReached;
    atomic_bool _segmentVideoBoundaryReached;
    BOOL _segmentWaitingForAudioCompletion;
    BOOL _segmentAudioPlaybackCompleted;
	    atomic_bool _cancelled;
	    atomic_bool _segmentEnding;
	    atomic_bool _finishingForAutomaticRecycle;
    atomic_bool _decodeLoopFinished;
    atomic_bool _decodeWaitingForPacket;
    atomic_bool _paused;
    atomic_bool _playing;

    CFTimeInterval _perfOpenStartHostSeconds;
    double _perfStopPrevMs;
    double _perfAvformatOpenMs;
    double _perfFindStreamInfoMs;
    double _perfInitCodecAudioMs;
    double _perfInitialSeekMs;
    CFTimeInterval _perfStartHostSeconds;
    CFTimeInterval _perfFirstPacketHostSeconds;
    CFTimeInterval _perfFirstVideoPacketHostSeconds;
    CFTimeInterval _perfFirstVideoDecodedHostSeconds;
    double _perfAudioPrimeWaitMs;
    CFTimeInterval _perfFirstFrameEnqueuedHostSeconds;
    NSUInteger _perfVideoPacketsForFirstFrame;
    NSUInteger _perfSkippedVideoFramesForFirstFrame;
    BOOL _perfFirstPacketRecorded;
    BOOL _perfFirstVideoDecodedRecorded;
}

- (instancetype)initWithPath:(NSString *)path
           startMilliseconds:(NSInteger)startMilliseconds
             endMilliseconds:(NSInteger)endMilliseconds
          pausesAtSegmentEnd:(BOOL)pausesAtSegmentEnd
                       layer:(AVSampleBufferDisplayLayer *)displayLayer
                    delegate:(nullable id<SFXNativePlaybackPlayerDelegate>)delegate
                       owner:(SFXNativePlaybackPlayer *)owner
                      volume:(float)volume
                playbackRate:(float)playbackRate
                  decodeMode:(SFXNativePlaybackDecodeMode)decodeMode
             audioTrackIndex:(NSInteger)audioTrackIndex
      presentationGeneration:(NSUInteger)presentationGeneration
        pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
allowAutomaticSoftwareRecycle:(BOOL)allowAutomaticSoftwareRecycle
                       error:(NSError **)error;
- (void)configurePerfOpenStart:(CFTimeInterval)openStart stopPrevMs:(double)stopPrevMs;
- (void)start;
- (void)stopAndWait;
- (BOOL)seekToMilliseconds:(NSInteger)milliseconds
           endMilliseconds:(NSInteger)endMilliseconds
        pausesAtSegmentEnd:(BOOL)pausesAtSegmentEnd
    presentationGeneration:(NSUInteger)presentationGeneration
      pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
                     error:(NSError **)error;
- (BOOL)requestSeekToMilliseconds:(NSInteger)milliseconds
                  endMilliseconds:(NSInteger)endMilliseconds
               pausesAtSegmentEnd:(BOOL)pausesAtSegmentEnd
           presentationGeneration:(NSUInteger)presentationGeneration
             pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
              rebuildsAudioOutput:(BOOL)rebuildsAudioOutput
                            error:(NSError **)error;
- (BOOL)recoverAudioOutputWithError:(NSError **)error;
- (void)requestAudioOutputRecovery;
- (BOOL)prepareWithError:(NSError **)error;
- (void)populateKeyframeStreamTimestamps;
- (NSInteger)keyframeTimestampMillisecondsForTargetMilliseconds:(NSInteger)milliseconds;
- (BOOL)prepareVideoWithError:(NSError **)error;
- (void)resetVideoDecoderState;
- (BOOL)prepareHardwareVideoWithError:(NSError **)error;
- (BOOL)prepareSoftwareVideoWithError:(NSError **)error;
- (BOOL)prepareAudioWithError:(NSError **)error;
- (BOOL)prepareAudioOutputWithError:(NSError **)error;
- (void)teardownAudioOutput;
- (void)setPaused:(BOOL)paused;
- (void)setReadAheadSuspended:(BOOL)suspended;
- (void)setVolume:(float)volume;
- (void)setPlaybackRate:(float)playbackRate;
- (void)rebasePlaybackClocksLockedAtHostSeconds:(double)hostSeconds;
- (double)mediaSecondsForClockLockedWithFirstMediaSeconds:(double)firstMediaSeconds
                                         startHostSeconds:(double)startHostSeconds
                                              hostSeconds:(double)hostSeconds;
- (BOOL)hasActiveSegmentEnd;
- (BOOL)mediaSecondsReachedSegmentEnd:(double)mediaSeconds;
- (BOOL)resolveAutoPauseAuthorizationIfNeeded;
- (void)signalPacingCondition;
- (BOOL)segmentAudioBoundarySatisfiedLocked;
- (BOOL)segmentVideoBoundarySatisfiedLocked;
- (BOOL)segmentAudioBoundaryReached;
- (BOOL)segmentVideoBoundaryReached;
- (BOOL)isSegmentBoundaryDrainInProgress;
- (void)markSegmentAudioBoundaryReached;
- (void)markSegmentVideoBoundaryReached;
- (void)markSegmentAudioDrainCompleted;
- (void)resetSegmentBoundaryState;
- (void)finishSegmentBoundaryIfReadySchedulingClockNotification:(BOOL)scheduleClockNotification;
- (void)waitForSegmentAudioDrainIfNeeded;
- (void)waitForNaturalAudioDrainIfNeeded;
- (void)waitForSegmentFinishNotificationIfNeeded;
- (void)startAudioForDrainAfterVideoDecodeIfNeeded;
- (void)notifySegmentFinishedAfterMediaClockDelay;
- (void)notifySegmentFinishedIfNeeded;
- (void)notifyPlaybackFinishedIfNeeded;
- (void)startPacketReadAhead;
- (void)stopPacketReadAheadAndClear;
- (void)stopPacketReadAheadForSeekAndClear;
- (BOOL)hasPendingSeekRequestLocked;
- (BOOL)isPacketQueueAtHighWaterLocked;
- (double)packetQueueBufferedSecondsForHeadLocked:(nullable SFXQueuedPacket *)head
                                             tail:(nullable SFXQueuedPacket *)tail;
- (double)packetQueueBufferedSecondsLocked;
- (double)audioPacketQueueBufferedSecondsLocked;
- (void)clearAudioPacketQueueLocked;
- (void)clearPacketQueueLocked;
- (size_t)packetMemoryBytes:(nullable const AVPacket *)packet;
- (double)queuedAudioWallSecondsLocked;
- (nullable SFXQueuedPacket *)dequeueAudioPacketLocked;
- (void)requestAudioDrain;
- (void)drainAudioPacketsForGeneration:(NSUInteger)generation;
- (void)demuxLoop;
- (void)waitUntilPacketQueueHasStartupWaterline;
- (nullable SFXQueuedPacket *)dequeueVideoPacket;
- (BOOL)performPendingSeekIfNeeded;
- (BOOL)waitForAutoStopSeekIfNeeded;
- (BOOL)applyInSessionSeekToSeconds:(double)seekSeconds
                  segmentEndSeconds:(double)segmentEndSeconds
                 pausesAtSegmentEnd:(BOOL)pausesAtSegmentEnd
             presentationGeneration:(NSUInteger)presentationGeneration
               pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
                rebuildsAudioOutput:(BOOL)rebuildsAudioOutput
                              error:(NSError **)error;

@property (nonatomic, copy, readonly) NSString *path;
@property (nonatomic, readonly) double currentTime;
@property (nonatomic, readonly) double duration;
@property (nonatomic, readonly) NSInteger segmentEndMilliseconds;
@property (nonatomic, readonly) BOOL pausesAtSegmentEnd;
@property (nonatomic, readonly) NSInteger videoWidth;
@property (nonatomic, readonly) NSInteger videoHeight;
@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
@property (nonatomic, readonly) NSUInteger presentationGeneration;
@property (nonatomic, readonly) NSUInteger presentedVideoFrameCount;
@property (nonatomic, readonly) NSInteger lastSubmittedVideoFrameMilliseconds;
@property (nonatomic, readonly) NSInteger lastScheduledAudioStartMilliseconds;
@property (nonatomic, readonly) NSInteger lastScheduledAudioEndMilliseconds;
@property (nonatomic, readonly) NSUInteger segmentFinishNotificationCount;
@property (nonatomic, readonly) NSInteger lastFinishedSegmentEndMilliseconds;
@property (nonatomic, readonly) NSUInteger rebufferCount;
@property (nonatomic, readonly) NSInteger lastRebufferDurationMilliseconds;
@property (nonatomic, readonly) BOOL lastRebufferStartedWhileWaitingForPacket;
@property (nonatomic, readonly) NSUInteger audioPlayedBackBufferCount;
@property (nonatomic, readonly) NSUInteger unexpectedAudioDrainCount;
@property (nonatomic, readonly) NSUInteger segmentAudioDrainCount;
@property (nonatomic, readonly) NSUInteger audioOutputRecoveryCount;
@property (nonatomic, readonly) BOOL audioOutputDrained;
@property (nonatomic, readonly, getter=isFinished) BOOL finished;
/// Paused, or opened to pause on its first frame and not yet resumed.
@property (nonatomic, readonly, getter=isPaused) BOOL paused;
@property (nonatomic, readonly) NSInteger audioTrackIndex;
@property (nonatomic, readonly) SFXNativePlaybackDecodeMode decodeMode;
@property (nonatomic, readonly) BOOL usingHardwareDecode;
@end

@interface SFXNativePlaybackSession (AudioAndDecode)
- (void)decodeLoop;
- (void)waitWhilePausedIfNeeded;
- (void)startStarvationWatchdog;
- (void)armStarvationWatchdog;
- (void)disarmStarvationWatchdog;
- (void)stopStarvationWatchdog;
- (void)checkVideoStarvation;
- (void)resumeFromRebufferIfNeededAtHostSeconds:(double)hostSeconds;
- (BOOL)ensureSoftwareVideoScalerForFrame:(AVFrame *)frame
                                    width:(int)width
                                   height:(int)height
                             outputFormat:(enum AVPixelFormat)outputFormat;
- (BOOL)ensureSoftwarePixelBufferPoolWithWidth:(int)width
                                        height:(int)height
                                   pixelFormat:(OSType)pixelFormat;
- (nullable CVPixelBufferRef)copyPixelBufferForSoftwareFrame:(AVFrame *)frame;
- (void)handleVideoPacket:(AVPacket *)packet;
- (void)handleAudioPacket:(nullable AVPacket *)packet generation:(NSUInteger)generation;
- (BOOL)waitForAudioPrimeForGeneration:(NSUInteger)generation;
- (void)requestAudioPlaybackStartIfReadyForGeneration:(NSUInteger)generation;
- (BOOL)paceVideoFrame:(AVFrame *)frame stream:(AVStream *)stream;
- (nullable CMSampleBufferRef)sampleBufferForPixelBuffer:(CVPixelBufferRef)pixelBuffer
                                        presentationTime:(CMTime)presentationTime;
- (BOOL)enqueuePixelBuffer:(CVPixelBufferRef)pixelBuffer
          presentationTime:(CMTime)presentationTime
         frameMilliseconds:(NSInteger)frameMilliseconds
automaticRecycleMilliseconds:(NSInteger)automaticRecycleMilliseconds;
- (void)clearPendingPixelBufferSubmission;
- (NSInteger)markAutomaticSoftwareRecycleIfNeededAtMediaSeconds:(double)mediaSeconds;
- (int)audioFrameSampleRate:(const AVFrame *)frame;
- (int)audioFrameChannelCount:(const AVFrame *)frame;
- (BOOL)audioFrameMatchesOutput:(const AVFrame *)frame;
- (BOOL)ensureResamplerForFrame:(const AVFrame *)frame;
- (nullable const AVFrame *)outputAudioFrameForFrame:(const AVFrame *)frame;
- (void)audioBufferDidPlayForGeneration:(NSUInteger)generation
                          mediaDuration:(double)mediaDuration
                     finalSegmentBuffer:(BOOL)finalSegmentBuffer;
- (BOOL)flushPendingCoalescedAudioForGeneration:(NSUInteger)generation
                             finalSegmentBuffer:(BOOL)isFinalSegmentBuffer;
- (SFXAudioScheduleResult)scheduleAudioFrame:(const AVFrame *)frame
                                mediaSeconds:(double)mediaSeconds
                                  generation:(NSUInteger)generation;
- (void)notifyTimeIfNeeded:(BOOL)force;
- (void)notifyFailure:(NSString *)message;
- (void)teardown;
@end

NS_ASSUME_NONNULL_END
