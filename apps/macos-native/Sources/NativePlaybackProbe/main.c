#include <CoreVideo/CoreVideo.h>

#include <libavcodec/avcodec.h>
#include <libavcodec/packet.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libavutil/error.h>
#include <libavutil/hwcontext.h>
#include <libavutil/pixdesc.h>

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static enum AVPixelFormat hardwarePixelFormat = AV_PIX_FMT_NONE;

static const char *codec_name(enum AVCodecID codecID) {
    const char *name = avcodec_get_name(codecID);
    return name != NULL ? name : "unknown";
}

static void ffmpeg_error_string(int code, char *buffer, size_t bufferSize) {
    if (av_strerror(code, buffer, bufferSize) < 0) {
        snprintf(buffer, bufferSize, "FFmpeg error %d", code);
    }
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
    double seconds = frame->best_effort_timestamp == AV_NOPTS_VALUE
        ? -1
        : av_q2d(videoStream->time_base) * frame->best_effort_timestamp;
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

static int receive_available_frames(
    AVCodecContext *codecContext,
    AVStream *videoStream,
    AVFrame *frame,
    int *decodedFrames,
    int *hardwareFrames,
    int *softwareFrames
) {
    int result = 0;
    while ((result = avcodec_receive_frame(codecContext, frame)) >= 0) {
        (*decodedFrames)++;

        bool shouldPrint = *decodedFrames <= 5 || *decodedFrames % 60 == 0;
        if (frame->format == hardwarePixelFormat) {
            (*hardwareFrames)++;
            if (shouldPrint) {
                print_frame(frame, videoStream, *decodedFrames);
            }
        } else {
            (*softwareFrames)++;
            if (shouldPrint) {
                print_frame(frame, videoStream, *decodedFrames);
            }
        }

        av_frame_unref(frame);
    }

    if (result == AVERROR(EAGAIN) || result == AVERROR_EOF) {
        return 0;
    }

    char error[AV_ERROR_MAX_STRING_SIZE] = {0};
    ffmpeg_error_string(result, error, sizeof(error));
    fprintf(stderr, "avcodec_receive_frame failed: %s\n", error);
    return 1;
}

static int run_videotoolbox_decode_probe(
    AVFormatContext *formatContext,
    int videoStreamIndex,
    int maxPackets
) {
    AVStream *videoStream = formatContext->streams[videoStreamIndex];
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

    while (fedPackets < maxPackets && av_read_frame(formatContext, packet) >= 0) {
        if (packet->stream_index != videoStreamIndex) {
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
        if (receive_available_frames(
            codecContext,
            videoStream,
            frame,
            &decodedFrames,
            &hardwareFrames,
            &softwareFrames
        ) != 0) {
            break;
        }
    }

    avcodec_send_packet(codecContext, NULL);
    (void)receive_available_frames(
        codecContext,
        videoStream,
        frame,
        &decodedFrames,
        &hardwareFrames,
        &softwareFrames
    );

    printf("Video packets fed: %d\n", fedPackets);
    printf("Packet send failures: %d\n", sendFailures);
    printf("Decoded frames: %d\n", decodedFrames);
    printf("Hardware frames: %d\n", hardwareFrames);
    printf("Software frames: %d\n", softwareFrames);

    av_packet_free(&packet);
    av_frame_free(&frame);
    avcodec_free_context(&codecContext);
    av_buffer_unref(&hardwareDeviceContext);

    return hardwareFrames > 0 ? 0 : 1;
}

int main(int argc, char **argv) {
    if (argc < 2 || argc > 3) {
        fprintf(stderr, "Usage: NativePlaybackProbe <media-file> [max-video-packets]\n");
        return 2;
    }

    const char *path = argv[1];
    int maxPackets = argc == 3 ? atoi(argv[2]) : 300;
    if (maxPackets <= 0) {
        maxPackets = 300;
    }

    AVFormatContext *formatContext = NULL;
    int result = avformat_open_input(&formatContext, path, NULL, NULL);
    if (result < 0) {
        char error[AV_ERROR_MAX_STRING_SIZE] = {0};
        ffmpeg_error_string(result, error, sizeof(error));
        fprintf(stderr, "avformat_open_input failed: %s\n", error);
        return 1;
    }

    result = avformat_find_stream_info(formatContext, NULL);
    if (result < 0) {
        char error[AV_ERROR_MAX_STRING_SIZE] = {0};
        ffmpeg_error_string(result, error, sizeof(error));
        fprintf(stderr, "avformat_find_stream_info failed: %s\n", error);
        avformat_close_input(&formatContext);
        return 1;
    }

    int videoStreamIndex = -1;
    for (unsigned int index = 0; index < formatContext->nb_streams; index++) {
        AVStream *stream = formatContext->streams[index];
        if (stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            videoStreamIndex = (int)index;
            break;
        }
    }

    if (videoStreamIndex < 0) {
        fprintf(stderr, "No video stream found.\n");
        avformat_close_input(&formatContext);
        return 1;
    }

    AVStream *videoStream = formatContext->streams[videoStreamIndex];
    AVCodecParameters *codecParameters = videoStream->codecpar;

    printf("Input: %s\n", path);
    printf("Container: %s\n", formatContext->iformat ? formatContext->iformat->name : "unknown");
    printf(
        "Video stream: #%d %s %dx%d, time_base=%d/%d, extradata=%d bytes\n",
        videoStreamIndex,
        codec_name(codecParameters->codec_id),
        codecParameters->width,
        codecParameters->height,
        videoStream->time_base.num,
        videoStream->time_base.den,
        codecParameters->extradata_size
    );

    int probeResult = run_videotoolbox_decode_probe(
        formatContext,
        videoStreamIndex,
        maxPackets
    );
    avformat_close_input(&formatContext);

    return probeResult;
}
