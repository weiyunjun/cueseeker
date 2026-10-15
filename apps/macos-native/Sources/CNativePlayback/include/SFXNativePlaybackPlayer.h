#import <AppKit/AppKit.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SFXNativePlaybackPlayer;
@class SFXMediaMetadata;
@class SFXMediaAudioTrack;
@class SFXMediaCoverCandidateFrame;

@interface SFXNativePlaybackFrameSnapshot : NSObject

@property (nonatomic, readonly) CVPixelBufferRef pixelBuffer;
@property (nonatomic, readonly) NSInteger width;
@property (nonatomic, readonly) NSInteger height;

- (instancetype)init NS_UNAVAILABLE;

@end

typedef NS_ENUM(NSInteger, SFXNativePlaybackDecodeMode) {
    SFXNativePlaybackDecodeModeHardware = 0,
    SFXNativePlaybackDecodeModeSoftware = 1,
    SFXNativePlaybackDecodeModeAuto = 2
};

typedef struct SFXNativePlaybackRuntimeTelemetry {
    double userCPUSeconds;
    double systemCPUSeconds;
    uint64_t instructions;
    uint64_t cycles;
    uint64_t interruptWakeups;
    uint64_t physFootprintBytes;

    uint64_t videoDecodedFrames;
    uint64_t videoSubmittedFrames;
    uint64_t videoDecodeMicroseconds;
    uint64_t videoPixelTransferMicroseconds;
    uint64_t videoSubmissionMicroseconds;
    uint64_t videoFormatDescCreateCalls;
    uint64_t videoWaitIterations;

    uint64_t audioDecodedFrames;
    uint64_t audioScheduledBuffers;
    uint64_t audioCompletionCallbacks;
    uint64_t audioDecodeAndResampleMicroseconds;
    uint64_t audioScheduleMicroseconds;
    BOOL timePitchBypassed;
} SFXNativePlaybackRuntimeTelemetry;

@protocol SFXNativePlaybackPlayerDelegate <NSObject>
@required
- (void)nativePlaybackPlayer:(SFXNativePlaybackPlayer *)player
	               didUpdateTime:(double)time
	                    duration:(double)duration
	                     playing:(BOOL)playing;
- (void)nativePlaybackPlayer:(SFXNativePlaybackPlayer *)player
	        didFailWithMessage:(NSString *)message;
@optional
- (void)nativePlaybackPlayer:(SFXNativePlaybackPlayer *)player
	               didUpdateTime:(double)time
	                    duration:(double)duration
	                     playing:(BOOL)playing
	      presentationGeneration:(NSUInteger)presentationGeneration;
- (void)nativePlaybackPlayer:(SFXNativePlaybackPlayer *)player
didPresentVideoFrameAtMilliseconds:(NSInteger)milliseconds
	      presentationGeneration:(NSUInteger)presentationGeneration;
- (void)nativePlaybackPlayer:(SFXNativePlaybackPlayer *)player
didFinishSegmentAtMilliseconds:(NSInteger)endMilliseconds;
- (void)nativePlaybackPlayerDidFinishPlayback:(SFXNativePlaybackPlayer *)player;
- (BOOL)nativePlaybackPlayer:(SFXNativePlaybackPlayer *)player
shouldPauseAtAutoStopBoundaryAtMilliseconds:(NSInteger)endMilliseconds
      presentationGeneration:(NSUInteger)presentationGeneration;
- (void)nativePlaybackPlayer:(SFXNativePlaybackPlayer *)player
didReachAutoStopBoundaryAtMilliseconds:(NSInteger)endMilliseconds;
@end

@interface SFXNativePlaybackPlayer : NSObject

@property (nonatomic, weak, nullable) id<SFXNativePlaybackPlayerDelegate> delegate;
@property (nonatomic, strong, readonly) NSView *view;
@property (nonatomic, copy, readonly, nullable) NSString *currentPath;
@property (nonatomic, copy, nullable) NSString *httpHeaders;
@property (nonatomic, readonly) double currentTime;
@property (nonatomic, readonly) double duration;
@property (nonatomic, readonly) NSInteger videoWidth;
@property (nonatomic, readonly) NSInteger videoHeight;
@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
@property (nonatomic, readonly) NSUInteger nativeSessionOpenCount;
@property (nonatomic, readonly) NSUInteger nativeInSessionSeekCount;
@property (nonatomic, readonly) NSUInteger nativePresentationGeneration;
@property (nonatomic, readonly) NSUInteger nativeDisplayImageRemovalCount;
@property (nonatomic, readonly) NSUInteger nativePresentedVideoFrameCount;
@property (nonatomic, readonly) NSInteger nativeLastSubmittedVideoFrameMilliseconds;
@property (nonatomic, strong, readonly, nullable) SFXNativePlaybackFrameSnapshot *latestSubmittedVideoFrameSnapshot;
@property (nonatomic, readonly) NSInteger nativeLastScheduledAudioStartMilliseconds;
@property (nonatomic, readonly) NSInteger nativeLastScheduledAudioEndMilliseconds;
@property (nonatomic, readonly) NSUInteger nativeSegmentFinishNotificationCount;
@property (nonatomic, readonly) NSInteger nativeLastFinishedSegmentEndMilliseconds;
@property (nonatomic, readonly) NSUInteger nativeRebufferCount;
@property (nonatomic, readonly) NSInteger nativeLastRebufferDurationMilliseconds;
@property (nonatomic, readonly) BOOL nativeLastRebufferStartedWhileWaitingForPacket;
@property (nonatomic, readonly) NSUInteger nativeAudioPlayedBackBufferCount;
@property (nonatomic, readonly) NSUInteger nativeUnexpectedAudioDrainCount;
@property (nonatomic, readonly) NSUInteger nativeSegmentAudioDrainCount;
@property (nonatomic, readonly) NSUInteger nativeAudioOutputRecoveryCount;
@property (nonatomic, readonly) BOOL nativeAudioOutputDrained;
@property (nonatomic) float volume;
@property (nonatomic) float playbackRate;
@property (nonatomic) SFXNativePlaybackDecodeMode decodeMode;
@property (nonatomic, readonly) SFXNativePlaybackDecodeMode activeDecodeMode;
@property (nonatomic, readonly) BOOL usingHardwareDecode;
@property (nonatomic, copy, readonly, nullable) NSString *activeVideoCodecName;
@property (nonatomic, copy, readonly, nullable) NSString *activeOutputPixelFormatName;

- (SFXNativePlaybackRuntimeTelemetry)runtimeTelemetrySnapshot;

+ (BOOL)isHardwareDecodeSupportedForCodecName:(NSString *)codecName;
/// The audio track an open plays, counted from 0 among the file's audio
/// streams in file order. A file without that track plays its first one.
@property (nonatomic) NSInteger audioTrackIndex;
/// The audio track the open file is playing, counted the same way; -1 when
/// nothing is open or the file has no audio.
@property (nonatomic, readonly) NSInteger currentAudioTrackIndex;

- (BOOL)openPath:(NSString *)path
startMilliseconds:(NSInteger)startMilliseconds
	           error:(NSError **)error;
- (BOOL)openPath:(NSString *)path
startMilliseconds:(NSInteger)startMilliseconds
 endMilliseconds:(NSInteger)endMilliseconds
	           error:(NSError **)error;
- (BOOL)openPath:(NSString *)path
startMilliseconds:(NSInteger)startMilliseconds
autoStopAtMilliseconds:(NSInteger)endMilliseconds
                  error:(NSError **)error;
- (BOOL)seekToMilliseconds:(NSInteger)milliseconds error:(NSError **)error;
- (BOOL)seekToMilliseconds:(NSInteger)milliseconds
	      pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
	                     error:(NSError **)error;
- (BOOL)seekToMilliseconds:(NSInteger)milliseconds
           endMilliseconds:(NSInteger)endMilliseconds
                     error:(NSError **)error;
- (BOOL)seekToMilliseconds:(NSInteger)milliseconds
    autoStopAtMilliseconds:(NSInteger)endMilliseconds
                     error:(NSError **)error;
- (BOOL)seekToMilliseconds:(NSInteger)milliseconds
    autoStopAtMilliseconds:(NSInteger)endMilliseconds
      pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
                     error:(NSError **)error;
- (BOOL)seekToMilliseconds:(NSInteger)milliseconds
           endMilliseconds:(NSInteger)endMilliseconds
      pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
                     error:(NSError **)error;
- (BOOL)setPaused:(BOOL)paused error:(NSError **)error;
/// Reopens the current file at the current position on another audio track,
/// keeping the position, the pause and the segment end.
- (BOOL)selectAudioTrackIndex:(NSInteger)audioTrackIndex error:(NSError **)error;
- (BOOL)setTimelineScrubbing:(BOOL)active error:(NSError **)error;
- (void)requestTimelineScrubPreviewAtMilliseconds:(NSInteger)milliseconds;
- (void)requestAudioOutputRecoveryForTesting;
- (void)stop;

@end

@interface SFXMediaMetadataInspector : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (nullable NSNumber *)durationSecondsAtMediaPath:(NSString *)mediaPath
                                            error:(NSError **)error
    NS_SWIFT_NAME(durationSeconds(atMediaPath:));
+ (nullable SFXMediaMetadata *)metadataAtMediaPath:(NSString *)mediaPath
                                             error:(NSError **)error
    NS_SWIFT_NAME(metadata(atMediaPath:));
+ (nullable SFXMediaMetadata *)metadataAtMediaPath:(NSString *)mediaPath
                                       httpHeaders:(nullable NSString *)httpHeaders
                                             error:(NSError **)error
    NS_SWIFT_NAME(metadata(atMediaPath:httpHeaders:));
+ (nullable NSArray<SFXMediaCoverCandidateFrame *> *)sampleCoverFramesAtMediaPath:(NSString *)mediaPath
                                                                      httpHeaders:(nullable NSString *)httpHeaders
                                                           timestampsMilliseconds:(NSArray<NSNumber *> *)timestampsMilliseconds
                                                                     scoringWidth:(NSInteger)scoringWidth
                                                                    scoringHeight:(NSInteger)scoringHeight
                                                                            error:(NSError **)error
    NS_SWIFT_NAME(sampleCoverFrames(atMediaPath:httpHeaders:timestampsMilliseconds:scoringWidth:scoringHeight:));

@end

@interface SFXMediaCoverCandidateFrame : NSObject

@property (nonatomic, readonly) NSInteger timestampMilliseconds;
@property (nonatomic, strong, readonly) NSData *scoringRGB24Data;
@property (nonatomic, readonly) CGImageRef cgImage CF_RETURNS_NOT_RETAINED;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface SFXMediaMetadata : NSObject

@property (nonatomic, strong, readonly, nullable) NSNumber *durationSeconds;
@property (nonatomic, strong, readonly, nullable) NSNumber *videoWidth;
@property (nonatomic, strong, readonly, nullable) NSNumber *videoHeight;
@property (nonatomic, strong, readonly, nullable) NSNumber *frameRate;
@property (nonatomic, copy, readonly, nullable) NSString *videoCodec;
/// Every audio stream, in file order.
@property (nonatomic, copy, readonly) NSArray<SFXMediaAudioTrack *> *audioTracks;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface SFXMediaAudioTrack : NSObject

@property (nonatomic, copy, readonly, nullable) NSString *language;
@property (nonatomic, copy, readonly, nullable) NSString *title;
@property (nonatomic, copy, readonly, nullable) NSString *codec;
@property (nonatomic, strong, readonly, nullable) NSNumber *channels;

- (instancetype)init NS_UNAVAILABLE;

@end

FOUNDATION_EXPORT NSString * const SFXNativePlaybackErrorDomain;

NS_ASSUME_NONNULL_END
