#import "SFXNativePlaybackInternal.h"

NSString * const SFXNativePlaybackErrorDomain = @"CueSeeker.NativePlayback";

enum AVPixelFormat SFXHardwarePixelFormat = AV_PIX_FMT_NONE;
const float SFXMinimumPlaybackRate = 0.5f;
const float SFXMaximumPlaybackRate = 2.0f;
const double SFXVideoStarvationThresholdSeconds = 0.12;
const double SFXVideoStarvationWatchdogIntervalSeconds = 0.05;
const double SFXAudioPrimeWallSeconds = 0.35;
const double SFXAudioQueueLowWaterWallSeconds = 0.75;
const double SFXAudioQueueHighWaterWallSeconds = 1.50;
const AVAudioFrameCount SFXAudioCoalesceStartupSamples = 4096;
const AVAudioFrameCount SFXAudioCoalesceSteadySamples = 16384;
const double SFXReadAheadStartupSeconds = 0.0;
const double SFXReadAheadLowWaterSeconds = 8.0;
const double SFXReadAheadTargetSeconds = 10.0;
const size_t SFXReadAheadLowWaterBytes = 48 * 1024 * 1024;
const size_t SFXReadAheadMaxBytes = 64 * 1024 * 1024;
const NSInteger SFXNoSegmentEndMilliseconds = -1;
const double SFXSegmentBoundaryEpsilonSeconds = 0.000001;


os_log_t SFXPerformanceLog(void) {
    static os_log_t log = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.cueseeker.perf", "CNativePlayback");
    });
    return log;
}

BOOL SFXPerformanceLoggingEnabled(void) {
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

NSInteger SFXSanitizedSegmentEndMilliseconds(NSInteger startMilliseconds, NSInteger endMilliseconds) {
    if (endMilliseconds < 0) {
        return SFXNoSegmentEndMilliseconds;
    }
    return MAX(startMilliseconds, endMilliseconds);
}

CFTimeInterval SFXPerformanceNow(void) {
    if (!SFXPerformanceLoggingEnabled()) {
        return 0;
    }

    return CACurrentMediaTime();
}

void SFXLogIfSlow(NSString *name, CFTimeInterval start, double thresholdMilliseconds) {
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

void SFXFreeQueuedPacket(SFXQueuedPacket *queuedPacket) {
    if (queuedPacket == NULL) {
        return;
    }
    av_packet_free(&queuedPacket->packet);
    free(queuedPacket);
}

float SFXClampedPlaybackRate(float playbackRate) {
    if (!isfinite(playbackRate)) {
        return 1.0f;
    }
    return fmaxf(SFXMinimumPlaybackRate, fminf(playbackRate, SFXMaximumPlaybackRate));
}

NSString *SFXFFmpegErrorString(int code) {
    char buffer[AV_ERROR_MAX_STRING_SIZE] = {0};
    if (av_strerror(code, buffer, sizeof(buffer)) < 0) {
        return [NSString stringWithFormat:@"FFmpeg error %d", code];
    }
    return [NSString stringWithUTF8String:buffer];
}

BOOL SFXIsHTTPMediaPath(const char *path) {
    if (path == NULL) {
        return NO;
    }
    return strncasecmp(path, "http://", 7) == 0 || strncasecmp(path, "https://", 8) == 0;
}

int SFXOpenMediaInput(
    AVFormatContext **formatContext,
    const char *path,
    NSString * _Nullable httpHeaders
) {
    AVDictionary *options = NULL;
    av_dict_set(&options, "cueseeker_skip_internal_subtitles", "1", 0);
    if (SFXIsHTTPMediaPath(path)) {
        av_dict_set(&options, "user_agent", "pan.baidu.com", 0);
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

NSString *SFXPixelFormatName(enum AVPixelFormat pixelFormat) {
    const char *name = av_get_pix_fmt_name(pixelFormat);
    if (name == NULL) {
        return [NSString stringWithFormat:@"pixel format %d", pixelFormat];
    }
    return [NSString stringWithUTF8String:name];
}

NSError *SFXNativePlaybackError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:SFXNativePlaybackErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

BOOL SFXIsHardwareDecodeSupported(enum AVCodecID codecID) {
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
        VTRegisterProfessionalVideoWorkflowVideoDecoders();
        break;
    default:
        return NO;
    }
    VTRegisterSupplementalVideoDecoderIfAvailable(codecType);
    return VTIsHardwareDecodeSupported(codecType) != 0;
}

enum AVCodecID SFXCodecIDForName(NSString *codecName) {
    if (codecName == nil || codecName.length == 0) {
        return AV_CODEC_ID_NONE;
    }
    NSString *lower = [codecName lowercaseString];
    if ([lower containsString:@"av1"] || [lower containsString:@"av01"]) {
        return AV_CODEC_ID_AV1;
    }
    if ([lower containsString:@"hevc"] || [lower containsString:@"h265"] || [lower containsString:@"hvc1"]) {
        return AV_CODEC_ID_HEVC;
    }
    if ([lower containsString:@"h264"] || [lower containsString:@"avc"]) {
        return AV_CODEC_ID_H264;
    }
    if ([lower containsString:@"vp9"] || [lower containsString:@"vp09"]) {
        return AV_CODEC_ID_VP9;
    }
    if ([lower containsString:@"prores"]) {
        return AV_CODEC_ID_PRORES;
    }
    const AVCodec *decoder = avcodec_find_decoder_by_name(lower.UTF8String);
    return decoder != NULL ? decoder->id : AV_CODEC_ID_NONE;
}

BOOL SFXIsHardwareDecodeSupportedForCodecName(NSString *codecName) {
    return SFXIsHardwareDecodeSupported(SFXCodecIDForName(codecName));
}

BOOL SFXIsHardwareDecodeSupportedForCodecAndPixelFormat(
    enum AVCodecID codecID,
    enum AVPixelFormat pixelFormat,
    int bitsPerRawSample,
    int profile,
    NSString **unsupportedReasonOut
) {
    const char *codecNameC = codecID != AV_CODEC_ID_NONE ? avcodec_get_name(codecID) : "unknown";
    NSString *codecName = [NSString stringWithUTF8String:codecNameC];

    if (!SFXIsHardwareDecodeSupported(codecID)) {
        if (unsupportedReasonOut != NULL) {
            *unsupportedReasonOut = [NSString stringWithFormat:
                @"Hardware decode is not supported by current device for %@.",
                codecName
            ];
        }
        return NO;
    }

    if (codecID == AV_CODEC_ID_PRORES) {
        return YES;
    }

    const AVPixFmtDescriptor *desc = pixelFormat != AV_PIX_FMT_NONE
        ? av_pix_fmt_desc_get(pixelFormat)
        : NULL;
    int bitDepth = desc != NULL ? desc->comp[0].depth : bitsPerRawSample;
    if (bitsPerRawSample > bitDepth) {
        bitDepth = bitsPerRawSample;
    }
    NSString *pixFmtName = pixelFormat != AV_PIX_FMT_NONE
        ? SFXPixelFormatName(pixelFormat)
        : @"unknown";

    if (bitDepth > 0 && bitDepth != 8 && bitDepth != 10) {
        if (unsupportedReasonOut != NULL) {
            *unsupportedReasonOut = [NSString stringWithFormat:
                @"Hardware decode does not support %d-bit pixel format (%@) for %@.",
                bitDepth,
                pixFmtName,
                codecName
            ];
        }
        return NO;
    }

    if (desc != NULL) {
        if ((desc->flags & AV_PIX_FMT_FLAG_RGB) != 0) {
            if (unsupportedReasonOut != NULL) {
                *unsupportedReasonOut = [NSString stringWithFormat:
                    @"Hardware decode does not support RGB pixel format (%@) for %@.",
                    pixFmtName,
                    codecName
                ];
            }
            return NO;
        }

        BOOL isYUV420 = desc->nb_components == 3
            && (desc->flags & AV_PIX_FMT_FLAG_RGB) == 0
            && desc->log2_chroma_w == 1
            && desc->log2_chroma_h == 1;

        switch (codecID) {
        case AV_CODEC_ID_HEVC:
            if (desc->nb_components != 3) {
                if (unsupportedReasonOut != NULL) {
                    *unsupportedReasonOut = [NSString stringWithFormat:
                        @"Hardware decode does not support pixel format (%@) for %@.",
                        pixFmtName,
                        codecName
                    ];
                }
                return NO;
            }
            break;
        case AV_CODEC_ID_VP9:
        case AV_CODEC_ID_AV1:
            if (!isYUV420) {
                if (unsupportedReasonOut != NULL) {
                    *unsupportedReasonOut = [NSString stringWithFormat:
                        @"Hardware decode does not support non-4:2:0 pixel format (%@) for %@.",
                        pixFmtName,
                        codecName
                    ];
                }
                return NO;
            }
            break;
        case AV_CODEC_ID_H264:
            if (!isYUV420 || bitDepth > 8) {
                if (unsupportedReasonOut != NULL) {
                    *unsupportedReasonOut = [NSString stringWithFormat:
                        @"Hardware decode does not support %d-bit pixel format (%@) for %@.",
                        bitDepth,
                        pixFmtName,
                        codecName
                    ];
                }
                return NO;
            }
            break;
        default:
            break;
        }
        return YES;
    }

    switch (codecID) {
    case AV_CODEC_ID_AV1:
        if (profile == AV_PROFILE_AV1_HIGH || profile == AV_PROFILE_AV1_PROFESSIONAL) {
            if (unsupportedReasonOut != NULL) {
                *unsupportedReasonOut = [NSString stringWithFormat:
                    @"Hardware decode does not support AV1 profile %d for %@.",
                    profile,
                    codecName
                ];
            }
            return NO;
        }
        break;
    case AV_CODEC_ID_VP9:
        if (profile == AV_PROFILE_VP9_1 || profile == AV_PROFILE_VP9_3) {
            if (unsupportedReasonOut != NULL) {
                *unsupportedReasonOut = [NSString stringWithFormat:
                    @"Hardware decode does not support VP9 profile %d for %@.",
                    profile,
                    codecName
                ];
            }
            return NO;
        }
        break;
    case AV_CODEC_ID_H264:
        if (bitDepth > 8
            || profile == AV_PROFILE_H264_HIGH_10
            || profile == AV_PROFILE_H264_HIGH_10_INTRA
            || profile == AV_PROFILE_H264_HIGH_422
            || profile == AV_PROFILE_H264_HIGH_422_INTRA
            || profile == AV_PROFILE_H264_HIGH_444
            || profile == AV_PROFILE_H264_HIGH_444_PREDICTIVE
            || profile == AV_PROFILE_H264_HIGH_444_INTRA
            || profile == AV_PROFILE_H264_CAVLC_444) {
            if (unsupportedReasonOut != NULL) {
                *unsupportedReasonOut = [NSString stringWithFormat:
                    @"Hardware decode does not support H.264 profile %d (%d-bit) for %@.",
                    profile,
                    bitDepth,
                    codecName
                ];
            }
            return NO;
        }
        break;
    default:
        break;
    }

    return YES;
}

BOOL SFXIsHardwareDecodeSupportedForParameters(
    const AVCodecParameters *parameters,
    NSString **unsupportedReasonOut
) {
    if (parameters == NULL) {
        if (unsupportedReasonOut != NULL) {
            *unsupportedReasonOut = @"No video stream parameters available.";
        }
        return NO;
    }
    return SFXIsHardwareDecodeSupportedForCodecAndPixelFormat(
        parameters->codec_id,
        (enum AVPixelFormat)parameters->format,
        parameters->bits_per_raw_sample,
        parameters->profile,
        unsupportedReasonOut
    );
}

BOOL SFXIsHardwareDecodeSupportedForCodecNameAndPixelFormatName(
    NSString *codecName,
    NSString * _Nullable pixelFormatName
) {
    enum AVCodecID codecID = SFXCodecIDForName(codecName);
    if (codecID == AV_CODEC_ID_NONE) {
        return NO;
    }
    if (pixelFormatName == nil || pixelFormatName.length == 0) {
        return SFXIsHardwareDecodeSupported(codecID);
    }
    enum AVPixelFormat pixelFormat = av_get_pix_fmt(pixelFormatName.UTF8String);
    if (pixelFormat == AV_PIX_FMT_NONE) {
        return NO;
    }
    return SFXIsHardwareDecodeSupportedForCodecAndPixelFormat(
        codecID,
        pixelFormat,
        0,
        AV_PROFILE_UNKNOWN,
        NULL
    );
}

const AVCodecHWConfig *SFXFindVideoToolboxConfig(const AVCodec *decoder) {
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

const AVCodec *SFXFindVideoToolboxDecoder(
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

const AVCodec *SFXFindSoftwareVideoDecoder(enum AVCodecID codecID) {
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

enum AVPixelFormat SFXChooseHardwareFormat(
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

double SFXStreamStartSeconds(AVStream *stream) {
    if (stream->start_time == AV_NOPTS_VALUE) {
        return 0;
    }
    return av_q2d(stream->time_base) * stream->start_time;
}

BOOL SFXStreamParticipatesInMediaTimeline(AVStream *stream) {
    enum AVMediaType mediaType = stream->codecpar->codec_type;
    return mediaType == AVMEDIA_TYPE_VIDEO
        || mediaType == AVMEDIA_TYPE_AUDIO
        || mediaType == AVMEDIA_TYPE_SUBTITLE;
}

double SFXMediaTimelineOriginSeconds(AVFormatContext *formatContext) {
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

double SFXFramePlaybackSeconds(const AVFrame *frame, AVStream *stream, double timelineOriginSeconds) {
    if (frame->best_effort_timestamp == AV_NOPTS_VALUE) {
        return -1;
    }
    return av_q2d(stream->time_base) * frame->best_effort_timestamp - timelineOriginSeconds;
}

double SFXPacketPlaybackSeconds(const AVPacket *packet, AVStream *stream, double timelineOriginSeconds) {
    int64_t timestamp = packet->pts != AV_NOPTS_VALUE ? packet->pts : packet->dts;
    if (timestamp == AV_NOPTS_VALUE) {
        return -1;
    }
    return av_q2d(stream->time_base) * timestamp - timelineOriginSeconds;
}

int64_t SFXSeekTimestamp(double seconds, AVStream *stream, double timelineOriginSeconds) {
    double timestampSeconds = seconds + timelineOriginSeconds;
    return (int64_t)llround(timestampSeconds / av_q2d(stream->time_base));
}

int64_t SFXGlobalSeekTimestamp(double seconds, double timelineOriginSeconds) {
    return (int64_t)llround((seconds + timelineOriginSeconds) * AV_TIME_BASE);
}

BOOL SFXSeekToStartPosition(
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

BOOL SFXFrameBeforeSeekTarget(
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

CMTime SFXFramePresentationTime(const AVFrame *frame, AVStream *stream, double timelineOriginSeconds) {
    double mediaSeconds = SFXFramePlaybackSeconds(frame, stream, timelineOriginSeconds);
    if (!isfinite(mediaSeconds)) {
        return CMTimeMake(0, 1);
    }
    return CMTimeMakeWithSeconds(mediaSeconds, 1000000);
}

CMSampleBufferRef SFXSampleBufferForPixelBuffer(
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

int SFXOutputChannelCount(int inputChannels) {
    if (inputChannels <= 0) {
        return 0;
    }
    return inputChannels > 2 ? 2 : inputChannels;
}

AVRational SFXVideoSampleAspectRatio(
    AVFormatContext *formatContext,
    AVStream *videoStream,
    const AVCodecContext *codecContext,
    const AVFrame *frame
) {
    AVRational sar = (videoStream != NULL)
        ? av_guess_sample_aspect_ratio(formatContext, videoStream, (AVFrame *)frame)
        : (AVRational){0, 1};
    if ((sar.num <= 0 || sar.den <= 0) && videoStream != NULL && frame != NULL) {
        sar = av_guess_sample_aspect_ratio(formatContext, videoStream, NULL);
    }
    if ((sar.num <= 0 || sar.den <= 0)
        && codecContext != NULL
        && codecContext->sample_aspect_ratio.num > 0
        && codecContext->sample_aspect_ratio.den > 0) {
        sar = codecContext->sample_aspect_ratio;
    }
    return (sar.num > 0 && sar.den > 0) ? sar : (AVRational){1, 1};
}

NSInteger SFXDisplayVideoWidthForDimensionsAndSAR(
    NSInteger storageWidth,
    NSInteger storageHeight,
    AVRational sampleAspectRatio
) {
    if (storageWidth <= 0 || storageHeight <= 0) {
        return 0;
    }
    if (sampleAspectRatio.num <= 0
        || sampleAspectRatio.den <= 0
        || sampleAspectRatio.num == sampleAspectRatio.den) {
        return storageWidth;
    }
    double scaledWidth = (double)storageWidth * (double)sampleAspectRatio.num / (double)sampleAspectRatio.den;
    if (!isfinite(scaledWidth) || scaledWidth <= 0.0) {
        return storageWidth;
    }
    return MAX(1, (NSInteger)llround(scaledWidth));
}

NSInteger SFXUnrotatedDisplayVideoWidthForPixelBuffer(CVPixelBufferRef pixelBuffer) {
    if (pixelBuffer == NULL) {
        return 0;
    }
    NSInteger storageWidth = (NSInteger)CVPixelBufferGetWidth(pixelBuffer);
    NSInteger storageHeight = (NSInteger)CVPixelBufferGetHeight(pixelBuffer);
    if (storageWidth <= 0 || storageHeight <= 0) {
        return 0;
    }
    AVRational sar = (AVRational){1, 1};
    CFTypeRef parAttachment = CVBufferCopyAttachment(pixelBuffer, kCVImageBufferPixelAspectRatioKey, NULL);
    if (parAttachment != NULL) {
        if (CFGetTypeID(parAttachment) == CFDictionaryGetTypeID()) {
            CFDictionaryRef parDict = (CFDictionaryRef)parAttachment;
            CFNumberRef numRef = (CFNumberRef)CFDictionaryGetValue(parDict, kCVImageBufferPixelAspectRatioHorizontalSpacingKey);
            CFNumberRef denRef = (CFNumberRef)CFDictionaryGetValue(parDict, kCVImageBufferPixelAspectRatioVerticalSpacingKey);
            int parsedNum = 0;
            int parsedDen = 0;
            if (numRef != NULL && denRef != NULL
                && CFNumberGetValue(numRef, kCFNumberIntType, &parsedNum)
                && CFNumberGetValue(denRef, kCFNumberIntType, &parsedDen)
                && parsedNum > 0 && parsedDen > 0) {
                sar = (AVRational){parsedNum, parsedDen};
            }
        }
        CFRelease(parAttachment);
    }
    return SFXDisplayVideoWidthForDimensionsAndSAR(storageWidth, storageHeight, sar);
}

SFXVideoOrientation SFXResolveVideoOrientationFromDisplayMatrix(const int32_t *displayMatrix) {
    if (displayMatrix == NULL) {
        return SFXVideoOrientationUp;
    }
    double rawRotation = av_display_rotation_get(displayMatrix);
    if (!isfinite(rawRotation)) {
        return SFXVideoOrientationUp;
    }
    double theta = -round(rawRotation);
    theta -= 360.0 * floor(theta / 360.0 + 0.9 / 360.0);
    int quadrant = ((int)llround(theta / 90.0) % 4 + 4) % 4;
    switch (quadrant) {
    case 1:
        return displayMatrix[3] > 0 ? SFXVideoOrientationLeftMirrored : SFXVideoOrientationRight;
    case 2:
        if (displayMatrix[0] < 0 && displayMatrix[4] < 0) {
            return SFXVideoOrientationDown;
        }
        if (displayMatrix[0] < 0) {
            return SFXVideoOrientationUpMirrored;
        }
        if (displayMatrix[4] < 0) {
            return SFXVideoOrientationDownMirrored;
        }
        return SFXVideoOrientationDown;
    case 3:
        return displayMatrix[3] < 0 ? SFXVideoOrientationRightMirrored : SFXVideoOrientationLeft;
    case 0:
    default:
        if (displayMatrix[4] < 0) {
            return SFXVideoOrientationDownMirrored;
        }
        if (displayMatrix[0] < 0) {
            return SFXVideoOrientationUpMirrored;
        }
        return SFXVideoOrientationUp;
    }
}

SFXVideoOrientation SFXResolveVideoOrientation(
    const AVStream *videoStream,
    const AVFrame *frame
) {
    const int32_t *displayMatrix = NULL;
    if (frame != NULL) {
        AVFrameSideData *frameSideData = av_frame_get_side_data(frame, AV_FRAME_DATA_DISPLAYMATRIX);
        if (frameSideData != NULL && frameSideData->size >= 9 * sizeof(int32_t)) {
            displayMatrix = (const int32_t *)frameSideData->data;
        }
    }
    if (displayMatrix == NULL && videoStream != NULL && videoStream->codecpar != NULL) {
        const AVPacketSideData *packetSideData = av_packet_side_data_get(
            videoStream->codecpar->coded_side_data,
            videoStream->codecpar->nb_coded_side_data,
            AV_PKT_DATA_DISPLAYMATRIX
        );
        if (packetSideData != NULL && packetSideData->size >= 9 * sizeof(int32_t)) {
            displayMatrix = (const int32_t *)packetSideData->data;
        }
    }
    return SFXResolveVideoOrientationFromDisplayMatrix(displayMatrix);
}

BOOL SFXVideoOrientationSwapsDimensions(SFXVideoOrientation orientation) {
    return orientation >= SFXVideoOrientationLeftMirrored && orientation <= SFXVideoOrientationLeft;
}

CGAffineTransform SFXLayerAffineTransformForVideoOrientation(SFXVideoOrientation orientation) {
    switch (orientation) {
    case SFXVideoOrientationUpMirrored:
        return CGAffineTransformMakeScale(-1.0, 1.0);
    case SFXVideoOrientationDown:
        return CGAffineTransformMakeRotation(M_PI);
    case SFXVideoOrientationDownMirrored:
        return CGAffineTransformMakeScale(1.0, -1.0);
    case SFXVideoOrientationLeftMirrored:
        return CGAffineTransformConcat(
            CGAffineTransformMakeRotation(M_PI_2),
            CGAffineTransformMakeScale(1.0, -1.0)
        );
    case SFXVideoOrientationRight:
        return CGAffineTransformMakeRotation(-M_PI_2);
    case SFXVideoOrientationRightMirrored:
        return CGAffineTransformConcat(
            CGAffineTransformMakeRotation(-M_PI_2),
            CGAffineTransformMakeScale(1.0, -1.0)
        );
    case SFXVideoOrientationLeft:
        return CGAffineTransformMakeRotation(M_PI_2);
    case SFXVideoOrientationUp:
    default:
        return CGAffineTransformIdentity;
    }
}

SFXVideoOrientation SFXVideoOrientationForPixelBuffer(CVPixelBufferRef pixelBuffer) {
    if (pixelBuffer == NULL) {
        return SFXVideoOrientationUp;
    }
    SFXVideoOrientation orientation = SFXVideoOrientationUp;
    CFTypeRef attachment = CVBufferCopyAttachment(pixelBuffer, kCGImagePropertyOrientation, NULL);
    if (attachment != NULL) {
        if (CFGetTypeID(attachment) == CFNumberGetTypeID()) {
            int parsedValue = 1;
            if (CFNumberGetValue((CFNumberRef)attachment, kCFNumberIntType, &parsedValue)
                && parsedValue >= (int)SFXVideoOrientationUp
                && parsedValue <= (int)SFXVideoOrientationLeft) {
                orientation = (SFXVideoOrientation)parsedValue;
            }
        }
        CFRelease(attachment);
    }
    return orientation;
}

static void SFXGetDisplayVideoDimensionsForPixelBuffer(
    CVPixelBufferRef pixelBuffer,
    NSInteger *widthOut,
    NSInteger *heightOut
) {
    NSInteger width = 0;
    NSInteger height = 0;
    if (pixelBuffer != NULL) {
        NSInteger unrotatedWidth = SFXUnrotatedDisplayVideoWidthForPixelBuffer(pixelBuffer);
        NSInteger unrotatedHeight = (NSInteger)CVPixelBufferGetHeight(pixelBuffer);
        SFXVideoOrientation orientation = SFXVideoOrientationForPixelBuffer(pixelBuffer);
        BOOL swaps = SFXVideoOrientationSwapsDimensions(orientation);
        width = swaps ? unrotatedHeight : unrotatedWidth;
        height = swaps ? unrotatedWidth : unrotatedHeight;
    }
    if (widthOut != NULL) {
        *widthOut = width;
    }
    if (heightOut != NULL) {
        *heightOut = height;
    }
}

NSInteger SFXDisplayVideoWidthForPixelBuffer(CVPixelBufferRef pixelBuffer) {
    NSInteger width = 0;
    SFXGetDisplayVideoDimensionsForPixelBuffer(pixelBuffer, &width, NULL);
    return width;
}

NSInteger SFXDisplayVideoHeightForPixelBuffer(CVPixelBufferRef pixelBuffer) {
    NSInteger height = 0;
    SFXGetDisplayVideoDimensionsForPixelBuffer(pixelBuffer, NULL, &height);
    return height;
}

void SFXApplyPixelAspectRatioAttachment(
    CVPixelBufferRef pixelBuffer,
    AVRational sampleAspectRatio
) {
    if (pixelBuffer == NULL) {
        return;
    }
    if (sampleAspectRatio.num > 0
        && sampleAspectRatio.den > 0
        && sampleAspectRatio.num != sampleAspectRatio.den) {
        NSDictionary *aspectDict = @{
            (__bridge NSString *)kCVImageBufferPixelAspectRatioHorizontalSpacingKey: @(sampleAspectRatio.num),
            (__bridge NSString *)kCVImageBufferPixelAspectRatioVerticalSpacingKey: @(sampleAspectRatio.den)
        };
        CVBufferSetAttachment(
            pixelBuffer,
            kCVImageBufferPixelAspectRatioKey,
            (__bridge CFDictionaryRef)aspectDict,
            kCVAttachmentMode_ShouldPropagate
        );
    } else {
        CVBufferRemoveAttachment(pixelBuffer, kCVImageBufferPixelAspectRatioKey);
    }
}

void SFXApplyVideoOrientationAttachment(
    CVPixelBufferRef pixelBuffer,
    SFXVideoOrientation orientation
) {
    if (pixelBuffer == NULL) {
        return;
    }
    if (orientation > SFXVideoOrientationUp && orientation <= SFXVideoOrientationLeft) {
        CVBufferSetAttachment(
            pixelBuffer,
            kCGImagePropertyOrientation,
            (__bridge CFNumberRef)@(orientation),
            kCVAttachmentMode_ShouldPropagate
        );
    } else {
        CVBufferRemoveAttachment(pixelBuffer, kCGImagePropertyOrientation);
    }
}

NSData *SFXTransformRGB24DataForVideoOrientation(
    NSData *rgb24Data,
    int width,
    int height,
    SFXVideoOrientation orientation,
    int *outWidth,
    int *outHeight
) {
    if (rgb24Data == nil || width <= 0 || height <= 0) {
        return nil;
    }
    size_t requiredBytes = (size_t)width * (size_t)height * 3;
    if (rgb24Data.length < requiredBytes) {
        return nil;
    }
    SFXVideoOrientation resolvedOrientation = (orientation >= SFXVideoOrientationUp && orientation <= SFXVideoOrientationLeft)
        ? orientation
        : SFXVideoOrientationUp;
    BOOL swaps = SFXVideoOrientationSwapsDimensions(resolvedOrientation);
    int dstWidth = swaps ? height : width;
    int dstHeight = swaps ? width : height;
    if (outWidth != NULL) {
        *outWidth = dstWidth;
    }
    if (outHeight != NULL) {
        *outHeight = dstHeight;
    }
    if (resolvedOrientation == SFXVideoOrientationUp) {
        return rgb24Data;
    }

    NSMutableData *transformed = [NSMutableData dataWithLength:requiredBytes];
    if (transformed == nil) {
        return nil;
    }
    const uint8_t *src = (const uint8_t *)rgb24Data.bytes;
    uint8_t *dst = (uint8_t *)transformed.mutableBytes;
    int srcStride = width * 3;
    int dstStride = dstWidth * 3;

    for (int outY = 0; outY < dstHeight; outY++) {
        uint8_t *dstRow = dst + (size_t)outY * (size_t)dstStride;
        for (int outX = 0; outX < dstWidth; outX++) {
            int inX = outX;
            int inY = outY;
            switch (resolvedOrientation) {
            case SFXVideoOrientationUpMirrored:
                inX = width - 1 - outX;
                inY = outY;
                break;
            case SFXVideoOrientationDown:
                inX = width - 1 - outX;
                inY = height - 1 - outY;
                break;
            case SFXVideoOrientationDownMirrored:
                inX = outX;
                inY = height - 1 - outY;
                break;
            case SFXVideoOrientationLeftMirrored:
                inX = outY;
                inY = outX;
                break;
            case SFXVideoOrientationRight:
                inX = outY;
                inY = height - 1 - outX;
                break;
            case SFXVideoOrientationRightMirrored:
                inX = width - 1 - outY;
                inY = height - 1 - outX;
                break;
            case SFXVideoOrientationLeft:
                inX = width - 1 - outY;
                inY = outX;
                break;
            case SFXVideoOrientationUp:
            default:
                break;
            }
            const uint8_t *srcPixel = src + (size_t)inY * (size_t)srcStride + (size_t)inX * 3;
            uint8_t *dstPixel = dstRow + (size_t)outX * 3;
            dstPixel[0] = srcPixel[0];
            dstPixel[1] = srcPixel[1];
            dstPixel[2] = srcPixel[2];
        }
    }
    return transformed;
}
