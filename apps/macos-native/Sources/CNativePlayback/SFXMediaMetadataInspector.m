#import "SFXNativePlaybackPlayer.h"

#include <math.h>
#include <libavcodec/codec_id.h>
#include <libavformat/avformat.h>
#include <libavutil/dict.h>
#include <libavutil/error.h>
#include <libavutil/rational.h>

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

static int SFXOpenMediaInputForMetadata(AVFormatContext **formatContext, const char *path) {
    AVDictionary *options = NULL;
    av_dict_set(&options, "cueseeker_skip_internal_subtitles", "1", 0);
    int result = avformat_open_input(formatContext, path, NULL, &options);
    av_dict_free(&options);
    return result;
}

@interface SFXMediaMetadata ()

- (instancetype)initWithDurationSeconds:(NSNumber *)durationSeconds
                             videoWidth:(NSNumber *)videoWidth
                            videoHeight:(NSNumber *)videoHeight
                              frameRate:(NSNumber *)frameRate
                             videoCodec:(NSString *)videoCodec NS_DESIGNATED_INITIALIZER;

@end

@implementation SFXMediaMetadata

- (instancetype)initWithDurationSeconds:(NSNumber *)durationSeconds
                             videoWidth:(NSNumber *)videoWidth
                            videoHeight:(NSNumber *)videoHeight
                              frameRate:(NSNumber *)frameRate
                             videoCodec:(NSString *)videoCodec {
    self = [super init];
    if (self != nil) {
        _durationSeconds = durationSeconds;
        _videoWidth = videoWidth;
        _videoHeight = videoHeight;
        _frameRate = frameRate;
        _videoCodec = [videoCodec copy];
    }
    return self;
}

@end

@implementation SFXMediaMetadataInspector

+ (nullable NSNumber *)durationSecondsAtMediaPath:(NSString *)mediaPath
                                           error:(NSError **)error {
    SFXMediaMetadata *metadata = [self metadataAtMediaPath:mediaPath error:error];
    return metadata.durationSeconds;
}

+ (nullable SFXMediaMetadata *)metadataAtMediaPath:(NSString *)mediaPath
                                            error:(NSError **)error {
    if (mediaPath.length == 0) {
        if (error != NULL) {
            *error = SFXMediaMetadataError(200, @"Media path is required.");
        }
        return nil;
    }

    AVFormatContext *formatContext = NULL;
    int result = SFXOpenMediaInputForMetadata(&formatContext, mediaPath.UTF8String);
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

    avformat_close_input(&formatContext);

    return [[SFXMediaMetadata alloc] initWithDurationSeconds:durationNumber
                                                 videoWidth:videoWidth
                                                videoHeight:videoHeight
                                                  frameRate:frameRate
                                                 videoCodec:videoCodec];
}

@end
