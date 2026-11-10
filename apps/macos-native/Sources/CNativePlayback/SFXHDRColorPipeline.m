#import "SFXNativePlaybackInternal.h"

#import <Accelerate/Accelerate.h>
#import <CoreImage/CoreImage.h>
#import <IOSurface/IOSurface.h>
#import <Metal/Metal.h>
#import <dlfcn.h>
#import <mach/mach_time.h>
#import <os/lock.h>
#import <stdatomic.h>

#if defined(__aarch64__)
#include <arm_neon.h>
#endif

#include <libavutil/ambient_viewing_environment.h>
#include <libavutil/dovi_meta.h>
#include <libavutil/hdr_dynamic_metadata.h>
#include <libavutil/mastering_display_metadata.h>

#define PL_LIBAV_IMPLEMENTATION 1
#include <libplacebo/colorspace.h>
#include <libplacebo/gamut_mapping.h>
#include <libplacebo/tone_mapping.h>
#include <libplacebo/utils/dolbyvision.h>
#include <libplacebo/utils/libav.h>

static CFStringRef const kSFXHDRFramePayloadAttachmentKey = CFSTR("com.cueseeker.playback.hdrFramePayload");

static atomic_bool sHDRScreenshotEnabled = true;
static os_unfair_lock sTelemetryLock = OS_UNFAIR_LOCK_INIT;
static SFXDebugTelemetryLogHandler _Nullable sDebugTelemetryHandler = nil;
static atomic_bool sDebugTelemetryEnabled = false;

double SFXMonotonicMilliseconds(void) {
    static mach_timebase_info_data_t timebase = {0, 0};
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info(&timebase);
    });
    uint64_t ticks = mach_absolute_time();
    double nanoseconds = ((double)ticks * (double)timebase.numer) / (double)MAX(1u, timebase.denom);
    return nanoseconds / 1000000.0;
}

void SFXSetHDRScreenshotEnabled(BOOL enabled) {
    atomic_store_explicit(&sHDRScreenshotEnabled, enabled ? true : false, memory_order_relaxed);
}

BOOL SFXIsHDRScreenshotEnabled(void) {
    return atomic_load_explicit(&sHDRScreenshotEnabled, memory_order_relaxed) ? YES : NO;
}

void SFXSetDebugTelemetryLogHandler(SFXDebugTelemetryLogHandler _Nullable handler) {
    os_unfair_lock_lock(&sTelemetryLock);
    sDebugTelemetryHandler = [handler copy];
    atomic_store_explicit(&sDebugTelemetryEnabled, sDebugTelemetryHandler != nil, memory_order_relaxed);
    os_unfair_lock_unlock(&sTelemetryLock);
}

BOOL SFXIsDebugTelemetryEnabled(void) {
    return atomic_load_explicit(&sDebugTelemetryEnabled, memory_order_relaxed) ? YES : NO;
}

void SFXEmitDebugTelemetryLog(NSString *event, NSString * _Nullable details) {
    if (!atomic_load_explicit(&sDebugTelemetryEnabled, memory_order_relaxed)) {
        return;
    }
    SFXDebugTelemetryLogHandler handler = nil;
    os_unfair_lock_lock(&sTelemetryLock);
    handler = sDebugTelemetryHandler;
    os_unfair_lock_unlock(&sTelemetryLock);
    if (handler != nil) {
        handler(event ?: @"playback.debug", details);
    }
}

typedef struct {
    BOOL isHDR;
    BOOL hasDolbyVision;
    BOOL hasActiveDoviReshape;
    uint8_t doviProfile;
    enum AVColorPrimaries avPrimaries;
    enum AVColorTransferCharacteristic avTransfer;
    enum AVColorSpace avMatrix;
    enum AVColorRange avRange;
    struct pl_color_space colorSpace;
    struct pl_color_repr colorRepr;
    struct pl_dovi_metadata doviMetadata;
} SFXHDRFramePayload;

static inline void SFXWriteBE16(uint8_t *dst, uint16_t val) {
    dst[0] = (uint8_t)((val >> 8) & 0xFF);
    dst[1] = (uint8_t)(val & 0xFF);
}

static inline void SFXWriteBE32(uint8_t *dst, uint32_t val) {
    dst[0] = (uint8_t)((val >> 24) & 0xFF);
    dst[1] = (uint8_t)((val >> 16) & 0xFF);
    dst[2] = (uint8_t)((val >> 8) & 0xFF);
    dst[3] = (uint8_t)(val & 0xFF);
}

static inline uint16_t SFXClampChromaticity50000(float v) {
    double scaled = round((double)fmaxf(0.0f, fminf(1.0f, v)) * 50000.0);
    if (scaled < 0.0) return 0;
    if (scaled > 50000.0) return 50000;
    return (uint16_t)scaled;
}

static void SFXApplyCoreVideoHDRDictionaryAttachments(
    CVPixelBufferRef pixelBuffer,
    const struct pl_color_space *csp,
    const AVFrame * _Nullable frame,
    const AVStream * _Nullable stream
) {
    if (pixelBuffer == NULL || csp == NULL) {
        return;
    }

    if (csp->hdr.max_luma > 5.0f) {
        struct pl_raw_primaries prim = csp->hdr.prim;
        if (prim.red.x <= 0.0f || prim.green.y <= 0.0f) {
            const struct pl_raw_primaries *bt2020 = pl_raw_primaries_get(PL_COLOR_PRIM_BT_2020);
            if (bt2020 != NULL) {
                prim = *bt2020;
            }
        }
        float maxLuma = csp->hdr.max_luma;
        float minLuma = (csp->hdr.min_luma > 0.0f && csp->hdr.min_luma < maxLuma) ? csp->hdr.min_luma : 0.005f;

        uint8_t mdcv[24];
        // SMPTE ST 2086 order: G, B, R, WhitePoint (x, y in 0.00002 increments), MaxLuminance, MinLuminance (in 0.0001 cd/m2)
        SFXWriteBE16(mdcv + 0, SFXClampChromaticity50000(prim.green.x));
        SFXWriteBE16(mdcv + 2, SFXClampChromaticity50000(prim.green.y));
        SFXWriteBE16(mdcv + 4, SFXClampChromaticity50000(prim.blue.x));
        SFXWriteBE16(mdcv + 6, SFXClampChromaticity50000(prim.blue.y));
        SFXWriteBE16(mdcv + 8, SFXClampChromaticity50000(prim.red.x));
        SFXWriteBE16(mdcv + 10, SFXClampChromaticity50000(prim.red.y));
        SFXWriteBE16(mdcv + 12, SFXClampChromaticity50000(prim.white.x));
        SFXWriteBE16(mdcv + 14, SFXClampChromaticity50000(prim.white.y));
        uint32_t maxLumFixed = (uint32_t)llround(fmax(50000.0, fmin(100000000.0, (double)maxLuma * 10000.0)));
        uint32_t minLumFixed = (uint32_t)llround(fmax(1.0, fmin(50000.0, (double)minLuma * 10000.0)));
        SFXWriteBE32(mdcv + 16, maxLumFixed);
        SFXWriteBE32(mdcv + 20, minLumFixed);

        CFDataRef mdcvData = CFDataCreate(kCFAllocatorDefault, mdcv, sizeof(mdcv));
        if (mdcvData != NULL) {
            CVBufferSetAttachment(
                pixelBuffer,
                kCVImageBufferMasteringDisplayColorVolumeKey,
                mdcvData,
                kCVAttachmentMode_ShouldPropagate
            );
            CFRelease(mdcvData);
        }
    } else {
        CVBufferRemoveAttachment(pixelBuffer, kCVImageBufferMasteringDisplayColorVolumeKey);
    }

    if (csp->hdr.max_cll > 0.0f || csp->hdr.max_fall > 0.0f) {
        uint16_t maxCLL = csp->hdr.max_cll > 0.0f
            ? (uint16_t)fmaxf(1.0f, fminf(10000.0f, roundf(csp->hdr.max_cll)))
            : 0;
        uint16_t maxFALL = csp->hdr.max_fall > 0.0f
            ? (uint16_t)fmaxf(1.0f, fminf(10000.0f, roundf(csp->hdr.max_fall)))
            : 0;
        uint8_t clli[4];
        SFXWriteBE16(clli + 0, maxCLL);
        SFXWriteBE16(clli + 2, maxFALL);
        CFDataRef clliData = CFDataCreate(kCFAllocatorDefault, clli, sizeof(clli));
        if (clliData != NULL) {
            CVBufferSetAttachment(
                pixelBuffer,
                kCVImageBufferContentLightLevelInfoKey,
                clliData,
                kCVAttachmentMode_ShouldPropagate
            );
            CFRelease(clliData);
        }
    } else {
        CVBufferRemoveAttachment(pixelBuffer, kCVImageBufferContentLightLevelInfoKey);
    }

    if (frame != NULL || stream != NULL) {
        const AVAmbientViewingEnvironment *ave = NULL;
        if (frame != NULL) {
            const AVFrameSideData *sd = av_frame_get_side_data(frame, AV_FRAME_DATA_AMBIENT_VIEWING_ENVIRONMENT);
            if (sd != NULL && sd->size >= sizeof(AVAmbientViewingEnvironment)) {
                ave = (const AVAmbientViewingEnvironment *)sd->data;
            }
        }
        if (ave == NULL && stream != NULL && stream->codecpar != NULL) {
            const AVPacketSideData *psd = av_packet_side_data_get(
                stream->codecpar->coded_side_data,
                stream->codecpar->nb_coded_side_data,
                AV_PKT_DATA_AMBIENT_VIEWING_ENVIRONMENT
            );
            if (psd != NULL && psd->size >= sizeof(AVAmbientViewingEnvironment)) {
                ave = (const AVAmbientViewingEnvironment *)psd->data;
            }
        }
        BOOL attachedAVE = NO;
        if (ave != NULL) {
            double ambIllum = av_q2d(ave->ambient_illuminance);
            double ambX = av_q2d(ave->ambient_light_x);
            double ambY = av_q2d(ave->ambient_light_y);
            if (ambIllum > 0.0 && ambX > 0.0 && ambY > 0.0) {
                uint8_t aveBytes[8];
                uint32_t illumFixed = (uint32_t)llround(fmax(1.0, fmin(100000000.0, ambIllum * 10000.0)));
                SFXWriteBE32(aveBytes + 0, illumFixed);
                SFXWriteBE16(aveBytes + 4, SFXClampChromaticity50000((float)ambX));
                SFXWriteBE16(aveBytes + 6, SFXClampChromaticity50000((float)ambY));
                CFDataRef aveData = CFDataCreate(kCFAllocatorDefault, aveBytes, sizeof(aveBytes));
                if (aveData != NULL) {
                    CVBufferSetAttachment(
                        pixelBuffer,
                        kCVImageBufferAmbientViewingEnvironmentKey,
                        aveData,
                        kCVAttachmentMode_ShouldPropagate
                    );
                    CFRelease(aveData);
                    attachedAVE = YES;
                }
            }
        }
        if (!attachedAVE) {
            CVBufferRemoveAttachment(pixelBuffer, kCVImageBufferAmbientViewingEnvironmentKey);
        }
    }
}

void SFXAttachHDRMetadataToPixelBuffer(
    CVPixelBufferRef pixelBuffer,
    const AVCodecContext * _Nullable codecContext,
    const AVStream * _Nullable stream,
    const AVFrame * _Nullable frame
) {
    if (pixelBuffer == NULL || frame == NULL) {
        return;
    }

    int w = frame->width > 0 ? frame->width : (int)CVPixelBufferGetWidth(pixelBuffer);
    int h = frame->height > 0 ? frame->height : (int)CVPixelBufferGetHeight(pixelBuffer);
    enum AVColorPrimaries resolvedPrimaries = SFXResolveVideoColorPrimaries(stream, codecContext, frame, w, h);
    enum AVColorTransferCharacteristic resolvedTransfer = SFXResolveVideoColorTransfer(stream, codecContext, frame);
    enum AVColorSpace resolvedMatrix = SFXResolveVideoColorSpace(stream, codecContext, frame, w, h);
    BOOL resolvedFullRange = SFXResolveVideoIsFullRange(stream, codecContext, frame, (enum AVPixelFormat)frame->format);
    enum AVColorRange resolvedRange = resolvedFullRange ? AVCOL_RANGE_JPEG : AVCOL_RANGE_MPEG;

    struct pl_frame plFrame = {0};
    pl_frame_from_avframe(&plFrame, frame);
    if (stream != NULL) {
        pl_frame_copy_stream_props(&plFrame, stream);
    }

    if (plFrame.color.primaries == PL_COLOR_PRIM_UNKNOWN) {
        plFrame.color.primaries = pl_primaries_from_av(resolvedPrimaries);
    }
    if (plFrame.color.transfer == PL_COLOR_TRC_UNKNOWN) {
        plFrame.color.transfer = pl_transfer_from_av(resolvedTransfer);
    }
    if (plFrame.repr.sys == PL_COLOR_SYSTEM_UNKNOWN) {
        plFrame.repr.sys = pl_system_from_av(resolvedMatrix);
    }
    if (plFrame.repr.levels == PL_COLOR_LEVELS_UNKNOWN) {
        plFrame.repr.levels = pl_levels_from_av(resolvedRange);
    }

    SFXHDRFramePayload payload;
    memset(&payload, 0, sizeof(payload));
    payload.avPrimaries = resolvedPrimaries;
    payload.avTransfer = resolvedTransfer;
    payload.avMatrix = resolvedMatrix;
    payload.avRange = resolvedRange;

    const AVFrameSideData *doviSideData = av_frame_get_side_data(frame, AV_FRAME_DATA_DOVI_METADATA);
    if (doviSideData != NULL && doviSideData->data != NULL) {
        const AVDOVIMetadata *doviMeta = (const AVDOVIMetadata *)doviSideData->data;
        const AVDOVIRpuDataHeader *header = av_dovi_get_header(doviMeta);
        if (header != NULL) {
            payload.hasDolbyVision = YES;
            payload.doviProfile = header->vdr_rpu_profile;
            if (header->disable_residual_flag) {
                pl_map_avdovi_metadata(
                    &plFrame.color,
                    &plFrame.repr,
                    &payload.doviMetadata,
                    doviMeta
                );
                payload.hasActiveDoviReshape = YES;
                payload.avPrimaries = AVCOL_PRI_BT2020;
                payload.avTransfer = AVCOL_TRC_SMPTE2084;
            }
        }
    }
    const AVFrameSideData *doviRpuSideData = av_frame_get_side_data(frame, AV_FRAME_DATA_DOVI_RPU_BUFFER);
    if (doviRpuSideData != NULL && doviRpuSideData->data != NULL && doviRpuSideData->size > 0) {
        pl_hdr_metadata_from_dovi_rpu(&plFrame.color.hdr, doviRpuSideData->data, doviRpuSideData->size);
    }

    if (!payload.hasDolbyVision && stream != NULL && stream->codecpar != NULL) {
        const AVPacketSideData *doviConfSD = av_packet_side_data_get(
            stream->codecpar->coded_side_data,
            stream->codecpar->nb_coded_side_data,
            AV_PKT_DATA_DOVI_CONF
        );
        if (doviConfSD != NULL && doviConfSD->size >= sizeof(AVDOVIDecoderConfigurationRecord)) {
            const AVDOVIDecoderConfigurationRecord *conf = (const AVDOVIDecoderConfigurationRecord *)doviConfSD->data;
            payload.hasDolbyVision = YES;
            payload.doviProfile = conf->dv_profile;
            if (conf->dv_profile == 5 || frame->colorspace == AVCOL_SPC_IPT_C2) {
                plFrame.color.primaries = PL_COLOR_PRIM_BT_2020;
                plFrame.color.transfer = PL_COLOR_TRC_PQ;
                payload.avPrimaries = AVCOL_PRI_BT2020;
                payload.avTransfer = AVCOL_TRC_SMPTE2084;
            } else if (conf->dv_profile == 8 && conf->dv_bl_signal_compatibility_id == 4 &&
                       plFrame.color.transfer == PL_COLOR_TRC_UNKNOWN) {
                plFrame.color.primaries = PL_COLOR_PRIM_BT_2020;
                plFrame.color.transfer = PL_COLOR_TRC_HLG;
                payload.avPrimaries = AVCOL_PRI_BT2020;
                payload.avTransfer = AVCOL_TRC_ARIB_STD_B67;
            } else if (plFrame.color.transfer == PL_COLOR_TRC_UNKNOWN) {
                plFrame.color.primaries = PL_COLOR_PRIM_BT_2020;
                plFrame.color.transfer = PL_COLOR_TRC_PQ;
                payload.avPrimaries = AVCOL_PRI_BT2020;
                payload.avTransfer = AVCOL_TRC_SMPTE2084;
            }
        }
    }

    BOOL isHDRTransfer = (plFrame.color.transfer == PL_COLOR_TRC_PQ ||
                          plFrame.color.transfer == PL_COLOR_TRC_HLG ||
                          payload.avTransfer == AVCOL_TRC_SMPTE2084 ||
                          payload.avTransfer == AVCOL_TRC_ARIB_STD_B67);
    BOOL isHDRSystem = (frame->colorspace == AVCOL_SPC_IPT_C2 ||
                        frame->colorspace == AVCOL_SPC_ICTCP ||
                        payload.hasDolbyVision);
    payload.isHDR = (isHDRTransfer || isHDRSystem) ? YES : NO;
    payload.colorSpace = plFrame.color;
    payload.colorRepr = plFrame.repr;

    if (!payload.isHDR) {
        CVBufferRemoveAttachment(pixelBuffer, kSFXHDRFramePayloadAttachmentKey);
        return;
    }

    if (payload.colorSpace.primaries == PL_COLOR_PRIM_UNKNOWN) {
        payload.colorSpace.primaries = PL_COLOR_PRIM_BT_2020;
    }
    if (payload.colorSpace.transfer != PL_COLOR_TRC_PQ &&
        payload.colorSpace.transfer != PL_COLOR_TRC_HLG) {
        payload.colorSpace.transfer = (payload.avTransfer == AVCOL_TRC_ARIB_STD_B67)
            ? PL_COLOR_TRC_HLG
            : PL_COLOR_TRC_PQ;
    }

    SFXApplyCoreVideoHDRDictionaryAttachments(
        pixelBuffer,
        &payload.colorSpace,
        frame,
        stream
    );

    CFDataRef payloadData = CFDataCreate(
        kCFAllocatorDefault,
        (const uint8_t *)&payload,
        sizeof(payload)
    );
    if (payloadData != NULL) {
        CVBufferSetAttachment(
            pixelBuffer,
            kSFXHDRFramePayloadAttachmentKey,
            payloadData,
            kCVAttachmentMode_ShouldPropagate
        );
        CFRelease(payloadData);
    }
}

BOOL SFXPixelBufferIsHDR(CVPixelBufferRef _Nullable pixelBuffer) {
    if (pixelBuffer == NULL) {
        return NO;
    }
    CFTypeRef attachment = CVBufferCopyAttachment(pixelBuffer, kSFXHDRFramePayloadAttachmentKey, NULL);
    if (attachment != NULL) {
        BOOL isHDR = NO;
        if (CFGetTypeID(attachment) == CFDataGetTypeID() &&
            CFDataGetLength((CFDataRef)attachment) == sizeof(SFXHDRFramePayload)) {
            const SFXHDRFramePayload *payload = (const SFXHDRFramePayload *)CFDataGetBytePtr((CFDataRef)attachment);
            isHDR = payload->isHDR;
        }
        CFRelease(attachment);
        if (isHDR) {
            return YES;
        }
    }
    CFTypeRef trc = CVBufferCopyAttachment(pixelBuffer, kCVImageBufferTransferFunctionKey, NULL);
    if (trc != NULL) {
        BOOL isHDRTrc = CFEqual(trc, kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ) ||
                        CFEqual(trc, kCVImageBufferTransferFunction_ITU_R_2100_HLG) ||
                        CFEqual(trc, kCVImageBufferTransferFunction_Linear);
        CFRelease(trc);
        return isHDRTrc;
    }
    return NO;
}

uint64_t SFXPixelBufferColorSignature(CVPixelBufferRef _Nullable pixelBuffer) {
    if (pixelBuffer == NULL) {
        return 0;
    }
    uint64_t hash = 1469598103934665603ULL;
    OSType fmt = CVPixelBufferGetPixelFormatType(pixelBuffer);
    hash = (hash ^ (uint64_t)fmt) * 1099511628211ULL;

    CFStringRef keys[3] = {
        kCVImageBufferColorPrimariesKey,
        kCVImageBufferTransferFunctionKey,
        kCVImageBufferYCbCrMatrixKey
    };
    for (int i = 0; i < 3; i++) {
        CFTypeRef val = CVBufferCopyAttachment(pixelBuffer, keys[i], NULL);
        CFHashCode h = (val != NULL) ? CFHash(val) : 0;
        if (val != NULL) {
            CFRelease(val);
        }
        hash = (hash ^ (uint64_t)h) * 1099511628211ULL;
    }
    BOOL isHDR = SFXPixelBufferIsHDR(pixelBuffer);
    hash = (hash ^ (uint64_t)(isHDR ? 1 : 0)) * 1099511628211ULL;
    return hash;
}

NSString *SFXDescribePixelBufferColorSummary(CVPixelBufferRef _Nullable pixelBuffer) {
    if (pixelBuffer == NULL) {
        return @"unknown";
    }
    CFTypeRef attachment = CVBufferCopyAttachment(pixelBuffer, kSFXHDRFramePayloadAttachmentKey, NULL);
    if (attachment != NULL &&
        CFGetTypeID(attachment) == CFDataGetTypeID() &&
        CFDataGetLength((CFDataRef)attachment) == sizeof(SFXHDRFramePayload)) {
        const SFXHDRFramePayload *p = (const SFXHDRFramePayload *)CFDataGetBytePtr((CFDataRef)attachment);
        NSString *prim = [NSString stringWithUTF8String:pl_color_primaries_name(p->colorSpace.primaries) ?: "unknown"];
        NSString *trc = [NSString stringWithUTF8String:pl_color_transfer_name(p->colorSpace.transfer) ?: "unknown"];
        NSString *summary = nil;
        if (p->hasDolbyVision) {
            summary = [NSString stringWithFormat:@"dovi_p%u(%@/%@,reshape=%d,max_luma=%.0f,max_cll=%.0f)",
                       (unsigned)p->doviProfile,
                       prim,
                       trc,
                       p->hasActiveDoviReshape ? 1 : 0,
                       p->colorSpace.hdr.max_luma,
                       p->colorSpace.hdr.max_cll];
        } else {
            summary = [NSString stringWithFormat:@"hdr(%@/%@,max_luma=%.0f,max_cll=%.0f)",
                       prim,
                       trc,
                       p->colorSpace.hdr.max_luma,
                       p->colorSpace.hdr.max_cll];
        }
        CFRelease(attachment);
        return summary;
    }
    if (attachment != NULL) {
        CFRelease(attachment);
    }
    return @"sdr(srgb/gamma2.2)";
}

BOOL SFXFastPackSoftwareAVFrameIntoPixelBuffer(
    const AVFrame *frame,
    CVPixelBufferRef pixelBuffer
) {
    if (frame == NULL || pixelBuffer == NULL) {
        return NO;
    }
    enum AVPixelFormat srcFmt = (enum AVPixelFormat)frame->format;
    OSType dstFmt = CVPixelBufferGetPixelFormatType(pixelBuffer);
    int width = frame->width;
    int height = frame->height;
    if (width <= 0 || height <= 0) {
        return NO;
    }

    BOOL is8BitTarget = (dstFmt == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
                         dstFmt == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange);
    BOOL is10BitTarget = (dstFmt == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange ||
                          dstFmt == kCVPixelFormatType_420YpCbCr10BiPlanarFullRange);

    if (is8BitTarget && (srcFmt == AV_PIX_FMT_YUV420P || srcFmt == AV_PIX_FMT_YUVJ420P)) {
        if (frame->data[0] == NULL || frame->data[1] == NULL || frame->data[2] == NULL) {
            return NO;
        }
        if (CVPixelBufferLockBaseAddress(pixelBuffer, 0) != kCVReturnSuccess) {
            return NO;
        }
        uint8_t *dstY = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        size_t dstYStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
        uint8_t *dstUV = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
        size_t dstUVStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);

        const uint8_t *srcY = frame->data[0];
        int srcYStride = frame->linesize[0];
        for (int y = 0; y < height; y++) {
            memcpy(dstY + (size_t)y * dstYStride, srcY + (ssize_t)y * srcYStride, (size_t)width);
        }

        int uvWidth = (width + 1) / 2;
        int uvHeight = (height + 1) / 2;
        const uint8_t *srcU = frame->data[1];
        const uint8_t *srcV = frame->data[2];
        int srcUStride = frame->linesize[1];
        int srcVStride = frame->linesize[2];

        for (int y = 0; y < uvHeight; y++) {
            const uint8_t *uRow = srcU + (ssize_t)y * srcUStride;
            const uint8_t *vRow = srcV + (ssize_t)y * srcVStride;
            uint8_t *uvRow = dstUV + (size_t)y * dstUVStride;
            int x = 0;
#if defined(__aarch64__)
            for (; x + 16 <= uvWidth; x += 16) {
                uint8x16x2_t uv;
                uv.val[0] = vld1q_u8(uRow + x);
                uv.val[1] = vld1q_u8(vRow + x);
                vst2q_u8(uvRow + 2 * x, uv);
            }
#endif
            for (; x < uvWidth; x++) {
                uvRow[2 * x] = uRow[x];
                uvRow[2 * x + 1] = vRow[x];
            }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return YES;
    }

    if (is8BitTarget && srcFmt == AV_PIX_FMT_NV12) {
        if (frame->data[0] == NULL || frame->data[1] == NULL) {
            return NO;
        }
        if (CVPixelBufferLockBaseAddress(pixelBuffer, 0) != kCVReturnSuccess) {
            return NO;
        }
        uint8_t *dstY = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        size_t dstYStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
        uint8_t *dstUV = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
        size_t dstUVStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);

        for (int y = 0; y < height; y++) {
            memcpy(dstY + (size_t)y * dstYStride, frame->data[0] + (ssize_t)y * frame->linesize[0], (size_t)width);
        }
        int uvHeight = (height + 1) / 2;
        size_t uvBytes = (size_t)((width + 1) / 2) * 2;
        for (int y = 0; y < uvHeight; y++) {
            memcpy(dstUV + (size_t)y * dstUVStride, frame->data[1] + (ssize_t)y * frame->linesize[1], uvBytes);
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return YES;
    }

    if (is10BitTarget && srcFmt == AV_PIX_FMT_YUV420P10LE) {
        if (frame->data[0] == NULL || frame->data[1] == NULL || frame->data[2] == NULL) {
            return NO;
        }
        if (CVPixelBufferLockBaseAddress(pixelBuffer, 0) != kCVReturnSuccess) {
            return NO;
        }
        uint8_t *dstYBase = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        size_t dstYStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
        uint8_t *dstUVBase = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
        size_t dstUVStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);

        const uint8_t *srcYBase = frame->data[0];
        int srcYStride = frame->linesize[0];
        for (int y = 0; y < height; y++) {
            const uint16_t *srcRow = (const uint16_t *)(srcYBase + (ssize_t)y * srcYStride);
            uint16_t *dstRow = (uint16_t *)(dstYBase + (size_t)y * dstYStride);
            int x = 0;
#if defined(__aarch64__)
            for (; x + 8 <= width; x += 8) {
                uint16x8_t v = vld1q_u16(srcRow + x);
                vst1q_u16(dstRow + x, vshlq_n_u16(v, 6));
            }
#endif
            for (; x < width; x++) {
                dstRow[x] = (uint16_t)(srcRow[x] << 6);
            }
        }

        int uvWidth = (width + 1) / 2;
        int uvHeight = (height + 1) / 2;
        const uint8_t *srcUBase = frame->data[1];
        const uint8_t *srcVBase = frame->data[2];
        int srcUStride = frame->linesize[1];
        int srcVStride = frame->linesize[2];

        for (int y = 0; y < uvHeight; y++) {
            const uint16_t *uRow = (const uint16_t *)(srcUBase + (ssize_t)y * srcUStride);
            const uint16_t *vRow = (const uint16_t *)(srcVBase + (ssize_t)y * srcVStride);
            uint16_t *uvRow = (uint16_t *)(dstUVBase + (size_t)y * dstUVStride);
            int x = 0;
#if defined(__aarch64__)
            for (; x + 8 <= uvWidth; x += 8) {
                uint16x8x2_t uv;
                uv.val[0] = vshlq_n_u16(vld1q_u16(uRow + x), 6);
                uv.val[1] = vshlq_n_u16(vld1q_u16(vRow + x), 6);
                vst2q_u16(uvRow + 2 * x, uv);
            }
#endif
            for (; x < uvWidth; x++) {
                uvRow[2 * x] = (uint16_t)(uRow[x] << 6);
                uvRow[2 * x + 1] = (uint16_t)(vRow[x] << 6);
            }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return YES;
    }

    if (is10BitTarget && srcFmt == AV_PIX_FMT_P010LE) {
        if (frame->data[0] == NULL || frame->data[1] == NULL) {
            return NO;
        }
        if (CVPixelBufferLockBaseAddress(pixelBuffer, 0) != kCVReturnSuccess) {
            return NO;
        }
        uint8_t *dstYBase = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        size_t dstYStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
        uint8_t *dstUVBase = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
        size_t dstUVStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);

        size_t yBytes = (size_t)width * sizeof(uint16_t);
        for (int y = 0; y < height; y++) {
            memcpy(dstYBase + (size_t)y * dstYStride, frame->data[0] + (ssize_t)y * frame->linesize[0], yBytes);
        }
        int uvHeight = (height + 1) / 2;
        size_t uvBytes = (size_t)((width + 1) / 2) * 2 * sizeof(uint16_t);
        for (int y = 0; y < uvHeight; y++) {
            memcpy(dstUVBase + (size_t)y * dstUVStride, frame->data[1] + (ssize_t)y * frame->linesize[1], uvBytes);
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return YES;
    }

    return NO;
}

typedef struct {
    uint32_t numPivots;
    uint32_t pad0[3];
    float pivots[12];
    uint32_t method[8];
    float polyCoeffs[8][4];
    uint32_t mmrOrder[8];
    float mmrConstant[8];
    float mmrCoeffs[8][3][8];
} SFXMetalReshapeComp;

typedef struct {
    uint32_t dstWidth;
    uint32_t dstHeight;
    uint32_t isBiPlanar;
    uint32_t hasDoviReshape;
    uint32_t sourceTransfer; // 0 = sRGB, 1 = PQ, 2 = HLG
    uint32_t outputTransfer; // 0 = sRGB, 1 = PQ
    uint32_t applyToneMapLUT;
    uint32_t quarterTurnsClockwise; // 0, 1, 2, 3
    float sampleScale;
    float inputMinPQ;
    float inputMaxPQ;
    float outputMaxNits;
    float hlgPeakNits;
    float hlgSystemGamma;
    float pad1[2];
    float yuvMatrix[3][4];    // row.xyz = matrix row, row.w = offset
    float doviLinear[3][4];   // row.xyz = LMS->BT2020 * dovi.linear
    float gamutMatrix[3][4];  // row.xyz = srcPrim->dstPrim matrix
    SFXMetalReshapeComp doviComp[3];
} SFXMetalHDRUniforms;

static NSString * const kSFXHDRMetalShaderSource = @""
"#include <metal_stdlib>\n"
"using namespace metal;\n"
"\n"
"struct SFXMetalReshapeComp {\n"
"    uint numPivots;\n"
"    uint pad0[3];\n"
"    float pivots[12];\n"
"    uint method[8];\n"
"    float polyCoeffs[8][4];\n"
"    uint mmrOrder[8];\n"
"    float mmrConstant[8];\n"
"    float mmrCoeffs[8][3][8];\n"
"};\n"
"\n"
"struct SFXMetalHDRUniforms {\n"
"    uint dstWidth;\n"
"    uint dstHeight;\n"
"    uint isBiPlanar;\n"
"    uint hasDoviReshape;\n"
"    uint sourceTransfer;\n"
"    uint outputTransfer;\n"
"    uint applyToneMapLUT;\n"
"    uint quarterTurnsClockwise;\n"
"    float sampleScale;\n"
"    float inputMinPQ;\n"
"    float inputMaxPQ;\n"
"    float outputMaxNits;\n"
"    float hlgPeakNits;\n"
"    float hlgSystemGamma;\n"
"    float pad1[2];\n"
"    float yuvMatrix[3][4];\n"
"    float doviLinear[3][4];\n"
"    float gamutMatrix[3][4];\n"
"    SFXMetalReshapeComp doviComp[3];\n"
"};\n"
"\n"
"inline float3 sfx_mul3x3(const constant float mat[3][4], float3 v) {\n"
"    return float3(\n"
"         mat[0][0] * v.x + mat[0][1] * v.y + mat[0][2] * v.z,\n"
"        mat[1][0] * v.x + mat[1][1] * v.y + mat[1][2] * v.z,\n"
"        mat[2][0] * v.x + mat[2][1] * v.y + mat[2][2] * v.z\n"
"    );\n"
"}\n"
"\n"
"inline float3 sfx_mul3x4(const constant float mat[3][4], float3 v) {\n"
"    return sfx_mul3x3(mat, v) + float3(mat[0][3], mat[1][3], mat[2][3]);\n"
"}\n"
"\n"
"inline float sfx_pq_eotf_scalar(float e) {\n"
"    e = clamp(e, 0.0f, 1.0f);\n"
"    const float m1 = 2610.0f / 16384.0f;\n"
"    const float m2 = (2523.0f / 4096.0f) * 128.0f;\n"
"    const float c1 = 3424.0f / 4096.0f;\n"
"    const float c2 = (2413.0f / 4096.0f) * 32.0f;\n"
"    const float c3 = (2392.0f / 4096.0f) * 32.0f;\n"
"    float em2 = pow(e, 1.0f / m2);\n"
"    float num = max(em2 - c1, 0.0f);\n"
"    float den = max(c2 - c3 * em2, 1e-6f);\n"
"    return pow(num / den, 1.0f / m1);\n"
"}\n"
"\n"
"inline float3 sfx_pq_eotf(float3 e) {\n"
"    return float3(sfx_pq_eotf_scalar(e.x), sfx_pq_eotf_scalar(e.y), sfx_pq_eotf_scalar(e.z));\n"
"}\n"
"\n"
"inline float sfx_pq_oetf_scalar(float y) {\n"
"    y = clamp(y, 0.0f, 1.0f);\n"
"    const float m1 = 2610.0f / 16384.0f;\n"
"    const float m2 = (2523.0f / 4096.0f) * 128.0f;\n"
"    const float c1 = 3424.0f / 4096.0f;\n"
"    const float c2 = (2413.0f / 4096.0f) * 32.0f;\n"
"    const float c3 = (2392.0f / 4096.0f) * 32.0f;\n"
"    float ym1 = pow(y, m1);\n"
"    return pow((c1 + c2 * ym1) / (1.0f + c3 * ym1), m2);\n"
"}\n"
"\n"
"inline float3 sfx_pq_oetf(float3 y) {\n"
"    return float3(sfx_pq_oetf_scalar(y.x), sfx_pq_oetf_scalar(y.y), sfx_pq_oetf_scalar(y.z));\n"
"}\n"
"\n"
"inline float sfx_hlg_inv_oetf_scalar(float e) {\n"
"    e = clamp(e, 0.0f, 1.0f);\n"
"    const float a = 0.17883277f;\n"
"    const float b = 0.28466892f;\n"
"    const float c = 0.55991073f;\n"
"    if (e <= 0.5f) {\n"
"        return (e * e) / 3.0f;\n"
"    } else {\n"
"        return (exp((e - c) / a) + b) / 12.0f;\n"
"    }\n"
"}\n"
"\n"
"inline float sfx_srgb_oetf_scalar(float l) {\n"
"    l = clamp(l, 0.0f, 1.0f);\n"
"    if (l <= 0.0031308f) {\n"
"        return l * 12.92f;\n"
"    } else {\n"
"        return 1.055f * pow(l, 1.0f / 2.4f) - 0.055f;\n"
"    }\n"
"}\n"
"\n"
"inline float3 sfx_srgb_oetf(float3 l) {\n"
"    return float3(sfx_srgb_oetf_scalar(l.x), sfx_srgb_oetf_scalar(l.y), sfx_srgb_oetf_scalar(l.z));\n"
"}\n"
"\n"
"inline float sfx_eval_dovi_comp(const constant SFXMetalReshapeComp &comp, float3 s, uint ch) {\n"
"    float x = (ch == 0) ? s.x : ((ch == 1) ? s.y : s.z);\n"
"    if (comp.numPivots < 2) {\n"
"        return x;\n"
"    }\n"
"    uint pieces = min(comp.numPivots - 1, 8u);\n"
"    x = clamp(x, comp.pivots[0], comp.pivots[pieces]);\n"
"    uint idx = 0;\n"
"    for (uint i = 1; i < pieces; i++) {\n"
"        if (x >= comp.pivots[i]) {\n"
"            idx = i;\n"
"        }\n"
"    }\n"
"    if (comp.method[idx] == 0u) {\n"
"        float c0 = comp.polyCoeffs[idx][0];\n"
"        float c1 = comp.polyCoeffs[idx][1];\n"
"        float c2 = comp.polyCoeffs[idx][2];\n"
"        return clamp(c0 + x * (c1 + x * c2), 0.0f, 1.0f);\n"
"    } else {\n"
"        float val = comp.mmrConstant[idx];\n"
"        uint order = clamp(comp.mmrOrder[idx], 1u, 3u);\n"
"        float3 sp = s;\n"
"        for (uint j = 0; j < order; j++) {\n"
"            float t0 = sp.x;\n"
"            float t1 = sp.y;\n"
"            float t2 = sp.z;\n"
"            float t3 = sp.x * sp.y;\n"
"            float t4 = sp.x * sp.z;\n"
"            float t5 = sp.y * sp.z;\n"
"            float t6 = t3 * sp.z;\n"
"            val += comp.mmrCoeffs[idx][j][0] * t0\n"
"                 + comp.mmrCoeffs[idx][j][1] * t1\n"
"                 + comp.mmrCoeffs[idx][j][2] * t2\n"
"                 + comp.mmrCoeffs[idx][j][3] * t3\n"
"                 + comp.mmrCoeffs[idx][j][4] * t4\n"
"                 + comp.mmrCoeffs[idx][j][5] * t5\n"
"                 + comp.mmrCoeffs[idx][j][6] * t6;\n"
"            sp *= s;\n"
"        }\n"
"        return clamp(val, 0.0f, 1.0f);\n"
"    }\n"
"}\n"
"\n"
"kernel void sfx_hdr_color_map_kernel(\n"
"    texture2d<float, access::sample> srcPlane0 [[texture(0)]],\n"
"    texture2d<float, access::sample> srcPlane1 [[texture(1)]],\n"
"    texture1d<float, access::sample> toneMapLUT [[texture(2)]],\n"
"    texture2d<float, access::write> dstTex [[texture(3)]],\n"
"    constant SFXMetalHDRUniforms &u [[buffer(0)]],\n"
"    uint2 gid [[thread_position_in_grid]]\n"
") {\n"
"    if (gid.x >= u.dstWidth || gid.y >= u.dstHeight) {\n"
"        return;\n"
"    }\n"
"    constexpr sampler linearSampler(coord::normalized, address::clamp_to_edge, filter::linear);\n"
"    float2 dstUV = (float2(gid) + 0.5f) / float2(max(u.dstWidth, 1u), max(u.dstHeight, 1u));\n"
"    float2 srcUV = dstUV;\n"
"    if (u.quarterTurnsClockwise == 2u) {\n"
"        srcUV = float2(1.0f - dstUV.x, dstUV.y);\n"
"    } else if (u.quarterTurnsClockwise == 3u) {\n"
"        srcUV = float2(1.0f - dstUV.x, 1.0f - dstUV.y);\n"
"    } else if (u.quarterTurnsClockwise == 4u) {\n"
"        srcUV = float2(dstUV.x, 1.0f - dstUV.y);\n"
"    } else if (u.quarterTurnsClockwise == 5u) {\n"
"        srcUV = float2(dstUV.y, dstUV.x);\n"
"    } else if (u.quarterTurnsClockwise == 6u) {\n"
"        srcUV = float2(dstUV.y, 1.0f - dstUV.x);\n"
"    } else if (u.quarterTurnsClockwise == 7u) {\n"
"        srcUV = float2(1.0f - dstUV.y, 1.0f - dstUV.x);\n"
"    } else if (u.quarterTurnsClockwise == 8u) {\n"
"        srcUV = float2(1.0f - dstUV.y, dstUV.x);\n"
"    }\n"
"\n"
"    float3 rawSample;\n"
"    if (u.isBiPlanar != 0u) {\n"
"        float yVal = srcPlane0.sample(linearSampler, srcUV).r * u.sampleScale;\n"
"        float2 uvVal = srcPlane1.sample(linearSampler, srcUV).rg * u.sampleScale;\n"
"        rawSample = clamp(float3(yVal, uvVal.x, uvVal.y), 0.0f, 1.0f);\n"
"    } else {\n"
"        rawSample = clamp(srcPlane0.sample(linearSampler, srcUV).rgb * u.sampleScale, 0.0f, 1.0f);\n"
"    }\n"
"\n"
"    float3 rgbLin;\n"
"    if (u.hasDoviReshape != 0u) {\n"
"        float3 reshaped = float3(\n"
"            sfx_eval_dovi_comp(u.doviComp[0], rawSample, 0u),\n"
"            sfx_eval_dovi_comp(u.doviComp[1], rawSample, 1u),\n"
"            sfx_eval_dovi_comp(u.doviComp[2], rawSample, 2u)\n"
"        );\n"
"        float3 lmsPQ = clamp(sfx_mul3x4(u.yuvMatrix, reshaped), 0.0f, 1.0f);\n"
"        float3 lmsLin = sfx_pq_eotf(lmsPQ);\n"
"        rgbLin = max(sfx_mul3x3(u.doviLinear, lmsLin) * (10000.0f / 203.0f), 0.0f);\n"
"    } else {\n"
"        float3 rgbNonLin = clamp(sfx_mul3x4(u.yuvMatrix, rawSample), 0.0f, 1.0f);\n"
"        if (u.sourceTransfer == 1u) {\n"
"            rgbLin = sfx_pq_eotf(rgbNonLin) * (10000.0f / 203.0f);\n"
"        } else if (u.sourceTransfer == 2u) {\n"
"            float3 sceneRGB = float3(\n"
"                sfx_hlg_inv_oetf_scalar(rgbNonLin.r),\n"
"                sfx_hlg_inv_oetf_scalar(rgbNonLin.g),\n"
"                sfx_hlg_inv_oetf_scalar(rgbNonLin.b)\n"
"            );\n"
"            float ys = max(1e-6f, dot(sceneRGB, float3(0.2627f, 0.6780f, 0.0593f)));\n"
"            float ootfGain = pow(ys, max(u.hlgSystemGamma - 1.0f, 0.0f)) * (u.hlgPeakNits / 203.0f);\n"
"            rgbLin = sceneRGB * ootfGain;\n"
"        } else {\n"
"            rgbLin = pow(rgbNonLin, 2.2f);\n"
"        }\n"
"    }\n"
"\n"
"    rgbLin = max(sfx_mul3x3(u.gamutMatrix, rgbLin), 0.0f);\n"
"\n"
"    if (u.applyToneMapLUT != 0u) {\n"
"        float sig = max(1e-6f, max(rgbLin.r, max(rgbLin.g, rgbLin.b)));\n"
"        float sigPQ = sfx_pq_oetf_scalar(sig * (203.0f / 10000.0f));\n"
"        float lutCoord = clamp((sigPQ - u.inputMinPQ) / max(1e-4f, u.inputMaxPQ - u.inputMinPQ), 0.0f, 1.0f);\n"
"        float mappedPQ = toneMapLUT.sample(linearSampler, lutCoord).r;\n"
"        float mappedLin = sfx_pq_eotf_scalar(mappedPQ) * (10000.0f / max(u.outputMaxNits, 1.0f));\n"
"        rgbLin *= (mappedLin / sig);\n"
"    }\n"
"\n"
"    float3 outRGB;\n"
"    if (u.outputTransfer == 1u) {\n"
"        outRGB = sfx_pq_oetf(clamp(rgbLin * (203.0f / 10000.0f), 0.0f, 1.0f));\n"
"    } else {\n"
"        outRGB = sfx_srgb_oetf(clamp(rgbLin, 0.0f, 1.0f));\n"
"    }\n"
"\n"
"    dstTex.write(float4(outRGB, 1.0f), gid);\n"
"}\n";

typedef NS_ENUM(NSInteger, SFXHDRRenderTargetMode) {
    SFXHDRRenderTargetModeLiveHDRDisplay = 0,
    SFXHDRRenderTargetModeLiveSDRDisplay = 1,
    SFXHDRRenderTargetModeStaticHDRScreenshot = 2,
    SFXHDRRenderTargetModeStaticSDRScreenshot = 3,
};

@interface SFXHDRMetalContext : NSObject
+ (instancetype _Nullable)sharedContext;
- (CVPixelBufferRef _Nullable)createRenderedPixelBufferFromSource:(CVPixelBufferRef)sourceBuffer
                                                      targetWidth:(size_t)targetWidth
                                                     targetHeight:(size_t)targetHeight
                                            quarterTurnsClockwise:(NSInteger)quarterTurns
                                                       targetMode:(SFXHDRRenderTargetMode)targetMode
                                               displayEDRHeadroom:(CGFloat)displayEDRHeadroom CF_RETURNS_RETAINED;
- (CGImageRef _Nullable)createRenderedCGImageFromSource:(CVPixelBufferRef)sourceBuffer
                                            targetWidth:(size_t)targetWidth
                                           targetHeight:(size_t)targetHeight
                                  quarterTurnsClockwise:(NSInteger)quarterTurns
                                             targetMode:(SFXHDRRenderTargetMode)targetMode CF_RETURNS_RETAINED;
@end

@implementation SFXHDRMetalContext {
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    id<MTLComputePipelineState> _pipelineState;
    CVMetalTextureCacheRef _textureCache;
    CIContext *_ciContext;
    os_unfair_lock _lock;
    CVPixelBufferPoolRef _hdrOutputPool;
    size_t _hdrPoolWidth;
    size_t _hdrPoolHeight;
    CVPixelBufferPoolRef _sdrOutputPool;
    size_t _sdrPoolWidth;
    size_t _sdrPoolHeight;
}

+ (instancetype _Nullable)sharedContext {
    static SFXHDRMetalContext *sShared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sShared = [[SFXHDRMetalContext alloc] initInternal];
    });
    return sShared;
}

- (instancetype _Nullable)initInternal {
    self = [super init];
    if (self) {
        _lock = OS_UNFAIR_LOCK_INIT;
        _device = MTLCreateSystemDefaultDevice();
        if (_device == nil) {
            return nil;
        }
        _commandQueue = [_device newCommandQueue];
        if (_commandQueue == nil) {
            return nil;
        }
        NSError *error = nil;
        MTLCompileOptions *options = [[MTLCompileOptions alloc] init];
        options.fastMathEnabled = YES;
        id<MTLLibrary> library = [_device newLibraryWithSource:kSFXHDRMetalShaderSource
                                                       options:options
                                                         error:&error];
        if (library == nil) {
            return nil;
        }
        id<MTLFunction> kernelFunc = [library newFunctionWithName:@"sfx_hdr_color_map_kernel"];
        if (kernelFunc == nil) {
            return nil;
        }
        _pipelineState = [_device newComputePipelineStateWithFunction:kernelFunc error:&error];
        if (_pipelineState == nil) {
            return nil;
        }
        CVReturn cacheStatus = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            NULL,
            _device,
            NULL,
            &_textureCache
        );
        if (cacheStatus != kCVReturnSuccess || _textureCache == NULL) {
            return nil;
        }
        CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        _ciContext = [CIContext contextWithMTLDevice:_device options:@{
            kCIContextWorkingColorSpace: (__bridge id)srgb,
            kCIContextOutputColorSpace: (__bridge id)srgb,
            kCIContextCacheIntermediates: @NO,
        }];
        CGColorSpaceRelease(srgb);
    }
    return self;
}

- (void)dealloc {
    if (_textureCache != NULL) {
        CFRelease(_textureCache);
    }
    if (_hdrOutputPool != NULL) {
        CVPixelBufferPoolRelease(_hdrOutputPool);
    }
    if (_sdrOutputPool != NULL) {
        CVPixelBufferPoolRelease(_sdrOutputPool);
    }
}

- (CVPixelBufferRef _Nullable)allocateOutputPixelBufferWithFormat:(OSType)pixelFormat
                                                            width:(size_t)width
                                                           height:(size_t)height {
    CVPixelBufferPoolRef *poolPtr = (pixelFormat == kCVPixelFormatType_64RGBAHalf)
        ? &_hdrOutputPool
        : &_sdrOutputPool;
    size_t *wPtr = (pixelFormat == kCVPixelFormatType_64RGBAHalf)
        ? &_hdrPoolWidth
        : &_sdrPoolWidth;
    size_t *hPtr = (pixelFormat == kCVPixelFormatType_64RGBAHalf)
        ? &_hdrPoolHeight
        : &_sdrPoolHeight;

    if (*poolPtr == NULL || *wPtr != width || *hPtr != height) {
        if (*poolPtr != NULL) {
            CVPixelBufferPoolRelease(*poolPtr);
            *poolPtr = NULL;
        }
        NSDictionary *poolAttrs = @{
            (__bridge NSString *)kCVPixelBufferPoolMinimumBufferCountKey: @4
        };
        NSDictionary *bufferAttrs = @{
            (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(pixelFormat),
            (__bridge NSString *)kCVPixelBufferWidthKey: @(width),
            (__bridge NSString *)kCVPixelBufferHeightKey: @(height),
            (__bridge NSString *)kCVPixelBufferMetalCompatibilityKey: @YES,
            (__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{},
        };
        CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            (__bridge CFDictionaryRef)poolAttrs,
            (__bridge CFDictionaryRef)bufferAttrs,
            poolPtr
        );
        *wPtr = width;
        *hPtr = height;
    }

    if (*poolPtr == NULL) {
        return NULL;
    }
    CVPixelBufferRef outBuffer = NULL;
    if (CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, *poolPtr, &outBuffer) != kCVReturnSuccess) {
        return NULL;
    }
    return outBuffer;
}

- (void)populateUniforms:(SFXMetalHDRUniforms *)u
              toneMapLUT:(float *)lutOut
              lutSamples:(size_t)lutSamples
       fromSourcePayload:(const SFXHDRFramePayload *)payload
            sourceFormat:(OSType)sourceFormat
             targetWidth:(size_t)targetWidth
            targetHeight:(size_t)targetHeight
   quarterTurnsClockwise:(NSInteger)quarterTurns
              targetMode:(SFXHDRRenderTargetMode)targetMode
      displayEDRHeadroom:(CGFloat)displayEDRHeadroom {
    memset(u, 0, sizeof(*u));
    u->dstWidth = (uint32_t)targetWidth;
    u->dstHeight = (uint32_t)targetHeight;
    u->quarterTurnsClockwise = (quarterTurns >= 1 && quarterTurns <= 8) ? (uint32_t)quarterTurns : 1u;

    BOOL is10BitBiPlanar = (sourceFormat == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange ||
                            sourceFormat == kCVPixelFormatType_420YpCbCr10BiPlanarFullRange);
    BOOL is8BitBiPlanar = (sourceFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
                           sourceFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange);
    u->isBiPlanar = (is10BitBiPlanar || is8BitBiPlanar) ? 1u : 0u;
    u->sampleScale = is10BitBiPlanar ? (65535.0f / 65472.0f) : 1.0f;

    struct pl_color_space srcCsp = payload->colorSpace;
    if (srcCsp.primaries == PL_COLOR_PRIM_UNKNOWN) {
        srcCsp.primaries = PL_COLOR_PRIM_BT_2020;
    }
    if (srcCsp.transfer != PL_COLOR_TRC_PQ && srcCsp.transfer != PL_COLOR_TRC_HLG) {
        srcCsp.transfer = PL_COLOR_TRC_PQ;
    }
    pl_color_space_infer(&srcCsp);

    u->sourceTransfer = (srcCsp.transfer == PL_COLOR_TRC_HLG) ? 2u : 1u;
    u->outputTransfer = (targetMode == SFXHDRRenderTargetModeLiveHDRDisplay) ? 1u : 0u;
    u->hlgPeakNits = PL_COLOR_HLG_PEAK;
    u->hlgSystemGamma = 1.2f;

    if (payload->hasActiveDoviReshape) {
        u->hasDoviReshape = 1u;
        const struct pl_dovi_metadata *dovi = &payload->doviMetadata;
        for (int r = 0; r < 3; r++) {
            float rowOffset = 0.0f;
            for (int c = 0; c < 3; c++) {
                float mrc = dovi->nonlinear.m[r][c];
                u->yuvMatrix[r][c] = mrc;
                float off = -fabsf(dovi->nonlinear_offset[c]);
                rowOffset += mrc * off;
            }
            u->yuvMatrix[r][3] = rowOffset;
        }
        // ITU-R BT.2100 ICtCp Hunt-Pointer-Estevez LMS -> BT.2020 RGB matrix multiplied by dovi->linear
        static const float kLMS2BT2020[3][3] = {
            {  3.43660669f, -2.50645212f,  0.06984542f },
            { -0.79132956f,  1.98360045f, -0.19227090f },
            { -0.02594990f, -0.09891371f,  1.12486361f }
        };
        for (int r = 0; r < 3; r++) {
            for (int c = 0; c < 3; c++) {
                float sum = 0.0f;
                for (int k = 0; k < 3; k++) {
                    sum += kLMS2BT2020[r][k] * dovi->linear.m[k][c];
                }
                u->doviLinear[r][c] = sum;
            }
            u->doviLinear[r][3] = 0.0f;
        }
        for (int c = 0; c < 3; c++) {
            const struct pl_reshape_data *srcComp = &dovi->comp[c];
            SFXMetalReshapeComp *dstComp = &u->doviComp[c];
            dstComp->numPivots = srcComp->num_pivots;
            for (int p = 0; p < 9; p++) {
                dstComp->pivots[p] = srcComp->pivots[p];
            }
            for (int s = 0; s < 8; s++) {
                dstComp->method[s] = srcComp->method[s];
                dstComp->polyCoeffs[s][0] = srcComp->poly_coeffs[s][0];
                dstComp->polyCoeffs[s][1] = srcComp->poly_coeffs[s][1];
                dstComp->polyCoeffs[s][2] = srcComp->poly_coeffs[s][2];
                dstComp->mmrOrder[s] = srcComp->mmr_order[s];
                dstComp->mmrConstant[s] = srcComp->mmr_constant[s];
                for (int o = 0; o < 3; o++) {
                    for (int k = 0; k < 7; k++) {
                        dstComp->mmrCoeffs[s][o][k] = srcComp->mmr_coeffs[s][o][k];
                    }
                }
            }
        }
    } else {
        u->hasDoviReshape = 0u;
        struct pl_color_repr repr = payload->colorRepr;
        if (!pl_color_system_is_ycbcr_like(repr.sys)) {
            repr.sys = PL_COLOR_SYSTEM_BT_2020_NC;
        }
        if (repr.levels == PL_COLOR_LEVELS_UNKNOWN) {
            repr.levels = PL_COLOR_LEVELS_LIMITED;
        }
        int depth = is10BitBiPlanar ? 10 : 8;
        repr.bits.sample_depth = depth;
        repr.bits.color_depth = depth;
        repr.bits.bit_shift = 0;
        pl_transform3x3 tr = pl_color_repr_decode(&repr, NULL);
        for (int r = 0; r < 3; r++) {
            for (int c = 0; c < 3; c++) {
                u->yuvMatrix[r][c] = tr.mat.m[r][c];
            }
            u->yuvMatrix[r][3] = tr.c[r];
        }
    }

    enum pl_color_primaries dstPrimEnum = (targetMode == SFXHDRRenderTargetModeLiveHDRDisplay)
        ? PL_COLOR_PRIM_BT_2020
        : PL_COLOR_PRIM_BT_709;
    const struct pl_raw_primaries *srcPrim = pl_raw_primaries_get(srcCsp.primaries);
    const struct pl_raw_primaries *dstPrim = pl_raw_primaries_get(dstPrimEnum);
    pl_matrix3x3 gamutMat = pl_get_color_mapping_matrix(
        srcPrim,
        dstPrim,
        PL_INTENT_RELATIVE_COLORIMETRIC
    );
    for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
            u->gamutMatrix[r][c] = gamutMat.m[r][c];
        }
        u->gamutMatrix[r][3] = 0.0f;
    }

    float inMinPQ = 0.0f;
    float inMaxPQ = 0.0f;
    pl_color_space_nominal_luma_ex(pl_nominal_luma_params(
        .color = &srcCsp,
        .metadata = PL_HDR_METADATA_HDR10,
        .scaling = PL_HDR_PQ,
        .out_min = &inMinPQ,
        .out_max = &inMaxPQ
    ));
    inMinPQ = fmaxf(0.005f, fminf(0.10f, inMinPQ));
    inMaxPQ = fmaxf(0.55f, fminf(1.0f, inMaxPQ));
    u->outputMaxNits = PL_COLOR_SDR_WHITE;

    if (targetMode == SFXHDRRenderTargetModeLiveHDRDisplay) {
        (void)displayEDRHeadroom;
        u->inputMinPQ = inMinPQ;
        u->inputMaxPQ = inMaxPQ;
        u->applyToneMapLUT = 0u;
        for (size_t i = 0; i < lutSamples; i++) {
            lutOut[i] = (lutSamples > 1) ? ((float)i / (float)(lutSamples - 1)) : 0.0f;
        }
        return;
    }

    struct pl_tone_map_params toneParams = {
        .constants = { PL_TONE_MAP_CONSTANTS },
        .input_scaling = PL_HDR_PQ,
        .output_scaling = PL_HDR_PQ,
        .lut_size = lutSamples,
        .input_min = inMinPQ,
        .input_max = inMaxPQ,
        .output_min = inMinPQ,
        .output_max = pl_hdr_rescale(PL_HDR_NITS, PL_HDR_PQ, PL_COLOR_SDR_WHITE),
        .hdr = srcCsp.hdr,
    };

    if (targetMode == SFXHDRRenderTargetModeStaticHDRScreenshot) {
        toneParams.function = &pl_tone_map_bt2390;
        toneParams.constants.knee_offset = 0.5f;
    } else {
        toneParams.function = &pl_tone_map_spline;
    }

    pl_tone_map_params_infer(&toneParams);
    pl_tone_map_generate(lutOut, &toneParams);
    u->inputMinPQ = toneParams.input_min;
    u->inputMaxPQ = toneParams.input_max;
    u->applyToneMapLUT = 1u;
}

- (CVPixelBufferRef _Nullable)createRenderedPixelBufferFromSource:(CVPixelBufferRef)sourceBuffer
                                                      targetWidth:(size_t)targetWidth
                                                     targetHeight:(size_t)targetHeight
                                            quarterTurnsClockwise:(NSInteger)quarterTurns
                                                       targetMode:(SFXHDRRenderTargetMode)targetMode
                                               displayEDRHeadroom:(CGFloat)displayEDRHeadroom {
    if (sourceBuffer == NULL || targetWidth == 0 || targetHeight == 0) {
        return NULL;
    }

    SFXHDRFramePayload payload;
    memset(&payload, 0, sizeof(payload));
    CFTypeRef payloadAttachment = CVBufferCopyAttachment(sourceBuffer, kSFXHDRFramePayloadAttachmentKey, NULL);
    if (payloadAttachment != NULL &&
        CFGetTypeID(payloadAttachment) == CFDataGetTypeID() &&
        CFDataGetLength((CFDataRef)payloadAttachment) == sizeof(SFXHDRFramePayload)) {
        memcpy(&payload, CFDataGetBytePtr((CFDataRef)payloadAttachment), sizeof(SFXHDRFramePayload));
    } else {
        payload.isHDR = SFXPixelBufferIsHDR(sourceBuffer);
        payload.colorSpace.primaries = PL_COLOR_PRIM_BT_2020;
        CFTypeRef trc = CVBufferCopyAttachment(sourceBuffer, kCVImageBufferTransferFunctionKey, NULL);
        if (trc != NULL && CFEqual(trc, kCVImageBufferTransferFunction_ITU_R_2100_HLG)) {
            payload.colorSpace.transfer = PL_COLOR_TRC_HLG;
        } else {
            payload.colorSpace.transfer = PL_COLOR_TRC_PQ;
        }
        if (trc != NULL) {
            CFRelease(trc);
        }
        payload.colorRepr.sys = PL_COLOR_SYSTEM_BT_2020_NC;
        payload.colorRepr.levels = PL_COLOR_LEVELS_LIMITED;
    }
    if (payloadAttachment != NULL) {
        CFRelease(payloadAttachment);
    }

    OSType srcFormat = CVPixelBufferGetPixelFormatType(sourceBuffer);
    MTLPixelFormat plane0Fmt = MTLPixelFormatInvalid;
    MTLPixelFormat plane1Fmt = MTLPixelFormatInvalid;
    if (srcFormat == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange ||
        srcFormat == kCVPixelFormatType_420YpCbCr10BiPlanarFullRange) {
        plane0Fmt = MTLPixelFormatR16Unorm;
        plane1Fmt = MTLPixelFormatRG16Unorm;
    } else if (srcFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
               srcFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
        plane0Fmt = MTLPixelFormatR8Unorm;
        plane1Fmt = MTLPixelFormatRG8Unorm;
    } else if (srcFormat == kCVPixelFormatType_64RGBAHalf) {
        plane0Fmt = MTLPixelFormatRGBA16Float;
    } else if (srcFormat == kCVPixelFormatType_32BGRA) {
        plane0Fmt = MTLPixelFormatBGRA8Unorm;
    } else {
        return NULL;
    }

    OSType dstFormat = (targetMode == SFXHDRRenderTargetModeLiveHDRDisplay)
        ? kCVPixelFormatType_64RGBAHalf
        : kCVPixelFormatType_32BGRA;
    MTLPixelFormat dstMetalFormat = (dstFormat == kCVPixelFormatType_64RGBAHalf)
        ? MTLPixelFormatRGBA16Float
        : MTLPixelFormatBGRA8Unorm;

    os_unfair_lock_lock(&_lock);
    CVPixelBufferRef dstBuffer = [self allocateOutputPixelBufferWithFormat:dstFormat
                                                                     width:targetWidth
                                                                    height:targetHeight];
    if (dstBuffer == NULL) {
        os_unfair_lock_unlock(&_lock);
        return NULL;
    }

    CVMetalTextureRef cvPlane0 = NULL;
    CVMetalTextureRef cvPlane1 = NULL;
    CVMetalTextureRef cvDst = NULL;

    size_t p0W = CVPixelBufferIsPlanar(sourceBuffer) ? CVPixelBufferGetWidthOfPlane(sourceBuffer, 0) : CVPixelBufferGetWidth(sourceBuffer);
    size_t p0H = CVPixelBufferIsPlanar(sourceBuffer) ? CVPixelBufferGetHeightOfPlane(sourceBuffer, 0) : CVPixelBufferGetHeight(sourceBuffer);
    CVMetalTextureCacheCreateTextureFromImage(
        kCFAllocatorDefault,
        _textureCache,
        sourceBuffer,
        NULL,
        plane0Fmt,
        p0W,
        p0H,
        0,
        &cvPlane0
    );
    if (plane1Fmt != MTLPixelFormatInvalid) {
        size_t p1W = CVPixelBufferGetWidthOfPlane(sourceBuffer, 1);
        size_t p1H = CVPixelBufferGetHeightOfPlane(sourceBuffer, 1);
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            _textureCache,
            sourceBuffer,
            NULL,
            plane1Fmt,
            p1W,
            p1H,
            1,
            &cvPlane1
        );
    } else {
        cvPlane1 = cvPlane0 != NULL ? (CVMetalTextureRef)CFRetain(cvPlane0) : NULL;
    }
    CVMetalTextureCacheCreateTextureFromImage(
        kCFAllocatorDefault,
        _textureCache,
        dstBuffer,
        NULL,
        dstMetalFormat,
        targetWidth,
        targetHeight,
        0,
        &cvDst
    );

    id<MTLTexture> tex0 = cvPlane0 != NULL ? CVMetalTextureGetTexture(cvPlane0) : nil;
    id<MTLTexture> tex1 = cvPlane1 != NULL ? CVMetalTextureGetTexture(cvPlane1) : nil;
    id<MTLTexture> texDst = cvDst != NULL ? CVMetalTextureGetTexture(cvDst) : nil;
    if (tex0 == nil || tex1 == nil || texDst == nil) {
        if (cvPlane0 != NULL) CFRelease(cvPlane0);
        if (cvPlane1 != NULL) CFRelease(cvPlane1);
        if (cvDst != NULL) CFRelease(cvDst);
        CVPixelBufferRelease(dstBuffer);
        os_unfair_lock_unlock(&_lock);
        return NULL;
    }

    const size_t lutSize = 256;
    float lutData[256];
    SFXMetalHDRUniforms uniforms;
    [self populateUniforms:&uniforms
                toneMapLUT:lutData
                lutSamples:lutSize
         fromSourcePayload:&payload
              sourceFormat:srcFormat
               targetWidth:targetWidth
              targetHeight:targetHeight
     quarterTurnsClockwise:quarterTurns
                targetMode:targetMode
        displayEDRHeadroom:displayEDRHeadroom];

    MTLTextureDescriptor *lutDesc = [[MTLTextureDescriptor alloc] init];
    lutDesc.textureType = MTLTextureType1D;
    lutDesc.pixelFormat = MTLPixelFormatR32Float;
    lutDesc.width = lutSize;
    lutDesc.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> lutTex = [_device newTextureWithDescriptor:lutDesc];
    [lutTex replaceRegion:MTLRegionMake1D(0, lutSize)
              mipmapLevel:0
                withBytes:lutData
              bytesPerRow:lutSize * sizeof(float)];

    id<MTLCommandBuffer> cmdBuf = [_commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [cmdBuf computeCommandEncoder];
    [encoder setComputePipelineState:_pipelineState];
    [encoder setTexture:tex0 atIndex:0];
    [encoder setTexture:tex1 atIndex:1];
    [encoder setTexture:lutTex atIndex:2];
    [encoder setTexture:texDst atIndex:3];
    [encoder setBytes:&uniforms length:sizeof(uniforms) atIndex:0];

    MTLSize threadgroupSize = MTLSizeMake(16, 16, 1);
    MTLSize threadgroups = MTLSizeMake(
        (targetWidth + threadgroupSize.width - 1) / threadgroupSize.width,
        (targetHeight + threadgroupSize.height - 1) / threadgroupSize.height,
        1
    );
    [encoder dispatchThreadgroups:threadgroups threadsPerThreadgroup:threadgroupSize];
    [encoder endEncoding];
    [cmdBuf commit];
    [cmdBuf waitUntilCompleted];

    if (cvPlane0 != NULL) CFRelease(cvPlane0);
    if (cvPlane1 != NULL) CFRelease(cvPlane1);
    if (cvDst != NULL) CFRelease(cvDst);
    CVMetalTextureCacheFlush(_textureCache, 0);
    os_unfair_lock_unlock(&_lock);

    // Copy PixelAspectRatio and VideoOrientation attachments from sourceBuffer
    CFTypeRef par = CVBufferCopyAttachment(sourceBuffer, kCVImageBufferPixelAspectRatioKey, NULL);
    if (par != NULL) {
        CVBufferSetAttachment(dstBuffer, kCVImageBufferPixelAspectRatioKey, par, kCVAttachmentMode_ShouldPropagate);
        CFRelease(par);
    } else {
        CVBufferRemoveAttachment(dstBuffer, kCVImageBufferPixelAspectRatioKey);
    }
    SFXVideoOrientation orientation = SFXVideoOrientationForPixelBuffer(sourceBuffer);
    SFXApplyVideoOrientationAttachment(dstBuffer, orientation);

    if (targetMode == SFXHDRRenderTargetModeLiveHDRDisplay) {
        CVBufferSetAttachment(
            dstBuffer,
            kCVImageBufferYCbCrMatrixKey,
            kCVImageBufferYCbCrMatrix_ITU_R_2020,
            kCVAttachmentMode_ShouldPropagate
        );
        CVBufferSetAttachment(
            dstBuffer,
            kCVImageBufferColorPrimariesKey,
            kCVImageBufferColorPrimaries_ITU_R_2020,
            kCVAttachmentMode_ShouldPropagate
        );
        CVBufferSetAttachment(
            dstBuffer,
            kCVImageBufferTransferFunctionKey,
            kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ,
            kCVAttachmentMode_ShouldPropagate
        );
        CGColorSpaceRef hdrColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_2100_PQ);
        if (hdrColorSpace != NULL) {
            CVBufferSetAttachment(
                dstBuffer,
                kCVImageBufferCGColorSpaceKey,
                hdrColorSpace,
                kCVAttachmentMode_ShouldPropagate
            );
            CFRelease(hdrColorSpace);
        }
        SFXApplyCoreVideoHDRDictionaryAttachments(
            dstBuffer,
            &payload.colorSpace,
            NULL,
            NULL
        );
        CFTypeRef ave = CVBufferCopyAttachment(sourceBuffer, kCVImageBufferAmbientViewingEnvironmentKey, NULL);
        if (ave != NULL) {
            CVBufferSetAttachment(
                dstBuffer,
                kCVImageBufferAmbientViewingEnvironmentKey,
                ave,
                kCVAttachmentMode_ShouldPropagate
            );
            CFRelease(ave);
        } else {
            CVBufferRemoveAttachment(dstBuffer, kCVImageBufferAmbientViewingEnvironmentKey);
        }
    } else {
        CVBufferSetAttachment(
            dstBuffer,
            kCVImageBufferYCbCrMatrixKey,
            kCVImageBufferYCbCrMatrix_ITU_R_709_2,
            kCVAttachmentMode_ShouldPropagate
        );
        CVBufferSetAttachment(
            dstBuffer,
            kCVImageBufferColorPrimariesKey,
            kCVImageBufferColorPrimaries_ITU_R_709_2,
            kCVAttachmentMode_ShouldPropagate
        );
        CVBufferSetAttachment(
            dstBuffer,
            kCVImageBufferTransferFunctionKey,
            kCVImageBufferTransferFunction_sRGB,
            kCVAttachmentMode_ShouldPropagate
        );
        CGColorSpaceRef sdrColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        if (sdrColorSpace != NULL) {
            CVBufferSetAttachment(
                dstBuffer,
                kCVImageBufferCGColorSpaceKey,
                sdrColorSpace,
                kCVAttachmentMode_ShouldPropagate
            );
            CFRelease(sdrColorSpace);
        }
    }

    return dstBuffer;
}

- (CGImageRef _Nullable)createRenderedCGImageFromSource:(CVPixelBufferRef)sourceBuffer
                                            targetWidth:(size_t)targetWidth
                                           targetHeight:(size_t)targetHeight
                                  quarterTurnsClockwise:(NSInteger)quarterTurns
                                             targetMode:(SFXHDRRenderTargetMode)targetMode {
    CVPixelBufferRef renderedBuffer = [self createRenderedPixelBufferFromSource:sourceBuffer
                                                                    targetWidth:targetWidth
                                                                   targetHeight:targetHeight
                                                          quarterTurnsClockwise:quarterTurns
                                                                     targetMode:targetMode
                                                             displayEDRHeadroom:1.0];
    if (renderedBuffer == NULL) {
        return NULL;
    }

    if (CVPixelBufferLockBaseAddress(renderedBuffer, kCVPixelBufferLock_ReadOnly) != kCVReturnSuccess) {
        CVPixelBufferRelease(renderedBuffer);
        return NULL;
    }
    size_t width = CVPixelBufferGetWidth(renderedBuffer);
    size_t height = CVPixelBufferGetHeight(renderedBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(renderedBuffer);
    const uint8_t *baseAddress = (const uint8_t *)CVPixelBufferGetBaseAddress(renderedBuffer);

    CGImageRef image = NULL;
    if (baseAddress != NULL && width > 0 && height > 0) {
        CFDataRef dataCopy = CFDataCreate(kCFAllocatorDefault, baseAddress, (CFIndex)(bytesPerRow * height));
        if (dataCopy != NULL) {
            CGDataProviderRef provider = CGDataProviderCreateWithCFData(dataCopy);
            CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            if (provider != NULL && srgb != NULL) {
                CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little;
                image = CGImageCreate(
                    width,
                    height,
                    8,
                    32,
                    bytesPerRow,
                    srgb,
                    bitmapInfo,
                    provider,
                    NULL,
                    false,
                    kCGRenderingIntentDefault
                );
            }
            if (srgb != NULL) CGColorSpaceRelease(srgb);
            if (provider != NULL) CGDataProviderRelease(provider);
            CFRelease(dataCopy);
        }
    }
    CVPixelBufferUnlockBaseAddress(renderedBuffer, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferRelease(renderedBuffer);
    return image;
}

- (CGImageRef _Nullable)createSDRCGImageFromPixelBuffer:(CVPixelBufferRef)pixelBuffer
                                            targetWidth:(size_t)targetWidth
                                           targetHeight:(size_t)targetHeight
                                  quarterTurnsClockwise:(NSInteger)quarterTurns {
    if (pixelBuffer == NULL || _ciContext == nil) {
        return NULL;
    }
    size_t srcW = CVPixelBufferGetWidth(pixelBuffer);
    size_t srcH = CVPixelBufferGetHeight(pixelBuffer);
    if (srcW == 0 || srcH == 0) {
        return NULL;
    }
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer
                                               options:@{ kCIImageApplyOrientationProperty: @NO }];
    if (ciImage == nil) {
        return NULL;
    }
    CGRect rawExtent = CGRectIntegral(ciImage.extent);
    if (CGRectIsEmpty(rawExtent)) {
        return NULL;
    }

    NSInteger unrotatedTargetWidth = MAX(1, SFXUnrotatedDisplayVideoWidthForPixelBuffer(pixelBuffer));
    if (unrotatedTargetWidth != (NSInteger)rawExtent.size.width && rawExtent.size.width > 0) {
        CGFloat scaleX = (CGFloat)unrotatedTargetWidth / rawExtent.size.width;
        CGRect scaledExtent = CGRectMake(0.0, 0.0, (CGFloat)unrotatedTargetWidth, rawExtent.size.height);
        ciImage = [[[[ciImage imageByClampingToExtent]
            imageByApplyingTransform:CGAffineTransformMakeTranslation(-rawExtent.origin.x, -rawExtent.origin.y)]
            imageByApplyingTransform:CGAffineTransformMakeScale(scaleX, 1.0)]
            imageByCroppingToRect:scaledExtent];
    }

    SFXVideoOrientation sanitizedOrientation = (quarterTurns >= SFXVideoOrientationUp && quarterTurns <= SFXVideoOrientationLeft)
        ? (SFXVideoOrientation)quarterTurns
        : SFXVideoOrientationUp;
    if (sanitizedOrientation != SFXVideoOrientationUp) {
        ciImage = [ciImage imageByApplyingOrientation:(int)sanitizedOrientation];
    }

    CGRect orientedExtent = CGRectIntegral(ciImage.extent);
    if (CGRectIsEmpty(orientedExtent)) {
        return NULL;
    }
    size_t outW = targetWidth > 0 ? targetWidth : (size_t)llround(orientedExtent.size.width);
    size_t outH = targetHeight > 0 ? targetHeight : (size_t)llround(orientedExtent.size.height);
    if (orientedExtent.size.width > 0 && orientedExtent.size.height > 0 &&
        ((size_t)llround(orientedExtent.size.width) != outW || (size_t)llround(orientedExtent.size.height) != outH)) {
        CGFloat scaleX = (CGFloat)outW / orientedExtent.size.width;
        CGFloat scaleY = (CGFloat)outH / orientedExtent.size.height;
        CGRect targetRect = CGRectMake(0.0, 0.0, (CGFloat)outW, (CGFloat)outH);
        ciImage = [[[[ciImage imageByClampingToExtent]
            imageByApplyingTransform:CGAffineTransformMakeTranslation(-orientedExtent.origin.x, -orientedExtent.origin.y)]
            imageByApplyingTransform:CGAffineTransformMakeScale(scaleX, scaleY)]
            imageByCroppingToRect:targetRect];
        orientedExtent = targetRect;
    }

    CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGImageRef cgImage = [_ciContext createCGImage:ciImage
                                          fromRect:orientedExtent
                                            format:kCIFormatRGBA8
                                        colorSpace:srgb];
    CGColorSpaceRelease(srgb);
    return cgImage;
}

@end

CVPixelBufferRef _Nullable SFXCreateDisplayPixelBufferForPlayback(
    CVPixelBufferRef _Nullable sourcePixelBuffer,
    BOOL isDisplayHDRActive,
    CGFloat displayEDRHeadroom,
    double * _Nullable outRenderMilliseconds
) {
    if (outRenderMilliseconds != NULL) {
        *outRenderMilliseconds = 0.0;
    }
    if (sourcePixelBuffer == NULL) {
        return NULL;
    }
    if (!SFXPixelBufferIsHDR(sourcePixelBuffer)) {
        return CVPixelBufferRetain(sourcePixelBuffer);
    }

    double startMs = SFXMonotonicMilliseconds();
    size_t width = CVPixelBufferGetWidth(sourcePixelBuffer);
    size_t height = CVPixelBufferGetHeight(sourcePixelBuffer);
    SFXHDRRenderTargetMode mode = isDisplayHDRActive
        ? SFXHDRRenderTargetModeLiveHDRDisplay
        : SFXHDRRenderTargetModeLiveSDRDisplay;
    CVPixelBufferRef rendered = [[SFXHDRMetalContext sharedContext]
        createRenderedPixelBufferFromSource:sourcePixelBuffer
                                targetWidth:width
                               targetHeight:height
                      quarterTurnsClockwise:0
                                 targetMode:mode
                         displayEDRHeadroom:displayEDRHeadroom];
    double elapsedMs = SFXMonotonicMilliseconds() - startMs;
    if (outRenderMilliseconds != NULL) {
        *outRenderMilliseconds = elapsedMs;
    }
    if (rendered != NULL) {
        return rendered;
    }
    return CVPixelBufferRetain(sourcePixelBuffer);
}

CGImageRef _Nullable SFXCopyRenderedImageFromPixelBufferWithRotation(
    CVPixelBufferRef pixelBuffer,
    size_t targetWidth,
    size_t targetHeight,
    NSInteger quarterTurnsClockwise,
    double decodeMilliseconds,
    NSString * _Nullable sceneName
) {
    if (pixelBuffer == NULL) {
        return NULL;
    }
    double renderStartMs = SFXMonotonicMilliseconds();
    SFXVideoOrientation attachedOrientation = SFXVideoOrientationForPixelBuffer(pixelBuffer);
    SFXVideoOrientation effectiveOrientation = (quarterTurnsClockwise >= SFXVideoOrientationUp && quarterTurnsClockwise <= SFXVideoOrientationLeft)
        ? (SFXVideoOrientation)quarterTurnsClockwise
        : attachedOrientation;
    BOOL swapsDimensions = SFXVideoOrientationSwapsDimensions(effectiveOrientation);
    size_t defaultUnrotatedW = (size_t)MAX(1, SFXUnrotatedDisplayVideoWidthForPixelBuffer(pixelBuffer));
    size_t defaultUnrotatedH = CVPixelBufferGetHeight(pixelBuffer);
    size_t defaultW = swapsDimensions ? defaultUnrotatedH : defaultUnrotatedW;
    size_t defaultH = swapsDimensions ? defaultUnrotatedW : defaultUnrotatedH;
    size_t outW = targetWidth > 0 ? targetWidth : defaultW;
    size_t outH = targetHeight > 0 ? targetHeight : defaultH;

    BOOL isHDRSource = SFXPixelBufferIsHDR(pixelBuffer);
    BOOL hdrScreenshotOn = SFXIsHDRScreenshotEnabled();
    CGImageRef image = NULL;
    if (isHDRSource) {
        SFXHDRRenderTargetMode mode = hdrScreenshotOn
            ? SFXHDRRenderTargetModeStaticHDRScreenshot
            : SFXHDRRenderTargetModeStaticSDRScreenshot;
        image = [[SFXHDRMetalContext sharedContext]
            createRenderedCGImageFromSource:pixelBuffer
                                targetWidth:outW
                               targetHeight:outH
                      quarterTurnsClockwise:(NSInteger)effectiveOrientation
                                 targetMode:mode];
    }
    if (image == NULL) {
        image = [[SFXHDRMetalContext sharedContext]
            createSDRCGImageFromPixelBuffer:pixelBuffer
                                targetWidth:outW
                               targetHeight:outH
                      quarterTurnsClockwise:(NSInteger)effectiveOrientation];
    }
    double renderMs = SFXMonotonicMilliseconds() - renderStartMs;
    double totalStaticRenderMs = decodeMilliseconds + renderMs;

    if (sceneName != nil && totalStaticRenderMs >= 200.0 && SFXIsDebugTelemetryEnabled()) {
        NSString *colorSummary = SFXDescribePixelBufferColorSummary(pixelBuffer);
        NSString *details = [NSString stringWithFormat:
            @"scene=%@ hdr_screenshot=%@ source_is_hdr=%@ source_color=%@ output=%zux%zu decode_ms=%.2f render_ms=%.2f total_ms=%.2f",
            sceneName,
            hdrScreenshotOn ? @"on" : @"off",
            isHDRSource ? @"true" : @"false",
            colorSummary,
            outW,
            outH,
            decodeMilliseconds,
            renderMs,
            totalStaticRenderMs];
        SFXEmitDebugTelemetryLog(@"playback.static_image.slow_render", details);
    }

    return image;
}

CGImageRef _Nullable SFXCopyRenderedImageFromPixelBuffer(
    CVPixelBufferRef pixelBuffer,
    size_t targetWidth,
    size_t targetHeight,
    NSString * _Nullable sceneName
) {
    return SFXCopyRenderedImageFromPixelBufferWithRotation(
        pixelBuffer,
        targetWidth,
        targetHeight,
        0,
        0.0,
        sceneName
    );
}

static CVPixelBufferRef _Nullable SFXCreateTemporaryPixelBufferFromAVFrame(
    const AVFormatContext * _Nullable formatContext,
    const AVStream * _Nullable videoStream,
    const AVCodecContext * _Nullable codecContext,
    const AVFrame *frame
) {
    if (frame == NULL || frame->width <= 0 || frame->height <= 0) {
        return NULL;
    }
    AVRational sar = SFXVideoSampleAspectRatio(
        (AVFormatContext *)formatContext,
        (AVStream *)videoStream,
        codecContext,
        frame
    );
    SFXVideoOrientation orientation = SFXResolveVideoOrientation(videoStream, frame);
    if (frame->format == AV_PIX_FMT_VIDEOTOOLBOX && frame->data[3] != NULL) {
        CVPixelBufferRef vtBuffer = (CVPixelBufferRef)frame->data[3];
        CVPixelBufferRetain(vtBuffer);
        SFXApplyColorSpaceAttachments(vtBuffer, videoStream, codecContext, frame);
        SFXApplyPixelAspectRatioAttachment(vtBuffer, sar);
        SFXApplyVideoOrientationAttachment(vtBuffer, orientation);
        SFXAttachHDRMetadataToPixelBuffer(vtBuffer, codecContext, videoStream, frame);
        return vtBuffer;
    }

    const AVPixFmtDescriptor *desc = av_pix_fmt_desc_get((enum AVPixelFormat)frame->format);
    int bitDepth = (desc != NULL && desc->nb_components > 0) ? desc->comp[0].depth : 8;
    BOOL isFullRange = SFXResolveVideoIsFullRange(videoStream, codecContext, frame, (enum AVPixelFormat)frame->format);
    OSType cvFormat = (bitDepth > 8)
        ? (isFullRange ? kCVPixelFormatType_420YpCbCr10BiPlanarFullRange : kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        : (isFullRange ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange);

    NSDictionary *attrs = @{
        (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(cvFormat),
        (__bridge NSString *)kCVPixelBufferWidthKey: @(frame->width),
        (__bridge NSString *)kCVPixelBufferHeightKey: @(frame->height),
        (__bridge NSString *)kCVPixelBufferMetalCompatibilityKey: @YES,
        (__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{},
    };
    CVPixelBufferRef pixelBuffer = NULL;
    if (CVPixelBufferCreate(
            kCFAllocatorDefault,
            (size_t)frame->width,
            (size_t)frame->height,
            cvFormat,
            (__bridge CFDictionaryRef)attrs,
            &pixelBuffer) != kCVReturnSuccess || pixelBuffer == NULL) {
        return NULL;
    }

    if (!SFXFastPackSoftwareAVFrameIntoPixelBuffer(frame, pixelBuffer)) {
        enum AVPixelFormat targetFFmpegFmt = (bitDepth > 8) ? AV_PIX_FMT_P010LE : AV_PIX_FMT_NV12;
        struct SwsContext *sws = sws_getContext(
            frame->width,
            frame->height,
            (enum AVPixelFormat)frame->format,
            frame->width,
            frame->height,
            targetFFmpegFmt,
            SWS_BILINEAR,
            NULL,
            NULL,
            NULL
        );
        if (sws == NULL || CVPixelBufferLockBaseAddress(pixelBuffer, 0) != kCVReturnSuccess) {
            if (sws != NULL) sws_freeContext(sws);
            CVPixelBufferRelease(pixelBuffer);
            return NULL;
        }
        uint8_t *dstData[4] = {
            (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
            (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1),
            NULL,
            NULL
        };
        int dstLinesize[4] = {
            (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0),
            (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1),
            0,
            0
        };
        sws_scale(
            sws,
            (const uint8_t * const *)frame->data,
            frame->linesize,
            0,
            frame->height,
            dstData,
            dstLinesize
        );
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        sws_freeContext(sws);
    }

    SFXApplyColorSpaceAttachments(pixelBuffer, videoStream, codecContext, frame);
    SFXApplyPixelAspectRatioAttachment(pixelBuffer, sar);
    SFXApplyVideoOrientationAttachment(pixelBuffer, orientation);
    SFXAttachHDRMetadataToPixelBuffer(pixelBuffer, codecContext, videoStream, frame);
    return pixelBuffer;
}

CGImageRef _Nullable SFXCopyRenderedImageFromAVFrame(
    const AVFormatContext * _Nullable formatContext,
    const AVStream * _Nullable videoStream,
    const AVCodecContext * _Nullable codecContext,
    const AVFrame *frame,
    size_t requestedTargetWidth,
    size_t requestedTargetHeight,
    double decodeMilliseconds,
    NSString * _Nullable sceneName,
    CGSize * _Nullable outDisplaySize
) {
    if (frame == NULL || frame->width <= 0 || frame->height <= 0) {
        return NULL;
    }
    AVRational sar = SFXVideoSampleAspectRatio(
        (AVFormatContext *)formatContext,
        (AVStream *)videoStream,
        codecContext,
        frame
    );
    SFXVideoOrientation orientation = SFXResolveVideoOrientation(videoStream, frame);
    NSInteger unrotatedW = SFXDisplayVideoWidthForDimensionsAndSAR(frame->width, frame->height, sar);
    NSInteger unrotatedH = frame->height;
    NSInteger displayW = SFXVideoOrientationSwapsDimensions(orientation) ? unrotatedH : unrotatedW;
    NSInteger displayH = SFXVideoOrientationSwapsDimensions(orientation) ? unrotatedW : unrotatedH;
    if (outDisplaySize != NULL) {
        *outDisplaySize = CGSizeMake((CGFloat)displayW, (CGFloat)displayH);
    }

    size_t outW = (size_t)MAX(1, displayW);
    size_t outH = (size_t)MAX(1, displayH);
    if (requestedTargetWidth > 0 && requestedTargetHeight > 0) {
        outW = requestedTargetWidth;
        outH = requestedTargetHeight;
    } else if (requestedTargetWidth > 0 && displayW > 0 && displayH > 0) {
        outW = MIN((size_t)displayW, requestedTargetWidth);
        outH = (size_t)MAX(1, llround(((double)displayH * (double)outW) / (double)displayW));
    }

    CVPixelBufferRef pixelBuffer = SFXCreateTemporaryPixelBufferFromAVFrame(
        formatContext,
        videoStream,
        codecContext,
        frame
    );
    if (pixelBuffer == NULL) {
        return NULL;
    }
    CGImageRef image = SFXCopyRenderedImageFromPixelBufferWithRotation(
        pixelBuffer,
        outW,
        outH,
        (NSInteger)orientation,
        decodeMilliseconds,
        sceneName
    );
    CVPixelBufferRelease(pixelBuffer);
    return image;
}

NSData * _Nullable SFXCopyRGB24DataFromCGImage(
    CGImageRef image,
    size_t targetWidth,
    size_t targetHeight
) {
    if (image == NULL || targetWidth == 0 || targetHeight == 0) {
        return nil;
    }
    size_t rgbaRowBytes = targetWidth * 4;
    NSMutableData *rgbaData = [NSMutableData dataWithLength:rgbaRowBytes * targetHeight];
    if (rgbaData == nil) {
        return nil;
    }
    CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef ctx = CGBitmapContextCreate(
        rgbaData.mutableBytes,
        targetWidth,
        targetHeight,
        8,
        rgbaRowBytes,
        srgb,
        (CGBitmapInfo)kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big
    );
    CGColorSpaceRelease(srgb);
    if (ctx == nil) {
        return nil;
    }
    CGContextSetInterpolationQuality(ctx, kCGInterpolationMedium);
    size_t imgW = CGImageGetWidth(image);
    size_t imgH = CGImageGetHeight(image);
    CGRect drawRect = CGRectMake(0, 0, (CGFloat)targetWidth, (CGFloat)targetHeight);
    if (imgW > 0 && imgH > 0) {
        double scale = fmin((double)targetWidth / (double)imgW, (double)targetHeight / (double)imgH);
        int scaledWidth = MAX(1, MIN((int)targetWidth, (int)llround((double)imgW * scale)));
        int scaledHeight = MAX(1, MIN((int)targetHeight, (int)llround((double)imgH * scale)));
        int padX = ((int)targetWidth - scaledWidth) / 2;
        int padY = ((int)targetHeight - scaledHeight) / 2;
        drawRect = CGRectMake((CGFloat)padX, (CGFloat)padY, (CGFloat)scaledWidth, (CGFloat)scaledHeight);
    }
    CGContextDrawImage(ctx, drawRect, image);
    CGContextRelease(ctx);

    NSMutableData *rgb24 = [NSMutableData dataWithLength:targetWidth * targetHeight * 3];
    const uint8_t *src = (const uint8_t *)rgbaData.bytes;
    uint8_t *dst = (uint8_t *)rgb24.mutableBytes;
    size_t count = targetWidth * targetHeight;
    for (size_t i = 0; i < count; i++) {
        dst[i * 3 + 0] = src[i * 4 + 0];
        dst[i * 3 + 1] = src[i * 4 + 1];
        dst[i * 3 + 2] = src[i * 4 + 2];
    }
    return rgb24;
}

CGImageRef _Nullable SFXCopyRenderedVideoFrameImageAtMediaPath(
    NSString *mediaPath,
    NSString * _Nullable httpHeaders,
    NSInteger timestampMilliseconds,
    NSString * _Nullable sceneName,
    NSError * _Nullable * _Nullable error
) {
    if (mediaPath.length == 0) {
        return NULL;
    }
    double decodeStartMs = SFXMonotonicMilliseconds();

    AVFormatContext *formatContext = NULL;
    int status = SFXOpenMediaInput(
        &formatContext,
        mediaPath.UTF8String,
        httpHeaders
    );
    if (status < 0 || formatContext == NULL) {
        if (error != NULL) {
            *error = SFXNativePlaybackError(status, SFXFFmpegErrorString(status));
        }
        return NULL;
    }

    if (avformat_find_stream_info(formatContext, NULL) < 0) {
        avformat_close_input(&formatContext);
        return NULL;
    }

    int videoStreamIndex = SFXSelectPrimaryVideoStreamIndex(formatContext);
    if (videoStreamIndex < 0) {
        videoStreamIndex = av_find_best_stream(formatContext, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    }
    if (videoStreamIndex < 0) {
        avformat_close_input(&formatContext);
        return NULL;
    }

    AVStream *videoStream = formatContext->streams[videoStreamIndex];
    const AVCodec *decoder = SFXFindSoftwareVideoDecoder(videoStream->codecpar->codec_id);
    if (decoder == NULL) {
        decoder = avcodec_find_decoder(videoStream->codecpar->codec_id);
    }
    if (decoder == NULL) {
        avformat_close_input(&formatContext);
        return NULL;
    }

    AVCodecContext *codecContext = avcodec_alloc_context3(decoder);
    if (codecContext == NULL) {
        avformat_close_input(&formatContext);
        return NULL;
    }
    if (avcodec_parameters_to_context(codecContext, videoStream->codecpar) < 0) {
        avcodec_free_context(&codecContext);
        avformat_close_input(&formatContext);
        return NULL;
    }
    codecContext->pkt_timebase = videoStream->time_base;
    codecContext->thread_count = 2;
    if (avcodec_open2(codecContext, decoder, NULL) < 0) {
        avcodec_free_context(&codecContext);
        avformat_close_input(&formatContext);
        return NULL;
    }

    NSInteger clampedTargetMs = MAX(0, timestampMilliseconds);
    double timelineOriginSeconds = SFXMediaTimelineOriginSeconds(formatContext);
    double targetSeconds = (double)clampedTargetMs / 1000.0;
    double resolvedDurationSeconds = SFXResolveMediaDurationSeconds(
        formatContext,
        videoStreamIndex,
        timelineOriginSeconds
    );
    if (isfinite(resolvedDurationSeconds)
        && resolvedDurationSeconds > 0.0
        && targetSeconds > resolvedDurationSeconds + 0.05) {
        avcodec_free_context(&codecContext);
        avformat_close_input(&formatContext);
        return NULL;
    }
    if (clampedTargetMs > 0) {
        SFXSeekToStartPosition(
            formatContext,
            videoStreamIndex,
            targetSeconds,
            timelineOriginSeconds,
            NULL
        );
        avcodec_flush_buffers(codecContext);
    }

    AVPacket *packet = av_packet_alloc();
    AVFrame *frame = av_frame_alloc();
    AVFrame *bestFrame = av_frame_alloc();
    BOOL hasBestFrame = NO;
    BOOL reachedTarget = NO;

    while (av_read_frame(formatContext, packet) >= 0) {
        if (packet->stream_index != videoStreamIndex) {
            av_packet_unref(packet);
            continue;
        }
        int sendStatus = avcodec_send_packet(codecContext, packet);
        av_packet_unref(packet);
        if (sendStatus < 0) {
            continue;
        }
        while (avcodec_receive_frame(codecContext, frame) == 0) {
            av_frame_unref(bestFrame);
            av_frame_move_ref(bestFrame, frame);
            hasBestFrame = YES;

            double frameSec = SFXFramePlaybackSeconds(bestFrame, videoStream, timelineOriginSeconds);
            if (frameSec + 0.010 >= targetSeconds) {
                reachedTarget = YES;
                break;
            }
        }
        if (reachedTarget) {
            break;
        }
    }

    if (!hasBestFrame) {
        avcodec_send_packet(codecContext, NULL);
        while (avcodec_receive_frame(codecContext, frame) == 0) {
            av_frame_unref(bestFrame);
            av_frame_move_ref(bestFrame, frame);
            hasBestFrame = YES;
        }
    }

    if (!reachedTarget && hasBestFrame) {
        double finalFrameSec = SFXFramePlaybackSeconds(bestFrame, videoStream, timelineOriginSeconds);
        if (finalFrameSec >= 0.0 && finalFrameSec + 1.0 < targetSeconds) {
            hasBestFrame = NO;
        }
    }

    double decodeMs = SFXMonotonicMilliseconds() - decodeStartMs;
    CGImageRef renderedImage = NULL;
    if (hasBestFrame) {
        renderedImage = SFXCopyRenderedImageFromAVFrame(
            formatContext,
            videoStream,
            codecContext,
            bestFrame,
            0,
            0,
            decodeMs,
            sceneName ?: @"static_extract",
            NULL
        );
    }

    av_frame_free(&bestFrame);
    av_frame_free(&frame);
    av_packet_free(&packet);
    avcodec_free_context(&codecContext);
    avformat_close_input(&formatContext);
    return renderedImage;
}
