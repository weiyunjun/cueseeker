#import "SFXNativePlaybackPlayer.h"

#include <math.h>
#include <libavformat/avformat.h>
#include <libavutil/dict.h>
#include <libavutil/error.h>

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

@implementation SFXMediaMetadataInspector

+ (nullable NSNumber *)durationSecondsAtMediaPath:(NSString *)mediaPath
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

    avformat_close_input(&formatContext);

    if (!isfinite(durationSeconds) || durationSeconds <= 0) {
        return nil;
    }

    return @(durationSeconds);
}

@end
