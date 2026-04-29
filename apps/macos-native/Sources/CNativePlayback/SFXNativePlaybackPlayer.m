#import "SFXNativePlaybackPlayer.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>
#import <dispatch/dispatch.h>

#include <libavcodec/avcodec.h>
#include <libavcodec/packet.h>
#include <libavformat/avformat.h>
#include <libavutil/channel_layout.h>
#include <libavutil/error.h>
#include <libavutil/hwcontext.h>
#include <libavutil/log.h>
#include <libavutil/mathematics.h>
#include <libavutil/pixdesc.h>
#include <libswresample/swresample.h>

#include <math.h>
#include <stdatomic.h>

NSString * const SFXNativePlaybackErrorDomain = @"SubFinderX.NativePlayback";

static enum AVPixelFormat SFXHardwarePixelFormat = AV_PIX_FMT_NONE;
static const float SFXMinimumPlaybackRate = 0.5f;
static const float SFXMaximumPlaybackRate = 2.0f;

static float SFXClampedPlaybackRate(float playbackRate) {
    if (!isfinite(playbackRate)) {
        return 1.0f;
    }
    return fmaxf(SFXMinimumPlaybackRate, fminf(playbackRate, SFXMaximumPlaybackRate));
}

static NSString *SFXFFmpegErrorString(int code) {
    char buffer[AV_ERROR_MAX_STRING_SIZE] = {0};
    if (av_strerror(code, buffer, sizeof(buffer)) < 0) {
        return [NSString stringWithFormat:@"FFmpeg error %d", code];
    }
    return [NSString stringWithUTF8String:buffer];
}

static NSError *SFXNativePlaybackError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:SFXNativePlaybackErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

static void SFXDispatchSyncOnMain(dispatch_block_t block) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

static const AVCodecHWConfig *SFXFindVideoToolboxConfig(const AVCodec *decoder) {
    for (int index = 0;; index++) {
        const AVCodecHWConfig *config = avcodec_get_hw_config(decoder, index);
        if (config == NULL) {
            return NULL;
        }

        if ((config->methods & AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX) != 0
            && config->device_type == AV_HWDEVICE_TYPE_VIDEOTOOLBOX) {
            return config;
        }
    }
}

static const AVCodec *SFXFindVideoToolboxDecoder(
    enum AVCodecID codecID,
    const AVCodecHWConfig **hardwareConfig
) {
    const AVCodec *defaultDecoder = avcodec_find_decoder(codecID);
    if (defaultDecoder != NULL) {
        const AVCodecHWConfig *config = SFXFindVideoToolboxConfig(defaultDecoder);
        if (config != NULL) {
            if (hardwareConfig != NULL) {
                *hardwareConfig = config;
            }
            return defaultDecoder;
        }
    }

    void *iterator = NULL;
    const AVCodec *candidate = NULL;
    while ((candidate = av_codec_iterate(&iterator)) != NULL) {
        if (!av_codec_is_decoder(candidate)
            || candidate->type != AVMEDIA_TYPE_VIDEO
            || candidate->id != codecID) {
            continue;
        }

        const AVCodecHWConfig *config = SFXFindVideoToolboxConfig(candidate);
        if (config == NULL) {
            continue;
        }

        if (hardwareConfig != NULL) {
            *hardwareConfig = config;
        }
        return candidate;
    }

    if (hardwareConfig != NULL) {
        *hardwareConfig = NULL;
    }
    return defaultDecoder;
}

static enum AVPixelFormat SFXChooseHardwareFormat(
    AVCodecContext *context,
    const enum AVPixelFormat *pixelFormats
) {
    (void)context;

    for (const enum AVPixelFormat *format = pixelFormats; *format != AV_PIX_FMT_NONE; format++) {
        if (*format == SFXHardwarePixelFormat) {
            return *format;
        }
    }

    return pixelFormats[0];
}

static double SFXStreamStartSeconds(AVStream *stream) {
    if (stream->start_time == AV_NOPTS_VALUE) {
        return 0;
    }
    return av_q2d(stream->time_base) * stream->start_time;
}

static double SFXFramePlaybackSeconds(const AVFrame *frame, AVStream *stream) {
    if (frame->best_effort_timestamp == AV_NOPTS_VALUE) {
        return -1;
    }
    return av_q2d(stream->time_base) * frame->best_effort_timestamp - SFXStreamStartSeconds(stream);
}

static int64_t SFXSeekTimestamp(double seconds, AVStream *stream) {
    int64_t relativeTimestamp = (int64_t)llround(seconds / av_q2d(stream->time_base));
    if (stream->start_time == AV_NOPTS_VALUE) {
        return relativeTimestamp;
    }
    return stream->start_time + relativeTimestamp;
}

static int64_t SFXGlobalSeekTimestamp(double seconds, AVFormatContext *formatContext) {
    int64_t timestamp = (int64_t)llround(seconds * AV_TIME_BASE);
    if (formatContext->start_time != AV_NOPTS_VALUE) {
        timestamp += formatContext->start_time;
    }
    return timestamp;
}

static BOOL SFXSeekToStartPosition(
    AVFormatContext *formatContext,
    int videoStreamIndex,
    double seconds,
    NSError **error
) {
    AVStream *videoStream = formatContext->streams[videoStreamIndex];
    int64_t streamTimestamp = SFXSeekTimestamp(seconds, videoStream);
    int streamResult = av_seek_frame(
        formatContext,
        videoStreamIndex,
        streamTimestamp,
        AVSEEK_FLAG_BACKWARD
    );
    if (streamResult >= 0) {
        return YES;
    }

    int64_t globalTimestamp = SFXGlobalSeekTimestamp(seconds, formatContext);
    int globalResult = av_seek_frame(
        formatContext,
        -1,
        globalTimestamp,
        AVSEEK_FLAG_BACKWARD
    );
    if (globalResult >= 0) {
        return YES;
    }

    if (seconds <= 0.001) {
        return YES;
    }

    if (error != NULL) {
        *error = SFXNativePlaybackError(
            14,
            [NSString stringWithFormat:
                @"av_seek_frame failed: stream seek %@, global seek %@",
                SFXFFmpegErrorString(streamResult),
                SFXFFmpegErrorString(globalResult)
            ]
        );
    }
    return NO;
}

static BOOL SFXFrameBeforeSeekTarget(const AVFrame *frame, AVStream *stream, double seekSeconds) {
    double frameSeconds = SFXFramePlaybackSeconds(frame, stream);
    if (frameSeconds < 0) {
        return NO;
    }
    return frameSeconds + 0.002 < seekSeconds;
}

static CMTime SFXFramePresentationTime(const AVFrame *frame, AVStream *stream) {
    if (frame->best_effort_timestamp == AV_NOPTS_VALUE) {
        return CMTimeMake(0, 1);
    }
    int64_t value = frame->best_effort_timestamp * stream->time_base.num;
    return CMTimeMake(value, stream->time_base.den);
}

static int SFXOutputChannelCount(int inputChannels) {
    if (inputChannels <= 0) {
        return 0;
    }
    return inputChannels > 2 ? 2 : inputChannels;
}

@interface SFXNativePlaybackView : NSView
@property (nonatomic, strong, readonly) AVSampleBufferDisplayLayer *displayLayer;
@end

@implementation SFXNativePlaybackView {
    AVSampleBufferDisplayLayer *_displayLayer;
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self == nil) {
        return nil;
    }

    self.wantsLayer = YES;
    self.layer.backgroundColor = NSColor.blackColor.CGColor;

    _displayLayer = [AVSampleBufferDisplayLayer layer];
    _displayLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    _displayLayer.backgroundColor = NSColor.blackColor.CGColor;
    [self.layer addSublayer:_displayLayer];

    return self;
}

- (AVSampleBufferDisplayLayer *)displayLayer {
    return _displayLayer;
}

- (void)layout {
    [super layout];
    _displayLayer.frame = self.bounds;
}

- (void)flush {
    [_displayLayer flushAndRemoveImage];
}

@end

@class SFXNativePlaybackSession;

@interface SFXNativePlaybackSession : NSObject
- (instancetype)initWithPath:(NSString *)path
           startMilliseconds:(NSInteger)startMilliseconds
                       layer:(AVSampleBufferDisplayLayer *)displayLayer
                    delegate:(id<SFXNativePlaybackPlayerDelegate>)delegate
                       owner:(SFXNativePlaybackPlayer *)owner
                      volume:(float)volume
                playbackRate:(float)playbackRate
      flushDisplayBeforeStart:(BOOL)flushDisplayBeforeStart
                       error:(NSError **)error;
- (void)start;
- (void)stopAndWait;
- (void)setPaused:(BOOL)paused;
- (void)setVolume:(float)volume;
- (void)setPlaybackRate:(float)playbackRate;
@property (nonatomic, copy, readonly) NSString *path;
@property (nonatomic, readonly) double currentTime;
@property (nonatomic, readonly) double duration;
@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
@end

@implementation SFXNativePlaybackSession {
    NSString *_path;
    __weak AVSampleBufferDisplayLayer *_displayLayer;
    __weak id<SFXNativePlaybackPlayerDelegate> _delegate;
    __weak SFXNativePlaybackPlayer *_owner;
    dispatch_queue_t _decodeQueue;

    AVFormatContext *_formatContext;
    AVCodecContext *_videoCodecContext;
    AVCodecContext *_audioCodecContext;
    AVBufferRef *_hardwareDeviceContext;
    AVPacket *_packet;
    AVFrame *_videoFrame;
    AVFrame *_audioFrame;
    AVFrame *_convertedAudioFrame;
    struct SwrContext *_resampler;
    AVChannelLayout _outputLayout;

    AVAudioEngine *_audioEngine;
    AVAudioPlayerNode *_audioPlayer;
    AVAudioUnitTimePitch *_audioTimePitch;
    AVAudioFormat *_audioFormat;

    int _videoStreamIndex;
    int _audioStreamIndex;
    int _audioOutputSampleRate;
    int _audioOutputChannels;
    int _resamplerInputSampleRate;
    int _resamplerInputChannels;
    enum AVSampleFormat _resamplerInputFormat;

    double _seekSeconds;
    double _duration;
    double _currentTime;
    double _audioFirstMediaSeconds;
    double _audioStartHostSeconds;
    double _videoFirstMediaSeconds;
    double _videoStartHostSeconds;
    double _lastDelegateUpdateHostSeconds;
    double _pauseStartedHostSeconds;
    float _volume;
    float _playbackRate;

    BOOL _flushDisplayBeforeStart;
    BOOL _flushDisplayOnFirstFrame;
    BOOL _audioClockInitialized;
    BOOL _audioPlayerStarted;
    BOOL _videoClockInitialized;
    BOOL _isPausedInsideLoop;
    atomic_bool _cancelled;
    atomic_bool _paused;
    atomic_bool _playing;
}

- (instancetype)initWithPath:(NSString *)path
           startMilliseconds:(NSInteger)startMilliseconds
                       layer:(AVSampleBufferDisplayLayer *)displayLayer
                    delegate:(id<SFXNativePlaybackPlayerDelegate>)delegate
                      owner:(SFXNativePlaybackPlayer *)owner
                      volume:(float)volume
                playbackRate:(float)playbackRate
      flushDisplayBeforeStart:(BOOL)flushDisplayBeforeStart
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
    _playbackRate = SFXClampedPlaybackRate(playbackRate);
    _flushDisplayBeforeStart = flushDisplayBeforeStart;
    _flushDisplayOnFirstFrame = !flushDisplayBeforeStart;
    _seekSeconds = MAX(0, (double)startMilliseconds / 1000.0);
    _currentTime = _seekSeconds;
    _videoStreamIndex = -1;
    _audioStreamIndex = -1;
    _decodeQueue = dispatch_queue_create("SubFinderX.NativePlayback.Decode", DISPATCH_QUEUE_SERIAL);
    atomic_init(&_cancelled, false);
    atomic_init(&_paused, false);
    atomic_init(&_playing, false);

    if (![self prepareWithError:error]) {
        [self teardown];
        return nil;
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

- (BOOL)isPlaying {
    return atomic_load(&_playing);
}

- (BOOL)prepareWithError:(NSError **)error {
    int result = avformat_open_input(&_formatContext, _path.UTF8String, NULL, NULL);
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(10, [NSString stringWithFormat:@"avformat_open_input failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    result = avformat_find_stream_info(_formatContext, NULL);
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(11, [NSString stringWithFormat:@"avformat_find_stream_info failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    if (_formatContext->duration != AV_NOPTS_VALUE) {
        _duration = (double)_formatContext->duration / AV_TIME_BASE;
    }

    for (unsigned int index = 0; index < _formatContext->nb_streams; index++) {
        AVStream *stream = _formatContext->streams[index];
        if (_videoStreamIndex < 0 && stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            _videoStreamIndex = (int)index;
        } else if (_audioStreamIndex < 0 && stream->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            _audioStreamIndex = (int)index;
        }
    }

    if (_videoStreamIndex < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(12, @"No video stream found.");
        }
        return NO;
    }

    if (![self prepareVideoWithError:error]) {
        return NO;
    }

    if (_audioStreamIndex >= 0 && ![self prepareAudioWithError:error]) {
        return NO;
    }

    _packet = av_packet_alloc();
    _videoFrame = av_frame_alloc();
    if (_packet == NULL || _videoFrame == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(13, @"Could not allocate native playback packet or frame.");
        }
        return NO;
    }

    if (!SFXSeekToStartPosition(_formatContext, _videoStreamIndex, _seekSeconds, error)) {
        return NO;
    }

    avcodec_flush_buffers(_videoCodecContext);
    if (_audioCodecContext != NULL) {
        avcodec_flush_buffers(_audioCodecContext);
    }

    if (_flushDisplayBeforeStart) {
        SFXDispatchSyncOnMain(^{
            [_displayLayer flushAndRemoveImage];
        });
    }

    return YES;
}

- (BOOL)prepareVideoWithError:(NSError **)error {
    AVStream *videoStream = _formatContext->streams[_videoStreamIndex];
    AVCodecParameters *parameters = videoStream->codecpar;
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

    _audioEngine = [[AVAudioEngine alloc] init];
    _audioPlayer = [[AVAudioPlayerNode alloc] init];
    _audioTimePitch = [[AVAudioUnitTimePitch alloc] init];
    _audioPlayer.volume = _volume;
    _audioTimePitch.rate = _playbackRate;
    _audioFormat = [[AVAudioFormat alloc]
        initStandardFormatWithSampleRate:(double)_audioOutputSampleRate
        channels:(AVAudioChannelCount)_audioOutputChannels
    ];

    if (_audioEngine == nil || _audioPlayer == nil || _audioTimePitch == nil || _audioFormat == nil) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(35, @"Could not create AVAudioEngine output objects.");
        }
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
        return NO;
    }

    return YES;
}

- (void)start {
    dispatch_async(_decodeQueue, ^{
        @autoreleasepool {
            [self decodeLoop];
            [self teardown];
        }
    });
}

- (void)stopAndWait {
    atomic_store(&_cancelled, true);
    atomic_store(&_paused, false);

    if (_decodeQueue != NULL) {
        dispatch_sync(_decodeQueue, ^{});
    }
}

- (void)setPaused:(BOOL)paused {
    atomic_store(&_paused, paused);
    atomic_store(&_playing, !paused);

    AVAudioPlayerNode *audioPlayer = _audioPlayer;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (paused) {
            [audioPlayer pause];
        } else if (audioPlayer != nil && _audioPlayerStarted) {
            [audioPlayer play];
        }
    });

    [self notifyTimeIfNeeded:YES];
}

- (void)setVolume:(float)volume {
    _volume = volume;
    AVAudioPlayerNode *audioPlayer = _audioPlayer;
    dispatch_async(dispatch_get_main_queue(), ^{
        audioPlayer.volume = volume;
    });
}

- (void)setPlaybackRate:(float)playbackRate {
    float clampedRate = SFXClampedPlaybackRate(playbackRate);
    double hostSeconds = CACurrentMediaTime();

    @synchronized (self) {
        [self rebasePlaybackClocksLockedAtHostSeconds:hostSeconds];
        _playbackRate = clampedRate;
        if (_isPausedInsideLoop) {
            _pauseStartedHostSeconds = hostSeconds;
        }
    }

    AVAudioUnitTimePitch *audioTimePitch = _audioTimePitch;
    dispatch_async(dispatch_get_main_queue(), ^{
        audioTimePitch.rate = clampedRate;
    });
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
    return firstMediaSeconds + (elapsedHostSeconds * _playbackRate);
}

- (void)decodeLoop {
    atomic_store(&_playing, true);
    [self notifyTimeIfNeeded:YES];

    while (!atomic_load(&_cancelled)) {
        [self waitWhilePausedIfNeeded];
        if (atomic_load(&_cancelled)) {
            break;
        }

        int result = av_read_frame(_formatContext, _packet);
        if (result < 0) {
            break;
        }

        if (_packet->stream_index == _audioStreamIndex && _audioCodecContext != NULL) {
            [self handleAudioPacket:_packet];
            av_packet_unref(_packet);
            continue;
        }

        if (_packet->stream_index == _videoStreamIndex) {
            [self handleVideoPacket:_packet];
        }

        av_packet_unref(_packet);
    }

    BOOL cancelled = atomic_load(&_cancelled);
    atomic_store(&_playing, false);
    if (!cancelled) {
        [self notifyTimeIfNeeded:YES];
    }
}

- (void)waitWhilePausedIfNeeded {
    if (!atomic_load(&_paused)) {
        if (_isPausedInsideLoop) {
            double pauseDuration = CACurrentMediaTime() - _pauseStartedHostSeconds;
            @synchronized (self) {
                _audioStartHostSeconds += pauseDuration;
                _videoStartHostSeconds += pauseDuration;
                _isPausedInsideLoop = NO;
            }

            AVAudioPlayerNode *audioPlayer = _audioPlayer;
            if (_audioPlayerStarted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [audioPlayer play];
                });
            }
        }
        return;
    }

    if (!_isPausedInsideLoop) {
        @synchronized (self) {
            _isPausedInsideLoop = YES;
            _pauseStartedHostSeconds = CACurrentMediaTime();
        }
        AVAudioPlayerNode *audioPlayer = _audioPlayer;
        dispatch_async(dispatch_get_main_queue(), ^{
            [audioPlayer pause];
        });
    }

    while (atomic_load(&_paused) && !atomic_load(&_cancelled)) {
        usleep(20 * 1000);
    }
}

- (void)handleVideoPacket:(AVPacket *)packet {
    int result = avcodec_send_packet(_videoCodecContext, packet);
    if (result < 0) {
        return;
    }

    AVStream *videoStream = _formatContext->streams[_videoStreamIndex];
    while ((result = avcodec_receive_frame(_videoCodecContext, _videoFrame)) >= 0) {
        if (SFXFrameBeforeSeekTarget(_videoFrame, videoStream, _seekSeconds)) {
            av_frame_unref(_videoFrame);
            continue;
        }

        if (_videoFrame->format == SFXHardwarePixelFormat) {
            [self paceVideoFrame:_videoFrame stream:videoStream];
            CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)_videoFrame->data[3];
            [self enqueuePixelBuffer:pixelBuffer presentationTime:SFXFramePresentationTime(_videoFrame, videoStream)];
        }

        double mediaSeconds = SFXFramePlaybackSeconds(_videoFrame, videoStream);
        if (mediaSeconds >= 0) {
            @synchronized (self) {
                _currentTime = mediaSeconds;
            }
            [self notifyTimeIfNeeded:NO];
        }

        av_frame_unref(_videoFrame);
    }
}

- (void)handleAudioPacket:(AVPacket *)packet {
    int result = avcodec_send_packet(_audioCodecContext, packet);
    if (result < 0) {
        return;
    }

    AVStream *audioStream = _formatContext->streams[_audioStreamIndex];
    while ((result = avcodec_receive_frame(_audioCodecContext, _audioFrame)) >= 0) {
        if (SFXFrameBeforeSeekTarget(_audioFrame, audioStream, _seekSeconds)) {
            av_frame_unref(_audioFrame);
            continue;
        }

        double mediaSeconds = SFXFramePlaybackSeconds(_audioFrame, audioStream);
        const AVFrame *outputFrame = [self outputAudioFrameForFrame:_audioFrame];
        if (outputFrame != NULL) {
            [self scheduleAudioFrame:outputFrame mediaSeconds:mediaSeconds];
        }

        av_frame_unref(_audioFrame);
    }
}

- (void)paceVideoFrame:(AVFrame *)frame stream:(AVStream *)stream {
    double mediaSeconds = SFXFramePlaybackSeconds(frame, stream);
    if (mediaSeconds < 0) {
        return;
    }

    double now = CACurrentMediaTime();
    double targetHostSeconds = 0;
    @synchronized (self) {
        double rate = fmax((double)_playbackRate, 0.001);
        if (_audioClockInitialized) {
            targetHostSeconds = _audioStartHostSeconds + ((mediaSeconds - _audioFirstMediaSeconds) / rate);
        } else if (!_videoClockInitialized) {
            _videoClockInitialized = YES;
            _videoFirstMediaSeconds = mediaSeconds;
            _videoStartHostSeconds = now;
            return;
        } else {
            targetHostSeconds = _videoStartHostSeconds + ((mediaSeconds - _videoFirstMediaSeconds) / rate);
        }
    }

    double waitSeconds = targetHostSeconds - now;
    if (waitSeconds > 0) {
        double cappedWait = waitSeconds > 0.25 ? 0.25 : waitSeconds;
        usleep((useconds_t)(cappedWait * 1000000.0));
    }
}

- (CMSampleBufferRef)sampleBufferForPixelBuffer:(CVPixelBufferRef)pixelBuffer
                               presentationTime:(CMTime)presentationTime {
    CMVideoFormatDescriptionRef formatDescription = NULL;
    OSStatus status = CMVideoFormatDescriptionCreateForImageBuffer(
        kCFAllocatorDefault,
        pixelBuffer,
        &formatDescription
    );
    if (status != noErr || formatDescription == NULL) {
        return NULL;
    }

    CMSampleTimingInfo timing = {
        .duration = CMTimeMake(1, 60),
        .presentationTimeStamp = presentationTime,
        .decodeTimeStamp = kCMTimeInvalid
    };
    CMSampleBufferRef sampleBuffer = NULL;
    status = CMSampleBufferCreateReadyWithImageBuffer(
        kCFAllocatorDefault,
        pixelBuffer,
        formatDescription,
        &timing,
        &sampleBuffer
    );
    CFRelease(formatDescription);

    if (status != noErr || sampleBuffer == NULL) {
        return NULL;
    }

    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    if (attachments != NULL && CFArrayGetCount(attachments) > 0) {
        CFMutableDictionaryRef attachment = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFDictionarySetValue(attachment, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
    }

    return sampleBuffer;
}

- (void)enqueuePixelBuffer:(CVPixelBufferRef)pixelBuffer presentationTime:(CMTime)presentationTime {
    if (pixelBuffer == NULL || _displayLayer == nil) {
        return;
    }

    CVPixelBufferRetain(pixelBuffer);
    AVSampleBufferDisplayLayer *displayLayer = _displayLayer;
    dispatch_async(dispatch_get_main_queue(), ^{
        CMSampleBufferRef sampleBuffer = [self sampleBufferForPixelBuffer:pixelBuffer
                                                         presentationTime:presentationTime];
        if (sampleBuffer != NULL) {
            if (_flushDisplayOnFirstFrame
                || displayLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
                [displayLayer flush];
                _flushDisplayOnFirstFrame = NO;
            }
            [displayLayer enqueueSampleBuffer:sampleBuffer];
            CFRelease(sampleBuffer);
        }
        CVPixelBufferRelease(pixelBuffer);
    });
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
    if (frame->ch_layout.nb_channels <= 0) {
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

- (void)scheduleAudioFrame:(const AVFrame *)frame mediaSeconds:(double)mediaSeconds {
    if (_audioPlayer == nil || _audioFormat == nil || frame->format != AV_SAMPLE_FMT_FLTP) {
        return;
    }

    int channels = frame->ch_layout.nb_channels;
    if (channels <= 0 || channels > (int)_audioFormat.channelCount) {
        return;
    }

    AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc]
        initWithPCMFormat:_audioFormat
        frameCapacity:(AVAudioFrameCount)frame->nb_samples
    ];
    if (buffer == nil || buffer.floatChannelData == NULL) {
        return;
    }

    buffer.frameLength = (AVAudioFrameCount)frame->nb_samples;
    for (int channel = 0; channel < channels; channel++) {
        memcpy(
            buffer.floatChannelData[channel],
            frame->extended_data[channel],
            sizeof(float) * (size_t)frame->nb_samples
        );
    }

    [_audioPlayer scheduleBuffer:buffer completionHandler:nil];

    if (!_audioPlayerStarted) {
        if (mediaSeconds >= 0) {
            @synchronized (self) {
                if (!_audioClockInitialized) {
                    _audioClockInitialized = YES;
                    _audioFirstMediaSeconds = mediaSeconds;
                    _audioStartHostSeconds = CACurrentMediaTime();
                }
            }
        }

        _audioPlayerStarted = YES;
        AVAudioPlayerNode *audioPlayer = _audioPlayer;
        dispatch_async(dispatch_get_main_queue(), ^{
            [audioPlayer play];
        });
    }
}

- (void)notifyTimeIfNeeded:(BOOL)force {
    double now = CACurrentMediaTime();
    if (!force && now - _lastDelegateUpdateHostSeconds < 0.25) {
        return;
    }
    _lastDelegateUpdateHostSeconds = now;

    double currentTime = self.currentTime;
    double duration = _duration;
    BOOL playing = self.isPlaying;
    id<SFXNativePlaybackPlayerDelegate> delegate = _delegate;
    SFXNativePlaybackPlayer *owner = _owner;

    dispatch_async(dispatch_get_main_queue(), ^{
        [delegate nativePlaybackPlayer:owner
                         didUpdateTime:currentTime
                              duration:duration
                               playing:playing];
    });
}

- (void)notifyFailure:(NSString *)message {
    id<SFXNativePlaybackPlayerDelegate> delegate = _delegate;
    SFXNativePlaybackPlayer *owner = _owner;
    dispatch_async(dispatch_get_main_queue(), ^{
        [delegate nativePlaybackPlayer:owner didFailWithMessage:message];
    });
}

- (void)teardown {
    AVAudioPlayerNode *audioPlayer = _audioPlayer;
    AVAudioEngine *audioEngine = _audioEngine;
    dispatch_async(dispatch_get_main_queue(), ^{
        [audioPlayer stop];
        [audioEngine stop];
    });

    swr_free(&_resampler);
    av_channel_layout_uninit(&_outputLayout);
    av_frame_free(&_convertedAudioFrame);
    av_frame_free(&_audioFrame);
    av_frame_free(&_videoFrame);
    av_packet_free(&_packet);
    avcodec_free_context(&_audioCodecContext);
    avcodec_free_context(&_videoCodecContext);
    av_buffer_unref(&_hardwareDeviceContext);
    avformat_close_input(&_formatContext);

    _audioPlayer = nil;
    _audioTimePitch = nil;
    _audioEngine = nil;
    _audioFormat = nil;
}

@end

@implementation SFXNativePlaybackPlayer {
    SFXNativePlaybackView *_nativeView;
    SFXNativePlaybackSession *_session;
    NSString *_currentPath;
    float _volume;
    float _playbackRate;
}

- (instancetype)init {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    av_log_set_level(AV_LOG_ERROR);

    _volume = 1.0;
    _playbackRate = 1.0;
    _nativeView = [[SFXNativePlaybackView alloc] initWithFrame:NSZeroRect];
    return self;
}

- (NSView *)view {
    return _nativeView;
}

- (NSString *)currentPath {
    return _currentPath;
}

- (double)currentTime {
    return _session.currentTime;
}

- (double)duration {
    return _session.duration;
}

- (BOOL)isPlaying {
    return _session.isPlaying;
}

- (float)volume {
    return _volume;
}

- (float)playbackRate {
    return _playbackRate;
}

- (void)setVolume:(float)volume {
    _volume = fmaxf(0.0, fminf(volume, 1.0));
    [_session setVolume:_volume];
}

- (void)setPlaybackRate:(float)playbackRate {
    _playbackRate = SFXClampedPlaybackRate(playbackRate);
    [_session setPlaybackRate:_playbackRate];
}

- (BOOL)openPath:(NSString *)path
startMilliseconds:(NSInteger)startMilliseconds
           error:(NSError **)error {
    return [self openPath:path
        startMilliseconds:startMilliseconds
       flushDisplayBeforeStart:NO
                    error:error];
}

- (BOOL)openPath:(NSString *)path
startMilliseconds:(NSInteger)startMilliseconds
flushDisplayBeforeStart:(BOOL)flushDisplayBeforeStart
           error:(NSError **)error {
    [self stopAndFlushDisplay:flushDisplayBeforeStart];

    SFXNativePlaybackSession *session = [[SFXNativePlaybackSession alloc]
        initWithPath:path
        startMilliseconds:startMilliseconds
        layer:_nativeView.displayLayer
        delegate:self.delegate
        owner:self
        volume:_volume
        playbackRate:_playbackRate
        flushDisplayBeforeStart:flushDisplayBeforeStart
        error:error
    ];
    if (session == nil) {
        return NO;
    }

    _session = session;
    _currentPath = [path copy];
    [_session start];
    return YES;
}

- (BOOL)seekToMilliseconds:(NSInteger)milliseconds error:(NSError **)error {
    if (_currentPath == nil) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(40, @"Native playback has no current file to seek.");
        }
        return NO;
    }

    return [self openPath:_currentPath
        startMilliseconds:milliseconds
       flushDisplayBeforeStart:NO
                    error:error];
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

- (void)stop {
    [self stopAndFlushDisplay:YES];
}

- (void)stopAndFlushDisplay:(BOOL)flushDisplay {
    [_session stopAndWait];
    _session = nil;
    _currentPath = nil;
    if (flushDisplay) {
        [_nativeView flush];
    }
}

@end
