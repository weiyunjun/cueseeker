#import "SFXNativePlaybackPlayer.h"

#import <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <strings.h>
#include <libavcodec/avcodec.h>
#include <libavcodec/codec_id.h>
#include <libavformat/avformat.h>
#include <libavutil/dict.h>
#include <libavutil/error.h>
#include <libavutil/pixdesc.h>
#include <libavutil/rational.h>
#include <libswscale/swscale.h>

static NSString *SFXMetadataFFmpegErrorString(int code) {
    char buffer[AV_ERROR_MAX_STRING_SIZE] = {0};
    if (av_strerror(code, buffer, sizeof(buffer)) < 0) {
        return [NSString stringWithFormat:@"FFmpeg error %d", code];
    }
    return [NSString stringWithUTF8String:buffer];
}

static NSError *SFXMediaMetadataError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:SFXNativePlaybackErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

static BOOL SFXMetadataIsHTTPPath(const char *path) {
    if (path == NULL) {
        return NO;
    }
    return strncasecmp(path, "http://", 7) == 0 || strncasecmp(path, "https://", 8) == 0;
}

static int SFXOpenMediaInputForMetadata(
    AVFormatContext **formatContext,
    const char *path,
    NSString * _Nullable httpHeaders
) {
    AVDictionary *options = NULL;
    av_dict_set(&options, "cueseeker_skip_internal_subtitles", "1", 0);
    if (SFXMetadataIsHTTPPath(path)) {
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

static const AVCodec *SFXMetadataFindSoftwareVideoDecoder(enum AVCodecID codecID) {
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

static NSString *SFXMetadataTagValue(AVDictionary *metadata, const char *key) {
    AVDictionaryEntry *entry = av_dict_get(metadata, key, NULL, 0);
    if (entry == NULL || entry->value == NULL) {
        return nil;
    }
    NSString *value = [[NSString stringWithUTF8String:entry->value]
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return value.length > 0 ? value : nil;
}

@interface SFXMediaCoverCandidateFrame ()

- (instancetype)initWithTimestampMilliseconds:(NSInteger)timestampMilliseconds
                             scoringRGB24Data:(NSData *)scoringRGB24Data
                                      cgImage:(CGImageRef)cgImage NS_DESIGNATED_INITIALIZER;

@end

@implementation SFXMediaCoverCandidateFrame {
    CGImageRef _cgImage;
}

- (instancetype)initWithTimestampMilliseconds:(NSInteger)timestampMilliseconds
                             scoringRGB24Data:(NSData *)scoringRGB24Data
                                      cgImage:(CGImageRef)cgImage {
    self = [super init];
    if (self != nil) {
        _timestampMilliseconds = timestampMilliseconds;
        _scoringRGB24Data = [scoringRGB24Data copy];
        _cgImage = CGImageRetain(cgImage);
    }
    return self;
}

- (CGImageRef)cgImage {
    return _cgImage;
}

- (void)dealloc {
    if (_cgImage != NULL) {
        CGImageRelease(_cgImage);
        _cgImage = NULL;
    }
}

@end

@interface SFXMediaAudioTrack ()

- (instancetype)initWithLanguage:(NSString *)language
                           title:(NSString *)title
                           codec:(NSString *)codec
                        channels:(NSNumber *)channels NS_DESIGNATED_INITIALIZER;

@end

@implementation SFXMediaAudioTrack

- (instancetype)initWithLanguage:(NSString *)language
                           title:(NSString *)title
                           codec:(NSString *)codec
                        channels:(NSNumber *)channels {
    self = [super init];
    if (self != nil) {
        _language = [language copy];
        _title = [title copy];
        _codec = [codec copy];
        _channels = channels;
    }
    return self;
}

@end

@interface SFXMediaMetadata ()

- (instancetype)initWithDurationSeconds:(NSNumber *)durationSeconds
                             videoWidth:(NSNumber *)videoWidth
                            videoHeight:(NSNumber *)videoHeight
                              frameRate:(NSNumber *)frameRate
                             videoCodec:(NSString *)videoCodec
                            audioTracks:(NSArray<SFXMediaAudioTrack *> *)audioTracks NS_DESIGNATED_INITIALIZER;

@end

@implementation SFXMediaMetadata

- (instancetype)initWithDurationSeconds:(NSNumber *)durationSeconds
                             videoWidth:(NSNumber *)videoWidth
                            videoHeight:(NSNumber *)videoHeight
                              frameRate:(NSNumber *)frameRate
                             videoCodec:(NSString *)videoCodec
                            audioTracks:(NSArray<SFXMediaAudioTrack *> *)audioTracks {
    self = [super init];
    if (self != nil) {
        _durationSeconds = durationSeconds;
        _videoWidth = videoWidth;
        _videoHeight = videoHeight;
        _frameRate = frameRate;
        _videoCodec = [videoCodec copy];
        _audioTracks = [audioTracks copy];
    }
    return self;
}

@end

static SFXMediaCoverCandidateFrame * _Nullable SFXCreateCoverCandidateFrame(
    const AVFrame *frame,
    int srcWidth,
    int srcHeight,
    enum AVPixelFormat inputFormat,
    NSInteger timestampMilliseconds,
    int scoringWidth,
    int scoringHeight
) {
    double scale = fmin((double)scoringWidth / (double)srcWidth, (double)scoringHeight / (double)srcHeight);
    int scaledWidth = MAX(1, MIN(scoringWidth, (int)llround((double)srcWidth * scale)));
    int scaledHeight = MAX(1, MIN(scoringHeight, (int)llround((double)srcHeight * scale)));
    int padX = (scoringWidth - scaledWidth) / 2;
    int padY = (scoringHeight - scaledHeight) / 2;

    NSMutableData *scoringData = [NSMutableData dataWithLength:(NSUInteger)(scoringWidth * scoringHeight * 3)];
    if (scoringData == nil) {
        return nil;
    }

    struct SwsContext *scoringScaler = sws_getContext(
        srcWidth,
        srcHeight,
        inputFormat,
        scaledWidth,
        scaledHeight,
        AV_PIX_FMT_RGB24,
        SWS_BILINEAR,
        NULL,
        NULL,
        NULL
    );
    if (scoringScaler == NULL) {
        return nil;
    }

    int scoringStride = scoringWidth * 3;
    uint8_t *scoringBase = (uint8_t *)scoringData.mutableBytes;
    uint8_t *scoringDstSlice[4] = {
        scoringBase + (padY * scoringStride) + (padX * 3),
        NULL,
        NULL,
        NULL
    };
    int scoringDstStride[4] = { scoringStride, 0, 0, 0 };
    sws_scale(
        scoringScaler,
        (const uint8_t * const *)frame->data,
        frame->linesize,
        0,
        srcHeight,
        scoringDstSlice,
        scoringDstStride
    );
    sws_freeContext(scoringScaler);

    int fullStride = srcWidth * 3;
    NSMutableData *fullRGBData = [NSMutableData dataWithLength:(NSUInteger)(fullStride * srcHeight)];
    if (fullRGBData == nil) {
        return nil;
    }

    struct SwsContext *fullScaler = sws_getContext(
        srcWidth,
        srcHeight,
        inputFormat,
        srcWidth,
        srcHeight,
        AV_PIX_FMT_RGB24,
        SWS_BILINEAR,
        NULL,
        NULL,
        NULL
    );
    if (fullScaler == NULL) {
        return nil;
    }

    uint8_t *fullDstSlice[4] = { (uint8_t *)fullRGBData.mutableBytes, NULL, NULL, NULL };
    int fullDstStride[4] = { fullStride, 0, 0, 0 };
    sws_scale(
        fullScaler,
        (const uint8_t * const *)frame->data,
        frame->linesize,
        0,
        srcHeight,
        fullDstSlice,
        fullDstStride
    );
    sws_freeContext(fullScaler);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    if (colorSpace == NULL) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    if (colorSpace == NULL) {
        return nil;
    }

    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)fullRGBData);
    if (provider == NULL) {
        CGColorSpaceRelease(colorSpace);
        return nil;
    }

    CGImageRef cgImage = CGImageCreate(
        (size_t)srcWidth,
        (size_t)srcHeight,
        8,
        24,
        (size_t)fullStride,
        colorSpace,
        (CGBitmapInfo)kCGImageAlphaNone,
        provider,
        NULL,
        false,
        kCGRenderingIntentDefault
    );
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);

    if (cgImage == NULL) {
        return nil;
    }

    SFXMediaCoverCandidateFrame *candidate = [[SFXMediaCoverCandidateFrame alloc]
        initWithTimestampMilliseconds:timestampMilliseconds
                     scoringRGB24Data:scoringData
                              cgImage:cgImage];
    CGImageRelease(cgImage);
    return candidate;
}

@implementation SFXMediaMetadataInspector

+ (nullable NSNumber *)durationSecondsAtMediaPath:(NSString *)mediaPath
                                            error:(NSError **)error {
    SFXMediaMetadata *metadata = [self metadataAtMediaPath:mediaPath httpHeaders:nil error:error];
    return metadata.durationSeconds;
}

+ (nullable SFXMediaMetadata *)metadataAtMediaPath:(NSString *)mediaPath
                                             error:(NSError **)error {
    return [self metadataAtMediaPath:mediaPath httpHeaders:nil error:error];
}

+ (nullable SFXMediaMetadata *)metadataAtMediaPath:(NSString *)mediaPath
                                       httpHeaders:(nullable NSString *)httpHeaders
                                             error:(NSError **)error {
    if (mediaPath.length == 0) {
        if (error != NULL) {
            *error = SFXMediaMetadataError(200, @"Media path is required.");
        }
        return nil;
    }

    AVFormatContext *formatContext = NULL;
    int result = SFXOpenMediaInputForMetadata(&formatContext, mediaPath.UTF8String, httpHeaders);
    if (result < 0) {
        if (error != NULL) {
            *error = SFXMediaMetadataError(
                201,
                [NSString stringWithFormat:@"Could not open media for metadata inspection: %@", SFXMetadataFFmpegErrorString(result)]
            );
        }
        return nil;
    }

    result = avformat_find_stream_info(formatContext, NULL);
    if (result < 0) {
        avformat_close_input(&formatContext);
        if (error != NULL) {
            *error = SFXMediaMetadataError(
                202,
                [NSString stringWithFormat:@"Could not inspect media metadata: %@", SFXMetadataFFmpegErrorString(result)]
            );
        }
        return nil;
    }

    double durationSeconds = 0.0;
    if (formatContext->duration != AV_NOPTS_VALUE && formatContext->duration > 0) {
        durationSeconds = (double)formatContext->duration / AV_TIME_BASE;
    } else {
        for (unsigned int index = 0; index < formatContext->nb_streams; index++) {
            AVStream *stream = formatContext->streams[index];
            if (stream == NULL || stream->duration == AV_NOPTS_VALUE || stream->duration <= 0) {
                continue;
            }

            double streamDuration = stream->duration * av_q2d(stream->time_base);
            if (isfinite(streamDuration) && streamDuration > durationSeconds) {
                durationSeconds = streamDuration;
            }
        }
    }

    NSNumber *durationNumber = nil;
    if (isfinite(durationSeconds) && durationSeconds > 0) {
        durationNumber = @(durationSeconds);
    }

    NSNumber *videoWidth = nil;
    NSNumber *videoHeight = nil;
    NSNumber *frameRate = nil;
    NSString *videoCodec = nil;
    int videoStreamIndex = av_find_best_stream(formatContext, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    if (videoStreamIndex >= 0 && videoStreamIndex < (int)formatContext->nb_streams) {
        AVStream *videoStream = formatContext->streams[videoStreamIndex];
        AVCodecParameters *codecParameters = videoStream != NULL ? videoStream->codecpar : NULL;
        if (codecParameters != NULL) {
            if (codecParameters->width > 0) {
                videoWidth = @(codecParameters->width);
            }
            if (codecParameters->height > 0) {
                videoHeight = @(codecParameters->height);
            }

            const char *codecName = avcodec_get_name(codecParameters->codec_id);
            if (codecName != NULL && codecName[0] != '\0') {
                videoCodec = [NSString stringWithUTF8String:codecName];
            }
        }

        AVRational frameRateRational = videoStream->avg_frame_rate.num > 0 && videoStream->avg_frame_rate.den > 0
            ? videoStream->avg_frame_rate
            : videoStream->r_frame_rate;
        if (frameRateRational.num > 0 && frameRateRational.den > 0) {
            double frameRateValue = av_q2d(frameRateRational);
            if (isfinite(frameRateValue) && frameRateValue > 0) {
                frameRate = @(frameRateValue);
            }
        }
    }

    NSMutableArray<SFXMediaAudioTrack *> *audioTracks = [NSMutableArray array];
    for (unsigned int index = 0; index < formatContext->nb_streams; index++) {
        AVStream *stream = formatContext->streams[index];
        if (stream == NULL || stream->codecpar == NULL || stream->codecpar->codec_type != AVMEDIA_TYPE_AUDIO) {
            continue;
        }

        NSString *language = SFXMetadataTagValue(stream->metadata, "language");
        if ([language caseInsensitiveCompare:@"und"] == NSOrderedSame) {
            language = nil;
        }
        const char *codecName = avcodec_get_name(stream->codecpar->codec_id);
        NSString *codec = codecName != NULL && codecName[0] != '\0'
            ? [NSString stringWithUTF8String:codecName]
            : nil;
        int channelCount = stream->codecpar->ch_layout.nb_channels;
        [audioTracks addObject:[[SFXMediaAudioTrack alloc]
            initWithLanguage:language
                       title:SFXMetadataTagValue(stream->metadata, "title")
                       codec:codec
                    channels:channelCount > 0 ? @(channelCount) : nil]];
    }

    avformat_close_input(&formatContext);

    return [[SFXMediaMetadata alloc] initWithDurationSeconds:durationNumber
                                                  videoWidth:videoWidth
                                                 videoHeight:videoHeight
                                                   frameRate:frameRate
                                                  videoCodec:videoCodec
                                                 audioTracks:audioTracks];
}

+ (nullable NSArray<SFXMediaCoverCandidateFrame *> *)sampleCoverFramesAtMediaPath:(NSString *)mediaPath
                                                                      httpHeaders:(nullable NSString *)httpHeaders
                                                           timestampsMilliseconds:(NSArray<NSNumber *> *)timestampsMilliseconds
                                                                     scoringWidth:(NSInteger)scoringWidth
                                                                    scoringHeight:(NSInteger)scoringHeight
                                                                            error:(NSError **)error {
    if (mediaPath.length == 0) {
        if (error != NULL) {
            *error = SFXMediaMetadataError(210, @"Media path is required for cover frame sampling.");
        }
        return nil;
    }
    if (timestampsMilliseconds.count == 0) {
        if (error != NULL) {
            *error = SFXMediaMetadataError(211, @"At least one candidate timestamp is required.");
        }
        return nil;
    }

    int targetScoringWidth = (int)MAX(64, scoringWidth);
    int targetScoringHeight = (int)MAX(36, scoringHeight);

    AVFormatContext *formatContext = NULL;
    AVCodecContext *codecContext = NULL;
    AVPacket *packet = NULL;
    AVFrame *frame = NULL;
    NSMutableArray<SFXMediaCoverCandidateFrame *> *candidates = [NSMutableArray arrayWithCapacity:timestampsMilliseconds.count];
    NSError *failureError = nil;

    int result = SFXOpenMediaInputForMetadata(&formatContext, mediaPath.UTF8String, httpHeaders);
    if (result < 0) {
        failureError = SFXMediaMetadataError(
            212,
            [NSString stringWithFormat:@"Could not open media for cover sampling: %@", SFXMetadataFFmpegErrorString(result)]
        );
        goto cleanup;
    }

    result = avformat_find_stream_info(formatContext, NULL);
    if (result < 0) {
        failureError = SFXMediaMetadataError(
            213,
            [NSString stringWithFormat:@"Could not inspect stream info for cover sampling: %@", SFXMetadataFFmpegErrorString(result)]
        );
        goto cleanup;
    }

    int videoStreamIndex = av_find_best_stream(formatContext, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    if (videoStreamIndex < 0 || videoStreamIndex >= (int)formatContext->nb_streams) {
        failureError = SFXMediaMetadataError(214, @"No video stream found for cover sampling.");
        goto cleanup;
    }

    for (unsigned int index = 0; index < formatContext->nb_streams; index++) {
        if ((int)index != videoStreamIndex && formatContext->streams[index] != NULL) {
            formatContext->streams[index]->discard = AVDISCARD_ALL;
        }
    }

    AVStream *videoStream = formatContext->streams[videoStreamIndex];
    AVCodecParameters *parameters = videoStream->codecpar;
    const AVCodec *decoder = SFXMetadataFindSoftwareVideoDecoder(parameters->codec_id);
    if (decoder == NULL) {
        failureError = SFXMediaMetadataError(215, @"No software video decoder found for cover sampling.");
        goto cleanup;
    }

    codecContext = avcodec_alloc_context3(decoder);
    if (codecContext == NULL) {
        failureError = SFXMediaMetadataError(216, @"Could not allocate video decoder context for cover sampling.");
        goto cleanup;
    }

    result = avcodec_parameters_to_context(codecContext, parameters);
    if (result < 0) {
        failureError = SFXMediaMetadataError(
            217,
            [NSString stringWithFormat:@"Could not copy video codec parameters: %@", SFXMetadataFFmpegErrorString(result)]
        );
        goto cleanup;
    }

    codecContext->thread_count = 2;
    codecContext->thread_type = FF_THREAD_FRAME | FF_THREAD_SLICE;

    result = avcodec_open2(codecContext, decoder, NULL);
    if (result < 0) {
        failureError = SFXMediaMetadataError(
            218,
            [NSString stringWithFormat:@"Could not open video decoder for cover sampling: %@", SFXMetadataFFmpegErrorString(result)]
        );
        goto cleanup;
    }

    packet = av_packet_alloc();
    frame = av_frame_alloc();
    if (packet == NULL || frame == NULL) {
        failureError = SFXMediaMetadataError(219, @"Could not allocate FFmpeg packet/frame for cover sampling.");
        goto cleanup;
    }

    double timelineOriginSeconds = 0.0;
    if (formatContext->start_time != AV_NOPTS_VALUE) {
        double candidate = (double)formatContext->start_time / AV_TIME_BASE;
        if (isfinite(candidate)) {
            timelineOriginSeconds = candidate;
        }
    }

    for (NSNumber *timestampNumber in timestampsMilliseconds) {
        NSInteger timestampMs = MAX(0, timestampNumber.integerValue);
        double seconds = (double)timestampMs / 1000.0;
        double targetSeconds = seconds + timelineOriginSeconds;

        int seekResult = -1;
        if (videoStream->time_base.num > 0 && videoStream->time_base.den > 0) {
            int64_t streamTarget = (int64_t)llround(targetSeconds / av_q2d(videoStream->time_base));
            seekResult = av_seek_frame(formatContext, videoStreamIndex, streamTarget, AVSEEK_FLAG_BACKWARD);
        }
        if (seekResult < 0) {
            int64_t globalTarget = (int64_t)llround(targetSeconds * AV_TIME_BASE);
            seekResult = av_seek_frame(formatContext, -1, globalTarget, AVSEEK_FLAG_BACKWARD);
        }
        if (seekResult < 0 && seconds > 0.001) {
            failureError = SFXMediaMetadataError(
                220,
                [NSString stringWithFormat:@"Could not seek media for cover sampling at %ld ms: %@", (long)timestampMs, SFXMetadataFFmpegErrorString(seekResult)]
            );
            goto cleanup;
        }

        avcodec_flush_buffers(codecContext);

        SFXMediaCoverCandidateFrame *decodedCandidate = nil;
        while (decodedCandidate == nil && av_read_frame(formatContext, packet) >= 0) {
            if (packet->stream_index != videoStreamIndex) {
                av_packet_unref(packet);
                continue;
            }

            result = avcodec_send_packet(codecContext, packet);
            av_packet_unref(packet);
            if (result < 0) {
                continue;
            }

            while (decodedCandidate == nil && (result = avcodec_receive_frame(codecContext, frame)) >= 0) {
                int width = frame->width > 0 ? frame->width : codecContext->width;
                int height = frame->height > 0 ? frame->height : codecContext->height;
                enum AVPixelFormat inputFormat = (enum AVPixelFormat)frame->format;
                if (width > 0
                    && height > 0
                    && inputFormat != AV_PIX_FMT_NONE
                    && av_pix_fmt_desc_get(inputFormat) != NULL) {
                    decodedCandidate = SFXCreateCoverCandidateFrame(
                        frame,
                        width,
                        height,
                        inputFormat,
                        timestampMs,
                        targetScoringWidth,
                        targetScoringHeight
                    );
                }
                av_frame_unref(frame);
            }
        }

        if (decodedCandidate == nil) {
            avcodec_send_packet(codecContext, NULL);
            while (decodedCandidate == nil && (result = avcodec_receive_frame(codecContext, frame)) >= 0) {
                int width = frame->width > 0 ? frame->width : codecContext->width;
                int height = frame->height > 0 ? frame->height : codecContext->height;
                enum AVPixelFormat inputFormat = (enum AVPixelFormat)frame->format;
                if (width > 0
                    && height > 0
                    && inputFormat != AV_PIX_FMT_NONE
                    && av_pix_fmt_desc_get(inputFormat) != NULL) {
                    decodedCandidate = SFXCreateCoverCandidateFrame(
                        frame,
                        width,
                        height,
                        inputFormat,
                        timestampMs,
                        targetScoringWidth,
                        targetScoringHeight
                    );
                }
                av_frame_unref(frame);
            }
        }

        if (decodedCandidate == nil) {
            failureError = SFXMediaMetadataError(
                221,
                [NSString stringWithFormat:@"Could not decode cover candidate frame at %ld ms.", (long)timestampMs]
            );
            goto cleanup;
        }

        [candidates addObject:decodedCandidate];
    }

cleanup:
    av_frame_free(&frame);
    av_packet_free(&packet);
    avcodec_free_context(&codecContext);
    avformat_close_input(&formatContext);

    if (failureError != nil) {
        if (error != NULL) {
            *error = failureError;
        }
        return nil;
    }

    return [candidates copy];
}

@end
