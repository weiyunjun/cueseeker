#import <AppKit/AppKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>
#import <dispatch/dispatch.h>

#include <libavcodec/avcodec.h>
#include <libavcodec/packet.h>
#include <libavformat/avformat.h>
#include <libavutil/channel_layout.h>
#include <libavutil/dict.h>
#include <libavutil/avutil.h>
#include <libavutil/error.h>
#include <libavutil/hwcontext.h>
#include <libavutil/mathematics.h>
#include <libavutil/pixdesc.h>
#include <libswresample/swresample.h>

#include <errno.h>
#include <limits.h>
#include <mach/mach.h>
#include <math.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MAX_SEEK_TARGETS 128

typedef struct {
    AVFormatContext *formatContext;
    int videoStreamIndex;
    int audioStreamIndex;
    int requestedAudioStreamIndex;
    int audioOutputSampleRate;
    int audioOutputChannels;
    int maxOutputFrames;
    int seekPrerollPacketLimit;
    bool hasSeek;
    double seekSeconds;
    bool hasSeekAgain;
    double seekAgainSeconds;
    int seekTargetCount;
    int seekListLoops;
    double seekTargets[MAX_SEEK_TARGETS];
    int pauseAfterOutputFrames;
    double pauseDurationSeconds;
    double runDurationSeconds;
    double memorySampleIntervalSeconds;
    bool quietOutput;
    bool displayFrames;
    AVSampleBufferDisplayLayer *__unsafe_unretained displayLayer;
    AVAudioEngine *__unsafe_unretained audioEngine;
    AVAudioPlayerNode *__unsafe_unretained audioPlayer;
    AVAudioFormat *__unsafe_unretained audioFormat;
} ProbeRunContext;

typedef struct {
    AVCodecContext *codecContext;
    AVFrame *frame;
    AVFrame *convertedFrame;
    struct SwrContext *resampler;
    int decodedFrames;
    int scheduledBuffers;
    int skippedBeforeSeek;
    int unsupportedFrames;
    int decodeFailures;
    int conversionFailures;
    int passthroughFrames;
    int convertedFrames;
    int sampleRate;
    int channels;
    int outputSampleRate;
    int outputChannels;
    int resamplerInputSampleRate;
    int resamplerInputChannels;
    enum AVSampleFormat resamplerInputFormat;
    enum AVSampleFormat outputSampleFormat;
    AVChannelLayout outputLayout;
    bool resamplerInitialized;
    bool outputUsesDownmix;
    bool outputUsesFormatConversion;
    bool outputUsesSampleRateConversion;
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

typedef struct {
    bool enabled;
    bool initialized;
    bool startedPlayer;
    double firstMediaSeconds;
    double startHostSeconds;
    int pacedVideoFrames;
    int videoClockPacedFrames;
    double maxWaitSeconds;
    double maxLatenessSeconds;
} AudioClock;

typedef struct {
    bool enabled;
    bool triggered;
    int pauseAfterOutputFrames;
    double durationSeconds;
    int completedPauses;
} PauseProbe;

typedef struct {
    bool enabled;
    bool started;
    bool expired;
    double durationSeconds;
    double startHostSeconds;
} RunDurationLimit;

typedef struct {
    double rssMB;
    double footprintMB;
    double virtualMB;
} ProcessMemorySnapshot;

typedef struct {
    bool enabled;
    bool started;
    double sampleIntervalSeconds;
    double startHostSeconds;
    double lastSampleHostSeconds;
    int samples;
    double firstRssMB;
    double firstFootprintMB;
    double lastRssMB;
    double lastFootprintMB;
    double maxRssMB;
    double maxFootprintMB;
} MemoryProbe;

typedef struct {
    bool videoNativeCandidate;
    bool hasSelectedAudioStream;
    bool audioOutputCandidate;
    bool fullNativeCandidate;
    bool nativeUnsupported;
} NativeCapabilityReport;

static enum AVPixelFormat hardwarePixelFormat = AV_PIX_FMT_NONE;
static const int defaultMaxOutputFrames = 300;
static const int defaultSeekPrerollPacketLimit = 3000;
static const int receiveFramesOK = 0;
static const int receiveFramesError = 1;
static const int receiveFramesOutputLimit = 2;
static const int receiveFramesRunDurationLimit = 3;
static const int receiveFramesInterrupted = 4;

static volatile sig_atomic_t receivedInterrupt = 0;

static void handle_interrupt_signal(int signalNumber) {
    (void)signalNumber;
    receivedInterrupt = 1;
}

static void install_interrupt_handler(void) {
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_handler = handle_interrupt_signal;
    sigemptyset(&action.sa_mask);
    sigaction(SIGINT, &action, NULL);
    sigaction(SIGTERM, &action, NULL);
}

static bool should_stop_for_interrupt(void) {
    return receivedInterrupt != 0;
}

static const char *codec_name(enum AVCodecID codecID) {
    const char *name = avcodec_get_name(codecID);
    return name != NULL ? name : "unknown";
}

static const char *stream_metadata_value(AVStream *stream, const char *key) {
    if (stream == NULL || key == NULL) {
        return NULL;
    }

    AVDictionaryEntry *entry = av_dict_get(stream->metadata, key, NULL, 0);
    return entry != NULL ? entry->value : NULL;
}

static const char *text_or_dash(const char *value) {
    return value != NULL && value[0] != '\0' ? value : "-";
}

static const char *yes_no(bool value) {
    return value ? "yes" : "no";
}

static void describe_channel_layout(
    const AVChannelLayout *layout,
    int channelCountForDescription,
    char *buffer,
    size_t bufferSize
) {
    if (buffer == NULL || bufferSize == 0) {
        return;
    }

    buffer[0] = '\0';
    if (layout != NULL && layout->nb_channels > 0) {
        if (av_channel_layout_describe(layout, buffer, bufferSize) >= 0 && buffer[0] != '\0') {
            return;
        }
        channelCountForDescription = layout->nb_channels;
    }

    if (channelCountForDescription > 0) {
        snprintf(buffer, bufferSize, "%d channel%s", channelCountForDescription, channelCountForDescription == 1 ? "" : "s");
    } else {
        snprintf(buffer, bufferSize, "unknown");
    }
}

static int audio_output_channel_count(int inputChannels) {
    if (inputChannels <= 0) {
        return 0;
    }

    return inputChannels > 2 ? 2 : inputChannels;
}

static int positive_or_default(int value, int defaultValue) {
    return value > 0 ? value : defaultValue;
}

static void ffmpeg_error_string(int code, char *buffer, size_t bufferSize) {
    if (av_strerror(code, buffer, bufferSize) < 0) {
        snprintf(buffer, bufferSize, "FFmpeg error %d", code);
    }
}

static int open_media_input(AVFormatContext **formatContext, const char *path) {
    AVDictionary *options = NULL;
    av_dict_set(&options, "cueseeker_skip_internal_subtitles", "1", 0);
    int result = avformat_open_input(formatContext, path, NULL, &options);
    av_dict_free(&options);
    return result;
}

static double bytes_to_mb(uint64_t bytes) {
    return (double)bytes / (1024.0 * 1024.0);
}

static bool read_process_memory_snapshot(ProcessMemorySnapshot *snapshot) {
    if (snapshot == NULL) {
        return false;
    }

    task_vm_info_data_t info;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t result = task_info(
        mach_task_self(),
        TASK_VM_INFO,
        (task_info_t)&info,
        &count
    );
    if (result != KERN_SUCCESS) {
        fprintf(stderr, "task_info(TASK_VM_INFO) failed: %s\n", mach_error_string(result));
        return false;
    }

    snapshot->rssMB = bytes_to_mb(info.resident_size);
    snapshot->footprintMB = bytes_to_mb(info.phys_footprint);
    snapshot->virtualMB = bytes_to_mb(info.virtual_size);
    return true;
}

static void print_memory_sample(
    MemoryProbe *probe,
    int outputVideoFrames,
    const char *reason
) {
    if (probe == NULL || !probe->enabled) {
        return;
    }

    double now = CACurrentMediaTime();
    if (!probe->started) {
        probe->started = true;
        probe->startHostSeconds = now;
        probe->lastSampleHostSeconds = now;
    }

    ProcessMemorySnapshot snapshot = {0};
    if (!read_process_memory_snapshot(&snapshot)) {
        return;
    }

    if (probe->samples == 0) {
        probe->firstRssMB = snapshot.rssMB;
        probe->firstFootprintMB = snapshot.footprintMB;
        probe->maxRssMB = snapshot.rssMB;
        probe->maxFootprintMB = snapshot.footprintMB;
    }

    if (snapshot.rssMB > probe->maxRssMB) {
        probe->maxRssMB = snapshot.rssMB;
    }
    if (snapshot.footprintMB > probe->maxFootprintMB) {
        probe->maxFootprintMB = snapshot.footprintMB;
    }

    probe->lastRssMB = snapshot.rssMB;
    probe->lastFootprintMB = snapshot.footprintMB;
    probe->lastSampleHostSeconds = now;
    probe->samples++;

    printf(
        "Memory sample: reason=%s, elapsed=%.3fs, output_video_frames=%d, rss=%.1fMB, footprint=%.1fMB, virtual=%.1fMB\n",
        reason,
        now - probe->startHostSeconds,
        outputVideoFrames,
        snapshot.rssMB,
        snapshot.footprintMB,
        snapshot.virtualMB
    );
}

static void maybe_print_memory_sample(MemoryProbe *probe, int outputVideoFrames) {
    if (probe == NULL || !probe->enabled) {
        return;
    }

    if (!probe->started) {
        print_memory_sample(probe, outputVideoFrames, "start");
        return;
    }

    double now = CACurrentMediaTime();
    if (now - probe->lastSampleHostSeconds >= probe->sampleIntervalSeconds) {
        print_memory_sample(probe, outputVideoFrames, "periodic");
    }
}

static void print_memory_summary(MemoryProbe *probe, int outputVideoFrames) {
    if (probe == NULL || !probe->enabled) {
        return;
    }

    print_memory_sample(probe, outputVideoFrames, "end");
    if (probe->samples == 0) {
        return;
    }

    printf("Memory samples: %d\n", probe->samples);
    printf(
        "Memory RSS MB: start=%.1f, max=%.1f, end=%.1f, delta=%.1f\n",
        probe->firstRssMB,
        probe->maxRssMB,
        probe->lastRssMB,
        probe->lastRssMB - probe->firstRssMB
    );
    printf(
        "Memory footprint MB: start=%.1f, max=%.1f, end=%.1f, delta=%.1f\n",
        probe->firstFootprintMB,
        probe->maxFootprintMB,
        probe->lastFootprintMB,
        probe->lastFootprintMB - probe->firstFootprintMB
    );
}

static void start_run_duration_limit(RunDurationLimit *limit) {
    if (limit == NULL || !limit->enabled || limit->started) {
        return;
    }

    limit->started = true;
    limit->startHostSeconds = CACurrentMediaTime();
}

static bool run_duration_limit_reached(RunDurationLimit *limit) {
    if (limit == NULL || !limit->enabled || !limit->started) {
        return false;
    }

    if (CACurrentMediaTime() - limit->startHostSeconds >= limit->durationSeconds) {
        limit->expired = true;
        return true;
    }

    return false;
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

static const AVCodec *find_videotoolbox_decoder(
    enum AVCodecID codecID,
    const AVCodecHWConfig **hardwareConfig
) {
    const AVCodec *defaultDecoder = avcodec_find_decoder(codecID);
    if (defaultDecoder != NULL) {
        const AVCodecHWConfig *config = find_videotoolbox_config(defaultDecoder);
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

        const AVCodecHWConfig *config = find_videotoolbox_config(candidate);
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
    AudioClock *audioClock,
    const AVFrame *frame,
    AVStream *videoStream
) {
    if (pacer == NULL) {
        return;
    }

    double mediaSeconds = playback_seconds_from_frame(frame, videoStream);
    if (mediaSeconds < 0) {
        return;
    }

    double now = CACurrentMediaTime();
    if (audioClock != NULL && audioClock->enabled && audioClock->initialized) {
        double targetHostSeconds = audioClock->startHostSeconds
            + (mediaSeconds - audioClock->firstMediaSeconds);
        double waitSeconds = targetHostSeconds - now;

        if (waitSeconds > 0) {
            if (waitSeconds > pacer->maxWaitSeconds) {
                pacer->maxWaitSeconds = waitSeconds;
            }
            if (waitSeconds > audioClock->maxWaitSeconds) {
                audioClock->maxWaitSeconds = waitSeconds;
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
            if (latenessSeconds > audioClock->maxLatenessSeconds) {
                audioClock->maxLatenessSeconds = latenessSeconds;
            }
        }

        pacer->pacedFrames++;
        audioClock->pacedVideoFrames++;
        return;
    }

    if (audioClock != NULL && audioClock->enabled) {
        audioClock->videoClockPacedFrames++;
    }

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
    int audioStreamIndex,
    int outputSampleRate,
    int outputChannels
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
    audio->convertedFrame = av_frame_alloc();
    if (audio->codecContext == NULL || audio->frame == NULL || audio->convertedFrame == NULL) {
        fprintf(stderr, "Could not allocate audio decoder context.\n");
        avcodec_free_context(&audio->codecContext);
        av_frame_free(&audio->frame);
        av_frame_free(&audio->convertedFrame);
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
        av_frame_free(&audio->convertedFrame);
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
        av_frame_free(&audio->convertedFrame);
        free(audio);
        return NULL;
    }

    audio->sampleRate = audio->codecContext->sample_rate;
    audio->channels = audio->codecContext->ch_layout.nb_channels;
    audio->outputSampleRate = positive_or_default(outputSampleRate, audio->sampleRate);
    audio->outputChannels = audio_output_channel_count(outputChannels);
    audio->outputSampleFormat = AV_SAMPLE_FMT_FLTP;
    audio->resamplerInputFormat = AV_SAMPLE_FMT_NONE;
    if (audio->outputSampleRate <= 0) {
        audio->outputSampleRate = 48000;
    }
    if (audio->outputChannels <= 0) {
        audio->outputChannels = audio_output_channel_count(audio->channels);
    }
    if (audio->outputChannels <= 0) {
        fprintf(stderr, "Could not determine audio output channel count.\n");
        avcodec_free_context(&audio->codecContext);
        av_frame_free(&audio->frame);
        av_frame_free(&audio->convertedFrame);
        free(audio);
        return NULL;
    }
    av_channel_layout_default(&audio->outputLayout, audio->outputChannels);

    printf(
        "Audio decoder: %s, sample_rate=%d, channels=%d, output_sample_rate=%d, output_channels=%d\n",
        decoder->name,
        audio->sampleRate,
        audio->channels,
        audio->outputSampleRate,
        audio->outputChannels
    );

    return audio;
}

static void destroy_audio_decode_context(AudioDecodeContext *audio) {
    if (audio == NULL) {
        return;
    }

    swr_free(&audio->resampler);
    av_channel_layout_uninit(&audio->outputLayout);
    avcodec_free_context(&audio->codecContext);
    av_frame_free(&audio->frame);
    av_frame_free(&audio->convertedFrame);
    free(audio);
}

static int audio_frame_sample_rate(
    const AudioDecodeContext *audio,
    const AVFrame *frame
) {
    if (frame != NULL && frame->sample_rate > 0) {
        return frame->sample_rate;
    }

    if (audio != NULL && audio->sampleRate > 0) {
        return audio->sampleRate;
    }

    return audio != NULL && audio->outputSampleRate > 0 ? audio->outputSampleRate : 48000;
}

static int audio_frame_channel_count(
    const AudioDecodeContext *audio,
    const AVFrame *frame
) {
    if (frame != NULL && frame->ch_layout.nb_channels > 0) {
        return frame->ch_layout.nb_channels;
    }

    return audio != NULL ? audio->channels : 0;
}

static bool audio_frame_matches_output(
    const AudioDecodeContext *audio,
    const AVFrame *frame
) {
    if (audio == NULL || frame == NULL) {
        return false;
    }

    return frame->format == audio->outputSampleFormat
        && audio_frame_sample_rate(audio, frame) == audio->outputSampleRate
        && audio_frame_channel_count(audio, frame) == audio->outputChannels;
}

static bool ensure_audio_resampler(
    AudioDecodeContext *audio,
    const AVFrame *frame
) {
    if (audio == NULL || frame == NULL) {
        return false;
    }

    int inputSampleRate = audio_frame_sample_rate(audio, frame);
    int inputChannels = audio_frame_channel_count(audio, frame);
    enum AVSampleFormat inputFormat = (enum AVSampleFormat)frame->format;
    if (inputSampleRate <= 0 || inputChannels <= 0 || inputFormat == AV_SAMPLE_FMT_NONE) {
        fprintf(stderr, "Cannot configure audio resampler for incomplete input format.\n");
        return false;
    }

    if (audio->resamplerInitialized
        && audio->resamplerInputSampleRate == inputSampleRate
        && audio->resamplerInputChannels == inputChannels
        && audio->resamplerInputFormat == inputFormat) {
        return true;
    }

    swr_free(&audio->resampler);
    audio->resamplerInitialized = false;

    AVChannelLayout inputLayout = {0};
    bool ownsInputLayout = false;
    const AVChannelLayout *inputLayoutRef = &frame->ch_layout;
    if (frame->ch_layout.nb_channels <= 0) {
        av_channel_layout_default(&inputLayout, inputChannels);
        inputLayoutRef = &inputLayout;
        ownsInputLayout = true;
    }

    int result = swr_alloc_set_opts2(
        &audio->resampler,
        &audio->outputLayout,
        audio->outputSampleFormat,
        audio->outputSampleRate,
        inputLayoutRef,
        inputFormat,
        inputSampleRate,
        0,
        NULL
    );

    if (ownsInputLayout) {
        av_channel_layout_uninit(&inputLayout);
    }

    if (result < 0 || audio->resampler == NULL) {
        char error[AV_ERROR_MAX_STRING_SIZE] = {0};
        ffmpeg_error_string(result, error, sizeof(error));
        fprintf(stderr, "swr_alloc_set_opts2 failed: %s\n", error);
        swr_free(&audio->resampler);
        return false;
    }

    result = swr_init(audio->resampler);
    if (result < 0) {
        char error[AV_ERROR_MAX_STRING_SIZE] = {0};
        ffmpeg_error_string(result, error, sizeof(error));
        fprintf(stderr, "swr_init failed: %s\n", error);
        swr_free(&audio->resampler);
        return false;
    }

    audio->resamplerInitialized = true;
    audio->resamplerInputSampleRate = inputSampleRate;
    audio->resamplerInputChannels = inputChannels;
    audio->resamplerInputFormat = inputFormat;
    if (inputChannels != audio->outputChannels) {
        audio->outputUsesDownmix = true;
    }
    if (inputFormat != audio->outputSampleFormat) {
        audio->outputUsesFormatConversion = true;
    }
    if (inputSampleRate != audio->outputSampleRate) {
        audio->outputUsesSampleRateConversion = true;
    }

    char inputLayoutDescription[128] = {0};
    char outputLayoutDescription[128] = {0};
    describe_channel_layout(&frame->ch_layout, inputChannels, inputLayoutDescription, sizeof(inputLayoutDescription));
    describe_channel_layout(&audio->outputLayout, audio->outputChannels, outputLayoutDescription, sizeof(outputLayoutDescription));
    printf(
        "Audio resampler: input=%s/%s/%dHz, output=%s/fltp/%dHz\n",
        inputLayoutDescription,
        av_get_sample_fmt_name(inputFormat) != NULL ? av_get_sample_fmt_name(inputFormat) : "unknown",
        inputSampleRate,
        outputLayoutDescription,
        audio->outputSampleRate
    );

    return true;
}

static const AVFrame *audio_output_frame_for_schedule(
    AudioDecodeContext *audio,
    const AVFrame *frame
) {
    if (audio == NULL || frame == NULL) {
        return NULL;
    }

    if (audio_frame_matches_output(audio, frame)) {
        audio->passthroughFrames++;
        return frame;
    }

    if (!ensure_audio_resampler(audio, frame)) {
        audio->conversionFailures++;
        return NULL;
    }

    av_frame_unref(audio->convertedFrame);
    if (av_channel_layout_copy(&audio->convertedFrame->ch_layout, &audio->outputLayout) < 0) {
        fprintf(stderr, "av_channel_layout_copy failed for converted audio frame.\n");
        audio->conversionFailures++;
        return NULL;
    }

    int inputSampleRate = audio_frame_sample_rate(audio, frame);
    audio->convertedFrame->format = audio->outputSampleFormat;
    audio->convertedFrame->sample_rate = audio->outputSampleRate;
    audio->convertedFrame->nb_samples = (int)av_rescale_rnd(
        frame->nb_samples,
        audio->outputSampleRate,
        inputSampleRate,
        AV_ROUND_UP
    ) + 256;

    int result = swr_convert_frame(audio->resampler, audio->convertedFrame, frame);
    if (result < 0) {
        char error[AV_ERROR_MAX_STRING_SIZE] = {0};
        ffmpeg_error_string(result, error, sizeof(error));
        fprintf(stderr, "swr_convert_frame failed: %s\n", error);
        audio->conversionFailures++;
        av_frame_unref(audio->convertedFrame);
        return NULL;
    }

    audio->convertedFrames++;
    return audio->convertedFrame;
}

static bool schedule_audio_frame(
    const AVFrame *frame,
    AVAudioPlayerNode *audioPlayer,
    AVAudioFormat *audioFormat,
    double mediaSeconds,
    AudioClock *audioClock
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

    if (audioClock != NULL && audioClock->enabled && !audioClock->startedPlayer) {
        if (mediaSeconds >= 0 && !audioClock->initialized) {
            audioClock->initialized = true;
            audioClock->firstMediaSeconds = mediaSeconds;
            audioClock->startHostSeconds = CACurrentMediaTime();
        }

        audioClock->startedPlayer = true;
        [audioPlayer play];
    }

    return true;
}

static int receive_available_audio_frames(
    AudioDecodeContext *audio,
    AVStream *audioStream,
    AVAudioPlayerNode *audioPlayer,
    AVAudioFormat *audioFormat,
    AudioClock *audioClock,
    bool hasSeek,
    double seekSeconds,
    bool quietOutput
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
        if (!quietOutput && (outputFrames <= 5 || audio->decodedFrames % 50 == 0)) {
            print_audio_frame(audio->frame, audioStream, audio->decodedFrames);
        }

        double mediaSeconds = playback_seconds_from_frame(audio->frame, audioStream);
        const AVFrame *outputFrame = audio_output_frame_for_schedule(audio, audio->frame);
        if (outputFrame != NULL
            && schedule_audio_frame(outputFrame, audioPlayer, audioFormat, mediaSeconds, audioClock)) {
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
}

static void shift_playback_clocks(
    VideoPacer *videoPacer,
    AudioClock *audioClock,
    double shiftSeconds
) {
    if (videoPacer != NULL && videoPacer->initialized) {
        videoPacer->startHostSeconds += shiftSeconds;
    }
    if (audioClock != NULL && audioClock->initialized) {
        audioClock->startHostSeconds += shiftSeconds;
    }
}

static void pause_and_resume_probe_outputs(
    PauseProbe *pauseProbe,
    AVAudioPlayerNode *audioPlayer,
    VideoPacer *videoPacer,
    AudioClock *audioClock
) {
    if (pauseProbe == NULL || !pauseProbe->enabled || pauseProbe->triggered) {
        return;
    }

    pauseProbe->triggered = true;

    printf(
        "Pausing probe playback for %.3fs after output frame %d\n",
        pauseProbe->durationSeconds,
        pauseProbe->pauseAfterOutputFrames
    );

    double pauseStartSeconds = CACurrentMediaTime();
    if (audioPlayer != nil) {
        [audioPlayer pause];
    }

    if (pauseProbe->durationSeconds > 0) {
        usleep((useconds_t)(pauseProbe->durationSeconds * 1000000.0));
    }

    double pauseDurationSeconds = CACurrentMediaTime() - pauseStartSeconds;
    shift_playback_clocks(videoPacer, audioClock, pauseDurationSeconds);

    if (audioPlayer != nil) {
        [audioPlayer play];
    }

    pauseProbe->completedPauses++;
    printf("Resumed probe playback after %.3fs pause\n", pauseDurationSeconds);
}

static int seek_input_to_seconds(
    ProbeRunContext context,
    AVCodecContext *videoCodecContext,
    AudioDecodeContext *audio,
    VideoPacer *videoPacer,
    AudioClock *audioClock,
    double seekSeconds
) {
    AVStream *videoStream = context.formatContext->streams[context.videoStreamIndex];
    int64_t seekTimestamp = timestamp_for_seek_seconds(seekSeconds, videoStream);

    printf(
        "Seek target: %.3fs, video stream timestamp=%lld\n",
        seekSeconds,
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
        int pacedFrames = videoPacer->pacedFrames;
        int lateFrames = videoPacer->lateFrames;
        double maxWaitSeconds = videoPacer->maxWaitSeconds;
        double maxLatenessSeconds = videoPacer->maxLatenessSeconds;
        *videoPacer = (VideoPacer){0};
        videoPacer->pacedFrames = pacedFrames;
        videoPacer->lateFrames = lateFrames;
        videoPacer->maxWaitSeconds = maxWaitSeconds;
        videoPacer->maxLatenessSeconds = maxLatenessSeconds;
    }
    if (audioClock != NULL) {
        bool enabled = audioClock->enabled;
        int pacedVideoFrames = audioClock->pacedVideoFrames;
        int videoClockPacedFrames = audioClock->videoClockPacedFrames;
        double maxWaitSeconds = audioClock->maxWaitSeconds;
        double maxLatenessSeconds = audioClock->maxLatenessSeconds;
        *audioClock = (AudioClock){0};
        audioClock->enabled = enabled;
        audioClock->pacedVideoFrames = pacedVideoFrames;
        audioClock->videoClockPacedFrames = videoClockPacedFrames;
        audioClock->maxWaitSeconds = maxWaitSeconds;
        audioClock->maxLatenessSeconds = maxLatenessSeconds;
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
    AudioClock *audioClock,
    PauseProbe *pauseProbe,
    AVAudioPlayerNode *audioPlayer,
    RunDurationLimit *runDurationLimit,
    MemoryProbe *memoryProbe,
    bool hasSeek,
    double seekSeconds,
    int *skippedVideoFrames,
    int *outputVideoFrames,
    int maxOutputFrames,
    bool quietOutput
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
        start_run_duration_limit(runDurationLimit);
        maybe_print_memory_sample(memoryProbe, outputFrames);

        bool shouldPrint = !quietOutput && (outputFrames <= 5 || *decodedFrames % 60 == 0);
        if (frame->format == hardwarePixelFormat) {
            if (displayFrames) {
                pace_video_frame(videoPacer, audioClock, frame, videoStream);
                CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)frame->data[3];
                enqueue_pixel_buffer_for_display(
                    displayLayer,
                    pixelBuffer,
                    cm_time_from_frame(frame, videoStream)
                );
                if (pauseProbe != NULL
                    && pauseProbe->enabled
                    && !pauseProbe->triggered
                    && outputFrames >= pauseProbe->pauseAfterOutputFrames) {
                    pause_and_resume_probe_outputs(
                        pauseProbe,
                        audioPlayer,
                        videoPacer,
                        audioClock
                    );
                }
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

        if (run_duration_limit_reached(runDurationLimit)) {
            return receiveFramesRunDurationLimit;
        }

        if (should_stop_for_interrupt()) {
            return receiveFramesInterrupted;
        }

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
        ? create_audio_decode_context(
            context.formatContext,
            context.audioStreamIndex,
            context.audioOutputSampleRate,
            context.audioOutputChannels
        )
        : NULL;
    AVCodecParameters *codecParameters = videoStream->codecpar;
    const AVCodecHWConfig *hardwareConfig = NULL;
    const AVCodec *decoder = find_videotoolbox_decoder(codecParameters->codec_id, &hardwareConfig);
    if (decoder == NULL) {
        fprintf(stderr, "No FFmpeg decoder found for %s.\n", codec_name(codecParameters->codec_id));
        return 1;
    }

    if (hardwareConfig == NULL) {
        fprintf(
            stderr,
            "No VideoToolbox-capable FFmpeg decoder found for %s; default decoder is %s.\n",
            codec_name(codecParameters->codec_id),
            decoder->name
        );
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
    int seekOperations = 0;
    int completedSegments = 0;
    int activeOutputLimit = context.maxOutputFrames;
    bool reachedEndOfInput = false;
    bool hitPrerollPacketLimit = false;
    bool decodeFailed = false;
    bool interrupted = false;
    VideoPacer videoPacer = {0};
    AudioClock audioClock = {
        .enabled = context.displayFrames && context.audioPlayer != nil && context.audioFormat != nil
    };
    RunDurationLimit runDurationLimit = {
        .enabled = context.runDurationSeconds > 0,
        .durationSeconds = context.runDurationSeconds
    };
    MemoryProbe memoryProbe = {
        .enabled = context.memorySampleIntervalSeconds > 0,
        .sampleIntervalSeconds = context.memorySampleIntervalSeconds
    };
    PauseProbe pauseProbe = {
        .enabled = context.displayFrames && context.pauseAfterOutputFrames > 0,
        .pauseAfterOutputFrames = context.pauseAfterOutputFrames,
        .durationSeconds = context.pauseDurationSeconds
    };

    maybe_print_memory_sample(&memoryProbe, outputVideoFrames);

    int seekTargetCount = context.seekTargetCount;
    int seekLoopCount = seekTargetCount > 0 ? context.seekListLoops : 1;
    if (seekLoopCount <= 0) {
        seekLoopCount = 1;
    }
    int segmentCount = seekTargetCount > 0 ? seekTargetCount * seekLoopCount : 1;
    bool activeHasSeek = context.hasSeek;
    double activeSeekSeconds = context.seekSeconds;

    for (int segmentIndex = 0; segmentIndex < segmentCount; segmentIndex++) {
        bool segmentHasSeek = seekTargetCount > 0;
        double segmentSeekSeconds = segmentHasSeek
            ? context.seekTargets[segmentIndex % seekTargetCount]
            : 0;
        int segmentStartOutputFrames = outputVideoFrames;
        int segmentStartFedPackets = fedPackets;
        int segmentStartSkippedVideoFrames = skippedVideoFrames;
        int segmentOutputLimit = context.maxOutputFrames >= INT_MAX - segmentStartOutputFrames
            ? INT_MAX
            : segmentStartOutputFrames + context.maxOutputFrames;
        activeOutputLimit = segmentOutputLimit;

        activeHasSeek = segmentHasSeek;
        activeSeekSeconds = segmentSeekSeconds;

        if (segmentHasSeek) {
            printf(
                "Seek segment %d/%d target: %.3fs\n",
                segmentIndex + 1,
                segmentCount,
                segmentSeekSeconds
            );

            if (seek_input_to_seconds(
                context,
                codecContext,
                audio,
                &videoPacer,
                &audioClock,
                segmentSeekSeconds
            ) != 0) {
                decodeFailed = true;
                break;
            }
            seekOperations++;
        }

        while (outputVideoFrames < segmentOutputLimit && !runDurationLimit.expired) {
            if (should_stop_for_interrupt()) {
                interrupted = true;
                break;
            }

            if (segmentHasSeek
                && outputVideoFrames == segmentStartOutputFrames
                && fedPackets - segmentStartFedPackets >= context.seekPrerollPacketLimit) {
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
                    &audioClock,
                    segmentHasSeek,
                    segmentSeekSeconds,
                    context.quietOutput
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
                &audioClock,
                &pauseProbe,
                context.audioPlayer,
                &runDurationLimit,
                &memoryProbe,
                segmentHasSeek,
                segmentSeekSeconds,
                &skippedVideoFrames,
                &outputVideoFrames,
                segmentOutputLimit,
                context.quietOutput
            );
            if (receiveResult == receiveFramesOutputLimit) {
                break;
            }
            if (receiveResult == receiveFramesRunDurationLimit) {
                break;
            }
            if (receiveResult == receiveFramesInterrupted) {
                interrupted = true;
                break;
            }
            if (receiveResult != receiveFramesOK) {
                decodeFailed = true;
                break;
            }
        }

        printf(
            "Segment %d output video frames: %d\n",
            segmentIndex + 1,
            outputVideoFrames - segmentStartOutputFrames
        );
        if (segmentHasSeek) {
            printf(
                "Segment %d skipped video frames before seek target: %d\n",
                segmentIndex + 1,
                skippedVideoFrames - segmentStartSkippedVideoFrames
            );
        }
        if (outputVideoFrames - segmentStartOutputFrames >= context.maxOutputFrames) {
            completedSegments++;
        }

        if (reachedEndOfInput
            || hitPrerollPacketLimit
            || decodeFailed
            || runDurationLimit.expired
            || interrupted) {
            break;
        }
    }

    if (reachedEndOfInput && !decodeFailed && !hitPrerollPacketLimit && !interrupted) {
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
            &audioClock,
            &pauseProbe,
            context.audioPlayer,
            &runDurationLimit,
            &memoryProbe,
            activeHasSeek,
            activeSeekSeconds,
            &skippedVideoFrames,
            &outputVideoFrames,
            activeOutputLimit,
            context.quietOutput
        );
    }

    if (reachedEndOfInput && audio != NULL && !hitPrerollPacketLimit && !interrupted) {
        avcodec_send_packet(audio->codecContext, NULL);
        (void)receive_available_audio_frames(
            audio,
            audioStream,
            context.audioPlayer,
            context.audioFormat,
            &audioClock,
            activeHasSeek,
            activeSeekSeconds,
            context.quietOutput
        );
    }

    if (interrupted) {
        printf("Interrupted: yes\n");
    }

    printf("Video packets fed: %d\n", fedPackets);
    printf("Packet send failures: %d\n", sendFailures);
    printf("Decoded frames: %d\n", decodedFrames);
    printf("Hardware frames: %d\n", hardwareFrames);
    printf("Software frames: %d\n", softwareFrames);
    printf("Output video frames: %d\n", outputVideoFrames);
    if (seekOperations > 0) {
        printf("Seek operations: %d\n", seekOperations);
    }
    if (context.hasSeek && !context.hasSeekAgain && context.seekTargetCount == 1) {
        printf("Seek target: %.3fs\n", context.seekSeconds);
        printf("Skipped video frames before seek target: %d\n", skippedVideoFrames);
        printf("Seek preroll packet limit: %d\n", context.seekPrerollPacketLimit);
    } else if (context.hasSeekAgain && context.seekTargetCount == 2) {
        printf("Seek target: %.3fs\n", context.seekSeconds);
        printf("Repeated seek target: %.3fs\n", context.seekAgainSeconds);
        printf("Skipped video frames before seek target: %d\n", skippedVideoFrames);
        printf("Seek preroll packet limit: %d\n", context.seekPrerollPacketLimit);
    } else if (context.seekTargetCount > 0) {
        printf("Seek target count: %d\n", context.seekTargetCount);
        printf("Seek list loops: %d\n", seekLoopCount);
        printf("Skipped video frames before seek targets: %d\n", skippedVideoFrames);
        printf("Seek preroll packet limit: %d\n", context.seekPrerollPacketLimit);
    }
    if (runDurationLimit.enabled) {
        double elapsedSeconds = runDurationLimit.started
            ? CACurrentMediaTime() - runDurationLimit.startHostSeconds
            : 0;
        printf("Run duration limit: %.3fs\n", runDurationLimit.durationSeconds);
        printf("Run duration elapsed: %.3fs\n", elapsedSeconds);
        printf("Run duration reached: %s\n", runDurationLimit.expired ? "yes" : "no");
    }
    if (context.displayFrames) {
        printf("Paced video frames: %d\n", videoPacer.pacedFrames);
        printf("Late video frames: %d\n", videoPacer.lateFrames);
        printf("Max video wait: %.3fs\n", videoPacer.maxWaitSeconds);
        printf("Max video lateness: %.3fs\n", videoPacer.maxLatenessSeconds);
        if (audioClock.enabled) {
            printf("Audio clock initialized: %s\n", audioClock.initialized ? "yes" : "no");
            printf("Audio-master paced video frames: %d\n", audioClock.pacedVideoFrames);
            printf("Video-clock paced frames: %d\n", audioClock.videoClockPacedFrames);
            printf("Max audio-clock wait: %.3fs\n", audioClock.maxWaitSeconds);
            printf("Max audio-clock lateness: %.3fs\n", audioClock.maxLatenessSeconds);
        }
        if (pauseProbe.enabled) {
            printf("Pause probe completed pauses: %d\n", pauseProbe.completedPauses);
            printf("Pause probe duration: %.3fs\n", pauseProbe.durationSeconds);
        }
    }
    if (audio != NULL) {
        printf("Audio packets fed: %d\n", audioPackets);
        printf("Decoded audio frames: %d\n", audio->decodedFrames);
        printf("Scheduled audio buffers: %d\n", audio->scheduledBuffers);
        if (seekOperations > 0) {
            printf("Skipped audio frames before seek targets: %d\n", audio->skippedBeforeSeek);
        }
        printf("Audio passthrough frames: %d\n", audio->passthroughFrames);
        printf("Audio converted frames: %d\n", audio->convertedFrames);
        printf("Audio conversion failures: %d\n", audio->conversionFailures);
        printf("Audio output downmix used: %s\n", yes_no(audio->outputUsesDownmix));
        printf("Audio output format conversion used: %s\n", yes_no(audio->outputUsesFormatConversion));
        printf("Audio output sample-rate conversion used: %s\n", yes_no(audio->outputUsesSampleRateConversion));
        printf("Unsupported audio frames: %d\n", audio->unsupportedFrames);
        printf("Audio decode failures: %d\n", audio->decodeFailures);
    }
    print_memory_summary(&memoryProbe, outputVideoFrames);

    av_packet_free(&packet);
    av_frame_free(&frame);
    avcodec_free_context(&codecContext);
    av_buffer_unref(&hardwareDeviceContext);
    destroy_audio_decode_context(audio);

    bool completedRequestedWork = completedSegments == segmentCount
        || runDurationLimit.expired
        || interrupted;

    return !decodeFailed
        && !hitPrerollPacketLimit
        && completedRequestedWork
        && outputVideoFrames > 0
        ? (interrupted ? 130 : 0)
        : 1;
}

static int open_input(
    const char *path,
    AVFormatContext **formatContext,
    int *videoStreamIndex,
    int *audioStreamIndex,
    int requestedAudioStreamIndex
) {
    int result = open_media_input(formatContext, path);
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
        } else if (stream->codecpar->codec_type == AVMEDIA_TYPE_AUDIO
            && ((requestedAudioStreamIndex < 0 && *audioStreamIndex < 0)
                || requestedAudioStreamIndex == (int)index)) {
            *audioStreamIndex = (int)index;
        }
    }

    if (*videoStreamIndex < 0) {
        fprintf(stderr, "No video stream found.\n");
        avformat_close_input(formatContext);
        return 1;
    }
    if (requestedAudioStreamIndex >= 0 && *audioStreamIndex < 0) {
        fprintf(stderr, "Requested audio stream #%d was not found or is not an audio stream.\n", requestedAudioStreamIndex);
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
        char layoutDescription[128] = {0};
        describe_channel_layout(
            &audioParameters->ch_layout,
            audioParameters->ch_layout.nb_channels,
            layoutDescription,
            sizeof(layoutDescription)
        );
        printf(
            "Audio stream: #%d %s, sample_rate=%d, channels=%d, channel_layout=%s, time_base=%d/%d\n",
            *audioStreamIndex,
            codec_name(audioParameters->codec_id),
            audioParameters->sample_rate,
            audioParameters->ch_layout.nb_channels,
            layoutDescription,
            audioStream->time_base.num,
            audioStream->time_base.den
        );
    } else {
        printf("Audio stream: none\n");
    }

    return 0;
}

static void print_audio_stream_details(
    AVFormatContext *formatContext,
    int streamIndex,
    bool selected
) {
    AVStream *stream = formatContext->streams[streamIndex];
    AVCodecParameters *parameters = stream->codecpar;
    const AVCodec *decoder = avcodec_find_decoder(parameters->codec_id);
    const char *profileName = avcodec_profile_name(parameters->codec_id, parameters->profile);
    char layoutDescription[128] = {0};
    describe_channel_layout(
        &parameters->ch_layout,
        parameters->ch_layout.nb_channels,
        layoutDescription,
        sizeof(layoutDescription)
    );
    int outputChannels = audio_output_channel_count(parameters->ch_layout.nb_channels);

    printf(
        "Audio candidate stream: #%d%s codec=%s",
        streamIndex,
        selected ? " selected" : "",
        codec_name(parameters->codec_id)
    );
    if (profileName != NULL) {
        printf(", profile=%s", profileName);
    }
    printf(
        ", sample_rate=%d, channels=%d, channel_layout=%s, output_channels=%d, downmix=%s, decoder=%s, language=%s, title=%s, default=%s, forced=%s, comment=%s, descriptions=%s\n",
        parameters->sample_rate,
        parameters->ch_layout.nb_channels,
        layoutDescription,
        outputChannels,
        yes_no(parameters->ch_layout.nb_channels > outputChannels && outputChannels > 0),
        decoder != NULL ? decoder->name : "unavailable",
        text_or_dash(stream_metadata_value(stream, "language")),
        text_or_dash(stream_metadata_value(stream, "title")),
        yes_no((stream->disposition & AV_DISPOSITION_DEFAULT) != 0),
        yes_no((stream->disposition & AV_DISPOSITION_FORCED) != 0),
        yes_no((stream->disposition & AV_DISPOSITION_COMMENT) != 0),
        yes_no((stream->disposition & AV_DISPOSITION_DESCRIPTIONS) != 0)
    );
}

static void print_all_audio_stream_details(
    AVFormatContext *formatContext,
    int selectedAudioStreamIndex
) {
    int audioStreamCount = 0;
    for (unsigned int index = 0; index < formatContext->nb_streams; index++) {
        AVStream *stream = formatContext->streams[index];
        if (stream->codecpar->codec_type != AVMEDIA_TYPE_AUDIO) {
            continue;
        }

        print_audio_stream_details(
            formatContext,
            (int)index,
            selectedAudioStreamIndex == (int)index
        );
        audioStreamCount++;
    }

    if (audioStreamCount == 0) {
        printf("Audio candidate streams: none\n");
    }
}

static int inspect_native_capability(
    AVFormatContext *formatContext,
    int videoStreamIndex,
    int audioStreamIndex,
    NativeCapabilityReport *report
) {
    AVStream *videoStream = formatContext->streams[videoStreamIndex];
    AVCodecParameters *videoParameters = videoStream->codecpar;
    const AVCodec *videoDecoder = avcodec_find_decoder(videoParameters->codec_id);
    const AVCodecHWConfig *videoToolboxConfig = NULL;
    const AVCodec *videoToolboxDecoder = find_videotoolbox_decoder(
        videoParameters->codec_id,
        &videoToolboxConfig
    );
    bool hasVideoDecoder = videoDecoder != NULL;
    bool hasVideoToolboxConfig = videoToolboxConfig != NULL;

    printf("Native capability inspect:\n");
    if (hasVideoDecoder) {
        printf("Video decoder: %s\n", videoDecoder->name);
        if (videoToolboxDecoder != NULL && videoToolboxDecoder != videoDecoder) {
            printf("VideoToolbox decoder: %s\n", videoToolboxDecoder->name);
        }
        printf(
            "VideoToolbox config: %s",
            hasVideoToolboxConfig ? "yes" : "no"
        );
        if (hasVideoToolboxConfig) {
            printf(", pixel_format=%s", av_get_pix_fmt_name(videoToolboxConfig->pix_fmt));
        }
        printf("\n");
    } else {
        printf("Video decoder: unavailable for %s\n", codec_name(videoParameters->codec_id));
        printf("VideoToolbox config: no\n");
    }

    AVBufferRef *hardwareDeviceContext = NULL;
    int hardwareDeviceResult = av_hwdevice_ctx_create(
        &hardwareDeviceContext,
        AV_HWDEVICE_TYPE_VIDEOTOOLBOX,
        NULL,
        NULL,
        0
    );
    if (hardwareDeviceResult == 0) {
        printf("VideoToolbox device creation: yes\n");
        av_buffer_unref(&hardwareDeviceContext);
    } else {
        char error[AV_ERROR_MAX_STRING_SIZE] = {0};
        ffmpeg_error_string(hardwareDeviceResult, error, sizeof(error));
        printf("VideoToolbox device creation: no, %s\n", error);
    }

    print_all_audio_stream_details(formatContext, audioStreamIndex);

    bool hasAudioDecoder = true;
    bool hasAudioOutputCandidate = true;
    if (audioStreamIndex >= 0) {
        AVStream *audioStream = formatContext->streams[audioStreamIndex];
        AVCodecParameters *audioParameters = audioStream->codecpar;
        const AVCodec *audioDecoder = avcodec_find_decoder(audioParameters->codec_id);
        hasAudioDecoder = audioDecoder != NULL;
        int outputChannels = audio_output_channel_count(audioParameters->ch_layout.nb_channels);
        hasAudioOutputCandidate = hasAudioDecoder
            && audioParameters->sample_rate > 0
            && outputChannels > 0;
        printf(
            "Selected audio decoder: %s\n",
            hasAudioDecoder ? audioDecoder->name : "unavailable"
        );
        printf(
            "Selected audio output candidate: %s",
            yes_no(hasAudioOutputCandidate)
        );
        if (outputChannels > 0) {
            printf(
                ", output_channels=%d, downmix=%s",
                outputChannels,
                yes_no(audioParameters->ch_layout.nb_channels > outputChannels)
            );
        }
        printf("\n");
    } else {
        printf("Selected audio decoder: no audio stream\n");
    }

    bool videoNativeCandidate = hasVideoDecoder
        && hasVideoToolboxConfig
        && hardwareDeviceResult == 0;
    bool nativeCandidate = videoNativeCandidate && hasAudioOutputCandidate;
    if (report != NULL) {
        report->videoNativeCandidate = videoNativeCandidate;
        report->hasSelectedAudioStream = audioStreamIndex >= 0;
        report->audioOutputCandidate = hasAudioOutputCandidate;
        report->fullNativeCandidate = nativeCandidate;
        report->nativeUnsupported = !nativeCandidate;
    }
    printf("Video native candidate: %s\n", yes_no(videoNativeCandidate));
    printf("Full native candidate: %s\n", yes_no(nativeCandidate));
    printf("Native candidate: %s\n", yes_no(nativeCandidate));
    if (!nativeCandidate) {
        printf("Native unsupported: yes\n");
    }

    return 0;
}

static int run_inspect_probe(
    const char *path,
    int requestedAudioStreamIndex,
    NativeCapabilityReport *report
) {
    __block AVFormatContext *formatContext = NULL;
    int videoStreamIndex = -1;
    int audioStreamIndex = -1;
    if (open_input(
        path,
        &formatContext,
        &videoStreamIndex,
        &audioStreamIndex,
        requestedAudioStreamIndex
    ) != 0) {
        return 1;
    }

    int inspectResult = inspect_native_capability(
        formatContext,
        videoStreamIndex,
        audioStreamIndex,
        report
    );
    avformat_close_input(&formatContext);
    return inspectResult;
}

static void strip_trailing_line_endings(char *line) {
    if (line == NULL) {
        return;
    }

    size_t length = strlen(line);
    while (length > 0 && (line[length - 1] == '\n' || line[length - 1] == '\r')) {
        line[length - 1] = '\0';
        length--;
    }
}

static int run_inspect_list_probe(
    const char *listPath,
    int requestedAudioStreamIndex
) {
    FILE *file = fopen(listPath, "r");
    if (file == NULL) {
        fprintf(stderr, "Could not open inspect list: %s\n", listPath);
        return 1;
    }

    char *line = NULL;
    size_t lineCapacity = 0;
    int lineNumber = 0;
    int inspectedFiles = 0;
    int openOrInspectFailures = 0;
    int fullNativeCandidates = 0;
    int nativeUnsupported = 0;

    while (getline(&line, &lineCapacity, file) >= 0) {
        lineNumber++;
        strip_trailing_line_endings(line);

        if (line[0] == '\0' || line[0] == '#') {
            continue;
        }

        inspectedFiles++;
        printf("Inspect list item %d (line %d): %s\n", inspectedFiles, lineNumber, line);

        NativeCapabilityReport report = {0};
        int result = run_inspect_probe(line, requestedAudioStreamIndex, &report);
        if (result != 0) {
            openOrInspectFailures++;
            nativeUnsupported++;
            printf(
                "Inspect list result: item=%d, status=failed, full_native=no, native_unsupported=yes, path=%s\n",
                inspectedFiles,
                line
            );
            continue;
        }

        if (report.fullNativeCandidate) {
            fullNativeCandidates++;
        }
        if (report.nativeUnsupported) {
            nativeUnsupported++;
        }

        printf(
            "Inspect list result: item=%d, status=ok, video_native=%s, audio_output=%s, full_native=%s, native_unsupported=%s, path=%s\n",
            inspectedFiles,
            yes_no(report.videoNativeCandidate),
            yes_no(report.audioOutputCandidate),
            yes_no(report.fullNativeCandidate),
            yes_no(report.nativeUnsupported),
            line
        );
    }

    free(line);
    fclose(file);

    printf("Inspect list files: %d\n", inspectedFiles);
    printf("Inspect list failures: %d\n", openOrInspectFailures);
    printf("Inspect list full native candidates: %d\n", fullNativeCandidates);
    printf("Inspect list native unsupported: %d\n", nativeUnsupported);

    return openOrInspectFailures == 0 ? 0 : 1;
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
        fprintf(
            stderr,
            "Invalid AVAudioEngine output format request: sample_rate=%d, channels=%d\n",
            sampleRate,
            channels
        );
        return false;
    }

    AVAudioEngine *engine = [[AVAudioEngine alloc] init];
    AVAudioPlayerNode *player = [[AVAudioPlayerNode alloc] init];
    AVAudioFormat *format = [[AVAudioFormat alloc]
        initStandardFormatWithSampleRate:(double)sampleRate
        channels:(AVAudioChannelCount)channels
    ];

    if (engine == nil || player == nil || format == nil) {
        fprintf(
            stderr,
            "Could not allocate AVAudioEngine output objects: engine=%s, player=%s, format=%s\n",
            engine != nil ? "yes" : "no",
            player != nil ? "yes" : "no",
            format != nil ? "yes" : "no"
        );
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

    *engineOut = engine;
    *playerOut = player;
    *formatOut = format;

    printf("Audio output: AVAudioEngine %.0f Hz, channels=%u\n", format.sampleRate, format.channelCount);
    return true;
}

static int run_console_probe(
    const char *path,
    int requestedAudioStreamIndex,
    int maxOutputFrames,
    bool hasSeek,
    double seekSeconds,
    bool hasSeekAgain,
    double seekAgainSeconds,
    int seekTargetCount,
    const double *seekTargets,
    int seekListLoops,
    int pauseAfterOutputFrames,
    double pauseDurationSeconds,
    double runDurationSeconds,
    double memorySampleIntervalSeconds,
    bool quietOutput
) {
    __block AVFormatContext *formatContext = NULL;
    int videoStreamIndex = -1;
    int audioStreamIndex = -1;
    if (open_input(
        path,
        &formatContext,
        &videoStreamIndex,
        &audioStreamIndex,
        requestedAudioStreamIndex
    ) != 0) {
        return 1;
    }

    ProbeRunContext context = {
        .formatContext = formatContext,
        .videoStreamIndex = videoStreamIndex,
        .audioStreamIndex = -1,
        .requestedAudioStreamIndex = requestedAudioStreamIndex,
        .audioOutputSampleRate = 0,
        .audioOutputChannels = 0,
        .maxOutputFrames = maxOutputFrames,
        .seekPrerollPacketLimit = defaultSeekPrerollPacketLimit,
        .hasSeek = hasSeek,
        .seekSeconds = seekSeconds,
        .hasSeekAgain = hasSeekAgain,
        .seekAgainSeconds = seekAgainSeconds,
        .seekTargetCount = seekTargetCount,
        .seekListLoops = seekListLoops,
        .pauseAfterOutputFrames = pauseAfterOutputFrames,
        .pauseDurationSeconds = pauseDurationSeconds,
        .runDurationSeconds = runDurationSeconds,
        .memorySampleIntervalSeconds = memorySampleIntervalSeconds,
        .quietOutput = quietOutput,
        .displayFrames = false,
        .displayLayer = nil,
        .audioEngine = nil,
        .audioPlayer = nil,
        .audioFormat = nil
    };
    if (seekTargetCount > 0 && seekTargets != NULL) {
        memcpy(context.seekTargets, seekTargets, sizeof(double) * (size_t)seekTargetCount);
    }
    int probeResult = run_videotoolbox_decode_probe(context);
    avformat_close_input(&formatContext);
    return probeResult;
}

static int run_display_probe(
    const char *path,
    int requestedAudioStreamIndex,
    int maxOutputFrames,
    bool hasSeek,
    double seekSeconds,
    bool hasSeekAgain,
    double seekAgainSeconds,
    int seekTargetCount,
    const double *seekTargets,
    int seekListLoops,
    int pauseAfterOutputFrames,
    double pauseDurationSeconds,
    double runDurationSeconds,
    double memorySampleIntervalSeconds,
    bool quietOutput
) {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    __block AVFormatContext *formatContext = NULL;
    int videoStreamIndex = -1;
    int audioStreamIndex = -1;
    if (open_input(
        path,
        &formatContext,
        &videoStreamIndex,
        &audioStreamIndex,
        requestedAudioStreamIndex
    ) != 0) {
        return 1;
    }

    NSWindow *window = nil;
    AVSampleBufferDisplayLayer *displayLayer = make_display_layer(&window);
    AVAudioEngine *audioEngine = nil;
    AVAudioPlayerNode *audioPlayer = nil;
    AVAudioFormat *audioFormat = nil;
    int audioOutputSampleRate = 0;
    int audioOutputChannels = 0;

    if (audioStreamIndex >= 0) {
        AVCodecParameters *audioParameters = formatContext->streams[audioStreamIndex]->codecpar;
        audioOutputSampleRate = positive_or_default(audioParameters->sample_rate, 48000);
        audioOutputChannels = audio_output_channel_count(audioParameters->ch_layout.nb_channels);
        if (audioOutputChannels <= 0) {
            fprintf(
                stderr,
                "Audio output unavailable for stream #%d: unsupported channel count %d.\n",
                audioStreamIndex,
                audioParameters->ch_layout.nb_channels
            );
            audioStreamIndex = -1;
        }
    }

    if (audioStreamIndex >= 0) {
        AVCodecParameters *audioParameters = formatContext->streams[audioStreamIndex]->codecpar;
        printf(
            "Audio output request: stream #%d, input_channels=%d, output_channels=%d, downmix=%s\n",
            audioStreamIndex,
            audioParameters->ch_layout.nb_channels,
            audioOutputChannels,
            yes_no(audioParameters->ch_layout.nb_channels > audioOutputChannels)
        );
        if (!make_audio_output(
            audioOutputSampleRate,
            audioOutputChannels,
            &audioEngine,
            &audioPlayer,
            &audioFormat
        )) {
            fprintf(
                stderr,
                "Audio output unavailable for stream #%d; continuing video-only.\n",
                audioStreamIndex
            );
            audioStreamIndex = -1;
        }
    }

    __block int probeResult = 1;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        ProbeRunContext context = {
            .formatContext = formatContext,
            .videoStreamIndex = videoStreamIndex,
            .audioStreamIndex = audioStreamIndex,
            .requestedAudioStreamIndex = requestedAudioStreamIndex,
            .audioOutputSampleRate = audioOutputSampleRate,
            .audioOutputChannels = audioOutputChannels,
            .maxOutputFrames = maxOutputFrames,
            .seekPrerollPacketLimit = defaultSeekPrerollPacketLimit,
            .hasSeek = hasSeek,
            .seekSeconds = seekSeconds,
            .hasSeekAgain = hasSeekAgain,
            .seekAgainSeconds = seekAgainSeconds,
            .seekTargetCount = seekTargetCount,
            .seekListLoops = seekListLoops,
            .pauseAfterOutputFrames = pauseAfterOutputFrames,
            .pauseDurationSeconds = pauseDurationSeconds,
            .runDurationSeconds = runDurationSeconds,
            .memorySampleIntervalSeconds = memorySampleIntervalSeconds,
            .quietOutput = quietOutput,
            .displayFrames = true,
            .displayLayer = displayLayer,
            .audioEngine = audioEngine,
            .audioPlayer = audioPlayer,
            .audioFormat = audioFormat
        };
        if (seekTargetCount > 0 && seekTargets != NULL) {
            memcpy(context.seekTargets, seekTargets, sizeof(double) * (size_t)seekTargetCount);
        }
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
                    exit(probeResult);
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

static bool parse_positive_seconds(const char *value, double *secondsOut) {
    if (!parse_nonnegative_seconds(value, secondsOut)) {
        return false;
    }

    return *secondsOut > 0;
}

static bool parse_positive_int(const char *value, int *intOut) {
    errno = 0;
    char *end = NULL;
    long parsed = strtol(value, &end, 10);
    if (errno != 0 || end == value || *end != '\0' || parsed <= 0 || parsed > INT32_MAX) {
        return false;
    }

    *intOut = (int)parsed;
    return true;
}

static bool parse_nonnegative_int(const char *value, int *intOut) {
    errno = 0;
    char *end = NULL;
    long parsed = strtol(value, &end, 10);
    if (errno != 0 || end == value || *end != '\0' || parsed < 0 || parsed > INT32_MAX) {
        return false;
    }

    *intOut = (int)parsed;
    return true;
}

static bool parse_seek_list(const char *value, double *targets, int *targetCountOut) {
    if (value == NULL || targets == NULL || targetCountOut == NULL) {
        return false;
    }

    char *copy = strdup(value);
    if (copy == NULL) {
        return false;
    }

    int count = 0;
    char *cursor = copy;
    while (cursor != NULL) {
        char *comma = strchr(cursor, ',');
        if (comma != NULL) {
            *comma = '\0';
        }

        if (*cursor == '\0' || count >= MAX_SEEK_TARGETS) {
            free(copy);
            return false;
        }

        double seconds = 0;
        if (!parse_nonnegative_seconds(cursor, &seconds)) {
            free(copy);
            return false;
        }

        targets[count++] = seconds;
        cursor = comma != NULL ? comma + 1 : NULL;
    }

    free(copy);

    if (count <= 0) {
        return false;
    }

    *targetCountOut = count;
    return true;
}

static void print_usage(void) {
    fprintf(
        stderr,
        "Usage: NativePlaybackProbe [--inspect | --inspect-list] [--display] [--quiet] [--audio-stream stream-index] [--seek seconds] [--seek-again seconds] [--seek-list seconds[,seconds...]] [--seek-list-loops count] [--pause-after-frames count] [--pause-duration seconds] [--run-duration seconds] [--memory-sample-interval seconds] <media-file-or-list-file> [max-output-video-frames]\n"
    );
}

int main(int argc, char **argv) {
    @autoreleasepool {
        install_interrupt_handler();

        if (argc < 2) {
            print_usage();
            return 2;
        }

        bool inspectOnly = false;
        bool inspectList = false;
        bool displayFrames = false;
        int requestedAudioStreamIndex = -1;
        bool hasSeek = false;
        double seekSeconds = 0;
        bool hasSeekAgain = false;
        double seekAgainSeconds = 0;
        bool hasSeekList = false;
        int seekTargetCount = 0;
        int seekListLoops = 1;
        double seekTargets[MAX_SEEK_TARGETS] = {0};
        int pauseAfterOutputFrames = 0;
        double pauseDurationSeconds = 1.0;
        double runDurationSeconds = 0;
        double memorySampleIntervalSeconds = 0;
        bool quietOutput = false;
        int argumentIndex = 1;

        while (argumentIndex < argc) {
            if (strcmp(argv[argumentIndex], "--inspect") == 0) {
                inspectOnly = true;
                argumentIndex++;
                continue;
            }

            if (strcmp(argv[argumentIndex], "--inspect-list") == 0) {
                inspectList = true;
                argumentIndex++;
                continue;
            }

            if (strcmp(argv[argumentIndex], "--display") == 0) {
                displayFrames = true;
                argumentIndex++;
                continue;
            }

            if (strcmp(argv[argumentIndex], "--quiet") == 0) {
                quietOutput = true;
                argumentIndex++;
                continue;
            }

            if (strcmp(argv[argumentIndex], "--audio-stream") == 0) {
                if (argumentIndex + 1 >= argc
                    || !parse_nonnegative_int(argv[argumentIndex + 1], &requestedAudioStreamIndex)) {
                    fprintf(stderr, "Invalid --audio-stream value.\n");
                    print_usage();
                    return 2;
                }

                argumentIndex += 2;
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

            if (strcmp(argv[argumentIndex], "--seek-again") == 0) {
                if (argumentIndex + 1 >= argc
                    || !parse_nonnegative_seconds(argv[argumentIndex + 1], &seekAgainSeconds)) {
                    fprintf(stderr, "Invalid --seek-again value.\n");
                    print_usage();
                    return 2;
                }

                hasSeekAgain = true;
                argumentIndex += 2;
                continue;
            }

            if (strcmp(argv[argumentIndex], "--seek-list") == 0) {
                if (argumentIndex + 1 >= argc
                    || !parse_seek_list(argv[argumentIndex + 1], seekTargets, &seekTargetCount)) {
                    fprintf(stderr, "Invalid --seek-list value.\n");
                    print_usage();
                    return 2;
                }

                hasSeekList = true;
                argumentIndex += 2;
                continue;
            }

            if (strcmp(argv[argumentIndex], "--seek-list-loops") == 0) {
                if (argumentIndex + 1 >= argc
                    || !parse_positive_int(argv[argumentIndex + 1], &seekListLoops)) {
                    fprintf(stderr, "Invalid --seek-list-loops value.\n");
                    print_usage();
                    return 2;
                }

                argumentIndex += 2;
                continue;
            }

            if (strcmp(argv[argumentIndex], "--pause-after-frames") == 0) {
                if (argumentIndex + 1 >= argc
                    || !parse_positive_int(argv[argumentIndex + 1], &pauseAfterOutputFrames)) {
                    fprintf(stderr, "Invalid --pause-after-frames value.\n");
                    print_usage();
                    return 2;
                }

                argumentIndex += 2;
                continue;
            }

            if (strcmp(argv[argumentIndex], "--pause-duration") == 0) {
                if (argumentIndex + 1 >= argc
                    || !parse_nonnegative_seconds(argv[argumentIndex + 1], &pauseDurationSeconds)) {
                    fprintf(stderr, "Invalid --pause-duration value.\n");
                    print_usage();
                    return 2;
                }

                argumentIndex += 2;
                continue;
            }

            if (strcmp(argv[argumentIndex], "--run-duration") == 0) {
                if (argumentIndex + 1 >= argc
                    || !parse_positive_seconds(argv[argumentIndex + 1], &runDurationSeconds)) {
                    fprintf(stderr, "Invalid --run-duration value.\n");
                    print_usage();
                    return 2;
                }

                argumentIndex += 2;
                continue;
            }

            if (strcmp(argv[argumentIndex], "--memory-sample-interval") == 0) {
                if (argumentIndex + 1 >= argc
                    || !parse_positive_seconds(argv[argumentIndex + 1], &memorySampleIntervalSeconds)) {
                    fprintf(stderr, "Invalid --memory-sample-interval value.\n");
                    print_usage();
                    return 2;
                }

                argumentIndex += 2;
                continue;
            }

            break;
        }

        if (hasSeekAgain && !hasSeek) {
            fprintf(stderr, "--seek-again requires an initial --seek value.\n");
            print_usage();
            return 2;
        }
        if (hasSeekList && (hasSeek || hasSeekAgain)) {
            fprintf(stderr, "--seek-list cannot be combined with --seek or --seek-again.\n");
            print_usage();
            return 2;
        }
        if (!hasSeekList && seekListLoops != 1) {
            fprintf(stderr, "--seek-list-loops requires --seek-list.\n");
            print_usage();
            return 2;
        }
        if (pauseAfterOutputFrames > 0 && !displayFrames) {
            fprintf(stderr, "--pause-after-frames requires --display.\n");
            print_usage();
            return 2;
        }
        if (inspectOnly && inspectList) {
            fprintf(stderr, "--inspect and --inspect-list cannot be combined.\n");
            print_usage();
            return 2;
        }
        if (inspectList && displayFrames) {
            fprintf(stderr, "--inspect-list cannot be combined with --display.\n");
            print_usage();
            return 2;
        }
        if (inspectList
            && (hasSeek
                || hasSeekAgain
                || hasSeekList
                || pauseAfterOutputFrames > 0
                || runDurationSeconds > 0
                || memorySampleIntervalSeconds > 0)) {
            fprintf(stderr, "--inspect-list cannot be combined with playback run options.\n");
            print_usage();
            return 2;
        }

        if (!hasSeekList && hasSeek) {
            seekTargets[seekTargetCount++] = seekSeconds;
            if (hasSeekAgain) {
                seekTargets[seekTargetCount++] = seekAgainSeconds;
            }
        }
        if (seekTargetCount > 0 && seekListLoops > INT_MAX / seekTargetCount) {
            fprintf(stderr, "Too many seek-list segments.\n");
            print_usage();
            return 2;
        }

        if (argumentIndex >= argc) {
            print_usage();
            return 2;
        }

        const char *path = argv[argumentIndex++];
        bool hasExplicitMaxOutputFrames = argumentIndex < argc;
        int maxOutputFrames = defaultMaxOutputFrames;
        if (hasExplicitMaxOutputFrames
            && !parse_positive_int(argv[argumentIndex++], &maxOutputFrames)) {
            fprintf(stderr, "Invalid max-output-video-frames value.\n");
            print_usage();
            return 2;
        }
        if (argumentIndex != argc) {
            print_usage();
            return 2;
        }
        if ((inspectOnly || inspectList) && hasExplicitMaxOutputFrames) {
            fprintf(stderr, "--inspect and --inspect-list do not accept max-output-video-frames.\n");
            print_usage();
            return 2;
        }
        if (runDurationSeconds > 0 && !hasExplicitMaxOutputFrames) {
            maxOutputFrames = INT_MAX;
        }

        if (inspectOnly) {
            return run_inspect_probe(path, requestedAudioStreamIndex, NULL);
        }

        if (inspectList) {
            return run_inspect_list_probe(path, requestedAudioStreamIndex);
        }

        if (displayFrames) {
            return run_display_probe(
                path,
                requestedAudioStreamIndex,
                maxOutputFrames,
                hasSeek,
                seekSeconds,
                hasSeekAgain,
                seekAgainSeconds,
                seekTargetCount,
                seekTargets,
                seekListLoops,
                pauseAfterOutputFrames,
                pauseDurationSeconds,
                runDurationSeconds,
                memorySampleIntervalSeconds,
                quietOutput
            );
        }

        return run_console_probe(
            path,
            requestedAudioStreamIndex,
            maxOutputFrames,
            hasSeek,
            seekSeconds,
            hasSeekAgain,
            seekAgainSeconds,
            seekTargetCount,
            seekTargets,
            seekListLoops,
            pauseAfterOutputFrames,
            pauseDurationSeconds,
            runDurationSeconds,
            memorySampleIntervalSeconds,
            quietOutput
        );
    }
}
