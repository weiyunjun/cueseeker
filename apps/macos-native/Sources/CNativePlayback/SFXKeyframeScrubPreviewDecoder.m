#import "SFXNativePlaybackInternal.h"

@implementation SFXKeyframeThumbnailDecoder {
    NSString *_path;
    NSString *_httpHeaders;
    AVFormatContext *_formatContext;
    AVCodecContext *_codecContext;
    AVPacket *_packet;
    AVFrame *_frame;
    struct SwsContext *_scaler;
    int _videoStreamIndex;
    double _timelineOriginSeconds;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _videoStreamIndex = -1;
    }
    return self;
}

- (void)dealloc {
    [self invalidate];
}

- (void)invalidate {
    _path = nil;
    _httpHeaders = nil;
    _videoStreamIndex = -1;
    _timelineOriginSeconds = 0.0;
    if (_scaler != NULL) {
        sws_freeContext(_scaler);
        _scaler = NULL;
    }
    av_frame_free(&_frame);
    av_packet_free(&_packet);
    avcodec_free_context(&_codecContext);
    avformat_close_input(&_formatContext);
}

- (BOOL)isPreparedForPath:(NSString *)path httpHeaders:(nullable NSString *)httpHeaders {
    if (_formatContext == NULL || _codecContext == NULL || _packet == NULL || _frame == NULL) {
        return NO;
    }
    if (_path == nil || ![_path isEqualToString:path]) {
        return NO;
    }
    if (_httpHeaders == nil && httpHeaders == nil) {
        return YES;
    }
    return _httpHeaders != nil && httpHeaders != nil && [_httpHeaders isEqualToString:httpHeaders];
}

- (BOOL)openVideoDecoderForStream:(AVStream *)videoStream {
    if (videoStream == NULL || videoStream->codecpar == NULL) {
        return NO;
    }
    AVCodecParameters *parameters = videoStream->codecpar;
    const AVCodec *decoder = SFXFindSoftwareVideoDecoder(parameters->codec_id);
    if (decoder == NULL) {
        return NO;
    }

    avcodec_free_context(&_codecContext);
    _codecContext = avcodec_alloc_context3(decoder);
    if (_codecContext == NULL) {
        return NO;
    }

    if (avcodec_parameters_to_context(_codecContext, parameters) < 0) {
        avcodec_free_context(&_codecContext);
        return NO;
    }

    _codecContext->thread_count = 2;
    _codecContext->thread_type = FF_THREAD_SLICE;
    _codecContext->skip_frame = AVDISCARD_NONKEY;
    _codecContext->skip_loop_filter = AVDISCARD_ALL;
    _codecContext->flags2 |= AV_CODEC_FLAG2_FAST;

    if (avcodec_open2(_codecContext, decoder, NULL) < 0) {
        avcodec_free_context(&_codecContext);
        return NO;
    }

    return YES;
}

- (BOOL)openMediaForPath:(NSString *)path httpHeaders:(nullable NSString *)httpHeaders {
    [self invalidate];
    if (path.length == 0) {
        return NO;
    }

    const char *inputPath = ([path hasPrefix:@"http://"] || [path hasPrefix:@"https://"])
        ? path.UTF8String
        : path.fileSystemRepresentation;
    if (inputPath == NULL || SFXOpenMediaInput(&_formatContext, inputPath, httpHeaders) < 0 || _formatContext == NULL) {
        [self invalidate];
        return NO;
    }

    BOOL hasHeaderVideoParameters = NO;
    for (unsigned int index = 0; index < _formatContext->nb_streams; index++) {
        AVStream *stream = _formatContext->streams[index];
        if (stream != NULL
            && stream->codecpar != NULL
            && stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO
            && stream->codecpar->codec_id != AV_CODEC_ID_NONE
            && stream->codecpar->width > 0
            && stream->codecpar->height > 0) {
            hasHeaderVideoParameters = YES;
            break;
        }
    }

    if (!hasHeaderVideoParameters) {
        if (avformat_find_stream_info(_formatContext, NULL) < 0) {
            [self invalidate];
            return NO;
        }
    }

    _videoStreamIndex = av_find_best_stream(_formatContext, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    if (_videoStreamIndex < 0 || _videoStreamIndex >= (int)_formatContext->nb_streams) {
        [self invalidate];
        return NO;
    }

    AVStream *videoStream = _formatContext->streams[_videoStreamIndex];
    if (![self openVideoDecoderForStream:videoStream]) {
        if (!hasHeaderVideoParameters || avformat_find_stream_info(_formatContext, NULL) < 0) {
            [self invalidate];
            return NO;
        }
        _videoStreamIndex = av_find_best_stream(_formatContext, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
        if (_videoStreamIndex < 0 || _videoStreamIndex >= (int)_formatContext->nb_streams) {
            [self invalidate];
            return NO;
        }
        videoStream = _formatContext->streams[_videoStreamIndex];
        if (![self openVideoDecoderForStream:videoStream]) {
            [self invalidate];
            return NO;
        }
    }

    for (unsigned int index = 0; index < _formatContext->nb_streams; index++) {
        if ((int)index != _videoStreamIndex && _formatContext->streams[index] != NULL) {
            _formatContext->streams[index]->discard = AVDISCARD_ALL;
        }
    }

    _timelineOriginSeconds = SFXMediaTimelineOriginSeconds(_formatContext);
    _packet = av_packet_alloc();
    _frame = av_frame_alloc();
    if (_packet == NULL || _frame == NULL) {
        [self invalidate];
        return NO;
    }

    _path = [path copy];
    _httpHeaders = [httpHeaders copy];
    return YES;
}

- (BOOL)hasValidDimensionsAndFormatForFrame:(const AVFrame *)frame {
    if (frame == NULL || _codecContext == NULL) {
        return NO;
    }
    int width = frame->width > 0 ? frame->width : _codecContext->width;
    int height = frame->height > 0 ? frame->height : _codecContext->height;
    enum AVPixelFormat inputFormat = (enum AVPixelFormat)frame->format;
    return width > 0
        && height > 0
        && inputFormat != AV_PIX_FMT_NONE
        && av_pix_fmt_desc_get(inputFormat) != NULL;
}

- (nullable CGImageRef)copyScaledImageFromCurrentFrameWithTargetPixelWidth:(NSInteger)targetPixelWidth
                                                             videoWidthOut:(nullable NSInteger *)videoWidthOut
                                                            videoHeightOut:(nullable NSInteger *)videoHeightOut CF_RETURNS_RETAINED {
    int srcWidth = _frame->width > 0 ? _frame->width : _codecContext->width;
    int srcHeight = _frame->height > 0 ? _frame->height : _codecContext->height;
    enum AVPixelFormat inputFormat = (enum AVPixelFormat)_frame->format;
    if (srcWidth <= 0 || srcHeight <= 0 || inputFormat == AV_PIX_FMT_NONE) {
        return NULL;
    }

    if (videoWidthOut != NULL) {
        *videoWidthOut = srcWidth;
    }
    if (videoHeightOut != NULL) {
        *videoHeightOut = srcHeight;
    }

    int dstWidth = (int)MAX(1, targetPixelWidth);
    int dstHeight = (int)MAX(1, llround((double)dstWidth * (double)srcHeight / (double)srcWidth));

    _scaler = sws_getCachedContext(
        _scaler,
        srcWidth,
        srcHeight,
        inputFormat,
        dstWidth,
        dstHeight,
        AV_PIX_FMT_RGB24,
        SWS_BILINEAR,
        NULL,
        NULL,
        NULL
    );
    if (_scaler == NULL) {
        return NULL;
    }

    int dstStride = dstWidth * 3;
    NSMutableData *rgbData = [NSMutableData dataWithLength:(NSUInteger)(dstStride * dstHeight)];
    if (rgbData == nil) {
        return NULL;
    }

    uint8_t *dstSlice[4] = { (uint8_t *)rgbData.mutableBytes, NULL, NULL, NULL };
    int dstStrideArray[4] = { dstStride, 0, 0, 0 };
    int convertedHeight = sws_scale(
        _scaler,
        (const uint8_t * const *)_frame->data,
        _frame->linesize,
        0,
        srcHeight,
        dstSlice,
        dstStrideArray
    );
    if (convertedHeight <= 0) {
        return NULL;
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    if (colorSpace == NULL) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    if (colorSpace == NULL) {
        return NULL;
    }

    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)rgbData);
    if (provider == NULL) {
        CGColorSpaceRelease(colorSpace);
        return NULL;
    }

    CGImageRef cgImage = CGImageCreate(
        (size_t)dstWidth,
        (size_t)dstHeight,
        8,
        24,
        (size_t)dstStride,
        colorSpace,
        (CGBitmapInfo)kCGImageAlphaNone,
        provider,
        NULL,
        false,
        kCGRenderingIntentDefault
    );
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    return cgImage;
}

- (nullable CGImageRef)copyThumbnailImageForPath:(NSString *)path
                                     httpHeaders:(nullable NSString *)httpHeaders
                                  atMilliseconds:(NSInteger)milliseconds
                                targetPixelWidth:(NSInteger)targetPixelWidth
                         keyframeMillisecondsOut:(nullable NSInteger *)keyframeMillisecondsOut
                                   videoWidthOut:(nullable NSInteger *)videoWidthOut
                                  videoHeightOut:(nullable NSInteger *)videoHeightOut {
    if (![self isPreparedForPath:path httpHeaders:httpHeaders]) {
        if (![self openMediaForPath:path httpHeaders:httpHeaders]) {
            return NULL;
        }
    }

    double seconds = fmax(0.0, (double)milliseconds / 1000.0);
    if (!SFXSeekToStartPosition(_formatContext, _videoStreamIndex, seconds, _timelineOriginSeconds, NULL)) {
        return NULL;
    }
    avcodec_flush_buffers(_codecContext);

    BOOL decodedFrame = NO;
    int packetsSent = 0;
    while (!decodedFrame && packetsSent < 16 && av_read_frame(_formatContext, _packet) >= 0) {
        if (_packet->stream_index != _videoStreamIndex) {
            av_packet_unref(_packet);
            continue;
        }

        BOOL isKeyframePacket = (_packet->flags & AV_PKT_FLAG_KEY) != 0;
        int sendResult = avcodec_send_packet(_codecContext, _packet);
        av_packet_unref(_packet);
        if (sendResult < 0) {
            continue;
        }
        packetsSent += 1;

        while (avcodec_receive_frame(_codecContext, _frame) >= 0) {
            if ([self hasValidDimensionsAndFormatForFrame:_frame]) {
                decodedFrame = YES;
                break;
            }
            av_frame_unref(_frame);
        }

        if (!decodedFrame && isKeyframePacket) {
            avcodec_send_packet(_codecContext, NULL);
            while (avcodec_receive_frame(_codecContext, _frame) >= 0) {
                if ([self hasValidDimensionsAndFormatForFrame:_frame]) {
                    decodedFrame = YES;
                    break;
                }
                av_frame_unref(_frame);
            }
            avcodec_flush_buffers(_codecContext);
        }
    }

    if (!decodedFrame) {
        avcodec_send_packet(_codecContext, NULL);
        while (avcodec_receive_frame(_codecContext, _frame) >= 0) {
            if ([self hasValidDimensionsAndFormatForFrame:_frame]) {
                decodedFrame = YES;
                break;
            }
            av_frame_unref(_frame);
        }
        avcodec_flush_buffers(_codecContext);
    }

    if (!decodedFrame) {
        return NULL;
    }

    if (keyframeMillisecondsOut != NULL) {
        AVStream *videoStream = _formatContext->streams[_videoStreamIndex];
        double frameSeconds = SFXFramePlaybackSeconds(_frame, videoStream, _timelineOriginSeconds);
        *keyframeMillisecondsOut = (isfinite(frameSeconds) && frameSeconds >= 0)
            ? MAX(0, (NSInteger)llround(frameSeconds * 1000.0))
            : MAX(0, milliseconds);
    }

    CGImageRef image = [self copyScaledImageFromCurrentFrameWithTargetPixelWidth:targetPixelWidth
                                                                   videoWidthOut:videoWidthOut
                                                                  videoHeightOut:videoHeightOut];
    av_frame_unref(_frame);
    return image;
}

@end
