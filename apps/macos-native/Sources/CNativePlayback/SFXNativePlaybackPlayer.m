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

NSString * const SFXNativePlaybackErrorDomain = @"CueSeeker.NativePlayback";

static enum AVPixelFormat SFXHardwarePixelFormat = AV_PIX_FMT_NONE;
static const float SFXMinimumPlaybackRate = 0.5f;
static const float SFXMaximumPlaybackRate = 2.0f;
static const double SFXVideoStarvationThresholdSeconds = 0.12;
static const double SFXVideoStarvationWatchdogIntervalSeconds = 0.05;
static const double SFXAudioPrimeWallSeconds = 0.35;
static const double SFXAudioQueueLowWaterWallSeconds = 0.75;
static const double SFXAudioQueueHighWaterWallSeconds = 1.50;
static const double SFXReadAheadStartupSeconds = 0.0;
static const double SFXReadAheadTargetSeconds = 10.0;
static const size_t SFXReadAheadMaxBytes = 64 * 1024 * 1024;
static const NSInteger SFXNoSegmentEndMilliseconds = -1;
static const double SFXSegmentBoundaryEpsilonSeconds = 0.000001;

typedef NS_ENUM(NSInteger, SFXAudioScheduleResult) {
    SFXAudioScheduleResultNotScheduled = 0,
    SFXAudioScheduleResultScheduled = 1,
    SFXAudioScheduleResultScheduledFinalSegmentBuffer = 2,
    SFXAudioScheduleResultSegmentBoundaryReached = 3
};

static os_log_t SFXPerformanceLog(void) {
    static os_log_t log = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.cueseeker.perf", "CNativePlayback");
    });
    return log;
}

static BOOL SFXPerformanceLoggingEnabled(void) {
    static BOOL enabled = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        const char *value = getenv("CUESEEKER_PERF_PLAYBACK");
        if (value != NULL
            && (
                strcmp(value, "1") == 0
                || strcasecmp(value, "true") == 0
                || strcasecmp(value, "yes") == 0
                || strcasecmp(value, "on") == 0
            )) {
            enabled = YES;
            return;
        }
        if (getenv("CUESEEKER_PERF") != NULL
            || getenv("CUESEEKER_DEBUG_TASK_DELAY_SECONDS") != NULL) {
            enabled = YES;
            return;
        }
#if DEBUG
        enabled = YES;
#endif
    });
    return enabled;
}

static NSInteger SFXSanitizedSegmentEndMilliseconds(NSInteger startMilliseconds, NSInteger endMilliseconds) {
    if (endMilliseconds < 0) {
        return SFXNoSegmentEndMilliseconds;
    }
    return MAX(startMilliseconds, endMilliseconds);
}

static CFTimeInterval SFXPerformanceNow(void) {
    if (!SFXPerformanceLoggingEnabled()) {
        return 0;
    }

    return CACurrentMediaTime();
}

static void SFXLogIfSlow(NSString *name, CFTimeInterval start, double thresholdMilliseconds) {
    if (!SFXPerformanceLoggingEnabled()) {
        return;
    }

    double elapsedMilliseconds = (SFXPerformanceNow() - start) * 1000.0;
    if (elapsedMilliseconds < thresholdMilliseconds) {
        return;
    }

    os_log(
        SFXPerformanceLog(),
        "SLOW %{public}@ %.2fms",
        name,
        elapsedMilliseconds
    );
}

typedef struct SFXQueuedPacket {
    AVPacket *packet;
    size_t bytes;
    double mediaSeconds;
    struct SFXQueuedPacket *next;
} SFXQueuedPacket;

static void SFXFreeQueuedPacket(SFXQueuedPacket *queuedPacket) {
    if (queuedPacket == NULL) {
        return;
    }
    av_packet_free(&queuedPacket->packet);
    free(queuedPacket);
}

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

static BOOL SFXIsHTTPMediaPath(const char *path) {
    if (path == NULL) {
        return NO;
    }
    return strncasecmp(path, "http://", 7) == 0 || strncasecmp(path, "https://", 8) == 0;
}

static int SFXOpenMediaInput(
    AVFormatContext **formatContext,
    const char *path,
    NSString * _Nullable httpHeaders
) {
    AVDictionary *options = NULL;
    av_dict_set(&options, "cueseeker_skip_internal_subtitles", "1", 0);
    if (SFXIsHTTPMediaPath(path)) {
        av_dict_set(&options, "user_agent", "CueSeeker/1.0", 0);
        av_dict_set(&options, "reconnect", "1", 0);
        av_dict_set(&options, "reconnect_streamed", "1", 0);
        av_dict_set(&options, "reconnect_delay_max", "5", 0);
        if (httpHeaders.length > 0) {
            av_dict_set(&options, "headers", httpHeaders.UTF8String, 0);
        }
    }
    int result = avformat_open_input(formatContext, path, NULL, &options);
    av_dict_free(&options);
    return result;
}

static NSString *SFXPixelFormatName(enum AVPixelFormat pixelFormat) {
    const char *name = av_get_pix_fmt_name(pixelFormat);
    if (name == NULL) {
        return [NSString stringWithFormat:@"pixel format %d", pixelFormat];
    }
    return [NSString stringWithUTF8String:name];
}

static NSError *SFXNativePlaybackError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:SFXNativePlaybackErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

static BOOL SFXIsHardwareDecodeSupported(enum AVCodecID codecID) {
    CMVideoCodecType codecType = 0;
    switch (codecID) {
    case AV_CODEC_ID_AV1:
        codecType = kCMVideoCodecType_AV1;
        break;
    case AV_CODEC_ID_H264:
        codecType = kCMVideoCodecType_H264;
        break;
    case AV_CODEC_ID_HEVC:
        codecType = kCMVideoCodecType_HEVC;
        break;
    case AV_CODEC_ID_VP9:
        codecType = kCMVideoCodecType_VP9;
        break;
    case AV_CODEC_ID_PRORES:
        codecType = kCMVideoCodecType_AppleProRes422;
        break;
    default:
        return NO;
    }
    return VTIsHardwareDecodeSupported(codecType) != 0;
}

static BOOL SFXIsHardwareDecodeSupportedForCodecName(NSString *codecName) {
    if (codecName == nil || codecName.length == 0) {
        return NO;
    }
    NSString *lower = [codecName lowercaseString];
    if ([lower containsString:@"av1"] || [lower containsString:@"av01"]) {
        return VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1) != 0;
    }
    if ([lower containsString:@"hevc"] || [lower containsString:@"h265"] || [lower containsString:@"hvc1"]) {
        return VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC) != 0;
    }
    if ([lower containsString:@"h264"] || [lower containsString:@"avc"]) {
        return VTIsHardwareDecodeSupported(kCMVideoCodecType_H264) != 0;
    }
    if ([lower containsString:@"vp9"] || [lower containsString:@"vp09"]) {
        return VTIsHardwareDecodeSupported(kCMVideoCodecType_VP9) != 0;
    }
    if ([lower containsString:@"prores"]) {
        return VTIsHardwareDecodeSupported(kCMVideoCodecType_AppleProRes422) != 0;
    }
    return NO;
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
    if (!SFXIsHardwareDecodeSupported(codecID)) {
        if (hardwareConfig != NULL) {
            *hardwareConfig = NULL;
        }
        return NULL;
    }

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

static const AVCodec *SFXFindSoftwareVideoDecoder(enum AVCodecID codecID) {
    switch (codecID) {
    case AV_CODEC_ID_AV1: {
        const AVCodec *decoder = avcodec_find_decoder_by_name("libdav1d");
        return decoder != NULL ? decoder : avcodec_find_decoder(codecID);
    }
    case AV_CODEC_ID_VP9: {
        const AVCodec *decoder = avcodec_find_decoder_by_name("vp9");
        if (decoder != NULL) {
            return decoder;
        }
        decoder = avcodec_find_decoder_by_name("libvpx-vp9");
        return decoder != NULL ? decoder : avcodec_find_decoder(codecID);
    }
    default:
        return avcodec_find_decoder(codecID);
    }
}

static enum AVPixelFormat SFXChooseHardwareFormat(
    AVCodecContext *context,
    const enum AVPixelFormat *pixelFormats
) {
    (void)context;

    for (const enum AVPixelFormat *format = pixelFormats; *format != AV_PIX_FMT_NONE; format++) {
        if (*format == AV_PIX_FMT_VIDEOTOOLBOX || *format == SFXHardwarePixelFormat) {
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

static BOOL SFXStreamParticipatesInMediaTimeline(AVStream *stream) {
    enum AVMediaType mediaType = stream->codecpar->codec_type;
    return mediaType == AVMEDIA_TYPE_VIDEO
        || mediaType == AVMEDIA_TYPE_AUDIO
        || mediaType == AVMEDIA_TYPE_SUBTITLE;
}

static double SFXMediaTimelineOriginSeconds(AVFormatContext *formatContext) {
    if (formatContext == NULL) {
        return 0;
    }

    if (formatContext->start_time != AV_NOPTS_VALUE) {
        return (double)formatContext->start_time / AV_TIME_BASE;
    }

    double originSeconds = DBL_MAX;
    for (unsigned int index = 0; index < formatContext->nb_streams; index++) {
        AVStream *stream = formatContext->streams[index];
        if (stream == NULL
            || stream->start_time == AV_NOPTS_VALUE
            || !SFXStreamParticipatesInMediaTimeline(stream)) {
            continue;
        }
        originSeconds = fmin(originSeconds, SFXStreamStartSeconds(stream));
    }

    return originSeconds < DBL_MAX ? originSeconds : 0;
}

static double SFXFramePlaybackSeconds(const AVFrame *frame, AVStream *stream, double timelineOriginSeconds) {
    if (frame->best_effort_timestamp == AV_NOPTS_VALUE) {
        return -1;
    }
    return av_q2d(stream->time_base) * frame->best_effort_timestamp - timelineOriginSeconds;
}

static double SFXPacketPlaybackSeconds(const AVPacket *packet, AVStream *stream, double timelineOriginSeconds) {
    int64_t timestamp = packet->pts != AV_NOPTS_VALUE ? packet->pts : packet->dts;
    if (timestamp == AV_NOPTS_VALUE) {
        return -1;
    }
    return av_q2d(stream->time_base) * timestamp - timelineOriginSeconds;
}

static int64_t SFXSeekTimestamp(double seconds, AVStream *stream, double timelineOriginSeconds) {
    double timestampSeconds = seconds + timelineOriginSeconds;
    return (int64_t)llround(timestampSeconds / av_q2d(stream->time_base));
}

static int64_t SFXGlobalSeekTimestamp(double seconds, double timelineOriginSeconds) {
    return (int64_t)llround((seconds + timelineOriginSeconds) * AV_TIME_BASE);
}

static BOOL SFXSeekToStartPosition(
    AVFormatContext *formatContext,
    int videoStreamIndex,
    double seconds,
    double timelineOriginSeconds,
    NSError **error
) {
    AVStream *videoStream = formatContext->streams[videoStreamIndex];
    int64_t streamTimestamp = SFXSeekTimestamp(seconds, videoStream, timelineOriginSeconds);
    int streamResult = av_seek_frame(
        formatContext,
        videoStreamIndex,
        streamTimestamp,
        AVSEEK_FLAG_BACKWARD
    );
    if (streamResult >= 0) {
        return YES;
    }

    int64_t globalTimestamp = SFXGlobalSeekTimestamp(seconds, timelineOriginSeconds);
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

static BOOL SFXFrameBeforeSeekTarget(
    const AVFrame *frame,
    AVStream *stream,
    double seekSeconds,
    double timelineOriginSeconds
) {
    double frameSeconds = SFXFramePlaybackSeconds(frame, stream, timelineOriginSeconds);
    if (frameSeconds < 0) {
        return NO;
    }
    return frameSeconds + 0.002 < seekSeconds;
}

static CMTime SFXFramePresentationTime(const AVFrame *frame, AVStream *stream, double timelineOriginSeconds) {
    double mediaSeconds = SFXFramePlaybackSeconds(frame, stream, timelineOriginSeconds);
    if (!isfinite(mediaSeconds)) {
        return CMTimeMake(0, 1);
    }
    return CMTimeMakeWithSeconds(mediaSeconds, 1000000);
}

static CMSampleBufferRef SFXSampleBufferForPixelBuffer(
    CVPixelBufferRef pixelBuffer,
    CMTime presentationTime
) {
    if (pixelBuffer == NULL) {
        return NULL;
    }

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

static CVPixelBufferRef SFXCopyBGRAKeyframePreviewPixelBuffer(
    NSString *path,
    NSString * _Nullable httpHeaders,
    NSInteger milliseconds,
    CMTime *presentationTimeOut,
    NSInteger *frameMillisecondsOut
) {
    AVFormatContext *formatContext = NULL;
    AVCodecContext *codecContext = NULL;
    AVPacket *packet = NULL;
    AVFrame *frame = NULL;
    struct SwsContext *scaler = NULL;
    CVPixelBufferRef pixelBuffer = NULL;
    NSError *seekError = nil;

    const char *inputPath = ([path hasPrefix:@"http://"] || [path hasPrefix:@"https://"])
        ? path.UTF8String
        : path.fileSystemRepresentation;
    int result = SFXOpenMediaInput(&formatContext, inputPath, httpHeaders);
    if (result < 0) {
        goto cleanup;
    }

    result = avformat_find_stream_info(formatContext, NULL);
    if (result < 0) {
        goto cleanup;
    }

    int videoStreamIndex = av_find_best_stream(
        formatContext,
        AVMEDIA_TYPE_VIDEO,
        -1,
        -1,
        NULL,
        0
    );
    if (videoStreamIndex < 0) {
        goto cleanup;
    }

    AVStream *videoStream = formatContext->streams[videoStreamIndex];
    double timelineOriginSeconds = SFXMediaTimelineOriginSeconds(formatContext);
    AVCodecParameters *parameters = videoStream->codecpar;
    const AVCodec *decoder = SFXFindSoftwareVideoDecoder(parameters->codec_id);
    if (decoder == NULL) {
        goto cleanup;
    }

    codecContext = avcodec_alloc_context3(decoder);
    if (codecContext == NULL) {
        goto cleanup;
    }

    result = avcodec_parameters_to_context(codecContext, parameters);
    if (result < 0) {
        goto cleanup;
    }

    codecContext->thread_count = 0;
    codecContext->thread_type = FF_THREAD_FRAME | FF_THREAD_SLICE;

    result = avcodec_open2(codecContext, decoder, NULL);
    if (result < 0) {
        goto cleanup;
    }

    double seconds = fmax(0, (double)milliseconds / 1000.0);
    if (!SFXSeekToStartPosition(formatContext, videoStreamIndex, seconds, timelineOriginSeconds, &seekError)) {
        goto cleanup;
    }
    avcodec_flush_buffers(codecContext);

    packet = av_packet_alloc();
    frame = av_frame_alloc();
    if (packet == NULL || frame == NULL) {
        goto cleanup;
    }

    while (av_read_frame(formatContext, packet) >= 0) {
        if (packet->stream_index != videoStreamIndex) {
            av_packet_unref(packet);
            continue;
        }

        result = avcodec_send_packet(codecContext, packet);
        av_packet_unref(packet);
        if (result < 0) {
            continue;
        }

        while ((result = avcodec_receive_frame(codecContext, frame)) >= 0) {
            int width = frame->width > 0 ? frame->width : codecContext->width;
            int height = frame->height > 0 ? frame->height : codecContext->height;
            enum AVPixelFormat inputFormat = (enum AVPixelFormat)frame->format;
            if (width <= 0
                || height <= 0
                || inputFormat == AV_PIX_FMT_NONE
                || av_pix_fmt_desc_get(inputFormat) == NULL) {
                av_frame_unref(frame);
                continue;
            }

            scaler = sws_getContext(
                width,
                height,
                inputFormat,
                width,
                height,
                AV_PIX_FMT_BGRA,
                SWS_BILINEAR,
                NULL,
                NULL,
                NULL
            );
            if (scaler == NULL) {
                av_frame_unref(frame);
                goto cleanup;
            }

            int pixelFormat = kCVPixelFormatType_32BGRA;
            int bufferWidth = width;
            int bufferHeight = height;
            CFNumberRef pixelFormatNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &pixelFormat);
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
            CFDictionaryRef attributes = NULL;
            if (pixelFormatNumber != NULL && widthNumber != NULL && heightNumber != NULL && ioSurfaceProperties != NULL) {
                attributes = CFDictionaryCreate(
                    kCFAllocatorDefault,
                    keys,
                    values,
                    4,
                    &kCFTypeDictionaryKeyCallBacks,
                    &kCFTypeDictionaryValueCallBacks
                );
            }
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
            if (attributes == NULL) {
                av_frame_unref(frame);
                goto cleanup;
            }

            CVReturn createResult = CVPixelBufferCreate(
                kCFAllocatorDefault,
                width,
                height,
                kCVPixelFormatType_32BGRA,
                attributes,
                &pixelBuffer
            );
            CFRelease(attributes);
            if (createResult != kCVReturnSuccess || pixelBuffer == NULL) {
                av_frame_unref(frame);
                goto cleanup;
            }

            CVReturn lockResult = CVPixelBufferLockBaseAddress(pixelBuffer, 0);
            if (lockResult != kCVReturnSuccess) {
                CVPixelBufferRelease(pixelBuffer);
                pixelBuffer = NULL;
                av_frame_unref(frame);
                goto cleanup;
            }

            uint8_t *destinationData[] = {
                CVPixelBufferGetBaseAddress(pixelBuffer),
                NULL,
                NULL,
                NULL
            };
            int destinationLinesize[] = {
                (int)CVPixelBufferGetBytesPerRow(pixelBuffer),
                0,
                0,
                0
            };

            int convertedHeight = sws_scale(
                scaler,
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
                pixelBuffer = NULL;
                av_frame_unref(frame);
                goto cleanup;
            }

            if (presentationTimeOut != NULL) {
                *presentationTimeOut = SFXFramePresentationTime(frame, videoStream, timelineOriginSeconds);
            }
            if (frameMillisecondsOut != NULL) {
                double frameSeconds = SFXFramePlaybackSeconds(frame, videoStream, timelineOriginSeconds);
                *frameMillisecondsOut = isfinite(frameSeconds) && frameSeconds >= 0
                    ? (NSInteger)llround(frameSeconds * 1000.0)
                    : milliseconds;
            }
            av_frame_unref(frame);
            goto cleanup;
        }
    }

cleanup:
    if (scaler != NULL) {
        sws_freeContext(scaler);
    }
    av_frame_free(&frame);
    av_packet_free(&packet);
    avcodec_free_context(&codecContext);
    avformat_close_input(&formatContext);
    return pixelBuffer;
}

static int SFXOutputChannelCount(int inputChannels) {
    if (inputChannels <= 0) {
        return 0;
    }
    return inputChannels > 2 ? 2 : inputChannels;
}

@interface SFXNativePlaybackView : NSView
@property (nonatomic, strong, readonly) AVSampleBufferDisplayLayer *displayLayer;
@property (nonatomic, readonly) NSUInteger displayImageRemovalCount;
@end

@implementation SFXNativePlaybackView {
    AVSampleBufferDisplayLayer *_displayLayer;
    NSUInteger _displayImageRemovalCount;
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

    [self updateDisplayLayerFrameWithLogName:@"SFXNativePlaybackView.layout"];
}

- (void)updateDisplayLayerFrameWithLogName:(NSString *)logName {
    CFTimeInterval start = SFXPerformanceNow();
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _displayLayer.frame = self.bounds;
    [_displayLayer setNeedsLayout];
    [_displayLayer layoutIfNeeded];
    [CATransaction commit];
    SFXLogIfSlow(logName, start, 8);
}

- (void)flush {
    CFTimeInterval start = SFXPerformanceNow();
    [_displayLayer flushAndRemoveImage];
    @synchronized (self) {
        _displayImageRemovalCount += 1;
    }
    SFXLogIfSlow(@"SFXNativePlaybackView.flush", start, 16);
}

- (NSUInteger)displayImageRemovalCount {
    @synchronized (self) {
        return _displayImageRemovalCount;
    }
}

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
- (void)cancelTimelineScrubPreviewRequests;
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

@interface SFXNativePlaybackFrameSnapshot ()
- (instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer;
@end

@implementation SFXNativePlaybackFrameSnapshot {
    CVPixelBufferRef _pixelBuffer;
}

- (instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    _pixelBuffer = CVPixelBufferRetain(pixelBuffer);
    return self;
}

- (void)dealloc {
    if (_pixelBuffer != NULL) {
        CVPixelBufferRelease(_pixelBuffer);
        _pixelBuffer = NULL;
    }
}

- (CVPixelBufferRef)pixelBuffer {
    return _pixelBuffer;
}

- (NSInteger)width {
    return _pixelBuffer == NULL ? 0 : (NSInteger)CVPixelBufferGetWidth(_pixelBuffer);
}

- (NSInteger)height {
    return _pixelBuffer == NULL ? 0 : (NSInteger)CVPixelBufferGetHeight(_pixelBuffer);
}

@end

@interface SFXNativePlaybackSession : NSObject
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
                       error:(NSError **)error;
- (void)start;
- (void)stopAndWait;
- (BOOL)seekToMilliseconds:(NSInteger)milliseconds
           endMilliseconds:(NSInteger)endMilliseconds
	       pausesAtSegmentEnd:(BOOL)pausesAtSegmentEnd
	 presentationGeneration:(NSUInteger)presentationGeneration
		      pauseAfterFirstFrame:(BOOL)pauseAfterFirstFrame
	                     error:(NSError **)error;
- (BOOL)recoverAudioOutputWithError:(NSError **)error;
- (void)requestAudioOutputRecovery;
- (BOOL)prepareAudioOutputWithError:(NSError **)error;
- (void)teardownAudioOutput;
- (void)setPaused:(BOOL)paused;
- (void)setReadAheadSuspended:(BOOL)suspended;
- (void)setVolume:(float)volume;
- (void)setPlaybackRate:(float)playbackRate;
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

@implementation SFXNativePlaybackSession {
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
    SFXQueuedPacket *_packetQueueHead;
    SFXQueuedPacket *_packetQueueTail;
    SFXQueuedPacket *_audioPacketQueueHead;
    SFXQueuedPacket *_audioPacketQueueTail;
    size_t _packetQueueBytes;
    int _packetQueueCount;
    BOOL _packetQueueEOF;
    BOOL _packetQueueDemuxStarted;
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

    AVAudioEngine *_audioEngine;
    AVAudioPlayerNode *_audioPlayer;
    AVAudioUnitTimePitch *_audioTimePitch;
    AVAudioFormat *_audioFormat;
    id _audioEngineConfigurationObserver;

    int _videoStreamIndex;
    int _audioStreamIndex;
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
    int _softwarePixelBufferWidth;
    int _softwarePixelBufferHeight;

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
    _playbackGeneration = 1;
    _audioOutputDrained = YES;
    _packetQueueCondition = [[NSCondition alloc] init];
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

- (NSInteger)videoWidth {
    return _videoCodecContext != NULL ? _videoCodecContext->width : 0;
}

- (NSInteger)videoHeight {
    return _videoCodecContext != NULL ? _videoCodecContext->height : 0;
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
    return _usingHardwareDecode;
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
        return;
    }

    @synchronized (self) {
        if (_playbackFinishNotified) {
            return;
        }
        _playbackFinishNotified = YES;
    }

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

    CFTimeInterval s6Start = CACurrentMediaTime();
    if (!SFXSeekToStartPosition(_formatContext, _videoStreamIndex, _seekSeconds, _timelineOriginSeconds, error)) {
        return NO;
    }

    avcodec_flush_buffers(_videoCodecContext);
    if (_audioCodecContext != NULL) {
        avcodec_flush_buffers(_audioCodecContext);
    }
    _perfInitialSeekMs = (CACurrentMediaTime() - s6Start) * 1000.0;

    return YES;
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
    _usingHardwareDecode = NO;
}

- (BOOL)prepareHardwareVideoWithError:(NSError **)error {
    AVStream *videoStream = _formatContext->streams[_videoStreamIndex];
    AVCodecParameters *parameters = videoStream->codecpar;
    if (!SFXIsHardwareDecodeSupported(parameters->codec_id)) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(
                20,
                [NSString stringWithFormat:
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

    _usingHardwareDecode = YES;
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

    _usingHardwareDecode = NO;
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
    _audioTimePitch.rate = atomic_load(&_playbackRate);
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
    [self startStarvationWatchdog];
    dispatch_async(_decodeQueue, ^{
        @autoreleasepool {
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

- (void)stopAndWait {
    atomic_store(&_cancelled, true);
    atomic_store(&_paused, false);
    [_packetQueueCondition lock];
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];

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

    [_packetQueueCondition lock];
    while ((_seekRequestPending || _seekRequestInProgress)
           && !atomic_load(&_cancelled)
           && !atomic_load(&_decodeLoopFinished)) {
        [_packetQueueCondition wait];
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
    [_packetQueueCondition broadcast];
    NSUInteger generation = _playbackGeneration;
    [_packetQueueCondition unlock];

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
    });
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
    _readAheadSuspended = NO;
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];
}

- (BOOL)hasPendingSeekRequestLocked {
    return _seekRequestPending;
}

- (BOOL)isPacketQueueAtHighWaterLocked {
    if (_packetQueueBytes >= SFXReadAheadMaxBytes) {
        return YES;
    }
    BOOL videoReady = [self packetQueueBufferedSecondsLocked] >= SFXReadAheadTargetSeconds;
    BOOL audioReady = _audioCodecContext == NULL
        || atomic_load(&_segmentAudioBoundaryReached)
        || [self audioPacketQueueBufferedSecondsLocked] >= SFXReadAheadTargetSeconds;
    return videoReady && audioReady;
}

- (double)packetQueueBufferedSecondsForHeadLocked:(SFXQueuedPacket *)head {
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
    return [self packetQueueBufferedSecondsForHeadLocked:_packetQueueHead];
}

- (double)audioPacketQueueBufferedSecondsLocked {
    return [self packetQueueBufferedSecondsForHeadLocked:_audioPacketQueueHead];
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
    [_packetQueueCondition broadcast];
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
            return;
        }

        [self handleAudioPacket:NULL generation:generation];

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
        [_packetQueueCondition broadcast];
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
	    while (!atomic_load(&_cancelled)
	           && !atomic_load(&_segmentEnding)
	           && !atomic_load(&_finishingForAutomaticRecycle)
	           && !_packetQueueEOF
	           && ![self hasPendingSeekRequestLocked]
           && _packetQueueHead == NULL) {
        atomic_store(&_decodeWaitingForPacket, true);
        [_packetQueueCondition wait];
    }
    atomic_store(&_decodeWaitingForPacket, false);

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
    [_packetQueueCondition broadcast];
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

    __block BOOL audioOutputReady = YES;
    __block NSError *audioOutputError = nil;
    if (_audioDecodeQueue != NULL) {
        dispatch_sync(_audioDecodeQueue, ^{
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

- (void)decodeLoop {
    atomic_store(&_playing, true);
    @synchronized (self) {
        _lastVideoOutputHostSeconds = CACurrentMediaTime();
    }
    [self notifyTimeIfNeeded:YES];
    [self startPacketReadAhead];
    [self waitUntilPacketQueueHasStartupWaterline];

	    while (!atomic_load(&_cancelled)
	           && !atomic_load(&_segmentEnding)
	           && !atomic_load(&_finishingForAutomaticRecycle)) {
        if ([self performPendingSeekIfNeeded]) {
            continue;
        }

        [self waitWhilePausedIfNeeded];
        if ([self performPendingSeekIfNeeded]) {
            continue;
        }

	        if (atomic_load(&_cancelled) || atomic_load(&_segmentEnding)) {
	            break;
	        }

        SFXQueuedPacket *queuedPacket = [self dequeueVideoPacket];
        if (queuedPacket == NULL) {
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
	    atomic_store(&_playing, false);
	    if (!cancelled && !segmentEnding && !finishingForAutomaticRecycle) {
	        [self notifyTimeIfNeeded:YES];
	    }
    atomic_store(&_decodeLoopFinished, true);
    [_packetQueueCondition lock];
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];
}

- (void)waitWhilePausedIfNeeded {
    if (!atomic_load(&_paused)) {
        return;
    }

	    [_packetQueueCondition lock];
	    while (atomic_load(&_paused)
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

    uint64_t intervalNanoseconds = (uint64_t)(SFXVideoStarvationWatchdogIntervalSeconds * NSEC_PER_SEC);
    dispatch_source_set_timer(
        timer,
        dispatch_time(DISPATCH_TIME_NOW, intervalNanoseconds),
        intervalNanoseconds,
        (uint64_t)(0.01 * NSEC_PER_SEC)
    );

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(timer, ^{
        [weakSelf checkVideoStarvation];
    });

    _starvationTimer = timer;
    dispatch_resume(timer);
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

- (BOOL)ensureSoftwareVideoScalerForFrame:(AVFrame *)frame width:(int)width height:(int)height {
    enum AVPixelFormat inputFormat = (enum AVPixelFormat)frame->format;
    if (_videoScaler != NULL
        && _videoScalerWidth == width
        && _videoScalerHeight == height
        && _videoScalerInputFormat == inputFormat) {
        return YES;
    }

    sws_freeContext(_videoScaler);
    _videoScaler = sws_getContext(
        width,
        height,
        inputFormat,
        width,
        height,
        AV_PIX_FMT_BGRA,
        SWS_BILINEAR,
        NULL,
        NULL,
        NULL
    );

    if (_videoScaler == NULL) {
        _videoScalerWidth = 0;
        _videoScalerHeight = 0;
        _videoScalerInputFormat = AV_PIX_FMT_NONE;
        return NO;
    }

    _videoScalerWidth = width;
    _videoScalerHeight = height;
    _videoScalerInputFormat = inputFormat;
    return YES;
}

- (BOOL)ensureSoftwarePixelBufferPoolWithWidth:(int)width height:(int)height {
    if (_softwarePixelBufferPool != NULL
        && _softwarePixelBufferWidth == width
        && _softwarePixelBufferHeight == height) {
        return YES;
    }

    if (_softwarePixelBufferPool != NULL) {
        CVPixelBufferPoolRelease(_softwarePixelBufferPool);
        _softwarePixelBufferPool = NULL;
    }

    int pixelFormat = kCVPixelFormatType_32BGRA;
    int bufferWidth = width;
    int bufferHeight = height;
    CFNumberRef pixelFormatNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &pixelFormat);
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
        return NO;
    }

    _softwarePixelBufferWidth = width;
    _softwarePixelBufferHeight = height;
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

    if (![self ensureSoftwareVideoScalerForFrame:frame width:width height:height]
        || ![self ensureSoftwarePixelBufferPoolWithWidth:width height:height]) {
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

    CVReturn lockResult = CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    if (lockResult != kCVReturnSuccess) {
        CVPixelBufferRelease(pixelBuffer);
        return NULL;
    }

    uint8_t *destinationData[] = {
        CVPixelBufferGetBaseAddress(pixelBuffer),
        NULL,
        NULL,
        NULL
    };
    int destinationLinesize[] = {
        (int)CVPixelBufferGetBytesPerRow(pixelBuffer),
        0,
        0,
        0
    };

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

    return pixelBuffer;
}

- (void)handleVideoPacket:(AVPacket *)packet {
    if (!_perfFirstVideoDecodedRecorded) {
        if (_perfFirstVideoPacketHostSeconds <= 0) {
            _perfFirstVideoPacketHostSeconds = CACurrentMediaTime();
        }
        _perfVideoPacketsForFirstFrame += 1;
    }

    int result = avcodec_send_packet(_videoCodecContext, packet);
    if (result < 0) {
        return;
    }

    AVStream *videoStream = _formatContext->streams[_videoStreamIndex];
    while ((result = avcodec_receive_frame(_videoCodecContext, _videoFrame)) >= 0) {
        if (SFXFrameBeforeSeekTarget(_videoFrame, videoStream, _seekSeconds, _timelineOriginSeconds)) {
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
        NSInteger automaticRecycleMilliseconds = -1;
        BOOL submittedVideoFrame = NO;
        if (_videoFrame->format == AV_PIX_FMT_VIDEOTOOLBOX || _videoFrame->format == SFXHardwarePixelFormat) {
            if (![self paceVideoFrame:_videoFrame stream:videoStream]) {
                av_frame_unref(_videoFrame);
                break;
            }
            CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)_videoFrame->data[3];
            [self enqueuePixelBuffer:pixelBuffer
                     presentationTime:presentationTime
                   frameMilliseconds:frameMilliseconds
             automaticRecycleMilliseconds:automaticRecycleMilliseconds];
            submittedVideoFrame = YES;
        } else if (!_usingHardwareDecode) {
            if (![self paceVideoFrame:_videoFrame stream:videoStream]) {
                av_frame_unref(_videoFrame);
                break;
            }
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

            automaticRecycleMilliseconds = [self markAutomaticSoftwareRecycleIfNeededAtMediaSeconds:mediaSeconds];
            [self enqueuePixelBuffer:pixelBuffer
                     presentationTime:presentationTime
                   frameMilliseconds:frameMilliseconds
             automaticRecycleMilliseconds:automaticRecycleMilliseconds];
            CVPixelBufferRelease(pixelBuffer);
            submittedVideoFrame = YES;
        }

        if (mediaSeconds >= 0) {
            @synchronized (self) {
                _currentTime = mediaSeconds;
                if (submittedVideoFrame) {
                    _lastSubmittedVideoFrameMilliseconds = (NSInteger)floor(mediaSeconds * 1000.0);
                }
            }
            [self notifyTimeIfNeeded:NO];
        }

        BOOL finishForRecycle = atomic_load(&_finishingForAutomaticRecycle);
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
        if (SFXFrameBeforeSeekTarget(_audioFrame, audioStream, _seekSeconds, _timelineOriginSeconds)) {
            av_frame_unref(_audioFrame);
            continue;
        }

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
        && !_usingHardwareDecode
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
        if (targetHostSeconds > now + 0.001) {
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
    [_packetQueueCondition unlock];
    CFTimeInterval audioPrimeWaitStart = CACurrentMediaTime();
    if (![self waitForAudioPrimeForGeneration:generation]) {
        return NO;
    }
    double audioPrimeWaitMs = (CACurrentMediaTime() - audioPrimeWaitStart) * 1000.0;

    double now = CACurrentMediaTime();
    [self resumeFromRebufferIfNeededAtHostSeconds:now];

    double targetHostSeconds = 0;
    BOOL initializedPlaybackClock = NO;
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
        }
        if (_audioClockInitialized) {
            targetHostSeconds = _audioStartHostSeconds + ((mediaSeconds - _audioFirstMediaSeconds) / rate);
        } else {
            targetHostSeconds = _videoStartHostSeconds + ((mediaSeconds - _videoFirstMediaSeconds) / rate);
        }
    }

    if (initializedPlaybackClock
        && !(atomic_load(&_pauseAfterFirstFrame) && !atomic_load(&_didPauseAfterFirstFrame))) {
        [self requestAudioPlaybackStartIfReadyForGeneration:generation];
    }

    while (targetHostSeconds > CACurrentMediaTime() || atomic_load(&_paused)) {
        [_packetQueueCondition lock];
        BOOL waitedForPause = atomic_load(&_paused);
        while (atomic_load(&_paused)
               && generation == _playbackGeneration
               && ![self hasPendingSeekRequestLocked]
               && !atomic_load(&_cancelled)
               && !atomic_load(&_segmentEnding)
               && !atomic_load(&_finishingForAutomaticRecycle)) {
            [_packetQueueCondition wait];
        }
        BOOL shouldAbort = generation != _playbackGeneration
            || [self hasPendingSeekRequestLocked]
            || atomic_load(&_cancelled)
            || atomic_load(&_segmentEnding)
            || atomic_load(&_finishingForAutomaticRecycle);
        if (!shouldAbort && !waitedForPause) {
            double waitSeconds = fmin(0.05, targetHostSeconds - CACurrentMediaTime());
            if (waitSeconds > 0) {
                [_packetQueueCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:waitSeconds]];
            }
        }
        [_packetQueueCondition unlock];
        if (shouldAbort) {
            return NO;
        }
        if (waitedForPause) {
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
    }

    @synchronized (self) {
        _lastVideoOutputHostSeconds = CACurrentMediaTime();
    }
    return YES;
}

- (CMSampleBufferRef)sampleBufferForPixelBuffer:(CVPixelBufferRef)pixelBuffer
                               presentationTime:(CMTime)presentationTime {
    CFTimeInterval start = SFXPerformanceNow();
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

    SFXLogIfSlow(@"SFXNativePlaybackSession.sampleBufferForPixelBuffer", start, 8);
    return sampleBuffer;
}

- (void)enqueuePixelBuffer:(CVPixelBufferRef)pixelBuffer
          presentationTime:(CMTime)presentationTime
        frameMilliseconds:(NSInteger)frameMilliseconds
automaticRecycleMilliseconds:(NSInteger)automaticRecycleMilliseconds {
    if (pixelBuffer == NULL) {
        return;
    }
    if (_perfFirstFrameEnqueuedHostSeconds <= 0) {
        _perfFirstFrameEnqueuedHostSeconds = CACurrentMediaTime();
    }

    [_packetQueueCondition lock];
    BOOL presentationIsCurrent = !_seekRequestPending
        && !_seekRequestInProgress
        && !_audioResetInProgress
        && !atomic_load(&_cancelled);
    NSUInteger presentationGeneration = _presentationGeneration;
    [_packetQueueCondition unlock];
    if (!presentationIsCurrent) {
        return;
    }

    CVPixelBufferRetain(pixelBuffer);
    BOOL shouldScheduleSubmission = NO;
    [_displaySubmissionLock lock];
    if (_pendingDisplayPixelBuffer != NULL) {
        CVPixelBufferRelease(_pendingDisplayPixelBuffer);
    }
    _pendingDisplayPixelBuffer = pixelBuffer;
    _pendingDisplayPresentationTime = presentationTime;
    _pendingDisplayAutomaticRecycleMilliseconds = automaticRecycleMilliseconds;
    _pendingDisplayFrameMilliseconds = frameMilliseconds;
    _pendingDisplayPresentationGeneration = presentationGeneration;
    if (!_displaySubmissionScheduled) {
        _displaySubmissionScheduled = YES;
        shouldScheduleSubmission = YES;
    }
    [_displaySubmissionLock unlock];

    if (shouldScheduleSubmission) {
        CFTimeInterval scheduledAt = SFXPerformanceNow();
        dispatch_async(dispatch_get_main_queue(), ^{
            SFXLogIfSlow(@"SFXNativePlaybackSession.displaySubmission.mainDelay", scheduledAt, 50);
            [self drainPendingPixelBufferSubmission];
        });
    }
}

- (void)drainPendingPixelBufferSubmission {
    CFTimeInterval start = SFXPerformanceNow();
    CVPixelBufferRef pixelBuffer = NULL;
    CMTime presentationTime = kCMTimeInvalid;
    NSInteger automaticRecycleMilliseconds = -1;
    NSInteger frameMilliseconds = -1;
    NSUInteger presentationGeneration = 0;

    [_displaySubmissionLock lock];
    pixelBuffer = _pendingDisplayPixelBuffer;
    presentationTime = _pendingDisplayPresentationTime;
    automaticRecycleMilliseconds = _pendingDisplayAutomaticRecycleMilliseconds;
    frameMilliseconds = _pendingDisplayFrameMilliseconds;
    presentationGeneration = _pendingDisplayPresentationGeneration;
    _pendingDisplayPixelBuffer = NULL;
    _pendingDisplayPresentationTime = kCMTimeInvalid;
    _pendingDisplayAutomaticRecycleMilliseconds = -1;
    _pendingDisplayFrameMilliseconds = -1;
    _pendingDisplayPresentationGeneration = 0;
    _displaySubmissionScheduled = NO;
    [_displaySubmissionLock unlock];

    if (pixelBuffer == NULL) {
        return;
    }

    if (atomic_load(&_cancelled) || _displayLayer == nil) {
        CVPixelBufferRelease(pixelBuffer);
        return;
    }

    BOOL enqueued = NO;
    BOOL firstFrameForPresentation = NO;
    CMSampleBufferRef sampleBuffer = [self sampleBufferForPixelBuffer:pixelBuffer
                                                     presentationTime:presentationTime];
    if (sampleBuffer != NULL) {
        [_packetQueueCondition lock];
        BOOL sessionPresentationIsCurrent = presentationGeneration == _presentationGeneration
            && !_seekRequestPending
            && !_seekRequestInProgress
            && !_audioResetInProgress
            && !atomic_load(&_cancelled);
        firstFrameForPresentation = sessionPresentationIsCurrent
            && _lastPresentedPresentationGeneration != presentationGeneration;
        [_packetQueueCondition unlock];

        if (sessionPresentationIsCurrent) {
            SFXNativePlaybackPlayer *owner = _owner;
            enqueued = [owner enqueueSampleBuffer:sampleBuffer
                                       forSession:self
                            presentationGeneration:presentationGeneration
                                flushBeforeEnqueue:firstFrameForPresentation];
        }
        CFRelease(sampleBuffer);
    }
    CVPixelBufferRelease(pixelBuffer);

    if (enqueued) {
        [_packetQueueCondition lock];
        if (presentationGeneration == _presentationGeneration) {
            _lastPresentedPresentationGeneration = presentationGeneration;
        }
        [_packetQueueCondition unlock];
        @synchronized (self) {
            _presentedVideoFrameCount += 1;
        }
        if (firstFrameForPresentation) {
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
            [owner session:self
                didPresentVideoFrameAtMilliseconds:frameMilliseconds
                presentationGeneration:presentationGeneration];
        }
        if (automaticRecycleMilliseconds >= 0) {
            SFXNativePlaybackPlayer *owner = _owner;
            [owner requestAutomaticSoftwareRecycleForSession:self
                                              atMilliseconds:automaticRecycleMilliseconds
                                      presentationGeneration:presentationGeneration];
        }
        [_packetQueueCondition lock];
        BOOL presentationIsStillCurrent = presentationGeneration == _presentationGeneration
            && !_seekRequestPending
            && !_seekRequestInProgress;
        [_packetQueueCondition unlock];
        if (presentationIsStillCurrent
            && atomic_load(&_pauseAfterFirstFrame)
            && !atomic_load(&_didPauseAfterFirstFrame)) {
            [self setPaused:YES];
            atomic_store(&_didPauseAfterFirstFrame, true);
        }
    } else if (automaticRecycleMilliseconds >= 0
               && atomic_load(&_finishingForAutomaticRecycle)
               && !atomic_load(&_cancelled)) {
        SFXNativePlaybackPlayer *owner = _owner;
        [owner requestAutomaticSoftwareRecycleForSession:self
                                           atMilliseconds:automaticRecycleMilliseconds
                                   presentationGeneration:presentationGeneration];
    }
    SFXLogIfSlow(@"SFXNativePlaybackSession.drainPendingPixelBufferSubmission", start, 8);
}

- (void)clearPendingPixelBufferSubmission {
    NSInteger automaticRecycleMilliseconds = -1;
    NSUInteger presentationGeneration = 0;

    [_displaySubmissionLock lock];
    if (_pendingDisplayPixelBuffer != NULL) {
        CVPixelBufferRelease(_pendingDisplayPixelBuffer);
        _pendingDisplayPixelBuffer = NULL;
    }
    automaticRecycleMilliseconds = _pendingDisplayAutomaticRecycleMilliseconds;
    presentationGeneration = _pendingDisplayPresentationGeneration;
    _pendingDisplayPresentationTime = kCMTimeInvalid;
    _pendingDisplayAutomaticRecycleMilliseconds = -1;
    _pendingDisplayFrameMilliseconds = -1;
    _pendingDisplayPresentationGeneration = 0;
    [_displaySubmissionLock unlock];

    if (automaticRecycleMilliseconds >= 0
        && atomic_load(&_finishingForAutomaticRecycle)
        && !atomic_load(&_cancelled)) {
        SFXNativePlaybackPlayer *owner = _owner;
        [owner requestAutomaticSoftwareRecycleForSession:self
                                           atMilliseconds:automaticRecycleMilliseconds
                                   presentationGeneration:presentationGeneration];
    }
}

- (NSInteger)markAutomaticSoftwareRecycleIfNeededAtMediaSeconds:(double)mediaSeconds {
    if (!_allowAutomaticSoftwareRecycle
        || _automaticSoftwareRecycleRequested
        || _usingHardwareDecode
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
    _pendingAudioCompletionRecordCount += 1;
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
    BOOL shouldRequestDrain = !_audioResetInProgress
        && !finalSegmentBuffer
        && !inputEnded
        && [self queuedAudioWallSecondsLocked] <= SFXAudioQueueLowWaterWallSeconds;
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];

    BOOL shouldCompleteSegment = finalSegmentBuffer || (reachedZero && segmentDrainWaiting);
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
        if (generation == _playbackGeneration) {
            if (_pendingAudioCompletionRecordCount > 0) {
                _pendingAudioCompletionRecordCount -= 1;
            }
            if (_audioInputEnded
                && _outstandingAudioBufferCount == 0
                && _pendingAudioCompletionRecordCount == 0) {
                _audioOutputDrained = YES;
            }
        }
        [_packetQueueCondition broadcast];
        [_packetQueueCondition unlock];
    });

    if (shouldRequestDrain) {
        [self requestAudioDrain];
    }
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
        return SFXAudioScheduleResultSegmentBoundaryReached;
    }

    if ([self hasActiveSegmentEnd] && mediaSeconds >= 0) {
        double remainingSeconds = _segmentEndSeconds - mediaSeconds;
        double frameDuration = sampleRate > 0 ? (double)frame->nb_samples / (double)sampleRate : 0;
        BOOL reachesSegmentEnd = remainingSeconds <= SFXSegmentBoundaryEpsilonSeconds
            || mediaSeconds + frameDuration + SFXSegmentBoundaryEpsilonSeconds >= _segmentEndSeconds;
        if (reachesSegmentEnd && [self resolveAutoPauseAuthorizationIfNeeded]) {
            if (remainingSeconds <= SFXSegmentBoundaryEpsilonSeconds) {
                [self markSegmentAudioBoundaryReached];
                return SFXAudioScheduleResultSegmentBoundaryReached;
            }

            if (mediaSeconds + frameDuration + SFXSegmentBoundaryEpsilonSeconds >= _segmentEndSeconds) {
                int segmentSampleCount = (int)floor(remainingSeconds * (double)sampleRate + SFXSegmentBoundaryEpsilonSeconds);
                if (segmentSampleCount <= 0) {
                    [self markSegmentAudioBoundaryReached];
                    return SFXAudioScheduleResultSegmentBoundaryReached;
                }
                scheduledSampleCount = MIN(frame->nb_samples, segmentSampleCount);
                isFinalSegmentBuffer = YES;
            }
        }
    }

    AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc]
        initWithPCMFormat:_audioFormat
        frameCapacity:(AVAudioFrameCount)scheduledSampleCount
    ];
    if (buffer == nil || buffer.floatChannelData == NULL) {
        return SFXAudioScheduleResultNotScheduled;
    }

    buffer.frameLength = (AVAudioFrameCount)scheduledSampleCount;
    for (int channel = 0; channel < channels; channel++) {
        memcpy(
            buffer.floatChannelData[channel],
            frame->extended_data[channel],
            sizeof(float) * (size_t)scheduledSampleCount
        );
    }

    SFXAudioScheduleResult result = isFinalSegmentBuffer
        ? SFXAudioScheduleResultScheduledFinalSegmentBuffer
        : SFXAudioScheduleResultScheduled;
    double scheduledDurationSeconds = (double)scheduledSampleCount / (double)sampleRate;
    if (mediaSeconds >= 0) {
        double scheduledEndSeconds = mediaSeconds + scheduledDurationSeconds;
        @synchronized (self) {
            _lastScheduledAudioStartMilliseconds = (NSInteger)llround(mediaSeconds * 1000.0);
            _lastScheduledAudioEndMilliseconds = (NSInteger)llround(scheduledEndSeconds * 1000.0);
        }
    }

    [_packetQueueCondition lock];
    BOOL canSchedule = generation == _playbackGeneration
        && !_audioResetInProgress
        && !atomic_load(&_cancelled)
        && !atomic_load(&_finishingForAutomaticRecycle);
    if (canSchedule) {
        if (_audioFirstScheduledMediaSeconds < 0 && mediaSeconds >= 0) {
            _audioFirstScheduledMediaSeconds = mediaSeconds;
        }
        _queuedAudioMediaSeconds += scheduledDurationSeconds;
        _outstandingAudioBufferCount += 1;
        BOOL wasPrimed = _audioPrimed;
        if ([self queuedAudioWallSecondsLocked] >= SFXAudioPrimeWallSeconds || isFinalSegmentBuffer) {
            _audioPrimed = YES;
        }
        BOOL becamePrimed = !wasPrimed && _audioPrimed;
        [_packetQueueCondition broadcast];
        if (becamePrimed) {
            dispatch_async(_audioDecodeQueue, ^{
                [self requestAudioPlaybackStartIfReadyForGeneration:generation];
            });
        }
    }
    [_packetQueueCondition unlock];
    if (!canSchedule) {
        return SFXAudioScheduleResultNotScheduled;
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

    return result;
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

- (void)teardown {
    [self stopStarvationWatchdog];

    [_packetQueueCondition lock];
    _audioResetInProgress = YES;
    _playbackGeneration += 1;
    [_packetQueueCondition broadcast];
    [_packetQueueCondition unlock];

    [self stopPacketReadAheadAndClear];
    [self clearPendingPixelBufferSubmission];

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

    swr_free(&_resampler);
    sws_freeContext(_videoScaler);
    _videoScaler = NULL;
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

}

@end

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
    SFXNativePlaybackFrameSnapshot *_latestSubmittedVideoFrameSnapshot;
}

+ (BOOL)isHardwareDecodeSupportedForCodecName:(NSString *)codecName {
    return SFXIsHardwareDecodeSupportedForCodecName(codecName);
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
        if (imageBuffer != NULL) {
            _latestSubmittedVideoFrameSnapshot = [[SFXNativePlaybackFrameSnapshot alloc]
                initWithPixelBuffer:(CVPixelBufferRef)imageBuffer];
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
            _latestSubmittedVideoFrameSnapshot = nil;
        }
    }
    if (flushDisplay) {
        [_nativeView flush];
    }
}

@end
