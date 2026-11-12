#import "SFXNativePlaybackInternal.h"

NSString * const SFXNativePlaybackErrorDomain = @"CueSeeker.NativePlayback";

enum AVPixelFormat SFXHardwarePixelFormat = AV_PIX_FMT_NONE;
const float SFXMinimumPlaybackRate = 0.5f;
const float SFXMaximumPlaybackRate = 3.0f;
const double SFXVideoStarvationThresholdSeconds = 0.12;
const double SFXVideoStarvationWatchdogIntervalSeconds = 0.05;
const double SFXAudioPrimeWallSeconds = 0.10;
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
const double SFXSeekFrameAlignmentToleranceSeconds = 0.002;


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
    switch (codecID) {
    case AV_CODEC_ID_AV1: {
        static BOOL supported = NO;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            VTRegisterSupplementalVideoDecoderIfAvailable(kCMVideoCodecType_AV1);
            supported = VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1) != 0;
        });
        return supported;
    }
    case AV_CODEC_ID_H264: {
        static BOOL supported = NO;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            VTRegisterSupplementalVideoDecoderIfAvailable(kCMVideoCodecType_H264);
            supported = VTIsHardwareDecodeSupported(kCMVideoCodecType_H264) != 0;
        });
        return supported;
    }
    case AV_CODEC_ID_HEVC: {
        static BOOL supported = NO;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            VTRegisterSupplementalVideoDecoderIfAvailable(kCMVideoCodecType_HEVC);
            supported = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC) != 0;
        });
        return supported;
    }
    case AV_CODEC_ID_VP9: {
        static BOOL supported = NO;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            VTRegisterSupplementalVideoDecoderIfAvailable(kCMVideoCodecType_VP9);
            supported = VTIsHardwareDecodeSupported(kCMVideoCodecType_VP9) != 0;
        });
        return supported;
    }
    case AV_CODEC_ID_PRORES: {
        static BOOL supported = NO;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            VTRegisterProfessionalVideoWorkflowVideoDecoders();
            VTRegisterSupplementalVideoDecoderIfAvailable(kCMVideoCodecType_AppleProRes422);
            supported = VTIsHardwareDecodeSupported(kCMVideoCodecType_AppleProRes422) != 0;
        });
        return supported;
    }
    default:
        return NO;
    }
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

static BOOL SFXIsAttachedCoverOrStillVideoStream(const AVStream *stream) {
    if (stream == NULL || stream->codecpar == NULL) {
        return YES;
    }
    const int coverDispositions = AV_DISPOSITION_ATTACHED_PIC
        | AV_DISPOSITION_STILL_IMAGE
        | AV_DISPOSITION_TIMED_THUMBNAILS;
    return (stream->disposition & coverDispositions) != 0;
}

static BOOL SFXIsStillImageVideoCodec(enum AVCodecID codecID) {
    switch (codecID) {
    case AV_CODEC_ID_MJPEG:
    case AV_CODEC_ID_MJPEGB:
    case AV_CODEC_ID_LJPEG:
    case AV_CODEC_ID_JPEGLS:
    case AV_CODEC_ID_PNG:
    case AV_CODEC_ID_BMP:
    case AV_CODEC_ID_WEBP:
    case AV_CODEC_ID_TIFF:
    case AV_CODEC_ID_GIF:
        return YES;
    default:
        return NO;
    }
}

int SFXSelectPrimaryVideoStreamIndex(AVFormatContext *formatContext) {
    if (formatContext == NULL || formatContext->nb_streams == 0) {
        return -1;
    }

    int firstMotionDefaultIndex = -1;
    int firstMotionIndex = -1;
    int firstNonAttachedDefaultIndex = -1;
    int firstNonAttachedIndex = -1;
    int firstAnyVideoIndex = -1;

    for (unsigned int index = 0; index < formatContext->nb_streams; index++) {
        AVStream *stream = formatContext->streams[index];
        if (stream == NULL
            || stream->codecpar == NULL
            || stream->codecpar->codec_type != AVMEDIA_TYPE_VIDEO
            || stream->codecpar->codec_id == AV_CODEC_ID_NONE) {
            continue;
        }
        if (firstAnyVideoIndex < 0) {
            firstAnyVideoIndex = (int)index;
        }
        if (SFXIsAttachedCoverOrStillVideoStream(stream)) {
            continue;
        }
        BOOL isDefault = (stream->disposition & AV_DISPOSITION_DEFAULT) != 0;
        if (firstNonAttachedIndex < 0) {
            firstNonAttachedIndex = (int)index;
        }
        if (isDefault && firstNonAttachedDefaultIndex < 0) {
            firstNonAttachedDefaultIndex = (int)index;
        }
        if (!SFXIsStillImageVideoCodec(stream->codecpar->codec_id)) {
            if (firstMotionIndex < 0) {
                firstMotionIndex = (int)index;
            }
            if (isDefault && firstMotionDefaultIndex < 0) {
                firstMotionDefaultIndex = (int)index;
            }
        }
    }

    int bestIndex = av_find_best_stream(formatContext, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    if (bestIndex >= 0 && bestIndex < (int)formatContext->nb_streams) {
        AVStream *bestStream = formatContext->streams[bestIndex];
        if (bestStream != NULL
            && bestStream->codecpar != NULL
            && bestStream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO
            && !SFXIsAttachedCoverOrStillVideoStream(bestStream)
            && (firstMotionIndex < 0 || !SFXIsStillImageVideoCodec(bestStream->codecpar->codec_id))) {
            return bestIndex;
        }
    }

    if (firstMotionDefaultIndex >= 0) {
        return firstMotionDefaultIndex;
    }
    if (firstMotionIndex >= 0) {
        return firstMotionIndex;
    }
    if (firstNonAttachedDefaultIndex >= 0) {
        return firstNonAttachedDefaultIndex;
    }
    if (firstNonAttachedIndex >= 0) {
        return firstNonAttachedIndex;
    }
    return firstAnyVideoIndex;
}

BOOL SFXIsAudioStreamValid(const AVStream *stream) {
    if (stream == NULL
        || stream->codecpar == NULL
        || stream->codecpar->codec_type != AVMEDIA_TYPE_AUDIO
        || stream->codecpar->codec_id == AV_CODEC_ID_NONE) {
        return NO;
    }
    int channels = stream->codecpar->ch_layout.nb_channels;
    int sampleRate = stream->codecpar->sample_rate;
    return channels > 0 && sampleRate > 0;
}

double SFXStreamStartSeconds(AVStream *stream) {
    if (stream->start_time == AV_NOPTS_VALUE) {
        return 0;
    }
    return av_q2d(stream->time_base) * stream->start_time;
}

BOOL SFXStreamParticipatesInMediaTimeline(AVStream *stream) {
    if (stream == NULL || stream->codecpar == NULL) {
        return NO;
    }
    enum AVMediaType mediaType = stream->codecpar->codec_type;
    if (mediaType == AVMEDIA_TYPE_VIDEO) {
        return !SFXIsAttachedCoverOrStillVideoStream(stream);
    }
    if (mediaType == AVMEDIA_TYPE_AUDIO) {
        return SFXIsAudioStreamValid(stream);
    }
    return mediaType == AVMEDIA_TYPE_SUBTITLE;
}

double SFXMediaTimelineOriginSeconds(AVFormatContext *formatContext) {
    if (formatContext == NULL) {
        return 0;
    }

    BOOL allowsNonZeroPositiveOrigin = formatContext->iformat != NULL
        && (formatContext->iformat->flags & AVFMT_TS_DISCONT) != 0;

    if (formatContext->start_time != AV_NOPTS_VALUE) {
        double formatOriginSeconds = (double)formatContext->start_time / AV_TIME_BASE;
        if (!isfinite(formatOriginSeconds)) {
            return 0;
        }
        if (formatOriginSeconds < 0.0 || allowsNonZeroPositiveOrigin) {
            return formatOriginSeconds;
        }
        return 0;
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

    if (originSeconds < DBL_MAX && isfinite(originSeconds)) {
        if (originSeconds < 0.0 || allowsNonZeroPositiveOrigin) {
            return originSeconds;
        }
    }
    return 0;
}

static double SFXProbeTailPacketDurationSeconds(
    AVFormatContext *formatContext,
    int primaryVideoStreamIndex,
    double timelineOriginSeconds
) {
    if (formatContext == NULL
        || formatContext->pb == NULL
        || (formatContext->pb->seekable & AVIO_SEEKABLE_NORMAL) == 0) {
        return 0.0;
    }

    int64_t initialBytePosition = avio_tell(formatContext->pb);
    double originSeconds = isfinite(timelineOriginSeconds) ? timelineOriginSeconds : 0.0;
    const double probeHorizonSeconds = fmax(0.0, originSeconds) + 86400.0;

    int seekResult = -1;
    if (primaryVideoStreamIndex >= 0 && primaryVideoStreamIndex < (int)formatContext->nb_streams) {
        AVStream *videoStream = formatContext->streams[primaryVideoStreamIndex];
        if (videoStream != NULL && videoStream->time_base.num > 0 && videoStream->time_base.den > 0) {
            int64_t targetStreamTs = (int64_t)llround(probeHorizonSeconds / av_q2d(videoStream->time_base));
            seekResult = av_seek_frame(formatContext, primaryVideoStreamIndex, targetStreamTs, AVSEEK_FLAG_BACKWARD);
        }
    }
    if (seekResult < 0) {
        int64_t targetGlobalTs = (int64_t)llround(probeHorizonSeconds * AV_TIME_BASE);
        seekResult = av_seek_frame(formatContext, -1, targetGlobalTs, AVSEEK_FLAG_BACKWARD);
    }
    if (seekResult < 0) {
        int64_t fileSize = avio_size(formatContext->pb);
        if (fileSize > 0) {
            int64_t tailByteOffset = MAX((int64_t)0, fileSize - (int64_t)(1024 * 1024));
            seekResult = av_seek_frame(formatContext, -1, tailByteOffset, AVSEEK_FLAG_BYTE);
        }
    }

    double maxPacketEndSeconds = -1.0;
    if (seekResult >= 0) {
        AVPacket *packet = av_packet_alloc();
        if (packet != NULL) {
            int packetsRead = 0;
            while (packetsRead < 4096 && av_read_frame(formatContext, packet) >= 0) {
                packetsRead += 1;
                if (packet->stream_index >= 0 && packet->stream_index < (int)formatContext->nb_streams) {
                    AVStream *stream = formatContext->streams[packet->stream_index];
                    if (stream != NULL
                        && stream->codecpar != NULL
                        && stream->time_base.num > 0
                        && stream->time_base.den > 0
                        && ((stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO
                             && !SFXIsAttachedCoverOrStillVideoStream(stream))
                            || (stream->codecpar->codec_type == AVMEDIA_TYPE_AUDIO
                                && SFXIsAudioStreamValid(stream)))) {
                        int64_t rawTimestamp = packet->pts != AV_NOPTS_VALUE ? packet->pts : packet->dts;
                        if (rawTimestamp != AV_NOPTS_VALUE) {
                            double packetEndSeconds = (double)rawTimestamp * av_q2d(stream->time_base);
                            if (packet->duration > 0) {
                                packetEndSeconds += (double)packet->duration * av_q2d(stream->time_base);
                            }
                            if (isfinite(packetEndSeconds) && packetEndSeconds > maxPacketEndSeconds) {
                                maxPacketEndSeconds = packetEndSeconds;
                            }
                        }
                    }
                }
                av_packet_unref(packet);
            }
            av_packet_free(&packet);
        }
    }

    int restoreResult = -1;
    if (primaryVideoStreamIndex >= 0 && primaryVideoStreamIndex < (int)formatContext->nb_streams) {
        AVStream *videoStream = formatContext->streams[primaryVideoStreamIndex];
        if (videoStream != NULL) {
            int64_t startTs = videoStream->start_time != AV_NOPTS_VALUE ? videoStream->start_time : 0;
            restoreResult = av_seek_frame(formatContext, primaryVideoStreamIndex, startTs, AVSEEK_FLAG_BACKWARD);
        }
    }
    if (restoreResult < 0) {
        int64_t startGlobalTs = formatContext->start_time != AV_NOPTS_VALUE ? formatContext->start_time : 0;
        restoreResult = av_seek_frame(formatContext, -1, startGlobalTs, AVSEEK_FLAG_BACKWARD);
    }
    if (restoreResult < 0 && initialBytePosition >= 0) {
        avio_seek(formatContext->pb, initialBytePosition, SEEK_SET);
        avformat_flush(formatContext);
    }

    double probedDuration = maxPacketEndSeconds - originSeconds;
    if (isfinite(probedDuration) && probedDuration > 0.0) {
        if (formatContext->duration == AV_NOPTS_VALUE || formatContext->duration <= 0) {
            formatContext->duration = (int64_t)llround(probedDuration * AV_TIME_BASE);
        }
        return probedDuration;
    }
    return 0.0;
}

double SFXResolveMediaDurationSeconds(
    AVFormatContext *formatContext,
    int primaryVideoStreamIndex,
    double timelineOriginSeconds
) {
    if (formatContext == NULL) {
        return 0.0;
    }

    if (formatContext->duration != AV_NOPTS_VALUE && formatContext->duration > 0) {
        double containerDuration = (double)formatContext->duration / AV_TIME_BASE;
        if (isfinite(containerDuration) && containerDuration > 0.0) {
            return containerDuration;
        }
    }

    double maxStreamDuration = 0.0;
    for (unsigned int index = 0; index < formatContext->nb_streams; index++) {
        AVStream *stream = formatContext->streams[index];
        if (stream == NULL
            || stream->codecpar == NULL
            || stream->duration == AV_NOPTS_VALUE
            || stream->duration <= 0
            || stream->time_base.num <= 0
            || stream->time_base.den <= 0) {
            continue;
        }
        if (stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO
            && SFXIsAttachedCoverOrStillVideoStream(stream)) {
            continue;
        }
        double streamDuration = (double)stream->duration * av_q2d(stream->time_base);
        if (isfinite(streamDuration) && streamDuration > maxStreamDuration) {
            maxStreamDuration = streamDuration;
        }
    }
    if (maxStreamDuration > 0.0) {
        return maxStreamDuration;
    }

    return SFXProbeTailPacketDurationSeconds(
        formatContext,
        primaryVideoStreamIndex,
        timelineOriginSeconds
    );
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
    return frameSeconds + SFXSeekFrameAlignmentToleranceSeconds < seekSeconds;
}

double SFXResolvedPlaybackSecondsForSeekTarget(
    double mediaSeconds,
    double seekSeconds
) {
    if (!isfinite(mediaSeconds) || mediaSeconds < 0 || !isfinite(seekSeconds) || seekSeconds <= 0) {
        return mediaSeconds;
    }
    if (mediaSeconds < seekSeconds
        && mediaSeconds + SFXSeekFrameAlignmentToleranceSeconds + 1e-5 >= seekSeconds) {
        return seekSeconds;
    }
    return mediaSeconds;
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

void SFXEnsureValidChannelLayout(AVChannelLayout *layout, int fallbackChannels) {
    if (layout == NULL) {
        return;
    }
    int channels = layout->nb_channels > 0 ? layout->nb_channels : fallbackChannels;
    if (channels <= 0) {
        return;
    }
    if (layout->nb_channels <= 0
        || layout->order == AV_CHANNEL_ORDER_UNSPEC
        || !av_channel_layout_check(layout)) {
        av_channel_layout_uninit(layout);
        av_channel_layout_default(layout, channels);
    }
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

NSString *SFXFFmpegPixelAspectRatioScaleFilter(BOOL swapsVideoDimensions) {
    return SFXFFmpegPixelAspectRatioScaleFilterWithColorMatrix(swapsVideoDimensions, nil);
}

NSString *SFXFFmpegPixelAspectRatioScaleFilterWithColorMatrix(
    BOOL swapsVideoDimensions,
    NSString * _Nullable inferredColorMatrix
) {
    NSString *baseFilter = swapsVideoDimensions
        ? @"scale=iw:'max(1,round(ih/sar))':reset_sar=1"
        : @"scale='max(1,round(iw*sar))':ih:reset_sar=1";
    if (inferredColorMatrix.length > 0) {
        return [NSString stringWithFormat:@"%@:in_color_matrix=%@", baseFilter, inferredColorMatrix];
    }
    return baseFilter;
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

static void SFXResolveVideoDimensions(
    const AVStream *videoStream,
    const AVCodecContext *codecContext,
    const AVFrame *frame,
    int fallbackWidth,
    int fallbackHeight,
    int *widthOut,
    int *heightOut
) {
    int width = fallbackWidth;
    int height = fallbackHeight;
    if ((width <= 0 || height <= 0) && frame != NULL && frame->width > 0 && frame->height > 0) {
        width = frame->width;
        height = frame->height;
    }
    if ((width <= 0 || height <= 0) && codecContext != NULL && codecContext->width > 0 && codecContext->height > 0) {
        width = codecContext->width;
        height = codecContext->height;
    }
    if ((width <= 0 || height <= 0) && videoStream != NULL && videoStream->codecpar != NULL
        && videoStream->codecpar->width > 0 && videoStream->codecpar->height > 0) {
        width = videoStream->codecpar->width;
        height = videoStream->codecpar->height;
    }
    if (widthOut != NULL) {
        *widthOut = width;
    }
    if (heightOut != NULL) {
        *heightOut = height;
    }
}

static BOOL SFXIsSpecifiedColorSpace(enum AVColorSpace colorSpace) {
    return colorSpace != AVCOL_SPC_UNSPECIFIED && colorSpace != AVCOL_SPC_RESERVED;
}

static BOOL SFXIsSpecifiedColorPrimaries(enum AVColorPrimaries primaries) {
    return primaries != AVCOL_PRI_UNSPECIFIED
        && primaries != AVCOL_PRI_RESERVED
        && primaries != AVCOL_PRI_RESERVED0;
}

static BOOL SFXIsSpecifiedColorTransfer(enum AVColorTransferCharacteristic transfer) {
    return transfer != AVCOL_TRC_UNSPECIFIED
        && transfer != AVCOL_TRC_RESERVED
        && transfer != AVCOL_TRC_RESERVED0;
}

enum AVColorSpace SFXResolveVideoColorSpace(
    const AVStream *videoStream,
    const AVCodecContext *codecContext,
    const AVFrame *frame,
    int width,
    int height
) {
    if (frame != NULL && SFXIsSpecifiedColorSpace(frame->colorspace)) {
        return frame->colorspace;
    }
    if (codecContext != NULL && SFXIsSpecifiedColorSpace(codecContext->colorspace)) {
        return codecContext->colorspace;
    }
    if (videoStream != NULL && videoStream->codecpar != NULL
        && SFXIsSpecifiedColorSpace(videoStream->codecpar->color_space)) {
        return videoStream->codecpar->color_space;
    }
    int resolvedWidth = 0;
    int resolvedHeight = 0;
    SFXResolveVideoDimensions(videoStream, codecContext, frame, width, height, &resolvedWidth, &resolvedHeight);
    if (resolvedWidth > 1280 || resolvedHeight > 576) {
        return AVCOL_SPC_BT709;
    }
    return AVCOL_SPC_SMPTE170M;
}

enum AVColorPrimaries SFXResolveVideoColorPrimaries(
    const AVStream *videoStream,
    const AVCodecContext *codecContext,
    const AVFrame *frame,
    int width,
    int height
) {
    if (frame != NULL && SFXIsSpecifiedColorPrimaries(frame->color_primaries)) {
        return frame->color_primaries;
    }
    if (codecContext != NULL && SFXIsSpecifiedColorPrimaries(codecContext->color_primaries)) {
        return codecContext->color_primaries;
    }
    if (videoStream != NULL && videoStream->codecpar != NULL
        && SFXIsSpecifiedColorPrimaries(videoStream->codecpar->color_primaries)) {
        return videoStream->codecpar->color_primaries;
    }
    enum AVColorSpace colorSpace = SFXResolveVideoColorSpace(videoStream, codecContext, frame, width, height);
    if (colorSpace == AVCOL_SPC_BT2020_NCL || colorSpace == AVCOL_SPC_BT2020_CL) {
        return AVCOL_PRI_BT2020;
    }
    if (colorSpace == AVCOL_SPC_SMPTE240M) {
        return AVCOL_PRI_SMPTE240M;
    }
    int resolvedWidth = 0;
    int resolvedHeight = 0;
    SFXResolveVideoDimensions(videoStream, codecContext, frame, width, height, &resolvedWidth, &resolvedHeight);
    if (colorSpace == AVCOL_SPC_BT709 || resolvedWidth > 1280 || resolvedHeight > 576) {
        return AVCOL_PRI_BT709;
    }
    if (videoStream != NULL) {
        AVRational rate = videoStream->avg_frame_rate.num > 0 && videoStream->avg_frame_rate.den > 0
            ? videoStream->avg_frame_rate
            : videoStream->r_frame_rate;
        if (rate.num > 0 && rate.den > 0) {
            double fps = av_q2d(rate);
            if (fabs(fps - 25.0) < 0.05 || fabs(fps - 50.0) < 0.05) {
                return AVCOL_PRI_BT470BG;
            }
        }
    }
    return AVCOL_PRI_SMPTE170M;
}

enum AVColorTransferCharacteristic SFXResolveVideoColorTransfer(
    const AVStream *videoStream,
    const AVCodecContext *codecContext,
    const AVFrame *frame
) {
    if (frame != NULL && SFXIsSpecifiedColorTransfer(frame->color_trc)) {
        return frame->color_trc;
    }
    if (codecContext != NULL && SFXIsSpecifiedColorTransfer(codecContext->color_trc)) {
        return codecContext->color_trc;
    }
    if (videoStream != NULL && videoStream->codecpar != NULL
        && SFXIsSpecifiedColorTransfer(videoStream->codecpar->color_trc)) {
        return videoStream->codecpar->color_trc;
    }
    return AVCOL_TRC_UNSPECIFIED;
}

BOOL SFXResolveVideoIsFullRange(
    const AVStream *videoStream,
    const AVCodecContext *codecContext,
    const AVFrame *frame,
    enum AVPixelFormat pixelFormat
) {
    if (pixelFormat == AV_PIX_FMT_YUVJ420P
        || pixelFormat == AV_PIX_FMT_YUVJ422P
        || pixelFormat == AV_PIX_FMT_YUVJ444P
        || pixelFormat == AV_PIX_FMT_YUVJ440P
        || pixelFormat == AV_PIX_FMT_YUVJ411P) {
        return YES;
    }
    if (frame != NULL && frame->color_range != AVCOL_RANGE_UNSPECIFIED) {
        return frame->color_range == AVCOL_RANGE_JPEG;
    }
    if (codecContext != NULL && codecContext->color_range != AVCOL_RANGE_UNSPECIFIED) {
        return codecContext->color_range == AVCOL_RANGE_JPEG;
    }
    if (videoStream != NULL && videoStream->codecpar != NULL
        && videoStream->codecpar->color_range != AVCOL_RANGE_UNSPECIFIED) {
        return videoStream->codecpar->color_range == AVCOL_RANGE_JPEG;
    }
    return NO;
}

void SFXApplyColorSpaceAttachments(
    CVPixelBufferRef pixelBuffer,
    const AVStream *videoStream,
    const AVCodecContext *codecContext,
    const AVFrame *frame
) {
    if (pixelBuffer == NULL) {
        return;
    }
    int width = (int)CVPixelBufferGetWidth(pixelBuffer);
    int height = (int)CVPixelBufferGetHeight(pixelBuffer);
    enum AVColorSpace colorSpace = SFXResolveVideoColorSpace(videoStream, codecContext, frame, width, height);
    enum AVColorPrimaries primaries = SFXResolveVideoColorPrimaries(videoStream, codecContext, frame, width, height);
    enum AVColorTransferCharacteristic transfer = SFXResolveVideoColorTransfer(videoStream, codecContext, frame);

    CFStringRef matrix = kCVImageBufferYCbCrMatrix_ITU_R_709_2;
    if (colorSpace == AVCOL_SPC_BT2020_NCL || colorSpace == AVCOL_SPC_BT2020_CL) {
        matrix = kCVImageBufferYCbCrMatrix_ITU_R_2020;
    } else if (colorSpace == AVCOL_SPC_SMPTE240M) {
        matrix = kCVImageBufferYCbCrMatrix_SMPTE_240M_1995;
    } else if (colorSpace == AVCOL_SPC_BT470BG || colorSpace == AVCOL_SPC_SMPTE170M) {
        matrix = kCVImageBufferYCbCrMatrix_ITU_R_601_4;
    }

    CFStringRef primariesKey = kCVImageBufferColorPrimaries_ITU_R_709_2;
    if (primaries == AVCOL_PRI_BT2020) {
        primariesKey = kCVImageBufferColorPrimaries_ITU_R_2020;
    } else if (primaries == AVCOL_PRI_SMPTE431) {
        primariesKey = kCVImageBufferColorPrimaries_DCI_P3;
    } else if (primaries == AVCOL_PRI_SMPTE432) {
        primariesKey = kCVImageBufferColorPrimaries_P3_D65;
    } else if (primaries == AVCOL_PRI_BT470BG) {
        primariesKey = kCVImageBufferColorPrimaries_EBU_3213;
    } else if (primaries == AVCOL_PRI_SMPTE170M || primaries == AVCOL_PRI_SMPTE240M) {
        primariesKey = kCVImageBufferColorPrimaries_SMPTE_C;
    }

    CFStringRef transferKey = kCVImageBufferTransferFunction_sRGB;
    if (transfer == AVCOL_TRC_SMPTE2084) {
        transferKey = kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ;
    } else if (transfer == AVCOL_TRC_ARIB_STD_B67) {
        transferKey = kCVImageBufferTransferFunction_ITU_R_2100_HLG;
    } else if (transfer == AVCOL_TRC_LINEAR) {
        transferKey = kCVImageBufferTransferFunction_Linear;
    }

    CVBufferSetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, matrix, kCVAttachmentMode_ShouldPropagate);
    CVBufferSetAttachment(pixelBuffer, kCVImageBufferColorPrimariesKey, primariesKey, kCVAttachmentMode_ShouldPropagate);
    CVBufferSetAttachment(pixelBuffer, kCVImageBufferTransferFunctionKey, transferKey, kCVAttachmentMode_ShouldPropagate);
    CVBufferRemoveAttachment(pixelBuffer, kCVImageBufferGammaLevelKey);
}

void SFXConfigureSwsContextColorSpace(
    struct SwsContext *scaler,
    const AVStream *videoStream,
    const AVCodecContext *codecContext,
    const AVFrame *frame,
    int width,
    int height,
    enum AVPixelFormat inputFormat,
    enum AVPixelFormat outputFormat
) {
    if (scaler == NULL) {
        return;
    }
    enum AVColorSpace colorSpace = SFXResolveVideoColorSpace(videoStream, codecContext, frame, width, height);
    int swsCS = SWS_CS_ITU709;
    if (colorSpace == AVCOL_SPC_BT2020_NCL || colorSpace == AVCOL_SPC_BT2020_CL) {
        swsCS = SWS_CS_BT2020;
    } else if (colorSpace == AVCOL_SPC_SMPTE240M) {
        swsCS = SWS_CS_SMPTE240M;
    } else if (colorSpace == AVCOL_SPC_BT470BG) {
        swsCS = SWS_CS_ITU624;
    } else if (colorSpace == AVCOL_SPC_SMPTE170M) {
        swsCS = SWS_CS_SMPTE170M;
    } else if (colorSpace == AVCOL_SPC_FCC) {
        swsCS = SWS_CS_FCC;
    }

    BOOL srcFullRange = SFXResolveVideoIsFullRange(videoStream, codecContext, frame, inputFormat);
    BOOL dstFullRange = srcFullRange;
    const AVPixFmtDescriptor *dstDesc = av_pix_fmt_desc_get(outputFormat);
    if (dstDesc != NULL && (dstDesc->flags & AV_PIX_FMT_FLAG_RGB) != 0) {
        dstFullRange = YES;
    }

    const int *invTable = sws_getCoefficients(swsCS);
    const int *table = sws_getCoefficients(swsCS);
    sws_setColorspaceDetails(
        scaler,
        invTable,
        srcFullRange ? 1 : 0,
        table,
        dstFullRange ? 1 : 0,
        0,
        1 << 16,
        1 << 16
    );
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
