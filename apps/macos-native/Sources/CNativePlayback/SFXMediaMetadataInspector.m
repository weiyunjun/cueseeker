#import "SFXNativePlaybackPlayer.h"
#import "SFXNativePlaybackInternal.h"

#import <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <strings.h>
#include <libavcodec/avcodec.h>
#include <libavcodec/codec_id.h>
#include <libavformat/avformat.h>
#include <libavutil/dict.h>
#include <libavutil/dovi_meta.h>
#include <libavutil/error.h>
#include <libavutil/hdr_dynamic_metadata.h>
#include <libavutil/mastering_display_metadata.h>
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
                        channels:(NSNumber *)channels
                      sampleRate:(NSNumber *)sampleRate
                        bitDepth:(NSNumber *)bitDepth NS_DESIGNATED_INITIALIZER;

@end

@implementation SFXMediaAudioTrack

- (instancetype)initWithLanguage:(NSString *)language
                           title:(NSString *)title
                           codec:(NSString *)codec
                        channels:(NSNumber *)channels
                      sampleRate:(NSNumber *)sampleRate
                        bitDepth:(NSNumber *)bitDepth {
    self = [super init];
    if (self != nil) {
        _language = [language copy];
        _title = [title copy];
        _codec = [codec copy];
        _channels = channels;
        _sampleRate = sampleRate;
        _bitDepth = bitDepth;
    }
    return self;
}

@end

@interface SFXMediaContainerProbe ()

- (instancetype)initWithFormatName:(NSString *)formatName
          hasHeaderVideoParameters:(BOOL)hasHeaderVideoParameters
              swapsVideoDimensions:(BOOL)swapsVideoDimensions
               inferredColorMatrix:(nullable NSString *)inferredColorMatrix NS_DESIGNATED_INITIALIZER;

@end

@implementation SFXMediaContainerProbe

- (instancetype)initWithFormatName:(NSString *)formatName
          hasHeaderVideoParameters:(BOOL)hasHeaderVideoParameters
              swapsVideoDimensions:(BOOL)swapsVideoDimensions
               inferredColorMatrix:(nullable NSString *)inferredColorMatrix {
    self = [super init];
    if (self != nil) {
        _formatName = [formatName copy];
        _hasHeaderVideoParameters = hasHeaderVideoParameters;
        _swapsVideoDimensions = swapsVideoDimensions;
        _inferredColorMatrix = [inferredColorMatrix copy];
    }
    return self;
}

@end

@interface SFXMediaHDRMetadata ()

- (instancetype)initWithStandards:(NSArray<NSString *> *)standards
               dolbyVisionProfile:(nullable NSNumber *)dolbyVisionProfile
       dolbyVisionCompatibilityID:(nullable NSNumber *)dolbyVisionCompatibilityID
                   colorPrimaries:(nullable NSString *)colorPrimaries
                 transferFunction:(nullable NSString *)transferFunction
        masteringDisplayPrimaries:(nullable NSString *)masteringDisplayPrimaries
     masteringDisplayMinLuminance:(nullable NSNumber *)masteringDisplayMinLuminance
     masteringDisplayMaxLuminance:(nullable NSNumber *)masteringDisplayMaxLuminance
                           maxCLL:(nullable NSNumber *)maxCLL
                          maxFALL:(nullable NSNumber *)maxFALL NS_DESIGNATED_INITIALIZER;

@end

@implementation SFXMediaHDRMetadata

- (instancetype)initWithStandards:(NSArray<NSString *> *)standards
               dolbyVisionProfile:(nullable NSNumber *)dolbyVisionProfile
       dolbyVisionCompatibilityID:(nullable NSNumber *)dolbyVisionCompatibilityID
                   colorPrimaries:(nullable NSString *)colorPrimaries
                 transferFunction:(nullable NSString *)transferFunction
        masteringDisplayPrimaries:(nullable NSString *)masteringDisplayPrimaries
     masteringDisplayMinLuminance:(nullable NSNumber *)masteringDisplayMinLuminance
     masteringDisplayMaxLuminance:(nullable NSNumber *)masteringDisplayMaxLuminance
                           maxCLL:(nullable NSNumber *)maxCLL
                          maxFALL:(nullable NSNumber *)maxFALL {
    self = [super init];
    if (self != nil) {
        _standards = [standards copy];
        _dolbyVisionProfile = dolbyVisionProfile;
        _dolbyVisionCompatibilityID = dolbyVisionCompatibilityID;
        _colorPrimaries = [colorPrimaries copy];
        _transferFunction = [transferFunction copy];
        _masteringDisplayPrimaries = [masteringDisplayPrimaries copy];
        _masteringDisplayMinLuminance = masteringDisplayMinLuminance;
        _masteringDisplayMaxLuminance = masteringDisplayMaxLuminance;
        _maxCLL = maxCLL;
        _maxFALL = maxFALL;
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
                          videoBitDepth:(NSNumber *)videoBitDepth
                       videoPixelFormat:(NSString *)videoPixelFormat
                             formatName:(nullable NSString *)formatName
                             majorBrand:(nullable NSString *)majorBrand
                            hdrMetadata:(nullable SFXMediaHDRMetadata *)hdrMetadata
                            audioTracks:(NSArray<SFXMediaAudioTrack *> *)audioTracks NS_DESIGNATED_INITIALIZER;

@end

@implementation SFXMediaMetadata

- (instancetype)initWithDurationSeconds:(NSNumber *)durationSeconds
                             videoWidth:(NSNumber *)videoWidth
                            videoHeight:(NSNumber *)videoHeight
                              frameRate:(NSNumber *)frameRate
                             videoCodec:(NSString *)videoCodec
                          videoBitDepth:(NSNumber *)videoBitDepth
                       videoPixelFormat:(NSString *)videoPixelFormat
                             formatName:(nullable NSString *)formatName
                             majorBrand:(nullable NSString *)majorBrand
                            hdrMetadata:(nullable SFXMediaHDRMetadata *)hdrMetadata
                            audioTracks:(NSArray<SFXMediaAudioTrack *> *)audioTracks {
    self = [super init];
    if (self != nil) {
        _durationSeconds = durationSeconds;
        _videoWidth = videoWidth;
        _videoHeight = videoHeight;
        _frameRate = frameRate;
        _videoCodec = [videoCodec copy];
        _videoBitDepth = videoBitDepth;
        _videoPixelFormat = [videoPixelFormat copy];
        _formatName = [formatName copy];
        _majorBrand = [majorBrand copy];
        _hdrMetadata = hdrMetadata;
        _audioTracks = [audioTracks copy];
    }
    return self;
}

@end

typedef struct SFXHDRProbeState {
    BOOL hasDolbyVision;
    int dolbyVisionProfile;
    int dolbyVisionCompatibilityID;
    BOOL hasHDR10Plus;
    enum AVColorPrimaries primaries;
    enum AVColorTransferCharacteristic transfer;
    enum AVColorSpace matrix;
    int masteringPrimariesKind; // 1: display_p3, 2: dci_p3, 3: bt2020, 4: bt709
    BOOL hasMasteringLuminance;
    BOOL masteringLuminanceIsExact;
    double masteringMinLuminance;
    double masteringMaxLuminance;
    unsigned int maxCLL;
    unsigned int maxFALL;
} SFXHDRProbeState;

static BOOL SFXHDRColorPrimariesUnspecified(enum AVColorPrimaries primaries) {
    return primaries == AVCOL_PRI_RESERVED0
        || primaries == AVCOL_PRI_UNSPECIFIED
        || primaries == AVCOL_PRI_RESERVED;
}

static BOOL SFXHDRColorTransferUnspecified(enum AVColorTransferCharacteristic transfer) {
    return transfer == AVCOL_TRC_RESERVED0
        || transfer == AVCOL_TRC_UNSPECIFIED
        || transfer == AVCOL_TRC_RESERVED;
}

static BOOL SFXHDRIsTransferSignalHDR(enum AVColorTransferCharacteristic transfer) {
    return transfer == AVCOL_TRC_SMPTE2084 || transfer == AVCOL_TRC_ARIB_STD_B67;
}

static BOOL SFXHDRStateHasAnyHDRSignal(const SFXHDRProbeState *state) {
    return state->hasDolbyVision
        || state->hasHDR10Plus
        || SFXHDRIsTransferSignalHDR(state->transfer)
        || state->matrix == AVCOL_SPC_IPT_C2;
}

static BOOL SFXHDRFormatNameTokenMatches(const char *formatName, const char *target) {
    size_t targetLen = strlen(target);
    const char *cursor = formatName;
    while (cursor != NULL && *cursor != '\0') {
        const char *comma = strchr(cursor, ',');
        size_t tokenLen = comma != NULL ? (size_t)(comma - cursor) : strlen(cursor);
        if (tokenLen == targetLen && strncasecmp(cursor, target, tokenLen) == 0) {
            return YES;
        }
        cursor = comma != NULL ? comma + 1 : NULL;
    }
    return NO;
}

static BOOL SFXIsBroadcastOrRawStreamFormatName(const char *formatName) {
    if (formatName == NULL || formatName[0] == '\0') {
        return NO;
    }
    static const char *const kStreamFormats[] = {
        "mpegts", "mpeg", "hls", "applehttp", "hevc", "h264", "m4v", "ivf", "obu", "rawvideo"
    };
    for (size_t i = 0; i < sizeof(kStreamFormats) / sizeof(kStreamFormats[0]); i++) {
        if (SFXHDRFormatNameTokenMatches(formatName, kStreamFormats[i])) {
            return YES;
        }
    }
    return NO;
}

static BOOL SFXHDRCodecSupportsBroadcastOrMidStreamHDR(enum AVCodecID codecID) {
    return codecID == AV_CODEC_ID_HEVC
        || codecID == AV_CODEC_ID_AV1
        || codecID == AV_CODEC_ID_VP9
        || codecID == AV_CODEC_ID_VVC;
}

static BOOL SFXHDRNearXY(double ax, double ay, double bx, double by) {
    return fabs(ax - bx) <= 0.005 && fabs(ay - by) <= 0.005;
}

static int SFXHDRClassifyCIExyPrimaries(AVCIExy r, AVCIExy g, AVCIExy b, AVCIExy w) {
    if (r.x.den <= 0 || r.y.den <= 0
        || g.x.den <= 0 || g.y.den <= 0
        || b.x.den <= 0 || b.y.den <= 0) {
        return 0;
    }
    double rx = av_q2d(r.x);
    double ry = av_q2d(r.y);
    double gx = av_q2d(g.x);
    double gy = av_q2d(g.y);
    double bx = av_q2d(b.x);
    double by = av_q2d(b.y);
    if (!isfinite(rx) || !isfinite(ry) || !isfinite(gx) || !isfinite(gy) || !isfinite(bx) || !isfinite(by)) {
        return 0;
    }

    BOOL hasWhite = w.x.den > 0 && w.y.den > 0;
    double wx = hasWhite ? av_q2d(w.x) : 0.0;
    double wy = hasWhite ? av_q2d(w.y) : 0.0;
    hasWhite = hasWhite && isfinite(wx) && isfinite(wy) && (wx > 0.0 || wy > 0.0);

    if (SFXHDRNearXY(rx, ry, 0.680, 0.320)
        && SFXHDRNearXY(gx, gy, 0.265, 0.690)
        && SFXHDRNearXY(bx, by, 0.150, 0.060)) {
        if (hasWhite && SFXHDRNearXY(wx, wy, 0.314, 0.351)) {
            return 2; // dci_p3
        }
        if (!hasWhite || SFXHDRNearXY(wx, wy, 0.3127, 0.3290)) {
            return 1; // display_p3
        }
    }
    if (SFXHDRNearXY(rx, ry, 0.708, 0.292)
        && SFXHDRNearXY(gx, gy, 0.170, 0.797)
        && SFXHDRNearXY(bx, by, 0.131, 0.046)
        && (!hasWhite || SFXHDRNearXY(wx, wy, 0.3127, 0.3290))) {
        return 3; // bt2020
    }
    if (SFXHDRNearXY(rx, ry, 0.640, 0.330)
        && SFXHDRNearXY(gx, gy, 0.300, 0.600)
        && SFXHDRNearXY(bx, by, 0.150, 0.060)
        && (!hasWhite || SFXHDRNearXY(wx, wy, 0.3127, 0.3290))) {
        return 4; // bt709
    }
    return 0;
}

static int SFXHDRClassifyMasteringPrimaries(const AVMasteringDisplayMetadata *md) {
    if (md == NULL || !md->has_primaries) {
        return 0;
    }
    AVCIExy r = { md->display_primaries[0][0], md->display_primaries[0][1] };
    AVCIExy g = { md->display_primaries[1][0], md->display_primaries[1][1] };
    AVCIExy b = { md->display_primaries[2][0], md->display_primaries[2][1] };
    AVCIExy w = { md->white_point[0], md->white_point[1] };
    return SFXHDRClassifyCIExyPrimaries(r, g, b, w);
}

static void SFXHDRMergeMasteringDisplay(SFXHDRProbeState *state, const AVMasteringDisplayMetadata *md) {
    if (md == NULL) {
        return;
    }
    if (state->masteringPrimariesKind == 0) {
        state->masteringPrimariesKind = SFXHDRClassifyMasteringPrimaries(md);
    }
    if (!state->masteringLuminanceIsExact
        && md->has_luminance
        && md->min_luminance.den > 0
        && md->max_luminance.den > 0) {
        double minLum = av_q2d(md->min_luminance);
        double maxLum = av_q2d(md->max_luminance);
        if (isfinite(minLum) && isfinite(maxLum) && minLum >= 0.0 && maxLum > 0.0 && maxLum >= minLum) {
            state->hasMasteringLuminance = YES;
            state->masteringLuminanceIsExact = YES;
            state->masteringMinLuminance = minLum;
            state->masteringMaxLuminance = maxLum;
        }
    }
}

static double SFXHDRPQ12BitCodeToNits(uint16_t pqCode) {
    if (pqCode == 0) {
        return 0.0;
    }
    double normalized = fmin(fmax((double)pqCode / 4095.0, 0.0), 1.0);
    static const double m1 = 2610.0 / 16384.0;
    static const double m2 = (2523.0 / 4096.0) * 128.0;
    static const double c1 = 3424.0 / 4096.0;
    static const double c2 = (2413.0 / 4096.0) * 32.0;
    static const double c3 = (2392.0 / 4096.0) * 32.0;
    double np = pow(normalized, 1.0 / m2);
    double num = fmax(np - c1, 0.0);
    double den = c2 - c3 * np;
    if (den <= 0.0) {
        return 0.0;
    }
    return 10000.0 * pow(num / den, 1.0 / m1);
}

static void SFXHDRMergeDOVIMetadata(SFXHDRProbeState *state, const AVFrameSideData *doviSD) {
    if (doviSD == NULL || doviSD->data == NULL || doviSD->size < sizeof(AVDOVIMetadata)) {
        return;
    }
    state->hasDolbyVision = YES;
    const AVDOVIMetadata *doviMeta = (const AVDOVIMetadata *)doviSD->data;

    if (doviMeta->num_ext_blocks > 0
        && doviMeta->ext_block_size >= sizeof(AVDOVIDmData)
        && doviMeta->ext_block_offset >= sizeof(AVDOVIMetadata)
        && doviMeta->ext_block_offset <= doviSD->size) {
        size_t maxBlocks = (doviSD->size - doviMeta->ext_block_offset) / doviMeta->ext_block_size;
        int blockCount = doviMeta->num_ext_blocks;
        if ((size_t)blockCount > maxBlocks) {
            blockCount = (int)maxBlocks;
        }
        for (int i = 0; i < blockCount; i++) {
            const AVDOVIDmData *ext = av_dovi_get_ext(doviMeta, i);
            if (ext == NULL) {
                continue;
            }
            if (ext->level == 9 && state->masteringPrimariesKind == 0) {
                const AVColorPrimariesDesc *desc = &ext->l9.source_display_primaries;
                if (desc->prim.r.x.den > 0 && desc->prim.r.y.den > 0
                    && desc->prim.g.x.den > 0 && desc->prim.g.y.den > 0
                    && desc->prim.b.x.den > 0 && desc->prim.b.y.den > 0
                    && desc->wp.x.den > 0 && desc->wp.y.den > 0) {
                    state->masteringPrimariesKind = SFXHDRClassifyCIExyPrimaries(
                        desc->prim.r,
                        desc->prim.g,
                        desc->prim.b,
                        desc->wp
                    );
                }
            } else if (ext->level == 6) {
                if (!state->masteringLuminanceIsExact && ext->l6.max_luminance > 0) {
                    double minLum = (double)ext->l6.min_luminance / 10000.0;
                    double maxLum = (double)ext->l6.max_luminance;
                    if (maxLum >= minLum) {
                        state->hasMasteringLuminance = YES;
                        state->masteringLuminanceIsExact = YES;
                        state->masteringMinLuminance = minLum;
                        state->masteringMaxLuminance = maxLum;
                    }
                }
                if (ext->l6.max_cll > 0 && state->maxCLL == 0) {
                    state->maxCLL = ext->l6.max_cll;
                }
                if (ext->l6.max_fall > 0 && state->maxFALL == 0) {
                    state->maxFALL = ext->l6.max_fall;
                }
            }
        }
    }

    if (!state->hasMasteringLuminance
        && doviMeta->color_offset >= sizeof(AVDOVIMetadata)
        && sizeof(AVDOVIColorMetadata) <= doviSD->size
        && doviMeta->color_offset <= doviSD->size - sizeof(AVDOVIColorMetadata)) {
        const AVDOVIColorMetadata *color = av_dovi_get_color(doviMeta);
        if (color != NULL && color->source_max_pq > 0) {
            double minNits = SFXHDRPQ12BitCodeToNits(color->source_min_pq);
            double maxNits = SFXHDRPQ12BitCodeToNits(color->source_max_pq);
            double minLum = round(minNits * 10000.0) / 10000.0;
            double maxLum = maxNits >= 10.0
                ? round(maxNits)
                : (round(maxNits * 10000.0) / 10000.0);
            if (isfinite(minLum) && isfinite(maxLum) && minLum >= 0.0 && maxLum > 0.0 && maxLum >= minLum) {
                state->hasMasteringLuminance = YES;
                state->masteringLuminanceIsExact = NO;
                state->masteringMinLuminance = minLum;
                state->masteringMaxLuminance = maxLum;
            }
        }
    }
}

static void SFXHDRMergeContentLight(SFXHDRProbeState *state, const AVContentLightMetadata *clm) {
    if (clm == NULL) {
        return;
    }
    if (clm->MaxCLL > 0 && state->maxCLL == 0) {
        state->maxCLL = clm->MaxCLL;
    }
    if (clm->MaxFALL > 0 && state->maxFALL == 0) {
        state->maxFALL = clm->MaxFALL;
    }
}

static void SFXHDRMergePacketSideDataList(SFXHDRProbeState *state, const AVPacketSideData *sdList, int nbSd) {
    if (sdList == NULL || nbSd <= 0) {
        return;
    }
    const AVPacketSideData *doviSD = av_packet_side_data_get(sdList, nbSd, AV_PKT_DATA_DOVI_CONF);
    if (doviSD != NULL && doviSD->data != NULL && doviSD->size >= sizeof(AVDOVIDecoderConfigurationRecord)) {
        const AVDOVIDecoderConfigurationRecord *conf = (const AVDOVIDecoderConfigurationRecord *)doviSD->data;
        state->hasDolbyVision = YES;
        if (conf->dv_profile > 0 && state->dolbyVisionProfile <= 0) {
            state->dolbyVisionProfile = conf->dv_profile;
        }
        if (conf->dv_bl_signal_compatibility_id > 0 && state->dolbyVisionCompatibilityID <= 0) {
            state->dolbyVisionCompatibilityID = conf->dv_bl_signal_compatibility_id;
        }
    }
    const AVPacketSideData *mdSD = av_packet_side_data_get(sdList, nbSd, AV_PKT_DATA_MASTERING_DISPLAY_METADATA);
    if (mdSD != NULL && mdSD->data != NULL && mdSD->size >= sizeof(AVMasteringDisplayMetadata)) {
        SFXHDRMergeMasteringDisplay(state, (const AVMasteringDisplayMetadata *)mdSD->data);
    }
    const AVPacketSideData *cllSD = av_packet_side_data_get(sdList, nbSd, AV_PKT_DATA_CONTENT_LIGHT_LEVEL);
    if (cllSD != NULL && cllSD->data != NULL && cllSD->size >= sizeof(AVContentLightMetadata)) {
        SFXHDRMergeContentLight(state, (const AVContentLightMetadata *)cllSD->data);
    }
    const AVPacketSideData *hdrPlusSD = av_packet_side_data_get(sdList, nbSd, AV_PKT_DATA_DYNAMIC_HDR10_PLUS);
    if (hdrPlusSD != NULL && hdrPlusSD->data != NULL && hdrPlusSD->size > 0) {
        state->hasHDR10Plus = YES;
    }
}

static void SFXHDRMergeFrame(SFXHDRProbeState *state, const AVFrame *frame) {
    if (frame == NULL) {
        return;
    }
    BOOL frameIsHDR = SFXHDRIsTransferSignalHDR(frame->color_trc);
    if (!SFXHDRColorTransferUnspecified(frame->color_trc)
        && (SFXHDRColorTransferUnspecified(state->transfer) || frameIsHDR)) {
        state->transfer = frame->color_trc;
    }
    if (!SFXHDRColorPrimariesUnspecified(frame->color_primaries)
        && (SFXHDRColorPrimariesUnspecified(state->primaries)
            || frame->color_primaries == AVCOL_PRI_BT2020
            || frameIsHDR)) {
        state->primaries = frame->color_primaries;
    }
    if (frame->colorspace != AVCOL_SPC_UNSPECIFIED
        && frame->colorspace != AVCOL_SPC_RESERVED
        && (state->matrix == AVCOL_SPC_UNSPECIFIED
            || state->matrix == AVCOL_SPC_RESERVED
            || frame->colorspace == AVCOL_SPC_IPT_C2
            || frame->colorspace == AVCOL_SPC_ICTCP)) {
        state->matrix = frame->colorspace;
    }

    const AVFrameSideData *doviSD = av_frame_get_side_data(frame, AV_FRAME_DATA_DOVI_METADATA);
    if (doviSD != NULL) {
        SFXHDRMergeDOVIMetadata(state, doviSD);
    }
    if (av_frame_get_side_data(frame, AV_FRAME_DATA_DOVI_RPU_BUFFER) != NULL) {
        state->hasDolbyVision = YES;
    }
    if (av_frame_get_side_data(frame, AV_FRAME_DATA_DYNAMIC_HDR_PLUS) != NULL) {
        state->hasHDR10Plus = YES;
    }
    const AVFrameSideData *mdSD = av_frame_get_side_data(frame, AV_FRAME_DATA_MASTERING_DISPLAY_METADATA);
    if (mdSD != NULL && mdSD->data != NULL && mdSD->size >= sizeof(AVMasteringDisplayMetadata)) {
        SFXHDRMergeMasteringDisplay(state, (const AVMasteringDisplayMetadata *)mdSD->data);
    }
    const AVFrameSideData *cllSD = av_frame_get_side_data(frame, AV_FRAME_DATA_CONTENT_LIGHT_LEVEL);
    if (cllSD != NULL && cllSD->data != NULL && cllSD->size >= sizeof(AVContentLightMetadata)) {
        SFXHDRMergeContentLight(state, (const AVContentLightMetadata *)cllSD->data);
    }
}

static void SFXHDRSampleFramesFromCursor(
    AVFormatContext *formatContext,
    int videoStreamIndex,
    AVCodecContext *codecContext,
    AVPacket *packet,
    AVFrame *frame,
    SFXHDRProbeState *state,
    int maxDecodedFrames,
    int maxVideoPackets,
    int maxTotalPackets,
    BOOL waitForKeyframe
) {
    int totalPackets = 0;
    int videoPackets = 0;
    int decodedFrames = 0;
    BOOL seenKeyframe = !waitForKeyframe;

    while (decodedFrames < maxDecodedFrames
           && videoPackets < maxVideoPackets
           && totalPackets < maxTotalPackets
           && av_read_frame(formatContext, packet) >= 0) {
        totalPackets += 1;
        if (packet->stream_index != videoStreamIndex) {
            av_packet_unref(packet);
            continue;
        }
        videoPackets += 1;
        SFXHDRMergePacketSideDataList(state, packet->side_data, packet->side_data_elems);

        if (!seenKeyframe) {
            if ((packet->flags & AV_PKT_FLAG_KEY) != 0) {
                seenKeyframe = YES;
            } else {
                av_packet_unref(packet);
                continue;
            }
        }

        int sendResult = avcodec_send_packet(codecContext, packet);
        av_packet_unref(packet);
        if (sendResult < 0) {
            continue;
        }

        while (decodedFrames < maxDecodedFrames && avcodec_receive_frame(codecContext, frame) >= 0) {
            SFXHDRMergeFrame(state, frame);
            decodedFrames += 1;
            av_frame_unref(frame);
        }
    }

    if (decodedFrames == 0 && seenKeyframe && videoPackets > 0) {
        avcodec_send_packet(codecContext, NULL);
        while (decodedFrames < maxDecodedFrames && avcodec_receive_frame(codecContext, frame) >= 0) {
            SFXHDRMergeFrame(state, frame);
            decodedFrames += 1;
            av_frame_unref(frame);
        }
    }
}

static NSString * _Nullable SFXHDRCanonicalPrimariesToken(enum AVColorPrimaries primaries) {
    if (SFXHDRColorPrimariesUnspecified(primaries)) {
        return nil;
    }
    const char *name = av_color_primaries_name(primaries);
    return (name != NULL && name[0] != '\0') ? [NSString stringWithUTF8String:name] : nil;
}

static NSString * _Nullable SFXHDRCanonicalTransferToken(enum AVColorTransferCharacteristic transfer) {
    if (SFXHDRColorTransferUnspecified(transfer)) {
        return nil;
    }
    const char *name = av_color_transfer_name(transfer);
    return (name != NULL && name[0] != '\0') ? [NSString stringWithUTF8String:name] : nil;
}

static SFXMediaHDRMetadata * _Nullable SFXBuildHDRMetadataFromState(const SFXHDRProbeState *state) {
    BOOL hasDOVI = state->hasDolbyVision || state->matrix == AVCOL_SPC_IPT_C2;
    BOOL hasHDR10Plus = state->hasHDR10Plus;
    BOOL hasHDR10 = NO;
    BOOL hasHLG = NO;

    if (hasDOVI) {
        if (state->dolbyVisionProfile == 5) {
            hasHDR10 = NO;
            hasHLG = NO;
        } else if (state->dolbyVisionProfile == 7
                   || state->dolbyVisionCompatibilityID == 1
                   || state->dolbyVisionCompatibilityID == 6) {
            hasHDR10 = YES;
        } else if (state->dolbyVisionCompatibilityID == 4) {
            hasHLG = YES;
        } else if (state->dolbyVisionCompatibilityID == 2) {
            hasHDR10 = NO;
            hasHLG = NO;
        } else {
            hasHDR10 = hasHDR10Plus || state->transfer == AVCOL_TRC_SMPTE2084;
            hasHLG = state->transfer == AVCOL_TRC_ARIB_STD_B67;
        }
    } else {
        hasHDR10 = hasHDR10Plus || state->transfer == AVCOL_TRC_SMPTE2084;
        hasHLG = state->transfer == AVCOL_TRC_ARIB_STD_B67;
    }

    NSMutableArray<NSString *> *standards = [NSMutableArray array];
    if (hasDOVI) {
        [standards addObject:@"dolbyVision"];
    }
    if (hasHDR10Plus) {
        [standards addObject:@"hdr10Plus"];
    }
    if (hasHDR10) {
        [standards addObject:@"hdr10"];
    }
    if (hasHLG) {
        [standards addObject:@"hlg"];
    }
    if (standards.count == 0) {
        return nil;
    }

    NSString *masteringPrimaries = nil;
    switch (state->masteringPrimariesKind) {
    case 1: masteringPrimaries = @"display_p3"; break;
    case 2: masteringPrimaries = @"dci_p3"; break;
    case 3: masteringPrimaries = @"bt2020"; break;
    case 4: masteringPrimaries = @"bt709"; break;
    default: break;
    }

    enum AVColorPrimaries effectivePrimaries = state->primaries;
    enum AVColorTransferCharacteristic effectiveTransfer = state->transfer;
    if (hasDOVI) {
        BOOL isSingleLayerIPTPQ = (state->dolbyVisionProfile == 5 || state->matrix == AVCOL_SPC_IPT_C2);
        if (SFXHDRColorPrimariesUnspecified(effectivePrimaries) || isSingleLayerIPTPQ) {
            effectivePrimaries = AVCOL_PRI_BT2020;
        }
        if (SFXHDRColorTransferUnspecified(effectiveTransfer) || isSingleLayerIPTPQ) {
            if (state->dolbyVisionProfile == 8 && state->dolbyVisionCompatibilityID == 4) {
                effectiveTransfer = AVCOL_TRC_ARIB_STD_B67;
            } else {
                effectiveTransfer = AVCOL_TRC_SMPTE2084;
            }
        }
    }

    return [[SFXMediaHDRMetadata alloc]
        initWithStandards:standards
        dolbyVisionProfile:state->dolbyVisionProfile > 0 ? @(state->dolbyVisionProfile) : nil
        dolbyVisionCompatibilityID:state->dolbyVisionCompatibilityID > 0 ? @(state->dolbyVisionCompatibilityID) : nil
        colorPrimaries:SFXHDRCanonicalPrimariesToken(effectivePrimaries)
        transferFunction:SFXHDRCanonicalTransferToken(effectiveTransfer)
        masteringDisplayPrimaries:masteringPrimaries
        masteringDisplayMinLuminance:state->hasMasteringLuminance ? @(state->masteringMinLuminance) : nil
        masteringDisplayMaxLuminance:state->hasMasteringLuminance ? @(state->masteringMaxLuminance) : nil
        maxCLL:state->maxCLL > 0 ? @(state->maxCLL) : nil
        maxFALL:state->maxFALL > 0 ? @(state->maxFALL) : nil];
}

static SFXMediaHDRMetadata * _Nullable SFXInspectVideoHDRMetadata(
    AVFormatContext *formatContext,
    int videoStreamIndex,
    int bitDepth,
    enum AVPixelFormat pixelFormat,
    double timelineOriginSeconds,
    double durationSeconds
) {
    if (formatContext == NULL || videoStreamIndex < 0 || videoStreamIndex >= (int)formatContext->nb_streams) {
        return nil;
    }
    AVStream *videoStream = formatContext->streams[videoStreamIndex];
    AVCodecParameters *codecParameters = videoStream != NULL ? videoStream->codecpar : NULL;
    if (codecParameters == NULL) {
        return nil;
    }

    SFXHDRProbeState state = {0};
    state.primaries = codecParameters->color_primaries;
    state.transfer = codecParameters->color_trc;
    state.matrix = codecParameters->color_space;
    SFXHDRMergePacketSideDataList(&state, codecParameters->coded_side_data, codecParameters->nb_coded_side_data);

    const char *formatName = (formatContext->iformat != NULL) ? formatContext->iformat->name : NULL;
    BOOL isStreamFormat = SFXIsBroadcastOrRawStreamFormatName(formatName);
    BOOL hasExplicitStreamHDR = SFXHDRStateHasAnyHDRSignal(&state)
        || state.primaries == AVCOL_PRI_BT2020
        || state.matrix == AVCOL_SPC_BT2020_NCL
        || state.matrix == AVCOL_SPC_BT2020_CL
        || state.matrix == AVCOL_SPC_ICTCP
        || state.masteringPrimariesKind != 0
        || state.hasMasteringLuminance
        || state.maxCLL > 0
        || state.maxFALL > 0;
    BOOL streamMaySwitchToHDR = isStreamFormat
        && (SFXHDRCodecSupportsBroadcastOrMidStreamHDR(codecParameters->codec_id)
            || bitDepth >= 10
            || (bitDepth <= 0 && pixelFormat == AV_PIX_FMT_NONE));
    BOOL hasAmbiguousDeepColor = (bitDepth >= 10 || (bitDepth <= 0 && pixelFormat == AV_PIX_FMT_NONE))
        && (SFXHDRColorTransferUnspecified(state.transfer) || SFXHDRColorPrimariesUnspecified(state.primaries));

    if (!hasExplicitStreamHDR && !hasAmbiguousDeepColor && !streamMaySwitchToHDR) {
        return nil;
    }

    const AVCodec *decoder = SFXMetadataFindSoftwareVideoDecoder(codecParameters->codec_id);
    if (decoder == NULL) {
        return SFXBuildHDRMetadataFromState(&state);
    }

    AVCodecContext *codecContext = avcodec_alloc_context3(decoder);
    AVPacket *packet = av_packet_alloc();
    AVFrame *frame = av_frame_alloc();
    if (codecContext == NULL || packet == NULL || frame == NULL) {
        av_frame_free(&frame);
        av_packet_free(&packet);
        avcodec_free_context(&codecContext);
        return SFXBuildHDRMetadataFromState(&state);
    }

    codecContext->thread_count = 1;
    if (avcodec_parameters_to_context(codecContext, codecParameters) >= 0
        && avcodec_open2(codecContext, decoder, NULL) >= 0) {
        SFXHDRSampleFramesFromCursor(formatContext, videoStreamIndex, codecContext, packet, frame, &state, 2, 48, 320, NO);

        if (streamMaySwitchToHDR && !SFXHDRStateHasAnyHDRSignal(&state)) {
            const double fractions[2] = { 0.35, 0.70 };
            BOOL didMidStreamSample = NO;

            // Branch A: Prefer single direct byte-offset seeks when total size is known.
            if (formatContext->pb != NULL
                && (formatContext->pb->seekable & AVIO_SEEKABLE_NORMAL) != 0) {
                int64_t totalBytes = avio_size(formatContext->pb);
                if (totalBytes > 0) {
                    for (int i = 0; i < 2 && !SFXHDRStateHasAnyHDRSignal(&state); i++) {
                        int64_t targetByte = (int64_t)llround((double)totalBytes * fractions[i]);
                        if (av_seek_frame(formatContext, -1, targetByte, AVSEEK_FLAG_BYTE) >= 0) {
                            didMidStreamSample = YES;
                            avcodec_flush_buffers(codecContext);
                            SFXHDRSampleFramesFromCursor(
                                formatContext,
                                videoStreamIndex,
                                codecContext,
                                packet,
                                frame,
                                &state,
                                1,
                                300,
                                1200,
                                YES
                            );
                        } else {
                            break;
                        }
                    }
                }
            }

            // Branch B: Timestamp seek fallback only when byte seeking was unavailable or failed.
            if (!didMidStreamSample
                && !SFXHDRStateHasAnyHDRSignal(&state)
                && isfinite(durationSeconds)
                && durationSeconds > 0.5) {
                for (int i = 0; i < 2 && !SFXHDRStateHasAnyHDRSignal(&state); i++) {
                    double targetSeconds = timelineOriginSeconds + durationSeconds * fractions[i];
                    int seekResult = -1;
                    if (videoStream->time_base.num > 0 && videoStream->time_base.den > 0) {
                        int64_t streamTarget = (int64_t)llround(targetSeconds / av_q2d(videoStream->time_base));
                        seekResult = av_seek_frame(formatContext, videoStreamIndex, streamTarget, AVSEEK_FLAG_BACKWARD);
                    }
                    if (seekResult < 0) {
                        int64_t globalTarget = (int64_t)llround(targetSeconds * AV_TIME_BASE);
                        seekResult = av_seek_frame(formatContext, -1, globalTarget, AVSEEK_FLAG_BACKWARD);
                    }
                    if (seekResult >= 0) {
                        didMidStreamSample = YES;
                        avcodec_flush_buffers(codecContext);
                        SFXHDRSampleFramesFromCursor(
                            formatContext,
                            videoStreamIndex,
                            codecContext,
                            packet,
                            frame,
                            &state,
                            1,
                            300,
                            1200,
                            YES
                        );
                    } else {
                        break;
                    }
                }
            }

            // Branch C: Sequential packet scan fallback only if neither seek branch sampled.
            if (!didMidStreamSample && !SFXHDRStateHasAnyHDRSignal(&state)) {
                SFXHDRSampleFramesFromCursor(
                    formatContext,
                    videoStreamIndex,
                    codecContext,
                    packet,
                    frame,
                    &state,
                    2,
                    120,
                    480,
                    NO
                );
            }
        }
    }

    av_frame_free(&frame);
    av_packet_free(&packet);
    avcodec_free_context(&codecContext);
    return SFXBuildHDRMetadataFromState(&state);
}

static SFXMediaCoverCandidateFrame * _Nullable SFXCreateCoverCandidateFrame(
    const AVFormatContext *formatContext,
    const AVStream *videoStream,
    const AVCodecContext *codecContext,
    const AVFrame *frame,
    int srcWidth,
    int srcHeight,
    int displayWidth,
    int displayHeight,
    SFXVideoOrientation orientation,
    enum AVPixelFormat inputFormat,
    NSInteger timestampMilliseconds,
    int scoringWidth,
    int scoringHeight,
    double decodeMs
) {
    CGImageRef gpuRenderedImage = SFXCopyRenderedImageFromAVFrame(
        formatContext,
        videoStream,
        codecContext,
        frame,
        0,
        0,
        decodeMs,
        @"library_cover",
        NULL
    );
    if (gpuRenderedImage != NULL) {
        NSData *gpuScoringData = SFXCopyRGB24DataFromCGImage(
            gpuRenderedImage,
            (size_t)MAX(1, scoringWidth),
            (size_t)MAX(1, scoringHeight)
        );
        if (gpuScoringData != nil) {
            SFXMediaCoverCandidateFrame *candidate = [[SFXMediaCoverCandidateFrame alloc]
                initWithTimestampMilliseconds:timestampMilliseconds
                             scoringRGB24Data:gpuScoringData
                                      cgImage:gpuRenderedImage];
            CGImageRelease(gpuRenderedImage);
            return candidate;
        }
        CGImageRelease(gpuRenderedImage);
    }

    int targetDisplayWidth = displayWidth > 0 ? displayWidth : srcWidth;
    int targetDisplayHeight = displayHeight > 0 ? displayHeight : srcHeight;
    int fullStride = targetDisplayWidth * 3;
    NSMutableData *fullRGBData = [NSMutableData dataWithLength:(NSUInteger)(fullStride * targetDisplayHeight)];
    if (fullRGBData == nil) {
        return nil;
    }

    struct SwsContext *fullScaler = sws_getContext(
        srcWidth,
        srcHeight,
        inputFormat,
        targetDisplayWidth,
        targetDisplayHeight,
        AV_PIX_FMT_RGB24,
        SWS_BILINEAR,
        NULL,
        NULL,
        NULL
    );
    if (fullScaler == NULL) {
        return nil;
    }
    SFXConfigureSwsContextColorSpace(
        fullScaler,
        videoStream,
        codecContext,
        frame,
        srcWidth,
        srcHeight,
        inputFormat,
        AV_PIX_FMT_RGB24
    );

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

    int orientedDisplayWidth = targetDisplayWidth;
    int orientedDisplayHeight = targetDisplayHeight;
    NSData *orientedRGBData = SFXTransformRGB24DataForVideoOrientation(
        fullRGBData,
        targetDisplayWidth,
        targetDisplayHeight,
        orientation,
        &orientedDisplayWidth,
        &orientedDisplayHeight
    );
    if (orientedRGBData == nil || orientedDisplayWidth <= 0 || orientedDisplayHeight <= 0) {
        return nil;
    }

    double scale = fmin((double)scoringWidth / (double)orientedDisplayWidth, (double)scoringHeight / (double)orientedDisplayHeight);
    int scaledWidth = MAX(1, MIN(scoringWidth, (int)llround((double)orientedDisplayWidth * scale)));
    int scaledHeight = MAX(1, MIN(scoringHeight, (int)llround((double)orientedDisplayHeight * scale)));
    int padX = (scoringWidth - scaledWidth) / 2;
    int padY = (scoringHeight - scaledHeight) / 2;

    NSMutableData *scoringData = [NSMutableData dataWithLength:(NSUInteger)(scoringWidth * scoringHeight * 3)];
    if (scoringData == nil) {
        return nil;
    }

    struct SwsContext *scoringScaler = sws_getContext(
        orientedDisplayWidth,
        orientedDisplayHeight,
        AV_PIX_FMT_RGB24,
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
    const uint8_t *orientedSrcSlice[4] = { (const uint8_t *)orientedRGBData.bytes, NULL, NULL, NULL };
    int orientedSrcStride[4] = { orientedDisplayWidth * 3, 0, 0, 0 };
    sws_scale(
        scoringScaler,
        orientedSrcSlice,
        orientedSrcStride,
        0,
        orientedDisplayHeight,
        scoringDstSlice,
        scoringDstStride
    );
    sws_freeContext(scoringScaler);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    if (colorSpace == NULL) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    if (colorSpace == NULL) {
        return nil;
    }

    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)orientedRGBData);
    if (provider == NULL) {
        CGColorSpaceRelease(colorSpace);
        return nil;
    }

    int orientedFullStride = orientedDisplayWidth * 3;
    CGImageRef cgImage = CGImageCreate(
        (size_t)orientedDisplayWidth,
        (size_t)orientedDisplayHeight,
        8,
        24,
        (size_t)orientedFullStride,
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

+ (nullable SFXMediaContainerProbe *)containerProbeAtMediaPath:(NSString *)mediaPath
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
    if (result < 0 || formatContext == NULL || formatContext->iformat == NULL || formatContext->iformat->name == NULL) {
        avformat_close_input(&formatContext);
        if (error != NULL) {
            *error = SFXMediaMetadataError(
                201,
                [NSString stringWithFormat:@"Could not open media for container inspection: %@", SFXMetadataFFmpegErrorString(result)]
            );
        }
        return nil;
    }

    NSString *formatName = [NSString stringWithUTF8String:formatContext->iformat->name];
    BOOL hasHeaderVideoParameters = NO;
    BOOL swapsVideoDimensions = NO;
    NSString *inferredColorMatrix = nil;
    int primaryVideoIndex = SFXSelectPrimaryVideoStreamIndex(formatContext);
    if (primaryVideoIndex >= 0 && primaryVideoIndex < (int)formatContext->nb_streams) {
        AVStream *stream = formatContext->streams[primaryVideoIndex];
        if (stream != NULL && stream->codecpar != NULL) {
            swapsVideoDimensions = SFXVideoOrientationSwapsDimensions(
                SFXResolveVideoOrientation(stream, NULL)
            );
            hasHeaderVideoParameters = stream->codecpar->width > 0 && stream->codecpar->height > 0;
            if ((stream->codecpar->color_space == AVCOL_SPC_UNSPECIFIED
                 || stream->codecpar->color_space == AVCOL_SPC_RESERVED)
                && (stream->codecpar->width > 1280 || stream->codecpar->height > 576)) {
                inferredColorMatrix = @"bt709";
            }
        }
    }

    avformat_close_input(&formatContext);

    return [[SFXMediaContainerProbe alloc] initWithFormatName:formatName
                                     hasHeaderVideoParameters:hasHeaderVideoParameters
                                         swapsVideoDimensions:swapsVideoDimensions
                                          inferredColorMatrix:inferredColorMatrix];
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

    NSString *formatName = (formatContext->iformat != NULL && formatContext->iformat->name != NULL)
        ? [NSString stringWithUTF8String:formatContext->iformat->name]
        : nil;
    NSString *majorBrand = SFXMetadataTagValue(formatContext->metadata, "major_brand");

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

    int videoStreamIndex = SFXSelectPrimaryVideoStreamIndex(formatContext);
    double timelineOriginSeconds = SFXMediaTimelineOriginSeconds(formatContext);
    double durationSeconds = SFXResolveMediaDurationSeconds(
        formatContext,
        videoStreamIndex,
        timelineOriginSeconds
    );

    NSNumber *durationNumber = nil;
    if (isfinite(durationSeconds) && durationSeconds > 0) {
        durationNumber = @(durationSeconds);
    }

    NSNumber *videoWidth = nil;
    NSNumber *videoHeight = nil;
    NSNumber *frameRate = nil;
    NSString *videoCodec = nil;
    NSNumber *videoBitDepth = nil;
    NSString *videoPixelFormat = nil;
    SFXMediaHDRMetadata *hdrMetadata = nil;
    if (videoStreamIndex >= 0 && videoStreamIndex < (int)formatContext->nb_streams) {
        AVStream *videoStream = formatContext->streams[videoStreamIndex];
        AVCodecParameters *codecParameters = videoStream != NULL ? videoStream->codecpar : NULL;
        if (codecParameters != NULL) {
            SFXVideoOrientation orientation = SFXResolveVideoOrientation(videoStream, NULL);
            BOOL swapsDimensions = SFXVideoOrientationSwapsDimensions(orientation);
            int orientedWidth = swapsDimensions ? codecParameters->height : codecParameters->width;
            int orientedHeight = swapsDimensions ? codecParameters->width : codecParameters->height;
            if (orientedWidth > 0) {
                videoWidth = @(orientedWidth);
            }
            if (orientedHeight > 0) {
                videoHeight = @(orientedHeight);
            }

            const char *codecName = avcodec_get_name(codecParameters->codec_id);
            if (codecName != NULL && codecName[0] != '\0') {
                videoCodec = [NSString stringWithUTF8String:codecName];
            }

            enum AVPixelFormat pixFmt = (enum AVPixelFormat)codecParameters->format;
            if (pixFmt != AV_PIX_FMT_NONE) {
                const char *pixFmtName = av_get_pix_fmt_name(pixFmt);
                if (pixFmtName != NULL && pixFmtName[0] != '\0') {
                    videoPixelFormat = [NSString stringWithUTF8String:pixFmtName];
                }
            }
            int bitDepth = codecParameters->bits_per_raw_sample;
            if (bitDepth <= 0 && pixFmt != AV_PIX_FMT_NONE) {
                const AVPixFmtDescriptor *desc = av_pix_fmt_desc_get(pixFmt);
                if (desc != NULL && desc->comp[0].depth > 0) {
                    bitDepth = desc->comp[0].depth;
                }
            }
            if (bitDepth > 0) {
                videoBitDepth = @(bitDepth);
            }

            hdrMetadata = SFXInspectVideoHDRMetadata(
                formatContext,
                videoStreamIndex,
                bitDepth,
                pixFmt,
                timelineOriginSeconds,
                durationSeconds
            );
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
        if (!SFXIsAudioStreamValid(stream)) {
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
        int sampleRate = stream->codecpar->sample_rate;
        int bitDepth = stream->codecpar->bits_per_raw_sample;
        if (bitDepth <= 0) {
            bitDepth = av_get_bits_per_sample(stream->codecpar->codec_id);
        }
        [audioTracks addObject:[[SFXMediaAudioTrack alloc]
            initWithLanguage:language
                       title:SFXMetadataTagValue(stream->metadata, "title")
                       codec:codec
                    channels:channelCount > 0 ? @(channelCount) : nil
                  sampleRate:sampleRate > 0 ? @(sampleRate) : nil
                    bitDepth:bitDepth > 0 ? @(bitDepth) : nil]];
    }

    avformat_close_input(&formatContext);

    return [[SFXMediaMetadata alloc] initWithDurationSeconds:durationNumber
                                                  videoWidth:videoWidth
                                                 videoHeight:videoHeight
                                                   frameRate:frameRate
                                                  videoCodec:videoCodec
                                               videoBitDepth:videoBitDepth
                                            videoPixelFormat:videoPixelFormat
                                                  formatName:formatName
                                                  majorBrand:majorBrand
                                                 hdrMetadata:hdrMetadata
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

    int videoStreamIndex = SFXSelectPrimaryVideoStreamIndex(formatContext);
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
        CFTimeInterval candidateDecodeStart = CACurrentMediaTime();

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
                    double decodeMs = (CACurrentMediaTime() - candidateDecodeStart) * 1000.0;
                    AVRational sar = SFXVideoSampleAspectRatio(formatContext, videoStream, codecContext, frame);
                    SFXVideoOrientation orientation = SFXResolveVideoOrientation(videoStream, frame);
                    int displayWidth = (int)SFXDisplayVideoWidthForDimensionsAndSAR(width, height, sar);
                    decodedCandidate = SFXCreateCoverCandidateFrame(
                        formatContext,
                        videoStream,
                        codecContext,
                        frame,
                        width,
                        height,
                        displayWidth,
                        height,
                        orientation,
                        inputFormat,
                        timestampMs,
                        targetScoringWidth,
                        targetScoringHeight,
                        decodeMs
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
                    double decodeMs = (CACurrentMediaTime() - candidateDecodeStart) * 1000.0;
                    AVRational sar = SFXVideoSampleAspectRatio(formatContext, videoStream, codecContext, frame);
                    SFXVideoOrientation orientation = SFXResolveVideoOrientation(videoStream, frame);
                    int displayWidth = (int)SFXDisplayVideoWidthForDimensionsAndSAR(width, height, sar);
                    decodedCandidate = SFXCreateCoverCandidateFrame(
                        formatContext,
                        videoStream,
                        codecContext,
                        frame,
                        width,
                        height,
                        displayWidth,
                        height,
                        orientation,
                        inputFormat,
                        timestampMs,
                        targetScoringWidth,
                        targetScoringHeight,
                        decodeMs
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
