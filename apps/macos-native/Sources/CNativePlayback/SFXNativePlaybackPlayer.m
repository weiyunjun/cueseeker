#import "SFXNativePlaybackPlayer.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <dispatch/dispatch.h>

#include <libavcodec/avcodec.h>
#include <libavcodec/packet.h>
#include <libavformat/avformat.h>
#include <libavutil/channel_layout.h>
#include <libavutil/error.h>
#include <libavutil/hwcontext.h>
#include <libavutil/log.h>
#include <libavutil/mathematics.h>
#include <libavutil/pixdesc.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>

#include <math.h>
#include <stdatomic.h>

NSString * const SFXNativePlaybackErrorDomain = @"SubFinderX.NativePlayback";

static enum AVPixelFormat SFXHardwarePixelFormat = AV_PIX_FMT_NONE;
static const float SFXMinimumPlaybackRate = 0.5f;
static const float SFXMaximumPlaybackRate = 2.0f;

typedef struct {
    float yOffset;
    float yScale;
    float uvOffset;
} SFXYUVUniforms;

static float SFXClampedPlaybackRate(float playbackRate) {
    if (!isfinite(playbackRate)) {
        return 1.0f;
    }
    return fmaxf(SFXMinimumPlaybackRate, fminf(playbackRate, SFXMaximumPlaybackRate));
}

static NSString *SFXFFmpegErrorString(int code) {
    char buffer[AV_ERROR_MAX_STRING_SIZE] = {0};
    if (av_strerror(code, buffer, sizeof(buffer)) < 0) {
        return [NSString stringWithFormat:@"FFmpeg error %d", code];
    }
    return [NSString stringWithUTF8String:buffer];
}

static NSString *SFXPixelFormatName(enum AVPixelFormat pixelFormat) {
    const char *name = av_get_pix_fmt_name(pixelFormat);
    if (name == NULL) {
        return [NSString stringWithFormat:@"pixel format %d", pixelFormat];
    }
    return [NSString stringWithUTF8String:name];
}

static NSError *SFXNativePlaybackError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:SFXNativePlaybackErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

static void SFXDispatchSyncOnMain(dispatch_block_t block) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

static const AVCodecHWConfig *SFXFindVideoToolboxConfig(const AVCodec *decoder) {
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

static const AVCodec *SFXFindVideoToolboxDecoder(
    enum AVCodecID codecID,
    const AVCodecHWConfig **hardwareConfig
) {
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

static const AVCodec *SFXFindSoftwareVideoDecoder(enum AVCodecID codecID) {
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

static enum AVPixelFormat SFXChooseHardwareFormat(
    AVCodecContext *context,
    const enum AVPixelFormat *pixelFormats
) {
    (void)context;

    for (const enum AVPixelFormat *format = pixelFormats; *format != AV_PIX_FMT_NONE; format++) {
        if (*format == SFXHardwarePixelFormat) {
            return *format;
        }
    }

    return pixelFormats[0];
}

static double SFXStreamStartSeconds(AVStream *stream) {
    if (stream->start_time == AV_NOPTS_VALUE) {
        return 0;
    }
    return av_q2d(stream->time_base) * stream->start_time;
}

static double SFXFramePlaybackSeconds(const AVFrame *frame, AVStream *stream) {
    if (frame->best_effort_timestamp == AV_NOPTS_VALUE) {
        return -1;
    }
    return av_q2d(stream->time_base) * frame->best_effort_timestamp - SFXStreamStartSeconds(stream);
}

static int64_t SFXSeekTimestamp(double seconds, AVStream *stream) {
    int64_t relativeTimestamp = (int64_t)llround(seconds / av_q2d(stream->time_base));
    if (stream->start_time == AV_NOPTS_VALUE) {
        return relativeTimestamp;
    }
    return stream->start_time + relativeTimestamp;
}

static int64_t SFXGlobalSeekTimestamp(double seconds, AVFormatContext *formatContext) {
    int64_t timestamp = (int64_t)llround(seconds * AV_TIME_BASE);
    if (formatContext->start_time != AV_NOPTS_VALUE) {
        timestamp += formatContext->start_time;
    }
    return timestamp;
}

static BOOL SFXSeekToStartPosition(
    AVFormatContext *formatContext,
    int videoStreamIndex,
    double seconds,
    NSError **error
) {
    AVStream *videoStream = formatContext->streams[videoStreamIndex];
    int64_t streamTimestamp = SFXSeekTimestamp(seconds, videoStream);
    int streamResult = av_seek_frame(
        formatContext,
        videoStreamIndex,
        streamTimestamp,
        AVSEEK_FLAG_BACKWARD
    );
    if (streamResult >= 0) {
        return YES;
    }

    int64_t globalTimestamp = SFXGlobalSeekTimestamp(seconds, formatContext);
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

static BOOL SFXFrameBeforeSeekTarget(const AVFrame *frame, AVStream *stream, double seekSeconds) {
    double frameSeconds = SFXFramePlaybackSeconds(frame, stream);
    if (frameSeconds < 0) {
        return NO;
    }
    return frameSeconds + 0.002 < seekSeconds;
}

static CMTime SFXFramePresentationTime(const AVFrame *frame, AVStream *stream) {
    if (frame->best_effort_timestamp == AV_NOPTS_VALUE) {
        return CMTimeMake(0, 1);
    }
    int64_t value = frame->best_effort_timestamp * stream->time_base.num;
    return CMTimeMake(value, stream->time_base.den);
}

static int SFXOutputChannelCount(int inputChannels) {
    if (inputChannels <= 0) {
        return 0;
    }
    return inputChannels > 2 ? 2 : inputChannels;
}

@interface SFXNativePlaybackView : NSView
@property (nonatomic, strong, readonly) AVSampleBufferDisplayLayer *displayLayer;
- (BOOL)hasMetalYUVRenderer;
- (void)setHardwareRenderingEnabled:(BOOL)enabled;
- (BOOL)renderHardwarePixelBuffer:(CVPixelBufferRef)pixelBuffer errorMessage:(NSString **)errorMessage;
- (void)enqueueSamplePixelBuffer:(CVPixelBufferRef)pixelBuffer presentationTime:(CMTime)presentationTime;
@end

@implementation SFXNativePlaybackView {
    AVSampleBufferDisplayLayer *_displayLayer;
    CAMetalLayer *_metalLayer;
    id<MTLDevice> _metalDevice;
    id<MTLCommandQueue> _metalCommandQueue;
    id<MTLRenderPipelineState> _metalPipelineState;
    CVMetalTextureCacheRef _metalTextureCache;
    NSString *_metalSetupError;
    BOOL _hardwareRenderingEnabled;
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self == nil) {
        return nil;
    }

    self.wantsLayer = YES;
    self.layer.backgroundColor = NSColor.blackColor.CGColor;

    _displayLayer = [AVSampleBufferDisplayLayer layer];
    _displayLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    _displayLayer.backgroundColor = NSColor.blackColor.CGColor;
    [self.layer addSublayer:_displayLayer];

    [self configureMetalRenderer];

    return self;
}

- (AVSampleBufferDisplayLayer *)displayLayer {
    return _displayLayer;
}

- (BOOL)hasMetalYUVRenderer {
    return _metalPipelineState != nil && _metalCommandQueue != nil && _metalTextureCache != NULL;
}

- (void)configureMetalRenderer {
    _metalDevice = MTLCreateSystemDefaultDevice();
    if (_metalDevice == nil) {
        _metalSetupError = @"Metal device is unavailable.";
        return;
    }

    _metalCommandQueue = [_metalDevice newCommandQueue];
    if (_metalCommandQueue == nil) {
        _metalSetupError = @"Metal command queue creation failed.";
        return;
    }

    NSString *shaderSource =
        @"#include <metal_stdlib>\n"
        @"using namespace metal;\n"
        @"struct VertexOut { float4 position [[position]]; float2 texCoord; };\n"
        @"struct YUVUniforms { float yOffset; float yScale; float uvOffset; };\n"
        @"vertex VertexOut vertex_main(uint vertexID [[vertex_id]]) {\n"
        @"    float2 positions[4] = { float2(-1.0, -1.0), float2(1.0, -1.0), float2(-1.0, 1.0), float2(1.0, 1.0) };\n"
        @"    float2 texCoords[4] = { float2(0.0, 1.0), float2(1.0, 1.0), float2(0.0, 0.0), float2(1.0, 0.0) };\n"
        @"    VertexOut out;\n"
        @"    out.position = float4(positions[vertexID], 0.0, 1.0);\n"
        @"    out.texCoord = texCoords[vertexID];\n"
        @"    return out;\n"
        @"}\n"
        @"fragment float4 fragment_main(VertexOut in [[stage_in]],\n"
        @"                              texture2d<float, access::sample> yTexture [[texture(0)]],\n"
        @"                              texture2d<float, access::sample> uvTexture [[texture(1)]],\n"
        @"                              constant YUVUniforms &uniforms [[buffer(0)]]) {\n"
        @"    constexpr sampler textureSampler(address::clamp_to_edge, filter::linear);\n"
        @"    float y = yTexture.sample(textureSampler, in.texCoord).r;\n"
        @"    float2 uv = uvTexture.sample(textureSampler, in.texCoord).rg;\n"
        @"    y = clamp((y - uniforms.yOffset) * uniforms.yScale, 0.0, 1.0);\n"
        @"    float cb = uv.x - uniforms.uvOffset;\n"
        @"    float cr = uv.y - uniforms.uvOffset;\n"
        @"    float3 rgb;\n"
        @"    rgb.r = y + 1.5748 * cr;\n"
        @"    rgb.g = y - 0.1873 * cb - 0.4681 * cr;\n"
        @"    rgb.b = y + 1.8556 * cb;\n"
        @"    return float4(saturate(rgb), 1.0);\n"
        @"}\n";

    NSError *libraryError = nil;
    id<MTLLibrary> library = [_metalDevice newLibraryWithSource:shaderSource
                                                        options:nil
                                                          error:&libraryError];
    if (library == nil) {
        _metalSetupError = [NSString stringWithFormat:@"Metal shader compilation failed: %@", libraryError.localizedDescription];
        return;
    }

    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = [library newFunctionWithName:@"vertex_main"];
    pipelineDescriptor.fragmentFunction = [library newFunctionWithName:@"fragment_main"];
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

    NSError *pipelineError = nil;
    _metalPipelineState = [_metalDevice newRenderPipelineStateWithDescriptor:pipelineDescriptor
                                                                       error:&pipelineError];
    if (_metalPipelineState == nil) {
        _metalSetupError = [NSString stringWithFormat:@"Metal pipeline creation failed: %@", pipelineError.localizedDescription];
        return;
    }

    CVReturn cacheResult = CVMetalTextureCacheCreate(
        kCFAllocatorDefault,
        NULL,
        _metalDevice,
        NULL,
        &_metalTextureCache
    );
    if (cacheResult != kCVReturnSuccess || _metalTextureCache == NULL) {
        _metalSetupError = @"CVMetalTextureCache creation failed.";
        return;
    }

    _metalLayer = [CAMetalLayer layer];
    _metalLayer.device = _metalDevice;
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    _metalLayer.framebufferOnly = YES;
    _metalLayer.opaque = YES;
    _metalLayer.backgroundColor = NSColor.blackColor.CGColor;
    _metalLayer.hidden = YES;
    [self.layer addSublayer:_metalLayer];
}

- (void)layout {
    [super layout];
    _displayLayer.frame = self.bounds;
    _metalLayer.frame = self.bounds;
    [self updateMetalDrawableSize];
}

- (void)flush {
    [_displayLayer flushAndRemoveImage];
    if (_hardwareRenderingEnabled) {
        _metalLayer.hidden = YES;
        _hardwareRenderingEnabled = NO;
    }
}

- (void)setHardwareRenderingEnabled:(BOOL)enabled {
    _hardwareRenderingEnabled = enabled;
    _displayLayer.hidden = enabled;
    _metalLayer.hidden = !enabled;
    if (enabled) {
        [_displayLayer flushAndRemoveImage];
        [self updateMetalDrawableSize];
    }
}

- (void)updateMetalDrawableSize {
    if (_metalLayer == nil) {
        return;
    }

    CGFloat scale = self.window.backingScaleFactor;
    if (scale <= 0) {
        scale = NSScreen.mainScreen.backingScaleFactor;
    }
    if (scale <= 0) {
        scale = 1;
    }

    NSSize size = self.bounds.size;
    _metalLayer.contentsScale = scale;
    _metalLayer.drawableSize = CGSizeMake(
        MAX(1, size.width * scale),
        MAX(1, size.height * scale)
    );
}

- (BOOL)metalFormatsForPixelBuffer:(CVPixelBufferRef)pixelBuffer
                           yFormat:(MTLPixelFormat *)yFormat
                          uvFormat:(MTLPixelFormat *)uvFormat
                          uniforms:(SFXYUVUniforms *)uniforms
                       errorMessage:(NSString **)errorMessage {
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    BOOL fullRange = NO;
    BOOL tenBit = NO;

    switch (pixelFormat) {
    case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
        fullRange = NO;
        tenBit = NO;
        break;
    case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
        fullRange = YES;
        tenBit = NO;
        break;
    case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange:
        fullRange = NO;
        tenBit = YES;
        break;
    case kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
        fullRange = YES;
        tenBit = YES;
        break;
    default:
        if (errorMessage != NULL) {
            *errorMessage = [NSString stringWithFormat:
                @"Unsupported Metal YUV hardware pixel format: 0x%08x.",
                (unsigned int)pixelFormat
            ];
        }
        return NO;
    }

    if (CVPixelBufferGetPlaneCount(pixelBuffer) < 2) {
        if (errorMessage != NULL) {
            *errorMessage = @"Metal YUV hardware rendering requires a bi-planar pixel buffer.";
        }
        return NO;
    }

    *yFormat = tenBit ? MTLPixelFormatR16Unorm : MTLPixelFormatR8Unorm;
    *uvFormat = tenBit ? MTLPixelFormatRG16Unorm : MTLPixelFormatRG8Unorm;

    if (fullRange) {
        *uniforms = (SFXYUVUniforms){0.0f, 1.0f, tenBit ? (512.0f / 1023.0f) : 0.5f};
    } else if (tenBit) {
        *uniforms = (SFXYUVUniforms){64.0f / 1023.0f, 1023.0f / 876.0f, 512.0f / 1023.0f};
    } else {
        *uniforms = (SFXYUVUniforms){16.0f / 255.0f, 255.0f / 219.0f, 128.0f / 255.0f};
    }

    return YES;
}

- (BOOL)renderHardwarePixelBuffer:(CVPixelBufferRef)pixelBuffer errorMessage:(NSString **)errorMessage {
    if (![NSThread isMainThread]) {
        __block BOOL rendered = NO;
        __block NSString *mainErrorMessage = nil;
        CVPixelBufferRetain(pixelBuffer);
        dispatch_sync(dispatch_get_main_queue(), ^{
            rendered = [self renderHardwarePixelBuffer:pixelBuffer errorMessage:&mainErrorMessage];
        });
        CVPixelBufferRelease(pixelBuffer);
        if (!rendered && errorMessage != NULL) {
            *errorMessage = mainErrorMessage;
        }
        return rendered;
    }

    if (![self hasMetalYUVRenderer]) {
        if (errorMessage != NULL) {
            *errorMessage = _metalSetupError ?: @"Metal YUV renderer is unavailable.";
        }
        return NO;
    }

    MTLPixelFormat yFormat = MTLPixelFormatInvalid;
    MTLPixelFormat uvFormat = MTLPixelFormatInvalid;
    SFXYUVUniforms uniforms = {0};
    if (![self metalFormatsForPixelBuffer:pixelBuffer
                                  yFormat:&yFormat
                                 uvFormat:&uvFormat
                                 uniforms:&uniforms
                              errorMessage:errorMessage]) {
        return NO;
    }

    [self setHardwareRenderingEnabled:YES];
    [self updateMetalDrawableSize];

    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    size_t uvWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
    size_t uvHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
    if (width == 0 || height == 0 || uvWidth == 0 || uvHeight == 0) {
        if (errorMessage != NULL) {
            *errorMessage = @"Metal YUV hardware rendering received an empty pixel buffer.";
        }
        return NO;
    }

    CVMetalTextureRef yTextureRef = NULL;
    CVMetalTextureRef uvTextureRef = NULL;
    CVReturn yResult = CVMetalTextureCacheCreateTextureFromImage(
        kCFAllocatorDefault,
        _metalTextureCache,
        pixelBuffer,
        NULL,
        yFormat,
        width,
        height,
        0,
        &yTextureRef
    );
    CVReturn uvResult = CVMetalTextureCacheCreateTextureFromImage(
        kCFAllocatorDefault,
        _metalTextureCache,
        pixelBuffer,
        NULL,
        uvFormat,
        uvWidth,
        uvHeight,
        1,
        &uvTextureRef
    );
    if (yResult != kCVReturnSuccess || uvResult != kCVReturnSuccess || yTextureRef == NULL || uvTextureRef == NULL) {
        if (yTextureRef != NULL) {
            CFRelease(yTextureRef);
        }
        if (uvTextureRef != NULL) {
            CFRelease(uvTextureRef);
        }
        if (errorMessage != NULL) {
            *errorMessage = @"CVMetalTexture creation failed for hardware frame.";
        }
        return NO;
    }

    id<MTLTexture> yTexture = CVMetalTextureGetTexture(yTextureRef);
    id<MTLTexture> uvTexture = CVMetalTextureGetTexture(uvTextureRef);
    id<CAMetalDrawable> drawable = [_metalLayer nextDrawable];
    if (yTexture == nil || uvTexture == nil || drawable == nil) {
        CFRelease(yTextureRef);
        CFRelease(uvTextureRef);
        if (errorMessage != NULL) {
            *errorMessage = @"Metal drawable or texture acquisition failed for hardware frame.";
        }
        return NO;
    }

    MTLRenderPassDescriptor *passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    passDescriptor.colorAttachments[0].texture = drawable.texture;
    passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);

    id<MTLCommandBuffer> commandBuffer = [_metalCommandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
    if (commandBuffer == nil || encoder == nil) {
        CFRelease(yTextureRef);
        CFRelease(uvTextureRef);
        if (errorMessage != NULL) {
            *errorMessage = @"Metal command encoding failed for hardware frame.";
        }
        return NO;
    }

    MTLViewport viewport = [self aspectFitViewportForPixelWidth:width pixelHeight:height];
    [encoder setViewport:viewport];
    [encoder setRenderPipelineState:_metalPipelineState];
    [encoder setFragmentTexture:yTexture atIndex:0];
    [encoder setFragmentTexture:uvTexture atIndex:1];
    [encoder setFragmentBytes:&uniforms length:sizeof(uniforms) atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    [encoder endEncoding];

    CVPixelBufferRetain(pixelBuffer);
    [commandBuffer presentDrawable:drawable];
    [commandBuffer addCompletedHandler:^(__unused id<MTLCommandBuffer> completedBuffer) {
        CFRelease(yTextureRef);
        CFRelease(uvTextureRef);
        CVPixelBufferRelease(pixelBuffer);
    }];
    [commandBuffer commit];
    return YES;
}

- (MTLViewport)aspectFitViewportForPixelWidth:(size_t)pixelWidth pixelHeight:(size_t)pixelHeight {
    CGSize drawableSize = _metalLayer.drawableSize;
    double drawableWidth = drawableSize.width;
    double drawableHeight = drawableSize.height;
    if (drawableWidth <= 0 || drawableHeight <= 0 || pixelWidth == 0 || pixelHeight == 0) {
        return (MTLViewport){0, 0, MAX(1, drawableWidth), MAX(1, drawableHeight), 0, 1};
    }

    double sourceAspect = (double)pixelWidth / (double)pixelHeight;
    double drawableAspect = drawableWidth / drawableHeight;
    double viewportWidth = drawableWidth;
    double viewportHeight = drawableHeight;
    double viewportX = 0;
    double viewportY = 0;
    if (drawableAspect > sourceAspect) {
        viewportWidth = drawableHeight * sourceAspect;
        viewportX = (drawableWidth - viewportWidth) / 2.0;
    } else {
        viewportHeight = drawableWidth / sourceAspect;
        viewportY = (drawableHeight - viewportHeight) / 2.0;
    }

    return (MTLViewport){viewportX, viewportY, viewportWidth, viewportHeight, 0, 1};
}

- (CMSampleBufferRef)sampleBufferForPixelBuffer:(CVPixelBufferRef)pixelBuffer
                               presentationTime:(CMTime)presentationTime {
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

- (void)enqueueSamplePixelBuffer:(CVPixelBufferRef)pixelBuffer presentationTime:(CMTime)presentationTime {
    if (pixelBuffer == NULL || _displayLayer == nil) {
        return;
    }

    if (![NSThread isMainThread]) {
        CVPixelBufferRetain(pixelBuffer);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self enqueueSamplePixelBuffer:pixelBuffer presentationTime:presentationTime];
            CVPixelBufferRelease(pixelBuffer);
        });
        return;
    }

    [self setHardwareRenderingEnabled:NO];

    CVPixelBufferRetain(pixelBuffer);
    AVSampleBufferDisplayLayer *displayLayer = _displayLayer;
    CMSampleBufferRef sampleBuffer = [self sampleBufferForPixelBuffer:pixelBuffer
                                                     presentationTime:presentationTime];
    if (sampleBuffer != NULL) {
        if (displayLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
            [displayLayer flush];
        }
        [displayLayer enqueueSampleBuffer:sampleBuffer];
        CFRelease(sampleBuffer);
    }
    CVPixelBufferRelease(pixelBuffer);
}

- (void)dealloc {
    if (_metalTextureCache != NULL) {
        CFRelease(_metalTextureCache);
        _metalTextureCache = NULL;
    }
}

@end

@class SFXNativePlaybackSession;

@interface SFXNativePlaybackSession : NSObject
- (instancetype)initWithPath:(NSString *)path
           startMilliseconds:(NSInteger)startMilliseconds
                        view:(SFXNativePlaybackView *)playbackView
                    delegate:(id<SFXNativePlaybackPlayerDelegate>)delegate
                      owner:(SFXNativePlaybackPlayer *)owner
                      volume:(float)volume
                playbackRate:(float)playbackRate
                 decodeMode:(SFXNativePlaybackDecodeMode)decodeMode
      flushDisplayBeforeStart:(BOOL)flushDisplayBeforeStart
                       error:(NSError **)error;
- (void)start;
- (void)stopAndWait;
- (void)setPaused:(BOOL)paused;
- (void)setVolume:(float)volume;
- (void)setPlaybackRate:(float)playbackRate;
@property (nonatomic, copy, readonly) NSString *path;
@property (nonatomic, readonly) double currentTime;
@property (nonatomic, readonly) double duration;
@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
@end

@implementation SFXNativePlaybackSession {
    NSString *_path;
    __weak SFXNativePlaybackView *_playbackView;
    __weak id<SFXNativePlaybackPlayerDelegate> _delegate;
    __weak SFXNativePlaybackPlayer *_owner;
    dispatch_queue_t _decodeQueue;

    AVFormatContext *_formatContext;
    AVCodecContext *_videoCodecContext;
    AVCodecContext *_audioCodecContext;
    AVBufferRef *_hardwareDeviceContext;
    AVPacket *_packet;
    AVFrame *_videoFrame;
    AVFrame *_audioFrame;
    AVFrame *_convertedAudioFrame;
    struct SwrContext *_resampler;
    struct SwsContext *_videoScaler;
    AVChannelLayout _outputLayout;
    CVPixelBufferPoolRef _softwarePixelBufferPool;

    AVAudioEngine *_audioEngine;
    AVAudioPlayerNode *_audioPlayer;
    AVAudioUnitTimePitch *_audioTimePitch;
    AVAudioFormat *_audioFormat;

    int _videoStreamIndex;
    int _audioStreamIndex;
    int _audioOutputSampleRate;
    int _audioOutputChannels;
    int _resamplerInputSampleRate;
    int _resamplerInputChannels;
    enum AVSampleFormat _resamplerInputFormat;
    int _videoScalerWidth;
    int _videoScalerHeight;
    enum AVPixelFormat _videoScalerInputFormat;
    int _softwarePixelBufferWidth;
    int _softwarePixelBufferHeight;

    double _seekSeconds;
    double _duration;
    double _currentTime;
    double _audioFirstMediaSeconds;
    double _audioStartHostSeconds;
    double _videoFirstMediaSeconds;
    double _videoStartHostSeconds;
    double _lastDelegateUpdateHostSeconds;
    double _pauseStartedHostSeconds;
    float _volume;
    float _playbackRate;
    SFXNativePlaybackDecodeMode _decodeMode;

    BOOL _flushDisplayBeforeStart;
    BOOL _flushDisplayOnFirstFrame;
    BOOL _usingHardwareDecode;
    BOOL _audioClockInitialized;
    BOOL _audioPlayerStarted;
    BOOL _videoClockInitialized;
    BOOL _isPausedInsideLoop;
    atomic_bool _cancelled;
    atomic_bool _paused;
    atomic_bool _playing;
}

- (instancetype)initWithPath:(NSString *)path
           startMilliseconds:(NSInteger)startMilliseconds
                        view:(SFXNativePlaybackView *)playbackView
                    delegate:(id<SFXNativePlaybackPlayerDelegate>)delegate
                      owner:(SFXNativePlaybackPlayer *)owner
                      volume:(float)volume
                playbackRate:(float)playbackRate
                 decodeMode:(SFXNativePlaybackDecodeMode)decodeMode
      flushDisplayBeforeStart:(BOOL)flushDisplayBeforeStart
                       error:(NSError **)error {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    _path = [path copy];
    _playbackView = playbackView;
    _delegate = delegate;
    _owner = owner;
    _volume = volume;
    _playbackRate = SFXClampedPlaybackRate(playbackRate);
    _decodeMode = decodeMode;
    _flushDisplayBeforeStart = flushDisplayBeforeStart;
    _flushDisplayOnFirstFrame = !flushDisplayBeforeStart;
    _seekSeconds = MAX(0, (double)startMilliseconds / 1000.0);
    _currentTime = _seekSeconds;
    _videoStreamIndex = -1;
    _audioStreamIndex = -1;
    _decodeQueue = dispatch_queue_create("SubFinderX.NativePlayback.Decode", DISPATCH_QUEUE_SERIAL);
    atomic_init(&_cancelled, false);
    atomic_init(&_paused, false);
    atomic_init(&_playing, false);

    if (![self prepareWithError:error]) {
        [self teardown];
        return nil;
    }

    return self;
}

- (NSString *)path {
    return _path;
}

- (double)currentTime {
    @synchronized (self) {
        return _currentTime;
    }
}

- (double)duration {
    return _duration;
}

- (BOOL)isPlaying {
    return atomic_load(&_playing);
}

- (BOOL)prepareWithError:(NSError **)error {
    int result = avformat_open_input(&_formatContext, _path.UTF8String, NULL, NULL);
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(10, [NSString stringWithFormat:@"avformat_open_input failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    result = avformat_find_stream_info(_formatContext, NULL);
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(11, [NSString stringWithFormat:@"avformat_find_stream_info failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    if (_formatContext->duration != AV_NOPTS_VALUE) {
        _duration = (double)_formatContext->duration / AV_TIME_BASE;
    }

    for (unsigned int index = 0; index < _formatContext->nb_streams; index++) {
        AVStream *stream = _formatContext->streams[index];
        if (_videoStreamIndex < 0 && stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            _videoStreamIndex = (int)index;
        } else if (_audioStreamIndex < 0 && stream->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            _audioStreamIndex = (int)index;
        }
    }

    if (_videoStreamIndex < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(12, @"No video stream found.");
        }
        return NO;
    }

    if (![self prepareVideoWithError:error]) {
        return NO;
    }

    if (_audioStreamIndex >= 0 && ![self prepareAudioWithError:error]) {
        return NO;
    }

    _packet = av_packet_alloc();
    _videoFrame = av_frame_alloc();
    if (_packet == NULL || _videoFrame == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(13, @"Could not allocate native playback packet or frame.");
        }
        return NO;
    }

    if (!SFXSeekToStartPosition(_formatContext, _videoStreamIndex, _seekSeconds, error)) {
        return NO;
    }

    avcodec_flush_buffers(_videoCodecContext);
    if (_audioCodecContext != NULL) {
        avcodec_flush_buffers(_audioCodecContext);
    }

    if (_flushDisplayBeforeStart) {
        SFXDispatchSyncOnMain(^{
            [_playbackView flush];
        });
    }

    return YES;
}

- (BOOL)prepareVideoWithError:(NSError **)error {
    switch (_decodeMode) {
    case SFXNativePlaybackDecodeModeHardware:
        return [self prepareHardwareVideoWithError:error];
    case SFXNativePlaybackDecodeModeSoftware:
        return [self prepareSoftwareVideoWithError:error];
    case SFXNativePlaybackDecodeModeAuto: {
        NSError *hardwareError = nil;
        if ([self prepareHardwareVideoWithError:&hardwareError]) {
            return YES;
        }

        [self resetVideoDecoderState];

        NSError *softwareError = nil;
        if ([self prepareSoftwareVideoWithError:&softwareError]) {
            return YES;
        }

        if (error != NULL) {
            NSString *hardwareMessage = hardwareError.localizedDescription ?: @"unknown hardware decoder error";
            NSString *softwareMessage = softwareError.localizedDescription ?: @"unknown software decoder error";
            *error = SFXNativePlaybackError(
                27,
                [NSString stringWithFormat:
                    @"Auto video decoder failed. Hardware: %@ Software: %@",
                    hardwareMessage,
                    softwareMessage
                ]
            );
        }
        return NO;
    }
    }

    return NO;
}

- (void)resetVideoDecoderState {
    avcodec_free_context(&_videoCodecContext);
    av_buffer_unref(&_hardwareDeviceContext);
    SFXHardwarePixelFormat = AV_PIX_FMT_NONE;
    _usingHardwareDecode = NO;
}

- (BOOL)prepareHardwareVideoWithError:(NSError **)error {
    if (![_playbackView hasMetalYUVRenderer]) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(19, @"Metal YUV renderer is unavailable for hardware playback.");
        }
        return NO;
    }

    AVStream *videoStream = _formatContext->streams[_videoStreamIndex];
    AVCodecParameters *parameters = videoStream->codecpar;
    const AVCodecHWConfig *hardwareConfig = NULL;
    const AVCodec *decoder = SFXFindVideoToolboxDecoder(parameters->codec_id, &hardwareConfig);
    if (decoder == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(20, @"No FFmpeg video decoder found.");
        }
        return NO;
    }

    if (hardwareConfig == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(
                21,
                [NSString stringWithFormat:
                    @"No VideoToolbox-capable FFmpeg video decoder found for %@.",
                    [NSString stringWithUTF8String:avcodec_get_name(parameters->codec_id)]
                ]
            );
        }
        return NO;
    }
    SFXHardwarePixelFormat = hardwareConfig->pix_fmt;

    int result = av_hwdevice_ctx_create(
        &_hardwareDeviceContext,
        AV_HWDEVICE_TYPE_VIDEOTOOLBOX,
        NULL,
        NULL,
        0
    );
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(22, [NSString stringWithFormat:@"VideoToolbox device creation failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    _videoCodecContext = avcodec_alloc_context3(decoder);
    if (_videoCodecContext == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(23, @"Could not allocate video decoder context.");
        }
        return NO;
    }

    result = avcodec_parameters_to_context(_videoCodecContext, parameters);
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(24, [NSString stringWithFormat:@"Video codec parameter copy failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    _videoCodecContext->get_format = SFXChooseHardwareFormat;
    _videoCodecContext->hw_device_ctx = av_buffer_ref(_hardwareDeviceContext);
    if (_videoCodecContext->hw_device_ctx == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(25, @"Could not attach VideoToolbox device context.");
        }
        return NO;
    }

    result = avcodec_open2(_videoCodecContext, decoder, NULL);
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(26, [NSString stringWithFormat:@"Video decoder open failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    _usingHardwareDecode = YES;
    SFXDispatchSyncOnMain(^{
        [_playbackView setHardwareRenderingEnabled:YES];
    });
    return YES;
}

- (BOOL)prepareSoftwareVideoWithError:(NSError **)error {
    AVStream *videoStream = _formatContext->streams[_videoStreamIndex];
    AVCodecParameters *parameters = videoStream->codecpar;
    const AVCodec *decoder = SFXFindSoftwareVideoDecoder(parameters->codec_id);
    if (decoder == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(
                28,
                [NSString stringWithFormat:
                    @"No FFmpeg software video decoder found for %@.",
                    [NSString stringWithUTF8String:avcodec_get_name(parameters->codec_id)]
                ]
            );
        }
        return NO;
    }

    _videoCodecContext = avcodec_alloc_context3(decoder);
    if (_videoCodecContext == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(23, @"Could not allocate video decoder context.");
        }
        return NO;
    }

    int result = avcodec_parameters_to_context(_videoCodecContext, parameters);
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(24, [NSString stringWithFormat:@"Video codec parameter copy failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    _videoCodecContext->thread_count = 0;
    _videoCodecContext->thread_type = FF_THREAD_FRAME | FF_THREAD_SLICE;

    result = avcodec_open2(_videoCodecContext, decoder, NULL);
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(26, [NSString stringWithFormat:@"Software video decoder open failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    _usingHardwareDecode = NO;
    SFXHardwarePixelFormat = AV_PIX_FMT_NONE;
    SFXDispatchSyncOnMain(^{
        [_playbackView setHardwareRenderingEnabled:NO];
    });
    return YES;
}

- (BOOL)prepareAudioWithError:(NSError **)error {
    AVStream *audioStream = _formatContext->streams[_audioStreamIndex];
    AVCodecParameters *parameters = audioStream->codecpar;
    const AVCodec *decoder = avcodec_find_decoder(parameters->codec_id);
    if (decoder == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(30, @"No FFmpeg audio decoder found.");
        }
        return NO;
    }

    _audioCodecContext = avcodec_alloc_context3(decoder);
    _audioFrame = av_frame_alloc();
    _convertedAudioFrame = av_frame_alloc();
    if (_audioCodecContext == NULL || _audioFrame == NULL || _convertedAudioFrame == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(31, @"Could not allocate audio decoder context.");
        }
        return NO;
    }

    int result = avcodec_parameters_to_context(_audioCodecContext, parameters);
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(32, [NSString stringWithFormat:@"Audio codec parameter copy failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    result = avcodec_open2(_audioCodecContext, decoder, NULL);
    if (result < 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(33, [NSString stringWithFormat:@"Audio decoder open failed: %@", SFXFFmpegErrorString(result)]);
        }
        return NO;
    }

    int inputChannels = _audioCodecContext->ch_layout.nb_channels;
    _audioOutputChannels = SFXOutputChannelCount(inputChannels);
    _audioOutputSampleRate = _audioCodecContext->sample_rate > 0 ? _audioCodecContext->sample_rate : 48000;
    if (_audioOutputChannels <= 0) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(34, @"Could not determine native audio output channel count.");
        }
        return NO;
    }
    av_channel_layout_default(&_outputLayout, _audioOutputChannels);

    _audioEngine = [[AVAudioEngine alloc] init];
    _audioPlayer = [[AVAudioPlayerNode alloc] init];
    _audioTimePitch = [[AVAudioUnitTimePitch alloc] init];
    _audioPlayer.volume = _volume;
    _audioTimePitch.rate = _playbackRate;
    _audioFormat = [[AVAudioFormat alloc]
        initStandardFormatWithSampleRate:(double)_audioOutputSampleRate
        channels:(AVAudioChannelCount)_audioOutputChannels
    ];

    if (_audioEngine == nil || _audioPlayer == nil || _audioTimePitch == nil || _audioFormat == nil) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(35, @"Could not create AVAudioEngine output objects.");
        }
        return NO;
    }

    [_audioEngine attachNode:_audioPlayer];
    [_audioEngine attachNode:_audioTimePitch];
    [_audioEngine connect:_audioPlayer to:_audioTimePitch format:_audioFormat];
    [_audioEngine connect:_audioTimePitch to:_audioEngine.mainMixerNode format:_audioFormat];

    NSError *audioError = nil;
    if (![_audioEngine startAndReturnError:&audioError]) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(
                36,
                [NSString stringWithFormat:@"AVAudioEngine start failed: %@", audioError.localizedDescription]
            );
        }
        return NO;
    }

    return YES;
}

- (void)start {
    dispatch_async(_decodeQueue, ^{
        @autoreleasepool {
            [self decodeLoop];
            [self teardown];
        }
    });
}

- (void)stopAndWait {
    atomic_store(&_cancelled, true);
    atomic_store(&_paused, false);

    if (_decodeQueue != NULL) {
        dispatch_sync(_decodeQueue, ^{});
    }
}

- (void)setPaused:(BOOL)paused {
    atomic_store(&_paused, paused);
    atomic_store(&_playing, !paused);

    AVAudioPlayerNode *audioPlayer = _audioPlayer;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (paused) {
            [audioPlayer pause];
        } else if (audioPlayer != nil && _audioPlayerStarted) {
            [audioPlayer play];
        }
    });

    [self notifyTimeIfNeeded:YES];
}

- (void)setVolume:(float)volume {
    _volume = volume;
    AVAudioPlayerNode *audioPlayer = _audioPlayer;
    dispatch_async(dispatch_get_main_queue(), ^{
        audioPlayer.volume = volume;
    });
}

- (void)setPlaybackRate:(float)playbackRate {
    float clampedRate = SFXClampedPlaybackRate(playbackRate);
    double hostSeconds = CACurrentMediaTime();

    @synchronized (self) {
        [self rebasePlaybackClocksLockedAtHostSeconds:hostSeconds];
        _playbackRate = clampedRate;
        if (_isPausedInsideLoop) {
            _pauseStartedHostSeconds = hostSeconds;
        }
    }

    AVAudioUnitTimePitch *audioTimePitch = _audioTimePitch;
    dispatch_async(dispatch_get_main_queue(), ^{
        audioTimePitch.rate = clampedRate;
    });
}

- (void)rebasePlaybackClocksLockedAtHostSeconds:(double)hostSeconds {
    if (_audioClockInitialized) {
        _audioFirstMediaSeconds = [self mediaSecondsForClockLockedWithFirstMediaSeconds:_audioFirstMediaSeconds
                                                                      startHostSeconds:_audioStartHostSeconds
                                                                            hostSeconds:hostSeconds];
        _audioStartHostSeconds = hostSeconds;
    }

    if (_videoClockInitialized) {
        _videoFirstMediaSeconds = [self mediaSecondsForClockLockedWithFirstMediaSeconds:_videoFirstMediaSeconds
                                                                      startHostSeconds:_videoStartHostSeconds
                                                                            hostSeconds:hostSeconds];
        _videoStartHostSeconds = hostSeconds;
    }
}

- (double)mediaSecondsForClockLockedWithFirstMediaSeconds:(double)firstMediaSeconds
                                         startHostSeconds:(double)startHostSeconds
                                              hostSeconds:(double)hostSeconds {
    if (atomic_load(&_paused) || _isPausedInsideLoop) {
        return _currentTime;
    }

    double elapsedHostSeconds = fmax(0, hostSeconds - startHostSeconds);
    return firstMediaSeconds + (elapsedHostSeconds * _playbackRate);
}

- (void)decodeLoop {
    atomic_store(&_playing, true);
    [self notifyTimeIfNeeded:YES];

    while (!atomic_load(&_cancelled)) {
        [self waitWhilePausedIfNeeded];
        if (atomic_load(&_cancelled)) {
            break;
        }

        int result = av_read_frame(_formatContext, _packet);
        if (result < 0) {
            break;
        }

        if (_packet->stream_index == _audioStreamIndex && _audioCodecContext != NULL) {
            [self handleAudioPacket:_packet];
            av_packet_unref(_packet);
            continue;
        }

        if (_packet->stream_index == _videoStreamIndex) {
            [self handleVideoPacket:_packet];
        }

        av_packet_unref(_packet);
    }

    BOOL cancelled = atomic_load(&_cancelled);
    atomic_store(&_playing, false);
    if (!cancelled) {
        [self notifyTimeIfNeeded:YES];
    }
}

- (void)waitWhilePausedIfNeeded {
    if (!atomic_load(&_paused)) {
        if (_isPausedInsideLoop) {
            double pauseDuration = CACurrentMediaTime() - _pauseStartedHostSeconds;
            @synchronized (self) {
                _audioStartHostSeconds += pauseDuration;
                _videoStartHostSeconds += pauseDuration;
                _isPausedInsideLoop = NO;
            }

            AVAudioPlayerNode *audioPlayer = _audioPlayer;
            if (_audioPlayerStarted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [audioPlayer play];
                });
            }
        }
        return;
    }

    if (!_isPausedInsideLoop) {
        @synchronized (self) {
            _isPausedInsideLoop = YES;
            _pauseStartedHostSeconds = CACurrentMediaTime();
        }
        AVAudioPlayerNode *audioPlayer = _audioPlayer;
        dispatch_async(dispatch_get_main_queue(), ^{
            [audioPlayer pause];
        });
    }

    while (atomic_load(&_paused) && !atomic_load(&_cancelled)) {
        usleep(20 * 1000);
    }
}

- (BOOL)ensureSoftwareVideoScalerForFrame:(AVFrame *)frame width:(int)width height:(int)height {
    enum AVPixelFormat inputFormat = (enum AVPixelFormat)frame->format;
    if (_videoScaler != NULL
        && _videoScalerWidth == width
        && _videoScalerHeight == height
        && _videoScalerInputFormat == inputFormat) {
        return YES;
    }

    sws_freeContext(_videoScaler);
    _videoScaler = sws_getContext(
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

    if (_videoScaler == NULL) {
        _videoScalerWidth = 0;
        _videoScalerHeight = 0;
        _videoScalerInputFormat = AV_PIX_FMT_NONE;
        return NO;
    }

    _videoScalerWidth = width;
    _videoScalerHeight = height;
    _videoScalerInputFormat = inputFormat;
    return YES;
}

- (BOOL)ensureSoftwarePixelBufferPoolWithWidth:(int)width height:(int)height {
    if (_softwarePixelBufferPool != NULL
        && _softwarePixelBufferWidth == width
        && _softwarePixelBufferHeight == height) {
        return YES;
    }

    if (_softwarePixelBufferPool != NULL) {
        CVPixelBufferPoolRelease(_softwarePixelBufferPool);
        _softwarePixelBufferPool = NULL;
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

    if (pixelFormatNumber == NULL || widthNumber == NULL || heightNumber == NULL || ioSurfaceProperties == NULL) {
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
        return NO;
    }

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
    CFDictionaryRef attributes = CFDictionaryCreate(
        kCFAllocatorDefault,
        keys,
        values,
        4,
        &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks
    );

    CFRelease(pixelFormatNumber);
    CFRelease(widthNumber);
    CFRelease(heightNumber);
    CFRelease(ioSurfaceProperties);

    if (attributes == NULL) {
        return NO;
    }

    CVReturn result = CVPixelBufferPoolCreate(
        kCFAllocatorDefault,
        NULL,
        attributes,
        &_softwarePixelBufferPool
    );
    CFRelease(attributes);

    if (result != kCVReturnSuccess || _softwarePixelBufferPool == NULL) {
        _softwarePixelBufferWidth = 0;
        _softwarePixelBufferHeight = 0;
        return NO;
    }

    _softwarePixelBufferWidth = width;
    _softwarePixelBufferHeight = height;
    return YES;
}

- (CVPixelBufferRef)copyPixelBufferForSoftwareFrame:(AVFrame *)frame {
    int width = frame->width > 0 ? frame->width : _videoCodecContext->width;
    int height = frame->height > 0 ? frame->height : _videoCodecContext->height;
    enum AVPixelFormat inputFormat = (enum AVPixelFormat)frame->format;
    if (width <= 0
        || height <= 0
        || inputFormat == AV_PIX_FMT_NONE
        || av_pix_fmt_desc_get(inputFormat) == NULL) {
        return NULL;
    }

    if (![self ensureSoftwareVideoScalerForFrame:frame width:width height:height]
        || ![self ensureSoftwarePixelBufferPoolWithWidth:width height:height]) {
        return NULL;
    }

    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn createResult = CVPixelBufferPoolCreatePixelBuffer(
        kCFAllocatorDefault,
        _softwarePixelBufferPool,
        &pixelBuffer
    );
    if (createResult != kCVReturnSuccess || pixelBuffer == NULL) {
        return NULL;
    }

    CVReturn lockResult = CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    if (lockResult != kCVReturnSuccess) {
        CVPixelBufferRelease(pixelBuffer);
        return NULL;
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
        _videoScaler,
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
        return NULL;
    }

    return pixelBuffer;
}

- (void)handleVideoPacket:(AVPacket *)packet {
    int result = avcodec_send_packet(_videoCodecContext, packet);
    if (result < 0) {
        return;
    }

    AVStream *videoStream = _formatContext->streams[_videoStreamIndex];
    while ((result = avcodec_receive_frame(_videoCodecContext, _videoFrame)) >= 0) {
        if (SFXFrameBeforeSeekTarget(_videoFrame, videoStream, _seekSeconds)) {
            av_frame_unref(_videoFrame);
            continue;
        }

        if (_videoFrame->format == SFXHardwarePixelFormat) {
            [self paceVideoFrame:_videoFrame stream:videoStream];
            CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)_videoFrame->data[3];
            NSString *renderErrorMessage = nil;
            if (![_playbackView renderHardwarePixelBuffer:pixelBuffer errorMessage:&renderErrorMessage]) {
                [self notifyFailure:renderErrorMessage ?: @"Metal YUV hardware frame rendering failed."];
                atomic_store(&_cancelled, true);
                av_frame_unref(_videoFrame);
                break;
            }
        } else if (_usingHardwareDecode) {
            NSString *formatName = SFXPixelFormatName((enum AVPixelFormat)_videoFrame->format);
            [self notifyFailure:[NSString stringWithFormat:
                @"Hardware decoder returned unsupported frame format %@.",
                formatName
            ]];
            atomic_store(&_cancelled, true);
            av_frame_unref(_videoFrame);
            break;
        } else if (!_usingHardwareDecode) {
            [self paceVideoFrame:_videoFrame stream:videoStream];
            CVPixelBufferRef pixelBuffer = [self copyPixelBufferForSoftwareFrame:_videoFrame];
            if (pixelBuffer == NULL) {
                NSString *formatName = SFXPixelFormatName((enum AVPixelFormat)_videoFrame->format);
                [self notifyFailure:[NSString stringWithFormat:
                    @"Software video frame conversion failed for %@.",
                    formatName
                ]];
                atomic_store(&_cancelled, true);
                av_frame_unref(_videoFrame);
                break;
            }

            [self enqueuePixelBuffer:pixelBuffer presentationTime:SFXFramePresentationTime(_videoFrame, videoStream)];
            CVPixelBufferRelease(pixelBuffer);
        }

        double mediaSeconds = SFXFramePlaybackSeconds(_videoFrame, videoStream);
        if (mediaSeconds >= 0) {
            @synchronized (self) {
                _currentTime = mediaSeconds;
            }
            [self notifyTimeIfNeeded:NO];
        }

        av_frame_unref(_videoFrame);
    }
}

- (void)handleAudioPacket:(AVPacket *)packet {
    int result = avcodec_send_packet(_audioCodecContext, packet);
    if (result < 0) {
        return;
    }

    AVStream *audioStream = _formatContext->streams[_audioStreamIndex];
    while ((result = avcodec_receive_frame(_audioCodecContext, _audioFrame)) >= 0) {
        if (SFXFrameBeforeSeekTarget(_audioFrame, audioStream, _seekSeconds)) {
            av_frame_unref(_audioFrame);
            continue;
        }

        double mediaSeconds = SFXFramePlaybackSeconds(_audioFrame, audioStream);
        const AVFrame *outputFrame = [self outputAudioFrameForFrame:_audioFrame];
        if (outputFrame != NULL) {
            [self scheduleAudioFrame:outputFrame mediaSeconds:mediaSeconds];
        }

        av_frame_unref(_audioFrame);
    }
}

- (void)paceVideoFrame:(AVFrame *)frame stream:(AVStream *)stream {
    double mediaSeconds = SFXFramePlaybackSeconds(frame, stream);
    if (mediaSeconds < 0) {
        return;
    }

    double now = CACurrentMediaTime();
    double targetHostSeconds = 0;
    @synchronized (self) {
        double rate = fmax((double)_playbackRate, 0.001);
        if (_audioClockInitialized) {
            targetHostSeconds = _audioStartHostSeconds + ((mediaSeconds - _audioFirstMediaSeconds) / rate);
        } else if (!_videoClockInitialized) {
            _videoClockInitialized = YES;
            _videoFirstMediaSeconds = mediaSeconds;
            _videoStartHostSeconds = now;
            return;
        } else {
            targetHostSeconds = _videoStartHostSeconds + ((mediaSeconds - _videoFirstMediaSeconds) / rate);
        }
    }

    double waitSeconds = targetHostSeconds - now;
    if (waitSeconds > 0) {
        double cappedWait = waitSeconds > 0.25 ? 0.25 : waitSeconds;
        usleep((useconds_t)(cappedWait * 1000000.0));
    }
}

- (void)enqueuePixelBuffer:(CVPixelBufferRef)pixelBuffer presentationTime:(CMTime)presentationTime {
    if (pixelBuffer == NULL || _playbackView == nil) {
        return;
    }

    if (_flushDisplayOnFirstFrame) {
        SFXDispatchSyncOnMain(^{
            [_playbackView flush];
        });
        _flushDisplayOnFirstFrame = NO;
    }

    [_playbackView enqueueSamplePixelBuffer:pixelBuffer presentationTime:presentationTime];
}

- (int)audioFrameSampleRate:(const AVFrame *)frame {
    if (frame->sample_rate > 0) {
        return frame->sample_rate;
    }
    return _audioCodecContext->sample_rate > 0 ? _audioCodecContext->sample_rate : _audioOutputSampleRate;
}

- (int)audioFrameChannelCount:(const AVFrame *)frame {
    if (frame->ch_layout.nb_channels > 0) {
        return frame->ch_layout.nb_channels;
    }
    return _audioCodecContext->ch_layout.nb_channels;
}

- (BOOL)audioFrameMatchesOutput:(const AVFrame *)frame {
    return frame->format == AV_SAMPLE_FMT_FLTP
        && [self audioFrameSampleRate:frame] == _audioOutputSampleRate
        && [self audioFrameChannelCount:frame] == _audioOutputChannels;
}

- (BOOL)ensureResamplerForFrame:(const AVFrame *)frame {
    int inputSampleRate = [self audioFrameSampleRate:frame];
    int inputChannels = [self audioFrameChannelCount:frame];
    enum AVSampleFormat inputFormat = (enum AVSampleFormat)frame->format;
    if (inputSampleRate <= 0 || inputChannels <= 0 || inputFormat == AV_SAMPLE_FMT_NONE) {
        return NO;
    }

    if (_resampler != NULL
        && _resamplerInputSampleRate == inputSampleRate
        && _resamplerInputChannels == inputChannels
        && _resamplerInputFormat == inputFormat) {
        return YES;
    }

    swr_free(&_resampler);

    AVChannelLayout inputLayout = {0};
    BOOL ownsInputLayout = NO;
    const AVChannelLayout *inputLayoutRef = &frame->ch_layout;
    if (frame->ch_layout.nb_channels <= 0) {
        av_channel_layout_default(&inputLayout, inputChannels);
        inputLayoutRef = &inputLayout;
        ownsInputLayout = YES;
    }

    int result = swr_alloc_set_opts2(
        &_resampler,
        &_outputLayout,
        AV_SAMPLE_FMT_FLTP,
        _audioOutputSampleRate,
        inputLayoutRef,
        inputFormat,
        inputSampleRate,
        0,
        NULL
    );

    if (ownsInputLayout) {
        av_channel_layout_uninit(&inputLayout);
    }

    if (result < 0 || _resampler == NULL) {
        swr_free(&_resampler);
        return NO;
    }

    result = swr_init(_resampler);
    if (result < 0) {
        swr_free(&_resampler);
        return NO;
    }

    _resamplerInputSampleRate = inputSampleRate;
    _resamplerInputChannels = inputChannels;
    _resamplerInputFormat = inputFormat;
    return YES;
}

- (const AVFrame *)outputAudioFrameForFrame:(const AVFrame *)frame {
    if ([self audioFrameMatchesOutput:frame]) {
        return frame;
    }

    if (![self ensureResamplerForFrame:frame]) {
        return NULL;
    }

    av_frame_unref(_convertedAudioFrame);
    if (av_channel_layout_copy(&_convertedAudioFrame->ch_layout, &_outputLayout) < 0) {
        return NULL;
    }

    int inputSampleRate = [self audioFrameSampleRate:frame];
    _convertedAudioFrame->format = AV_SAMPLE_FMT_FLTP;
    _convertedAudioFrame->sample_rate = _audioOutputSampleRate;
    _convertedAudioFrame->nb_samples = (int)av_rescale_rnd(
        frame->nb_samples,
        _audioOutputSampleRate,
        inputSampleRate,
        AV_ROUND_UP
    ) + 256;

    int result = swr_convert_frame(_resampler, _convertedAudioFrame, frame);
    if (result < 0) {
        av_frame_unref(_convertedAudioFrame);
        return NULL;
    }

    return _convertedAudioFrame;
}

- (void)scheduleAudioFrame:(const AVFrame *)frame mediaSeconds:(double)mediaSeconds {
    if (_audioPlayer == nil || _audioFormat == nil || frame->format != AV_SAMPLE_FMT_FLTP) {
        return;
    }

    int channels = frame->ch_layout.nb_channels;
    if (channels <= 0 || channels > (int)_audioFormat.channelCount) {
        return;
    }

    AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc]
        initWithPCMFormat:_audioFormat
        frameCapacity:(AVAudioFrameCount)frame->nb_samples
    ];
    if (buffer == nil || buffer.floatChannelData == NULL) {
        return;
    }

    buffer.frameLength = (AVAudioFrameCount)frame->nb_samples;
    for (int channel = 0; channel < channels; channel++) {
        memcpy(
            buffer.floatChannelData[channel],
            frame->extended_data[channel],
            sizeof(float) * (size_t)frame->nb_samples
        );
    }

    [_audioPlayer scheduleBuffer:buffer completionHandler:nil];

    if (!_audioPlayerStarted) {
        if (mediaSeconds >= 0) {
            @synchronized (self) {
                if (!_audioClockInitialized) {
                    _audioClockInitialized = YES;
                    _audioFirstMediaSeconds = mediaSeconds;
                    _audioStartHostSeconds = CACurrentMediaTime();
                }
            }
        }

        _audioPlayerStarted = YES;
        AVAudioPlayerNode *audioPlayer = _audioPlayer;
        dispatch_async(dispatch_get_main_queue(), ^{
            [audioPlayer play];
        });
    }
}

- (void)notifyTimeIfNeeded:(BOOL)force {
    double now = CACurrentMediaTime();
    if (!force && now - _lastDelegateUpdateHostSeconds < 0.25) {
        return;
    }
    _lastDelegateUpdateHostSeconds = now;

    double currentTime = self.currentTime;
    double duration = _duration;
    BOOL playing = self.isPlaying;
    id<SFXNativePlaybackPlayerDelegate> delegate = _delegate;
    SFXNativePlaybackPlayer *owner = _owner;

    dispatch_async(dispatch_get_main_queue(), ^{
        [delegate nativePlaybackPlayer:owner
                         didUpdateTime:currentTime
                              duration:duration
                               playing:playing];
    });
}

- (void)notifyFailure:(NSString *)message {
    id<SFXNativePlaybackPlayerDelegate> delegate = _delegate;
    SFXNativePlaybackPlayer *owner = _owner;
    dispatch_async(dispatch_get_main_queue(), ^{
        [delegate nativePlaybackPlayer:owner didFailWithMessage:message];
    });
}

- (void)teardown {
    AVAudioPlayerNode *audioPlayer = _audioPlayer;
    AVAudioEngine *audioEngine = _audioEngine;
    dispatch_async(dispatch_get_main_queue(), ^{
        [audioPlayer stop];
        [audioEngine stop];
    });

    swr_free(&_resampler);
    sws_freeContext(_videoScaler);
    _videoScaler = NULL;
    if (_softwarePixelBufferPool != NULL) {
        CVPixelBufferPoolRelease(_softwarePixelBufferPool);
        _softwarePixelBufferPool = NULL;
    }
    av_channel_layout_uninit(&_outputLayout);
    av_frame_free(&_convertedAudioFrame);
    av_frame_free(&_audioFrame);
    av_frame_free(&_videoFrame);
    av_packet_free(&_packet);
    avcodec_free_context(&_audioCodecContext);
    avcodec_free_context(&_videoCodecContext);
    av_buffer_unref(&_hardwareDeviceContext);
    avformat_close_input(&_formatContext);

    _audioPlayer = nil;
    _audioTimePitch = nil;
    _audioEngine = nil;
    _audioFormat = nil;
}

@end

@implementation SFXNativePlaybackPlayer {
    SFXNativePlaybackView *_nativeView;
    SFXNativePlaybackSession *_session;
    NSString *_currentPath;
    float _volume;
    float _playbackRate;
    SFXNativePlaybackDecodeMode _decodeMode;
}

- (instancetype)init {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    av_log_set_level(AV_LOG_ERROR);

    _volume = 1.0;
    _playbackRate = 1.0;
    _decodeMode = SFXNativePlaybackDecodeModeAuto;
    _nativeView = [[SFXNativePlaybackView alloc] initWithFrame:NSZeroRect];
    return self;
}

- (NSView *)view {
    return _nativeView;
}

- (NSString *)currentPath {
    return _currentPath;
}

- (double)currentTime {
    return _session.currentTime;
}

- (double)duration {
    return _session.duration;
}

- (BOOL)isPlaying {
    return _session.isPlaying;
}

- (float)volume {
    return _volume;
}

- (float)playbackRate {
    return _playbackRate;
}

- (SFXNativePlaybackDecodeMode)decodeMode {
    return _decodeMode;
}

- (void)setVolume:(float)volume {
    _volume = fmaxf(0.0, fminf(volume, 1.0));
    [_session setVolume:_volume];
}

- (void)setPlaybackRate:(float)playbackRate {
    _playbackRate = SFXClampedPlaybackRate(playbackRate);
    [_session setPlaybackRate:_playbackRate];
}

- (void)setDecodeMode:(SFXNativePlaybackDecodeMode)decodeMode {
    switch (decodeMode) {
    case SFXNativePlaybackDecodeModeHardware:
    case SFXNativePlaybackDecodeModeSoftware:
    case SFXNativePlaybackDecodeModeAuto:
        _decodeMode = decodeMode;
        break;
    default:
        _decodeMode = SFXNativePlaybackDecodeModeAuto;
        break;
    }
}

- (BOOL)openPath:(NSString *)path
startMilliseconds:(NSInteger)startMilliseconds
           error:(NSError **)error {
    return [self openPath:path
        startMilliseconds:startMilliseconds
       flushDisplayBeforeStart:NO
                    error:error];
}

- (BOOL)openPath:(NSString *)path
startMilliseconds:(NSInteger)startMilliseconds
flushDisplayBeforeStart:(BOOL)flushDisplayBeforeStart
           error:(NSError **)error {
    [self stopAndFlushDisplay:flushDisplayBeforeStart];

    SFXNativePlaybackSession *session = [[SFXNativePlaybackSession alloc]
        initWithPath:path
        startMilliseconds:startMilliseconds
        view:_nativeView
        delegate:self.delegate
        owner:self
        volume:_volume
        playbackRate:_playbackRate
        decodeMode:_decodeMode
        flushDisplayBeforeStart:flushDisplayBeforeStart
        error:error
    ];
    if (session == nil) {
        return NO;
    }

    _session = session;
    _currentPath = [path copy];
    [_session start];
    return YES;
}

- (BOOL)seekToMilliseconds:(NSInteger)milliseconds error:(NSError **)error {
    if (_currentPath == nil) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(40, @"Native playback has no current file to seek.");
        }
        return NO;
    }

    return [self openPath:_currentPath
        startMilliseconds:milliseconds
       flushDisplayBeforeStart:NO
                    error:error];
}

- (BOOL)setPaused:(BOOL)paused error:(NSError **)error {
    if (_session == nil) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(41, @"Native playback has no active session.");
        }
        return NO;
    }

    [_session setPaused:paused];
    return YES;
}

- (void)stop {
    [self stopAndFlushDisplay:YES];
}

- (void)stopAndFlushDisplay:(BOOL)flushDisplay {
    [_session stopAndWait];
    _session = nil;
    _currentPath = nil;
    if (flushDisplay) {
        [_nativeView flush];
    }
}

@end
