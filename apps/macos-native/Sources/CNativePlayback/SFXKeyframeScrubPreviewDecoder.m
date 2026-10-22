#import "SFXNativePlaybackInternal.h"

CVPixelBufferRef SFXCopyBGRAKeyframePreviewPixelBuffer(
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
