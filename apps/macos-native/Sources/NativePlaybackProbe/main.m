#import <AppKit/AppKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>
#import <dispatch/dispatch.h>

#include <libavcodec/avcodec.h>
#include <libavcodec/packet.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libavutil/error.h>
#include <libavutil/hwcontext.h>
#include <libavutil/pixdesc.h>

#include <errno.h>
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef struct {
    AVFormatContext *formatContext;
    int videoStreamIndex;
    int audioStreamIndex;
    int maxOutputFrames;
    int seekPrerollPacketLimit;
    bool hasSeek;
    double seekSeconds;
    bool displayFrames;
    AVSampleBufferDisplayLayer *__unsafe_unretained displayLayer;
    AVAudioEngine *__unsafe_unretained audioEngine;
    AVAudioPlayerNode *__unsafe_unretained audioPlayer;
    AVAudioFormat *__unsafe_unretained audioFormat;
} ProbeRunContext;

typedef struct {
    AVCodecContext *codecContext;
    AVFrame *frame;
    int decodedFrames;
    int scheduledBuffers;
    int skippedBeforeSeek;
    int unsupportedFrames;
    int decodeFailures;
    int sampleRate;
    int channels;
} AudioDecodeContext;

typedef struct {
    bool initialized;
    double firstMediaSeconds;
    double startHostSeconds;
    int pacedFrames;
    int lateFrames;
    double maxWaitSeconds;
    double maxLatenessSeconds;
} VideoPacer;

static enum AVPixelFormat hardwarePixelFormat = AV_PIX_FMT_NONE;
static const int defaultMaxOutputFrames = 300;
static const int defaultSeekPrerollPacketLimit = 3000;
static const int receiveFramesOK = 0;
static const int receiveFramesError = 1;
static const int receiveFramesOutputLimit = 2;

static const char *codec_name(enum AVCodecID codecID) {
    const char *name = avcodec_get_name(codecID);
    return name != NULL ? name : "unknown";
}

static void ffmpeg_error_string(int code, char *buffer, size_t bufferSize) {
    if (av_strerror(code, buffer, bufferSize) < 0) {
        snprintf(buffer, bufferSize, "FFmpeg error %d", code);
    }
}

static CMTime cm_time_from_frame(const AVFrame *frame, AVStream *videoStream) {
    if (frame->best_effort_timestamp == AV_NOPTS_VALUE) {
        return CMTimeMake(0, 1);
    }

    int64_t value = frame->best_effort_timestamp * videoStream->time_base.num;
    return CMTimeMake(value, videoStream->time_base.den);
}

static double seconds_from_frame(const AVFrame *frame, AVStream *stream) {
    if (frame->best_effort_timestamp == AV_NOPTS_VALUE) {
        return -1;
    }

    return av_q2d(stream->time_base) * frame->best_effort_timestamp;
}

static double stream_start_seconds(AVStream *stream) {
    if (stream->start_time == AV_NOPTS_VALUE) {
        return 0;
    }

    return av_q2d(stream->time_base) * stream->start_time;
}

static double playback_seconds_from_frame(const AVFrame *frame, AVStream *stream) {
    double seconds = seconds_from_frame(frame, stream);
    if (seconds < 0) {
        return -1;
    }

    return seconds - stream_start_seconds(stream);
}

static int64_t timestamp_for_seek_seconds(double seconds, AVStream *stream) {
    int64_t relativeTimestamp = (int64_t)llround(seconds / av_q2d(stream->time_base));
    if (stream->start_time == AV_NOPTS_VALUE) {
        return relativeTimestamp;
    }

    return stream->start_time + relativeTimestamp;
}

static bool frame_is_before_seek_target(
    const AVFrame *frame,
    AVStream *stream,
    double seekSeconds
) {
    double frameSeconds = playback_seconds_from_frame(frame, stream);
    if (frameSeconds < 0) {
        return false;
    }

    return frameSeconds + 0.002 < seekSeconds;
}

static enum AVPixelFormat choose_hardware_format(
    AVCodecContext *context,
    const enum AVPixelFormat *pixelFormats
) {
    (void)context;

    for (const enum AVPixelFormat *format = pixelFormats; *format != AV_PIX_FMT_NONE; format++) {
        if (*format == hardwarePixelFormat) {
            return *format;
        }
    }

    fprintf(stderr, "VideoToolbox pixel format was not offered by decoder.\n");
    return pixelFormats[0];
}

static const AVCodecHWConfig *find_videotoolbox_config(const AVCodec *decoder) {
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

static int print_frame(
    const AVFrame *frame,
    AVStream *videoStream,
    int decodedFrames
) {
    double seconds = seconds_from_frame(frame, videoStream);
    const char *formatName = av_get_pix_fmt_name((enum AVPixelFormat)frame->format);

    if (frame->format == hardwarePixelFormat) {
        CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)frame->data[3];
        size_t width = pixelBuffer != NULL ? CVPixelBufferGetWidth(pixelBuffer) : 0;
        size_t height = pixelBuffer != NULL ? CVPixelBufferGetHeight(pixelBuffer) : 0;

        printf(
            "Decoded hardware frame %d: %.3fs, %zux%zu, format=%s\n",
            decodedFrames,
            seconds,
            width,
            height,
            formatName != NULL ? formatName : "unknown"
        );
        return 1;
    }

    printf(
        "Decoded software frame %d: %.3fs, %dx%d, format=%s\n",
        decodedFrames,
        seconds,
        frame->width,
        frame->height,
        formatName != NULL ? formatName : "unknown"
    );
    return 0;
}

static void print_audio_frame(
    const AVFrame *frame,
    AVStream *audioStream,
    int decodedFrames
) {
    double seconds = seconds_from_frame(frame, audioStream);
    const char *formatName = av_get_sample_fmt_name((enum AVSampleFormat)frame->format);

    printf(
        "Decoded audio frame %d: %.3fs, samples=%d, channels=%d, format=%s\n",
        decodedFrames,
        seconds,
        frame->nb_samples,
        frame->ch_layout.nb_channels,
        formatName != NULL ? formatName : "unknown"
    );
}

static void pace_video_frame(
    VideoPacer *pacer,
    const AVFrame *frame,
    AVStream *videoStream
) {
    if (pacer == NULL) {
        return;
    }

    double mediaSeconds = seconds_from_frame(frame, videoStream);
    if (mediaSeconds < 0) {
        return;
    }

    double now = CACurrentMediaTime();
    if (!pacer->initialized) {
        pacer->initialized = true;
        pacer->firstMediaSeconds = mediaSeconds;
        pacer->startHostSeconds = now;
        pacer->pacedFrames++;
        return;
    }

    double targetHostSeconds = pacer->startHostSeconds
        + (mediaSeconds - pacer->firstMediaSeconds);
    double waitSeconds = targetHostSeconds - now;

    if (waitSeconds > 0) {
        if (waitSeconds > pacer->maxWaitSeconds) {
            pacer->maxWaitSeconds = waitSeconds;
        }

        double cappedWaitSeconds = waitSeconds > 0.25 ? 0.25 : waitSeconds;
        usleep((useconds_t)(cappedWaitSeconds * 1000000.0));
    } else {
        double latenessSeconds = -waitSeconds;
        if (latenessSeconds > 0.002) {
            pacer->lateFrames++;
        }
        if (latenessSeconds > pacer->maxLatenessSeconds) {
            pacer->maxLatenessSeconds = latenessSeconds;
        }
    }

    pacer->pacedFrames++;
}

static AudioDecodeContext *create_audio_decode_context(
    AVFormatContext *formatContext,
    int audioStreamIndex
) {
    if (audioStreamIndex < 0) {
        return NULL;
    }

    AVStream *audioStream = formatContext->streams[audioStreamIndex];
    AVCodecParameters *codecParameters = audioStream->codecpar;
    const AVCodec *decoder = avcodec_find_decoder(codecParameters->codec_id);
    if (decoder == NULL) {
        fprintf(stderr, "No FFmpeg decoder found for audio codec %s.\n", codec_name(codecParameters->codec_id));
        return NULL;
    }

    AudioDecodeContext *audio = calloc(1, sizeof(AudioDecodeContext));
    if (audio == NULL) {
        return NULL;
    }

    audio->codecContext = avcodec_alloc_context3(decoder);
    audio->frame = av_frame_alloc();
    if (audio->codecContext == NULL || audio->frame == NULL) {
        fprintf(stderr, "Could not allocate audio decoder context.\n");
        avcodec_free_context(&audio->codecContext);
        av_frame_free(&audio->frame);
        free(audio);
        return NULL;
    }

    int result = avcodec_parameters_to_context(audio->codecContext, codecParameters);
    if (result < 0) {
        char error[AV_ERROR_MAX_STRING_SIZE] = {0};
        ffmpeg_error_string(result, error, sizeof(error));
        fprintf(stderr, "avcodec_parameters_to_context for audio failed: %s\n", error);
        avcodec_free_context(&audio->codecContext);
        av_frame_free(&audio->frame);
        free(audio);
        return NULL;
    }

    result = avcodec_open2(audio->codecContext, decoder, NULL);
    if (result < 0) {
        char error[AV_ERROR_MAX_STRING_SIZE] = {0};
        ffmpeg_error_string(result, error, sizeof(error));
        fprintf(stderr, "avcodec_open2 for audio failed: %s\n", error);
        avcodec_free_context(&audio->codecContext);
        av_frame_free(&audio->frame);
        free(audio);
        return NULL;
    }

    audio->sampleRate = audio->codecContext->sample_rate;
    audio->channels = audio->codecContext->ch_layout.nb_channels;

    printf(
        "Audio decoder: %s, sample_rate=%d, channels=%d\n",
        decoder->name,
        audio->sampleRate,
        audio->channels
    );

    return audio;
}

static void destroy_audio_decode_context(AudioDecodeContext *audio) {
    if (audio == NULL) {
        return;
    }

    avcodec_free_context(&audio->codecContext);
    av_frame_free(&audio->frame);
    free(audio);
}

static bool schedule_audio_frame(
    const AVFrame *frame,
    AVAudioPlayerNode *audioPlayer,
    AVAudioFormat *audioFormat
) {
    if (audioPlayer == nil || audioFormat == nil) {
        return false;
    }

    if (frame->format != AV_SAMPLE_FMT_FLTP) {
        const char *formatName = av_get_sample_fmt_name((enum AVSampleFormat)frame->format);
        fprintf(
            stderr,
            "Unsupported audio sample format for this probe: %s\n",
            formatName != NULL ? formatName : "unknown"
        );
        return false;
    }

    int channels = frame->ch_layout.nb_channels;
    if (channels <= 0 || channels > (int)audioFormat.channelCount) {
        fprintf(stderr, "Unsupported audio channel count: %d\n", channels);
        return false;
    }

    AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc]
        initWithPCMFormat:audioFormat
        frameCapacity:(AVAudioFrameCount)frame->nb_samples
    ];
    if (buffer == nil || buffer.floatChannelData == NULL) {
        fprintf(stderr, "Could not allocate AVAudioPCMBuffer.\n");
        return false;
    }

    buffer.frameLength = (AVAudioFrameCount)frame->nb_samples;
    for (int channel = 0; channel < channels; channel++) {
        memcpy(
            buffer.floatChannelData[channel],
            frame->extended_data[channel],
            sizeof(float) * (size_t)frame->nb_samples
        );
    }

    [audioPlayer scheduleBuffer:buffer completionHandler:nil];
    return true;
}

static int receive_available_audio_frames(
    AudioDecodeContext *audio,
    AVStream *audioStream,
    AVAudioPlayerNode *audioPlayer,
    AVAudioFormat *audioFormat,
    bool hasSeek,
    double seekSeconds
) {
    int result = 0;
    while ((result = avcodec_receive_frame(audio->codecContext, audio->frame)) >= 0) {
        audio->decodedFrames++;

        if (hasSeek && frame_is_before_seek_target(audio->frame, audioStream, seekSeconds)) {
            audio->skippedBeforeSeek++;
            av_frame_unref(audio->frame);
            continue;
        }

        int outputFrames = audio->decodedFrames - audio->skippedBeforeSeek;
        if (outputFrames <= 5 || audio->decodedFrames % 50 == 0) {
            print_audio_frame(audio->frame, audioStream, audio->decodedFrames);
        }

        if (schedule_audio_frame(audio->frame, audioPlayer, audioFormat)) {
            audio->scheduledBuffers++;
        } else {
            audio->unsupportedFrames++;
        }

        av_frame_unref(audio->frame);
    }

    if (result == AVERROR(EAGAIN) || result == AVERROR_EOF) {
        return 0;
    }

    char error[AV_ERROR_MAX_STRING_SIZE] = {0};
    ffmpeg_error_string(result, error, sizeof(error));
    fprintf(stderr, "avcodec_receive_frame for audio failed: %s\n", error);
    audio->decodeFailures++;
    return 1;
}

static void flush_display_layer(AVSampleBufferDisplayLayer *displayLayer) {
    if (displayLayer == nil) {
        return;
    }

    void (^flushBlock)(void) = ^{
        [displayLayer flushAndRemoveImage];
    };

    if ([NSThread isMainThread]) {
        flushBlock();
    } else {
        dispatch_sync(dispatch_get_main_queue(), flushBlock);
    }
}

static void reset_audio_output(AVAudioPlayerNode *audioPlayer) {
    if (audioPlayer == nil) {
        return;
    }

    [audioPlayer stop];
    [audioPlayer play];
}

static int seek_input_to_seconds(
    ProbeRunContext context,
    AVCodecContext *videoCodecContext,
    AudioDecodeContext *audio,
    VideoPacer *videoPacer
) {
    if (!context.hasSeek) {
        return 0;
    }

    AVStream *videoStream = context.formatContext->streams[context.videoStreamIndex];
    int64_t seekTimestamp = timestamp_for_seek_seconds(context.seekSeconds, videoStream);

    printf(
        "Seek target: %.3fs, video stream timestamp=%lld\n",
        context.seekSeconds,
        (long long)seekTimestamp
    );

    int result = av_seek_frame(
        context.formatContext,
        context.videoStreamIndex,
        seekTimestamp,
        AVSEEK_FLAG_BACKWARD
    );
    if (result < 0) {
        char error[AV_ERROR_MAX_STRING_SIZE] = {0};
        ffmpeg_error_string(result, error, sizeof(error));
        fprintf(stderr, "av_seek_frame failed: %s\n", error);
        return 1;
    }

    avcodec_flush_buffers(videoCodecContext);
    if (audio != NULL) {
        avcodec_flush_buffers(audio->codecContext);
    }

    flush_display_layer(context.displayLayer);
    reset_audio_output(context.audioPlayer);

    if (videoPacer != NULL) {
        *videoPacer = (VideoPacer){0};
    }

    return 0;
}

static CMSampleBufferRef create_sample_buffer_for_pixel_buffer(
    CVPixelBufferRef pixelBuffer,
    CMTime presentationTime
) {
    CMVideoFormatDescriptionRef formatDescription = NULL;
    OSStatus status = CMVideoFormatDescriptionCreateForImageBuffer(
        kCFAllocatorDefault,
        pixelBuffer,
        &formatDescription
    );
    if (status != noErr || formatDescription == NULL) {
        fprintf(stderr, "CMVideoFormatDescriptionCreateForImageBuffer failed: %d\n", (int)status);
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
        fprintf(stderr, "CMSampleBufferCreateReadyWithImageBuffer failed: %d\n", (int)status);
        return NULL;
    }

    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    if (attachments != NULL && CFArrayGetCount(attachments) > 0) {
        CFMutableDictionaryRef attachment = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFDictionarySetValue(attachment, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
    }

    return sampleBuffer;
}

static void enqueue_pixel_buffer_for_display(
    AVSampleBufferDisplayLayer *displayLayer,
    CVPixelBufferRef pixelBuffer,
    CMTime presentationTime
) {
    if (displayLayer == nil || pixelBuffer == NULL) {
        return;
    }

    CVPixelBufferRetain(pixelBuffer);
    dispatch_async(dispatch_get_main_queue(), ^{
        CMSampleBufferRef sampleBuffer = create_sample_buffer_for_pixel_buffer(
            pixelBuffer,
            presentationTime
        );

        if (sampleBuffer != NULL) {
            if (displayLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
                [displayLayer flush];
            }
            [displayLayer enqueueSampleBuffer:sampleBuffer];
            CFRelease(sampleBuffer);
        }

        CVPixelBufferRelease(pixelBuffer);
    });
}

static int receive_available_frames(
    AVCodecContext *codecContext,
    AVStream *videoStream,
    AVFrame *frame,
    int *decodedFrames,
    int *hardwareFrames,
    int *softwareFrames,
    bool displayFrames,
    AVSampleBufferDisplayLayer *displayLayer,
    VideoPacer *videoPacer,
    bool hasSeek,
    double seekSeconds,
    int *skippedVideoFrames,
    int *outputVideoFrames,
    int maxOutputFrames
) {
    int result = 0;
    while ((result = avcodec_receive_frame(codecContext, frame)) >= 0) {
        (*decodedFrames)++;

        if (frame->format == hardwarePixelFormat) {
            (*hardwareFrames)++;
        } else {
            (*softwareFrames)++;
        }

        if (hasSeek && frame_is_before_seek_target(frame, videoStream, seekSeconds)) {
            if (skippedVideoFrames != NULL) {
                (*skippedVideoFrames)++;
            }
            av_frame_unref(frame);
            continue;
        }

        if (outputVideoFrames != NULL) {
            (*outputVideoFrames)++;
        }

        int outputFrames = outputVideoFrames != NULL ? *outputVideoFrames : *decodedFrames;
        bool shouldPrint = outputFrames <= 5 || *decodedFrames % 60 == 0;
        if (frame->format == hardwarePixelFormat) {
            if (displayFrames) {
                pace_video_frame(videoPacer, frame, videoStream);
                CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)frame->data[3];
                enqueue_pixel_buffer_for_display(
                    displayLayer,
                    pixelBuffer,
                    cm_time_from_frame(frame, videoStream)
                );
            }

            if (shouldPrint) {
                print_frame(frame, videoStream, *decodedFrames);
            }
        } else {
            if (shouldPrint) {
                print_frame(frame, videoStream, *decodedFrames);
            }
        }

        av_frame_unref(frame);

        if (maxOutputFrames > 0 && outputFrames >= maxOutputFrames) {
            return receiveFramesOutputLimit;
        }
    }

    if (result == AVERROR(EAGAIN) || result == AVERROR_EOF) {
        return receiveFramesOK;
    }

    char error[AV_ERROR_MAX_STRING_SIZE] = {0};
    ffmpeg_error_string(result, error, sizeof(error));
    fprintf(stderr, "avcodec_receive_frame failed: %s\n", error);
    return receiveFramesError;
}

static int run_videotoolbox_decode_probe(ProbeRunContext context) {
    AVStream *videoStream = context.formatContext->streams[context.videoStreamIndex];
    AVStream *audioStream = context.audioStreamIndex >= 0
        ? context.formatContext->streams[context.audioStreamIndex]
        : NULL;
    AudioDecodeContext *audio = context.audioStreamIndex >= 0
        ? create_audio_decode_context(context.formatContext, context.audioStreamIndex)
        : NULL;
    AVCodecParameters *codecParameters = videoStream->codecpar;
    const AVCodec *decoder = avcodec_find_decoder(codecParameters->codec_id);
    if (decoder == NULL) {
        fprintf(stderr, "No FFmpeg decoder found for %s.\n", codec_name(codecParameters->codec_id));
        return 1;
    }

    const AVCodecHWConfig *hardwareConfig = find_videotoolbox_config(decoder);
    if (hardwareConfig == NULL) {
        fprintf(stderr, "Decoder %s does not expose a VideoToolbox config.\n", decoder->name);
        return 1;
    }

    hardwarePixelFormat = hardwareConfig->pix_fmt;
    printf(
        "FFmpeg decoder: %s, VideoToolbox pixel format: %s\n",
        decoder->name,
        av_get_pix_fmt_name(hardwarePixelFormat)
    );

    AVBufferRef *hardwareDeviceContext = NULL;
    int result = av_hwdevice_ctx_create(
        &hardwareDeviceContext,
        AV_HWDEVICE_TYPE_VIDEOTOOLBOX,
        NULL,
        NULL,
        0
    );
    if (result < 0) {
        char error[AV_ERROR_MAX_STRING_SIZE] = {0};
        ffmpeg_error_string(result, error, sizeof(error));
        fprintf(stderr, "av_hwdevice_ctx_create failed: %s\n", error);
        return 1;
    }

    AVCodecContext *codecContext = avcodec_alloc_context3(decoder);
    if (codecContext == NULL) {
        fprintf(stderr, "avcodec_alloc_context3 failed.\n");
        av_buffer_unref(&hardwareDeviceContext);
        return 1;
    }

    result = avcodec_parameters_to_context(codecContext, codecParameters);
    if (result < 0) {
        char error[AV_ERROR_MAX_STRING_SIZE] = {0};
        ffmpeg_error_string(result, error, sizeof(error));
        fprintf(stderr, "avcodec_parameters_to_context failed: %s\n", error);
        avcodec_free_context(&codecContext);
        av_buffer_unref(&hardwareDeviceContext);
        return 1;
    }

    codecContext->get_format = choose_hardware_format;
    codecContext->hw_device_ctx = av_buffer_ref(hardwareDeviceContext);
    if (codecContext->hw_device_ctx == NULL) {
        fprintf(stderr, "av_buffer_ref for hardware device failed.\n");
        avcodec_free_context(&codecContext);
        av_buffer_unref(&hardwareDeviceContext);
        return 1;
    }

    result = avcodec_open2(codecContext, decoder, NULL);
    if (result < 0) {
        char error[AV_ERROR_MAX_STRING_SIZE] = {0};
        ffmpeg_error_string(result, error, sizeof(error));
        fprintf(stderr, "avcodec_open2 failed: %s\n", error);
        avcodec_free_context(&codecContext);
        av_buffer_unref(&hardwareDeviceContext);
        return 1;
    }

    AVPacket *packet = av_packet_alloc();
    AVFrame *frame = av_frame_alloc();
    if (packet == NULL || frame == NULL) {
        fprintf(stderr, "Could not allocate packet or frame.\n");
        av_packet_free(&packet);
        av_frame_free(&frame);
        avcodec_free_context(&codecContext);
        av_buffer_unref(&hardwareDeviceContext);
        return 1;
    }

    int fedPackets = 0;
    int decodedFrames = 0;
    int hardwareFrames = 0;
    int softwareFrames = 0;
    int sendFailures = 0;
    int audioPackets = 0;
    int skippedVideoFrames = 0;
    int outputVideoFrames = 0;
    bool reachedEndOfInput = false;
    bool hitPrerollPacketLimit = false;
    bool decodeFailed = false;
    VideoPacer videoPacer = {0};

    if (seek_input_to_seconds(context, codecContext, audio, &videoPacer) != 0) {
        av_packet_free(&packet);
        av_frame_free(&frame);
        avcodec_free_context(&codecContext);
        av_buffer_unref(&hardwareDeviceContext);
        destroy_audio_decode_context(audio);
        return 1;
    }

    while (outputVideoFrames < context.maxOutputFrames) {
        if (context.hasSeek
            && outputVideoFrames == 0
            && fedPackets >= context.seekPrerollPacketLimit) {
            hitPrerollPacketLimit = true;
            fprintf(
                stderr,
                "Seek preroll packet limit reached before producing an output video frame.\n"
            );
            break;
        }

        result = av_read_frame(context.formatContext, packet);
        if (result < 0) {
            reachedEndOfInput = true;
            break;
        }

        if (packet->stream_index == context.audioStreamIndex && audio != NULL) {
            result = avcodec_send_packet(audio->codecContext, packet);
            av_packet_unref(packet);

            if (result < 0) {
                char error[AV_ERROR_MAX_STRING_SIZE] = {0};
                ffmpeg_error_string(result, error, sizeof(error));
                fprintf(stderr, "avcodec_send_packet for audio failed: %s\n", error);
                audio->decodeFailures++;
                continue;
            }

            audioPackets++;
            (void)receive_available_audio_frames(
                audio,
                audioStream,
                context.audioPlayer,
                context.audioFormat,
                context.hasSeek,
                context.seekSeconds
            );
            continue;
        }

        if (packet->stream_index != context.videoStreamIndex) {
            av_packet_unref(packet);
            continue;
        }

        result = avcodec_send_packet(codecContext, packet);
        av_packet_unref(packet);

        if (result < 0) {
            char error[AV_ERROR_MAX_STRING_SIZE] = {0};
            ffmpeg_error_string(result, error, sizeof(error));
            fprintf(stderr, "avcodec_send_packet failed: %s\n", error);
            sendFailures++;
            continue;
        }

        fedPackets++;
        int receiveResult = receive_available_frames(
            codecContext,
            videoStream,
            frame,
            &decodedFrames,
            &hardwareFrames,
            &softwareFrames,
            context.displayFrames,
            context.displayLayer,
            &videoPacer,
            context.hasSeek,
            context.seekSeconds,
            &skippedVideoFrames,
            &outputVideoFrames,
            context.maxOutputFrames
        );
        if (receiveResult == receiveFramesOutputLimit) {
            break;
        }
        if (receiveResult != receiveFramesOK) {
            decodeFailed = true;
            break;
        }
    }

    if (reachedEndOfInput && !decodeFailed && !hitPrerollPacketLimit) {
        avcodec_send_packet(codecContext, NULL);
        (void)receive_available_frames(
            codecContext,
            videoStream,
            frame,
            &decodedFrames,
            &hardwareFrames,
            &softwareFrames,
            context.displayFrames,
            context.displayLayer,
            &videoPacer,
            context.hasSeek,
            context.seekSeconds,
            &skippedVideoFrames,
            &outputVideoFrames,
            context.maxOutputFrames
        );
    }

    if (reachedEndOfInput && audio != NULL && !hitPrerollPacketLimit) {
        avcodec_send_packet(audio->codecContext, NULL);
        (void)receive_available_audio_frames(
            audio,
            audioStream,
            context.audioPlayer,
            context.audioFormat,
            context.hasSeek,
            context.seekSeconds
        );
    }

    printf("Video packets fed: %d\n", fedPackets);
    printf("Packet send failures: %d\n", sendFailures);
    printf("Decoded frames: %d\n", decodedFrames);
    printf("Hardware frames: %d\n", hardwareFrames);
    printf("Software frames: %d\n", softwareFrames);
    printf("Output video frames: %d\n", outputVideoFrames);
    if (context.hasSeek) {
        printf("Seek target: %.3fs\n", context.seekSeconds);
        printf("Skipped video frames before seek target: %d\n", skippedVideoFrames);
        printf("Seek preroll packet limit: %d\n", context.seekPrerollPacketLimit);
    }
    if (context.displayFrames) {
        printf("Paced video frames: %d\n", videoPacer.pacedFrames);
        printf("Late video frames: %d\n", videoPacer.lateFrames);
        printf("Max video wait: %.3fs\n", videoPacer.maxWaitSeconds);
        printf("Max video lateness: %.3fs\n", videoPacer.maxLatenessSeconds);
    }
    if (audio != NULL) {
        printf("Audio packets fed: %d\n", audioPackets);
        printf("Decoded audio frames: %d\n", audio->decodedFrames);
        printf("Scheduled audio buffers: %d\n", audio->scheduledBuffers);
        if (context.hasSeek) {
            printf("Skipped audio frames before seek target: %d\n", audio->skippedBeforeSeek);
        }
        printf("Unsupported audio frames: %d\n", audio->unsupportedFrames);
        printf("Audio decode failures: %d\n", audio->decodeFailures);
    }

    av_packet_free(&packet);
    av_frame_free(&frame);
    avcodec_free_context(&codecContext);
    av_buffer_unref(&hardwareDeviceContext);
    destroy_audio_decode_context(audio);

    return !decodeFailed && !hitPrerollPacketLimit && outputVideoFrames > 0 ? 0 : 1;
}

static int open_input(
    const char *path,
    AVFormatContext **formatContext,
    int *videoStreamIndex,
    int *audioStreamIndex
) {
    int result = avformat_open_input(formatContext, path, NULL, NULL);
    if (result < 0) {
        char error[AV_ERROR_MAX_STRING_SIZE] = {0};
        ffmpeg_error_string(result, error, sizeof(error));
        fprintf(stderr, "avformat_open_input failed: %s\n", error);
        return 1;
    }

    result = avformat_find_stream_info(*formatContext, NULL);
    if (result < 0) {
        char error[AV_ERROR_MAX_STRING_SIZE] = {0};
        ffmpeg_error_string(result, error, sizeof(error));
        fprintf(stderr, "avformat_find_stream_info failed: %s\n", error);
        avformat_close_input(formatContext);
        return 1;
    }

    *videoStreamIndex = -1;
    *audioStreamIndex = -1;
    for (unsigned int index = 0; index < (*formatContext)->nb_streams; index++) {
        AVStream *stream = (*formatContext)->streams[index];
        if (*videoStreamIndex < 0 && stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            *videoStreamIndex = (int)index;
        } else if (*audioStreamIndex < 0 && stream->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            *audioStreamIndex = (int)index;
        }
    }

    if (*videoStreamIndex < 0) {
        fprintf(stderr, "No video stream found.\n");
        avformat_close_input(formatContext);
        return 1;
    }

    AVStream *videoStream = (*formatContext)->streams[*videoStreamIndex];
    AVCodecParameters *codecParameters = videoStream->codecpar;

    printf("Input: %s\n", path);
    printf("Container: %s\n", (*formatContext)->iformat ? (*formatContext)->iformat->name : "unknown");
    printf(
        "Video stream: #%d %s %dx%d, time_base=%d/%d, extradata=%d bytes\n",
        *videoStreamIndex,
        codec_name(codecParameters->codec_id),
        codecParameters->width,
        codecParameters->height,
        videoStream->time_base.num,
        videoStream->time_base.den,
        codecParameters->extradata_size
    );

    if (*audioStreamIndex >= 0) {
        AVStream *audioStream = (*formatContext)->streams[*audioStreamIndex];
        AVCodecParameters *audioParameters = audioStream->codecpar;
        printf(
            "Audio stream: #%d %s, sample_rate=%d, channels=%d, time_base=%d/%d\n",
            *audioStreamIndex,
            codec_name(audioParameters->codec_id),
            audioParameters->sample_rate,
            audioParameters->ch_layout.nb_channels,
            audioStream->time_base.num,
            audioStream->time_base.den
        );
    }

    return 0;
}

static AVSampleBufferDisplayLayer *make_display_layer(NSWindow **windowOut) {
    NSRect frame = NSMakeRect(0, 0, 960, 540);
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:frame
        styleMask:NSWindowStyleMaskTitled
            | NSWindowStyleMaskClosable
            | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered
        defer:NO
    ];
    [window setTitle:@"Native Playback Probe"];
    [window center];

    NSView *contentView = [window contentView];
    [contentView setWantsLayer:YES];
    contentView.layer.backgroundColor = NSColor.blackColor.CGColor;

    AVSampleBufferDisplayLayer *displayLayer = [AVSampleBufferDisplayLayer layer];
    displayLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    displayLayer.backgroundColor = NSColor.blackColor.CGColor;
    displayLayer.frame = contentView.bounds;
    displayLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
    [contentView.layer addSublayer:displayLayer];

    [window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];

    *windowOut = window;
    return displayLayer;
}

static bool make_audio_output(
    int sampleRate,
    int channels,
    AVAudioEngine **engineOut,
    AVAudioPlayerNode **playerOut,
    AVAudioFormat **formatOut
) {
    if (sampleRate <= 0 || channels <= 0) {
        return false;
    }

    AVAudioEngine *engine = [[AVAudioEngine alloc] init];
    AVAudioPlayerNode *player = [[AVAudioPlayerNode alloc] init];
    AVAudioFormat *format = [[AVAudioFormat alloc]
        initStandardFormatWithSampleRate:(double)sampleRate
        channels:(AVAudioChannelCount)channels
    ];

    if (engine == nil || player == nil || format == nil) {
        return false;
    }

    [engine attachNode:player];
    [engine connect:player to:engine.mainMixerNode format:format];

    NSError *error = nil;
    if (![engine startAndReturnError:&error]) {
        fprintf(
            stderr,
            "AVAudioEngine start failed: %s\n",
            error.localizedDescription.UTF8String
        );
        return false;
    }

    [player play];

    *engineOut = engine;
    *playerOut = player;
    *formatOut = format;

    printf("Audio output: AVAudioEngine %.0f Hz, channels=%u\n", format.sampleRate, format.channelCount);
    return true;
}

static int run_console_probe(
    const char *path,
    int maxOutputFrames,
    bool hasSeek,
    double seekSeconds
) {
    __block AVFormatContext *formatContext = NULL;
    int videoStreamIndex = -1;
    int audioStreamIndex = -1;
    if (open_input(path, &formatContext, &videoStreamIndex, &audioStreamIndex) != 0) {
        return 1;
    }

    ProbeRunContext context = {
        .formatContext = formatContext,
        .videoStreamIndex = videoStreamIndex,
        .audioStreamIndex = -1,
        .maxOutputFrames = maxOutputFrames,
        .seekPrerollPacketLimit = defaultSeekPrerollPacketLimit,
        .hasSeek = hasSeek,
        .seekSeconds = seekSeconds,
        .displayFrames = false,
        .displayLayer = nil,
        .audioEngine = nil,
        .audioPlayer = nil,
        .audioFormat = nil
    };
    int probeResult = run_videotoolbox_decode_probe(context);
    avformat_close_input(&formatContext);
    return probeResult;
}

static int run_display_probe(
    const char *path,
    int maxOutputFrames,
    bool hasSeek,
    double seekSeconds
) {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    __block AVFormatContext *formatContext = NULL;
    int videoStreamIndex = -1;
    int audioStreamIndex = -1;
    if (open_input(path, &formatContext, &videoStreamIndex, &audioStreamIndex) != 0) {
        return 1;
    }

    NSWindow *window = nil;
    AVSampleBufferDisplayLayer *displayLayer = make_display_layer(&window);
    AVAudioEngine *audioEngine = nil;
    AVAudioPlayerNode *audioPlayer = nil;
    AVAudioFormat *audioFormat = nil;

    if (audioStreamIndex >= 0) {
        AVCodecParameters *audioParameters = formatContext->streams[audioStreamIndex]->codecpar;
        if (!make_audio_output(
            audioParameters->sample_rate,
            audioParameters->ch_layout.nb_channels,
            &audioEngine,
            &audioPlayer,
            &audioFormat
        )) {
            fprintf(stderr, "Audio output unavailable; continuing video-only.\n");
            audioStreamIndex = -1;
        }
    }

    __block int probeResult = 1;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        ProbeRunContext context = {
            .formatContext = formatContext,
            .videoStreamIndex = videoStreamIndex,
            .audioStreamIndex = audioStreamIndex,
            .maxOutputFrames = maxOutputFrames,
            .seekPrerollPacketLimit = defaultSeekPrerollPacketLimit,
            .hasSeek = hasSeek,
            .seekSeconds = seekSeconds,
            .displayFrames = true,
            .displayLayer = displayLayer,
            .audioEngine = audioEngine,
            .audioPlayer = audioPlayer,
            .audioFormat = audioFormat
        };
        probeResult = run_videotoolbox_decode_probe(context);

        dispatch_async(dispatch_get_main_queue(), ^{
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                dispatch_get_main_queue(),
                ^{
                    [audioPlayer stop];
                    [audioEngine stop];
                    avformat_close_input(&formatContext);
                    [window close];
                    [NSApp terminate:nil];
                }
            );
        });
    });

    [NSApp run];
    return probeResult;
}

static bool parse_nonnegative_seconds(const char *value, double *secondsOut) {
    errno = 0;
    char *end = NULL;
    double seconds = strtod(value, &end);
    if (errno != 0 || end == value || *end != '\0' || !isfinite(seconds) || seconds < 0) {
        return false;
    }

    *secondsOut = seconds;
    return true;
}

static void print_usage(void) {
    fprintf(
        stderr,
        "Usage: NativePlaybackProbe [--display] [--seek seconds] <media-file> [max-output-video-frames]\n"
    );
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc < 2) {
            print_usage();
            return 2;
        }

        bool displayFrames = false;
        bool hasSeek = false;
        double seekSeconds = 0;
        int argumentIndex = 1;

        while (argumentIndex < argc) {
            if (strcmp(argv[argumentIndex], "--display") == 0) {
                displayFrames = true;
                argumentIndex++;
                continue;
            }

            if (strcmp(argv[argumentIndex], "--seek") == 0) {
                if (argumentIndex + 1 >= argc
                    || !parse_nonnegative_seconds(argv[argumentIndex + 1], &seekSeconds)) {
                    fprintf(stderr, "Invalid --seek value.\n");
                    print_usage();
                    return 2;
                }

                hasSeek = true;
                argumentIndex += 2;
                continue;
            }

            break;
        }

        if (argumentIndex >= argc) {
            print_usage();
            return 2;
        }

        const char *path = argv[argumentIndex++];
        int maxOutputFrames = argumentIndex < argc
            ? atoi(argv[argumentIndex++])
            : defaultMaxOutputFrames;
        if (argumentIndex != argc) {
            print_usage();
            return 2;
        }
        if (maxOutputFrames <= 0) {
            maxOutputFrames = defaultMaxOutputFrames;
        }

        if (displayFrames) {
            return run_display_probe(path, maxOutputFrames, hasSeek, seekSeconds);
        }

        return run_console_probe(path, maxOutputFrames, hasSeek, seekSeconds);
    }
}
