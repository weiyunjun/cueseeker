#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SFXNativePlaybackPlayer;

typedef NS_ENUM(NSInteger, SFXNativePlaybackDecodeMode) {
    SFXNativePlaybackDecodeModeHardware = 0,
    SFXNativePlaybackDecodeModeSoftware = 1,
    SFXNativePlaybackDecodeModeAuto = 2
};

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
didFinishSegmentAtMilliseconds:(NSInteger)endMilliseconds;
@end

@interface SFXNativePlaybackPlayer : NSObject

@property (nonatomic, weak, nullable) id<SFXNativePlaybackPlayerDelegate> delegate;
@property (nonatomic, strong, readonly) NSView *view;
@property (nonatomic, copy, readonly, nullable) NSString *currentPath;
@property (nonatomic, readonly) double currentTime;
@property (nonatomic, readonly) double duration;
@property (nonatomic, readonly) NSInteger videoWidth;
@property (nonatomic, readonly) NSInteger videoHeight;
@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
@property (nonatomic, readonly) NSUInteger nativeSessionOpenCount;
@property (nonatomic, readonly) NSUInteger nativeInSessionSeekCount;
@property (nonatomic, readonly) NSUInteger nativePresentedVideoFrameCount;
@property (nonatomic) float volume;
@property (nonatomic) float playbackRate;
@property (nonatomic) SFXNativePlaybackDecodeMode decodeMode;

- (BOOL)openPath:(NSString *)path
startMilliseconds:(NSInteger)startMilliseconds
	           error:(NSError **)error;
- (BOOL)openPath:(NSString *)path
startMilliseconds:(NSInteger)startMilliseconds
 endMilliseconds:(NSInteger)endMilliseconds
	           error:(NSError **)error;
- (BOOL)seekToMilliseconds:(NSInteger)milliseconds error:(NSError **)error;
- (BOOL)seekToMilliseconds:(NSInteger)milliseconds
	      pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
	                     error:(NSError **)error;
- (BOOL)seekToMilliseconds:(NSInteger)milliseconds
           endMilliseconds:(NSInteger)endMilliseconds
                     error:(NSError **)error;
- (BOOL)seekToMilliseconds:(NSInteger)milliseconds
           endMilliseconds:(NSInteger)endMilliseconds
      pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
                     error:(NSError **)error;
- (BOOL)setPaused:(BOOL)paused error:(NSError **)error;
- (BOOL)setTimelineScrubbing:(BOOL)active error:(NSError **)error;
- (void)requestTimelineScrubPreviewAtMilliseconds:(NSInteger)milliseconds;
- (void)stop;

@end

@interface SFXMediaMetadataInspector : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (nullable NSNumber *)durationSecondsAtMediaPath:(NSString *)mediaPath
                                           error:(NSError **)error
    NS_SWIFT_NAME(durationSeconds(atMediaPath:));

@end

FOUNDATION_EXPORT NSString * const SFXNativePlaybackErrorDomain;

NS_ASSUME_NONNULL_END
