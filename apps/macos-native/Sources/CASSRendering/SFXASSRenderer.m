#import "SFXASSRenderer.h"

#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>

#include <ass/ass.h>
#include <fcntl.h>
#include <limits.h>
#include <malloc/malloc.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

NSString * const SFXASSRenderingErrorDomain = @"CueSeeker.ASSRendering";

static const int kSFXASSMaxCachedGlyphs = 128;
static const int kSFXASSMaxBitmapCacheMegabytes = 4;
static const NSInteger kSFXASSEventWindowDurationMilliseconds = 5000;

typedef struct {
    int32_t startMs;
    int32_t endMs;
    uint32_t offset;
    uint32_t length;
} SFXASSEventSlice;

@interface SFXASSRenderOutput ()

- (instancetype)initWithRGBAData:(NSData *)rgbaData
                           width:(NSInteger)width
                          height:(NSInteger)height
                          stride:(NSInteger)stride
                      imageCount:(NSInteger)imageCount
                         changed:(BOOL)changed NS_DESIGNATED_INITIALIZER;

@end

@interface SFXASSCroppedRenderOutput ()

- (instancetype)initWithRGBAData:(NSData *)rgbaData
                            width:(NSInteger)width
                           height:(NSInteger)height
                           stride:(NSInteger)stride
                     destinationX:(NSInteger)destinationX
                     destinationY:(NSInteger)destinationY
                       frameWidth:(NSInteger)frameWidth
                      frameHeight:(NSInteger)frameHeight
                       imageCount:(NSInteger)imageCount
                          changed:(BOOL)changed
        unchangedFromMilliseconds:(NSInteger)unchangedFromMilliseconds
       unchangedUntilMilliseconds:(NSInteger)unchangedUntilMilliseconds
   activeEventSetFromMilliseconds:(NSInteger)activeEventSetFromMilliseconds
  activeEventSetUntilMilliseconds:(NSInteger)activeEventSetUntilMilliseconds NS_DESIGNATED_INITIALIZER;

@end

static BOOL SFXASSEventContainsAnimationTags(const ASS_Event *event) {
    if (event == NULL) {
        return NO;
    }
    if (event->Effect != NULL && event->Effect[0] != '\0') {
        return YES;
    }
    const char *text = event->Text;
    if (text == NULL || text[0] == '\0') {
        return NO;
    }
    const char *cursor = text;
    while ((cursor = strchr(cursor, '{')) != NULL) {
        const char *end = strchr(cursor + 1, '}');
        if (end == NULL) {
            break;
        }
        for (const char *p = cursor + 1; p < end; p++) {
            if (*p != '\\') {
                continue;
            }
            size_t rem = (size_t)(end - (p + 1));
            if ((rem >= 5 && strncmp(p + 1, "move(", 5) == 0)
                || (rem >= 4 && strncmp(p + 1, "fad(", 4) == 0)
                || (rem >= 5 && strncmp(p + 1, "fade(", 5) == 0)
                || (rem >= 2 && strncmp(p + 1, "t(", 2) == 0)
                || (rem >= 1 && (p[1] == 'k' || p[1] == 'K'))) {
                return YES;
            }
        }
        cursor = end + 1;
    }
    return NO;
}

static uint8_t * _Nullable SFXBuildASSEventAnimatedFlags(const ASS_Track *track) {
    if (track == NULL || track->n_events <= 0 || track->events == NULL) {
        return NULL;
    }
    uint8_t *flags = (uint8_t *)calloc((size_t)track->n_events, sizeof(uint8_t));
    if (flags == NULL) {
        return NULL;
    }
    for (int i = 0; i < track->n_events; i++) {
        flags[i] = SFXASSEventContainsAnimationTags(&track->events[i]) ? 1 : 0;
    }
    return flags;
}

static void SFXComputeASSRenderWindows(
    const ASS_Track *track,
    const uint8_t * _Nullable animatedFlags,
    NSInteger timestampMilliseconds,
    NSInteger *outUnchangedFromMilliseconds,
    NSInteger *outUnchangedUntilMilliseconds,
    NSInteger *outActiveEventSetFromMilliseconds,
    NSInteger *outActiveEventSetUntilMilliseconds
) {
    long long t = MAX(0LL, (long long)timestampMilliseconds);
    if (track == NULL || track->n_events <= 0 || track->events == NULL) {
        *outUnchangedFromMilliseconds = 0;
        *outUnchangedUntilMilliseconds = NSIntegerMax;
        *outActiveEventSetFromMilliseconds = 0;
        *outActiveEventSetUntilMilliseconds = NSIntegerMax;
        return;
    }

    long long windowStart = 0;
    long long windowEnd = (long long)NSIntegerMax;
    BOOL hasAnimatedActiveEvent = NO;
    for (int i = 0; i < track->n_events; i++) {
        const ASS_Event *event = &track->events[i];
        long long start = MAX(0LL, event->Start);
        long long end = start + MAX(0LL, event->Duration);
        if (end <= start) {
            continue;
        }
        if (t >= start && t < end) {
            if (!hasAnimatedActiveEvent) {
                BOOL isAnimated = animatedFlags != NULL
                    ? (animatedFlags[i] != 0)
                    : SFXASSEventContainsAnimationTags(event);
                if (isAnimated) {
                    hasAnimatedActiveEvent = YES;
                }
            }
            if (start > windowStart) {
                windowStart = start;
            }
            if (end < windowEnd) {
                windowEnd = end;
            }
        } else if (start > t) {
            if (start < windowEnd) {
                windowEnd = start;
            }
        } else {
            if (end > windowStart) {
                windowStart = end;
            }
        }
    }

    if (windowEnd <= windowStart) {
        windowStart = t;
        windowEnd = t < (long long)NSIntegerMax ? t + 1 : (long long)NSIntegerMax;
    }
    NSInteger activeSetFrom = (NSInteger)MIN(windowStart, (long long)NSIntegerMax);
    NSInteger activeSetUntil = (NSInteger)MIN(windowEnd, (long long)NSIntegerMax);
    *outActiveEventSetFromMilliseconds = activeSetFrom;
    *outActiveEventSetUntilMilliseconds = activeSetUntil;

    if (hasAnimatedActiveEvent) {
        *outUnchangedFromMilliseconds = timestampMilliseconds;
        *outUnchangedUntilMilliseconds = timestampMilliseconds < NSIntegerMax
            ? timestampMilliseconds + 1
            : NSIntegerMax;
    } else {
        *outUnchangedFromMilliseconds = activeSetFrom;
        *outUnchangedUntilMilliseconds = activeSetUntil;
    }
}

static inline void SFXClampASSWindowToRange(
    NSInteger *fromMilliseconds,
    NSInteger *untilMilliseconds,
    NSInteger clampStartMilliseconds,
    NSInteger clampEndMilliseconds,
    NSInteger fallbackTimestampMilliseconds
) {
    NSInteger clampedFrom = MAX(*fromMilliseconds, clampStartMilliseconds);
    NSInteger clampedUntil = MIN(*untilMilliseconds, clampEndMilliseconds);
    if (clampedUntil <= clampedFrom) {
        clampedFrom = fallbackTimestampMilliseconds;
        clampedUntil = fallbackTimestampMilliseconds < NSIntegerMax
            ? fallbackTimestampMilliseconds + 1
            : NSIntegerMax;
    }
    *fromMilliseconds = clampedFrom;
    *untilMilliseconds = clampedUntil;
}

static NSError *SFXASSRenderingError(SFXASSRenderingErrorCode code, NSString *message) {
    return [NSError errorWithDomain:SFXASSRenderingErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

static void SFXASSSetError(NSError **error, SFXASSRenderingErrorCode code, NSString *message) {
    if (error != NULL) {
        *error = SFXASSRenderingError(code, message);
    }
}

static void SFXASSMessageCallback(int level, const char *format, va_list args, void *data) {
    (void)data;

    if (level > 5 || format == NULL) {
        return;
    }

    char buffer[2048] = {0};
    vsnprintf(buffer, sizeof(buffer), format, args);
    fprintf(stderr, "libass[%d]: %s\n", level, buffer);
}

#define kSFXASSEnginePoolCapacity 2

typedef struct {
    ASS_Library *library;
    ASS_Renderer *renderer;
} SFXASSEngineContext;

static pthread_mutex_t gSFXASSEnginePoolMutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t gSFXASSEnginePoolCond = PTHREAD_COND_INITIALIZER;
static SFXASSEngineContext gSFXASSEnginePool[kSFXASSEnginePoolCapacity];
static NSUInteger gSFXASSEnginePoolCount = 0;
static BOOL gSFXASSIsWarmingUp = NO;
static BOOL gSFXASSHasCompletedWarmup = NO;
static NSUInteger gSFXASSEnginePoolGeneration = 0;
static NSUInteger gSFXASSEngineInitCountForTesting = 0;

static inline void SFXApplyASSRendererFrameSize(
    ASS_Renderer *renderer,
    NSInteger frameWidth,
    NSInteger frameHeight
) {
    int safeWidth = (int)MAX(1, MIN((NSInteger)INT_MAX, frameWidth));
    int safeHeight = (int)MAX(1, MIN((NSInteger)INT_MAX, frameHeight));
    ass_set_frame_size(renderer, safeWidth, safeHeight);
    ass_set_storage_size(renderer, safeWidth, safeHeight);
}

static BOOL SFXCreateASSEngineContext(
    BOOL extractEmbeddedFonts,
    NSInteger initialWidth,
    NSInteger initialHeight,
    ASS_Library **outLibrary,
    ASS_Renderer **outRenderer,
    NSError **error
) {
    ASS_Library *library = ass_library_init();
    if (library == NULL) {
        SFXASSSetError(error, SFXASSRenderingErrorDependencyUnavailable, @"libass failed to initialize.");
        return NO;
    }

    ass_set_message_cb(library, SFXASSMessageCallback, NULL);
    ass_set_extract_fonts(library, extractEmbeddedFonts ? 1 : 0);

    ASS_Renderer *renderer = ass_renderer_init(library);
    if (renderer == NULL) {
        ass_library_done(library);
        SFXASSSetError(error, SFXASSRenderingErrorDependencyUnavailable, @"libass renderer failed to initialize.");
        return NO;
    }

    SFXApplyASSRendererFrameSize(renderer, initialWidth, initialHeight);
    ass_set_cache_limits(renderer, kSFXASSMaxCachedGlyphs, kSFXASSMaxBitmapCacheMegabytes);
    ass_set_fonts(renderer, NULL, "Helvetica", ASS_FONTPROVIDER_AUTODETECT, NULL, 1);

    pthread_mutex_lock(&gSFXASSEnginePoolMutex);
    gSFXASSEngineInitCountForTesting += 1;
    pthread_mutex_unlock(&gSFXASSEnginePoolMutex);

    *outLibrary = library;
    *outRenderer = renderer;
    return YES;
}

static void SFXWarmUpASSFontEnvironment(void) {
    pthread_mutex_lock(&gSFXASSEnginePoolMutex);
    while (gSFXASSIsWarmingUp) {
        pthread_cond_wait(&gSFXASSEnginePoolCond, &gSFXASSEnginePoolMutex);
    }
    if (gSFXASSHasCompletedWarmup || gSFXASSEnginePoolCount > 0) {
        pthread_mutex_unlock(&gSFXASSEnginePoolMutex);
        return;
    }
    NSUInteger warmupGeneration = gSFXASSEnginePoolGeneration;
    gSFXASSIsWarmingUp = YES;
    pthread_mutex_unlock(&gSFXASSEnginePoolMutex);

    ASS_Library *library = NULL;
    ASS_Renderer *renderer = NULL;
    BOOL created = SFXCreateASSEngineContext(NO, 1920, 1080, &library, &renderer, NULL);

    pthread_mutex_lock(&gSFXASSEnginePoolMutex);
    if (created && library != NULL && renderer != NULL) {
        if (warmupGeneration == gSFXASSEnginePoolGeneration) {
            gSFXASSHasCompletedWarmup = YES;
            if (gSFXASSEnginePoolCount < kSFXASSEnginePoolCapacity) {
                gSFXASSEnginePool[gSFXASSEnginePoolCount].library = library;
                gSFXASSEnginePool[gSFXASSEnginePoolCount].renderer = renderer;
                gSFXASSEnginePoolCount += 1;
                library = NULL;
                renderer = NULL;
            }
        }
    }
    gSFXASSIsWarmingUp = NO;
    pthread_cond_broadcast(&gSFXASSEnginePoolCond);
    pthread_mutex_unlock(&gSFXASSEnginePoolMutex);

    if (renderer != NULL) {
        ass_renderer_done(renderer);
    }
    if (library != NULL) {
        ass_library_done(library);
    }
}

static void SFXInvalidateASSFontEnvironmentPool(void) {
    SFXASSEngineContext toDestroy[kSFXASSEnginePoolCapacity];
    NSUInteger destroyCount = 0;

    pthread_mutex_lock(&gSFXASSEnginePoolMutex);
    gSFXASSEnginePoolGeneration += 1;
    gSFXASSHasCompletedWarmup = NO;
    destroyCount = gSFXASSEnginePoolCount;
    for (NSUInteger i = 0; i < destroyCount; i++) {
        toDestroy[i] = gSFXASSEnginePool[i];
        gSFXASSEnginePool[i].library = NULL;
        gSFXASSEnginePool[i].renderer = NULL;
    }
    gSFXASSEnginePoolCount = 0;
    pthread_cond_broadcast(&gSFXASSEnginePoolCond);
    pthread_mutex_unlock(&gSFXASSEnginePoolMutex);

    for (NSUInteger i = 0; i < destroyCount; i++) {
        if (toDestroy[i].renderer != NULL) {
            ass_renderer_done(toDestroy[i].renderer);
        }
        if (toDestroy[i].library != NULL) {
            ass_library_done(toDestroy[i].library);
        }
    }
}

static BOOL SFXCheckoutASSEngineContext(
    BOOL dedicatedWithEmbeddedFonts,
    NSInteger frameWidth,
    NSInteger frameHeight,
    ASS_Library **outLibrary,
    ASS_Renderer **outRenderer,
    BOOL *outUsesPool,
    NSUInteger *outPoolGeneration,
    NSError **error
) {
    if (dedicatedWithEmbeddedFonts) {
        *outUsesPool = NO;
        *outPoolGeneration = 0;
        return SFXCreateASSEngineContext(YES, frameWidth, frameHeight, outLibrary, outRenderer, error);
    }

    *outUsesPool = YES;
    ASS_Library *library = NULL;
    ASS_Renderer *renderer = NULL;
    NSUInteger checkedOutGeneration = 0;

    pthread_mutex_lock(&gSFXASSEnginePoolMutex);
    while (gSFXASSIsWarmingUp && gSFXASSEnginePoolCount == 0) {
        pthread_cond_wait(&gSFXASSEnginePoolCond, &gSFXASSEnginePoolMutex);
    }
    checkedOutGeneration = gSFXASSEnginePoolGeneration;
    if (gSFXASSEnginePoolCount > 0) {
        gSFXASSEnginePoolCount -= 1;
        library = gSFXASSEnginePool[gSFXASSEnginePoolCount].library;
        renderer = gSFXASSEnginePool[gSFXASSEnginePoolCount].renderer;
        gSFXASSEnginePool[gSFXASSEnginePoolCount].library = NULL;
        gSFXASSEnginePool[gSFXASSEnginePoolCount].renderer = NULL;
    }
    pthread_mutex_unlock(&gSFXASSEnginePoolMutex);

    if (library != NULL && renderer != NULL) {
        SFXApplyASSRendererFrameSize(renderer, frameWidth, frameHeight);
        *outLibrary = library;
        *outRenderer = renderer;
        *outPoolGeneration = checkedOutGeneration;
        return YES;
    }

    if (!SFXCreateASSEngineContext(NO, frameWidth, frameHeight, &library, &renderer, error)) {
        *outPoolGeneration = 0;
        return NO;
    }

    pthread_mutex_lock(&gSFXASSEnginePoolMutex);
    if (checkedOutGeneration == gSFXASSEnginePoolGeneration) {
        gSFXASSHasCompletedWarmup = YES;
    }
    pthread_mutex_unlock(&gSFXASSEnginePoolMutex);

    *outLibrary = library;
    *outRenderer = renderer;
    *outPoolGeneration = checkedOutGeneration;
    return YES;
}

static void SFXReturnOrDestroyASSEngineContext(
    ASS_Library * _Nullable library,
    ASS_Renderer * _Nullable renderer,
    BOOL usesPool,
    NSUInteger poolGeneration
) {
    if (library == NULL && renderer == NULL) {
        return;
    }
    if (usesPool && library != NULL && renderer != NULL) {
        pthread_mutex_lock(&gSFXASSEnginePoolMutex);
        if (poolGeneration == gSFXASSEnginePoolGeneration
            && gSFXASSEnginePoolCount < kSFXASSEnginePoolCapacity) {
            gSFXASSEnginePool[gSFXASSEnginePoolCount].library = library;
            gSFXASSEnginePool[gSFXASSEnginePoolCount].renderer = renderer;
            gSFXASSEnginePoolCount += 1;
            pthread_mutex_unlock(&gSFXASSEnginePoolMutex);
            return;
        }
        pthread_mutex_unlock(&gSFXASSEnginePoolMutex);
    }
    if (renderer != NULL) {
        ass_renderer_done(renderer);
    }
    if (library != NULL) {
        ass_library_done(library);
    }
}

static BOOL SFXBytesContainEmbeddedFontsSection(const char *bytes, size_t length) {
    if (bytes == NULL || length < 7) {
        return NO;
    }
    size_t pos = 0;
    if (length >= 3
        && (unsigned char)bytes[0] == 0xEF
        && (unsigned char)bytes[1] == 0xBB
        && (unsigned char)bytes[2] == 0xBF) {
        pos = 3;
    }
    BOOL inFontsSection = NO;
    while (pos < length) {
        const char *lineStart = bytes + pos;
        const char *newline = (const char *)memchr(lineStart, '\n', length - pos);
        size_t lineLen = newline != NULL ? (size_t)(newline - lineStart + 1) : (length - pos);
        const char *trimmed = lineStart;
        const char *lineEnd = lineStart + lineLen;
        while (trimmed < lineEnd && (*trimmed == ' ' || *trimmed == '\t')) {
            trimmed++;
        }
        if ((size_t)(lineEnd - trimmed) >= 3
            && (unsigned char)trimmed[0] == 0xEF
            && (unsigned char)trimmed[1] == 0xBB
            && (unsigned char)trimmed[2] == 0xBF) {
            trimmed += 3;
            while (trimmed < lineEnd && (*trimmed == ' ' || *trimmed == '\t')) {
                trimmed++;
            }
        }
        const char *contentEnd = lineEnd;
        while (contentEnd > trimmed
               && (contentEnd[-1] == ' ' || contentEnd[-1] == '\t' || contentEnd[-1] == '\r' || contentEnd[-1] == '\n')) {
            contentEnd--;
        }
        size_t trimmedLen = (size_t)(contentEnd - trimmed);
        if (trimmedLen == 0) {
            pos += lineLen;
            continue;
        }
        if (trimmed[0] == ';' || (trimmedLen >= 2 && trimmed[0] == '!' && trimmed[1] == ':')) {
            pos += lineLen;
            continue;
        }
        if (trimmed[0] == '[' && trimmed[trimmedLen - 1] == ']') {
            inFontsSection = (trimmedLen == 7 && strncasecmp(trimmed, "[Fonts]", 7) == 0);
            pos += lineLen;
            continue;
        }
        if (inFontsSection) {
            return YES;
        }
        pos += lineLen;
    }
    return NO;
}

static BOOL SFXBytesContainEventsFormat(const char *bytes, size_t length) {
    if (bytes == NULL || length == 0) {
        return NO;
    }
    size_t pos = 0;
    BOOL inEvents = NO;
    while (pos < length) {
        const char *lineStart = bytes + pos;
        const char *newline = (const char *)memchr(lineStart, '\n', length - pos);
        size_t lineLen = newline != NULL ? (size_t)(newline - lineStart + 1) : (length - pos);
        const char *trimmed = lineStart;
        const char *lineEnd = lineStart + lineLen;
        while (trimmed < lineEnd && (*trimmed == ' ' || *trimmed == '\t')) {
            trimmed++;
        }
        const char *contentEnd = lineEnd;
        while (contentEnd > trimmed
               && (contentEnd[-1] == ' ' || contentEnd[-1] == '\t' || contentEnd[-1] == '\r' || contentEnd[-1] == '\n')) {
            contentEnd--;
        }
        size_t contentLen = (size_t)(contentEnd - trimmed);
        if (contentLen >= 2 && trimmed[0] == '[' && contentEnd[-1] == ']') {
            inEvents = (contentLen == 8 && strncasecmp(trimmed, "[Events]", 8) == 0);
        } else if (inEvents && contentLen >= 7 && strncasecmp(trimmed, "Format:", 7) == 0) {
            return YES;
        }
        pos += lineLen;
    }
    return NO;
}

static NSInteger SFXCompositeASSImages(
    ASS_Image *images,
    uint8_t *destination,
    NSInteger frameWidth,
    NSInteger frameHeight,
    NSInteger destinationStride
) {
    NSInteger imageCount = 0;

    for (ASS_Image *image = images; image != NULL; image = image->next) {
        if (image->w <= 0 || image->h <= 0 || image->bitmap == NULL) {
            continue;
        }

        imageCount += 1;

        int sourceRed = (int)((image->color >> 24) & 0xff);
        int sourceGreen = (int)((image->color >> 16) & 0xff);
        int sourceBlue = (int)((image->color >> 8) & 0xff);
        int sourceOpacity = 255 - (int)(image->color & 0xff);

        if (sourceOpacity <= 0) {
            continue;
        }

        for (int y = 0; y < image->h; y++) {
            NSInteger destinationY = (NSInteger)image->dst_y + y;
            if (destinationY < 0 || destinationY >= frameHeight) {
                continue;
            }

            uint8_t *sourceRow = image->bitmap + ((NSInteger)y * image->stride);
            uint8_t *destinationRow = destination + (destinationY * destinationStride);

            for (int x = 0; x < image->w; x++) {
                NSInteger destinationX = (NSInteger)image->dst_x + x;
                if (destinationX < 0 || destinationX >= frameWidth) {
                    continue;
                }

                int mask = sourceRow[x];
                int sourceAlpha = (mask * sourceOpacity + 127) / 255;
                if (sourceAlpha <= 0) {
                    continue;
                }

                uint8_t *pixel = destinationRow + (destinationX * 4);
                int inverseAlpha = 255 - sourceAlpha;

                pixel[0] = (uint8_t)((sourceRed * sourceAlpha + pixel[0] * inverseAlpha + 127) / 255);
                pixel[1] = (uint8_t)((sourceGreen * sourceAlpha + pixel[1] * inverseAlpha + 127) / 255);
                pixel[2] = (uint8_t)((sourceBlue * sourceAlpha + pixel[2] * inverseAlpha + 127) / 255);
                pixel[3] = (uint8_t)(sourceAlpha + (pixel[3] * inverseAlpha + 127) / 255);
            }
        }
    }

    return imageCount;
}

static BOOL SFXASSVisibleBounds(
    ASS_Image *images,
    NSInteger frameWidth,
    NSInteger frameHeight,
    NSInteger *minX,
    NSInteger *minY,
    NSInteger *maxX,
    NSInteger *maxY,
    NSInteger *imageCount
) {
    NSInteger nextMinX = frameWidth;
    NSInteger nextMinY = frameHeight;
    NSInteger nextMaxX = 0;
    NSInteger nextMaxY = 0;
    NSInteger nextImageCount = 0;

    for (ASS_Image *image = images; image != NULL; image = image->next) {
        if (image->w <= 0 || image->h <= 0 || image->bitmap == NULL || image->stride <= 0) {
            continue;
        }

        int sourceOpacity = 255 - (int)(image->color & 0xff);
        if (sourceOpacity <= 0) {
            continue;
        }

        NSInteger imageMinX = MAX((NSInteger)image->dst_x, 0);
        NSInteger imageMinY = MAX((NSInteger)image->dst_y, 0);
        NSInteger imageMaxX = MIN((NSInteger)image->dst_x + image->w, frameWidth);
        NSInteger imageMaxY = MIN((NSInteger)image->dst_y + image->h, frameHeight);
        if (imageMinX >= imageMaxX || imageMinY >= imageMaxY) {
            continue;
        }

        nextMinX = MIN(nextMinX, imageMinX);
        nextMinY = MIN(nextMinY, imageMinY);
        nextMaxX = MAX(nextMaxX, imageMaxX);
        nextMaxY = MAX(nextMaxY, imageMaxY);
        nextImageCount += 1;
    }

    if (nextImageCount == 0) {
        return NO;
    }

    *minX = nextMinX;
    *minY = nextMinY;
    *maxX = nextMaxX;
    *maxY = nextMaxY;
    *imageCount = nextImageCount;
    return YES;
}

static void SFXCompositeASSImagesIntoCrop(
    ASS_Image *images,
    uint8_t *destination,
    NSInteger cropMinX,
    NSInteger cropMinY,
    NSInteger cropMaxX,
    NSInteger cropMaxY,
    NSInteger destinationStride
) {
    for (ASS_Image *image = images; image != NULL; image = image->next) {
        if (image->w <= 0 || image->h <= 0 || image->bitmap == NULL || image->stride <= 0) {
            continue;
        }

        int sourceRed = (int)((image->color >> 24) & 0xff);
        int sourceGreen = (int)((image->color >> 16) & 0xff);
        int sourceBlue = (int)((image->color >> 8) & 0xff);
        int sourceOpacity = 255 - (int)(image->color & 0xff);

        if (sourceOpacity <= 0) {
            continue;
        }

        NSInteger imageMinX = MAX((NSInteger)image->dst_x, cropMinX);
        NSInteger imageMinY = MAX((NSInteger)image->dst_y, cropMinY);
        NSInteger imageMaxX = MIN((NSInteger)image->dst_x + image->w, cropMaxX);
        NSInteger imageMaxY = MIN((NSInteger)image->dst_y + image->h, cropMaxY);
        if (imageMinX >= imageMaxX || imageMinY >= imageMaxY) {
            continue;
        }

        NSInteger spanWidth = imageMaxX - imageMinX;
        NSInteger initialSourceX = imageMinX - image->dst_x;
        NSInteger initialDestOffset = (imageMinX - cropMinX) * 4;

        for (NSInteger destinationY = imageMinY; destinationY < imageMaxY; destinationY++) {
            NSInteger sourceY = destinationY - image->dst_y;
            const uint8_t *sourceRow = image->bitmap + (sourceY * image->stride) + initialSourceX;
            uint8_t *pixel = destination + ((destinationY - cropMinY) * destinationStride) + initialDestOffset;

            for (NSInteger x = 0; x < spanWidth; x++, pixel += 4) {
                int mask = sourceRow[x];
                if (mask == 0) {
                    continue;
                }
                int sourceAlpha = sourceOpacity == 255 ? mask : (mask * sourceOpacity + 127) / 255;
                if (sourceAlpha <= 0) {
                    continue;
                }
                if (sourceAlpha == 255) {
                    pixel[0] = (uint8_t)sourceRed;
                    pixel[1] = (uint8_t)sourceGreen;
                    pixel[2] = (uint8_t)sourceBlue;
                    pixel[3] = 255;
                } else if (pixel[3] == 0) {
                    pixel[0] = (uint8_t)((sourceRed * sourceAlpha + 127) / 255);
                    pixel[1] = (uint8_t)((sourceGreen * sourceAlpha + 127) / 255);
                    pixel[2] = (uint8_t)((sourceBlue * sourceAlpha + 127) / 255);
                    pixel[3] = (uint8_t)sourceAlpha;
                } else {
                    int inverseAlpha = 255 - sourceAlpha;
                    pixel[0] = (uint8_t)((sourceRed * sourceAlpha + pixel[0] * inverseAlpha + 127) / 255);
                    pixel[1] = (uint8_t)((sourceGreen * sourceAlpha + pixel[1] * inverseAlpha + 127) / 255);
                    pixel[2] = (uint8_t)((sourceBlue * sourceAlpha + pixel[2] * inverseAlpha + 127) / 255);
                    pixel[3] = (uint8_t)(sourceAlpha + (pixel[3] * inverseAlpha + 127) / 255);
                }
            }
        }
    }
}

static BOOL SFXASSValidateSourcePath(NSString *path, NSError **error) {
    if (path.length == 0) {
        SFXASSSetError(error, SFXASSRenderingErrorInvalidInput, @"ASS source path is required.");
        return NO;
    }

    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] || isDirectory) {
        NSString *message = [NSString stringWithFormat:@"ASS source file does not exist: %@", path];
        SFXASSSetError(error, SFXASSRenderingErrorLoadFailed, message);
        return NO;
    }

    return YES;
}

static BOOL SFXASSValidateFrameSize(NSInteger frameWidth, NSInteger frameHeight, NSError **error) {
    if (frameWidth <= 0 || frameHeight <= 0 || frameWidth > INT_MAX || frameHeight > INT_MAX) {
        SFXASSSetError(error, SFXASSRenderingErrorInvalidInput, @"Frame width and height must be positive Int32 values.");
        return NO;
    }

    NSInteger stride = frameWidth * 4;
    if (frameHeight > NSIntegerMax / stride) {
        SFXASSSetError(error, SFXASSRenderingErrorInvalidInput, @"Frame dimensions are too large.");
        return NO;
    }

    return YES;
}

static BOOL SFXASSValidateScript(NSString *script, NSString *sourceIdentifier, NSError **error) {
    if (script.length == 0) {
        SFXASSSetError(error, SFXASSRenderingErrorInvalidInput, @"ASS script text is required.");
        return NO;
    }
    if (sourceIdentifier.length == 0) {
        SFXASSSetError(error, SFXASSRenderingErrorInvalidInput, @"ASS source identifier is required.");
        return NO;
    }
    return YES;
}

static BOOL SFXParseASSTimestampMilliseconds(const char *p, const char *end, int32_t *outMs) {
    while (p < end && (*p == ' ' || *p == '\t')) {
        p++;
    }
    if (p >= end || *p < '0' || *p > '9') {
        return NO;
    }
    int64_t hours = 0;
    while (p < end && *p >= '0' && *p <= '9') {
        hours = hours * 10 + (*p - '0');
        p++;
    }
    if (p >= end || *p != ':') {
        return NO;
    }
    p++;
    if (p >= end || *p < '0' || *p > '9') {
        return NO;
    }
    int64_t minutes = 0;
    while (p < end && *p >= '0' && *p <= '9') {
        minutes = minutes * 10 + (*p - '0');
        p++;
    }
    if (p >= end || *p != ':') {
        return NO;
    }
    p++;
    if (p >= end || *p < '0' || *p > '9') {
        return NO;
    }
    int64_t seconds = 0;
    while (p < end && *p >= '0' && *p <= '9') {
        seconds = seconds * 10 + (*p - '0');
        p++;
    }
    if (p >= end || (*p != '.' && *p != ':')) {
        return NO;
    }
    p++;
    int64_t fracMs = 0;
    int fracDigits = 0;
    while (p < end && *p >= '0' && *p <= '9') {
        if (fracDigits == 0) {
            fracMs += (*p - '0') * 100;
        } else if (fracDigits == 1) {
            fracMs += (*p - '0') * 10;
        } else if (fracDigits == 2) {
            fracMs += (*p - '0');
        }
        fracDigits++;
        p++;
    }
    if (fracDigits == 0) {
        return NO;
    }
    int64_t totalMs = ((hours * 3600LL) + (minutes * 60LL) + seconds) * 1000LL + fracMs;
    if (totalMs < 0) {
        totalMs = 0;
    }
    if (totalMs > INT32_MAX) {
        totalMs = INT32_MAX;
    }
    *outMs = (int32_t)totalMs;
    return YES;
}

static NSData *SFXEnsureTrailingNewlineData(NSData *data) {
    if (data == nil || data.length == 0) {
        return data;
    }
    const char *bytes = (const char *)data.bytes;
    if (bytes[data.length - 1] == '\n') {
        return data;
    }
    NSMutableData *mutableData = [data mutableCopy];
    [mutableData appendBytes:"\n" length:1];
    return mutableData;
}

static BOOL SFXParseEventsFormatColumns(
    const char *formatValueStart,
    const char *formatValueEnd,
    int *outFieldCount,
    int *outStartIndex,
    int *outEndIndex
) {
    if (formatValueStart == NULL || formatValueEnd == NULL || formatValueStart >= formatValueEnd) {
        return NO;
    }
    int fieldCount = 0;
    int startIndex = -1;
    int endIndex = -1;
    int textIndex = -1;
    const char *cursor = formatValueStart;
    while (cursor <= formatValueEnd) {
        const char *comma = (const char *)memchr(cursor, ',', (size_t)(formatValueEnd - cursor));
        const char *tokenEnd = comma != NULL ? comma : formatValueEnd;
        const char *tokenStart = cursor;
        while (tokenStart < tokenEnd && (*tokenStart == ' ' || *tokenStart == '\t')) {
            tokenStart++;
        }
        while (tokenEnd > tokenStart
               && (tokenEnd[-1] == ' ' || tokenEnd[-1] == '\t' || tokenEnd[-1] == '\r' || tokenEnd[-1] == '\n')) {
            tokenEnd--;
        }
        size_t tokenLen = (size_t)(tokenEnd - tokenStart);
        if (tokenLen == 5 && strncasecmp(tokenStart, "Start", 5) == 0 && startIndex < 0) {
            startIndex = fieldCount;
        } else if (tokenLen == 3 && strncasecmp(tokenStart, "End", 3) == 0 && endIndex < 0) {
            endIndex = fieldCount;
        } else if (tokenLen == 4 && strncasecmp(tokenStart, "Text", 4) == 0) {
            textIndex = fieldCount;
        }
        fieldCount++;
        if (comma == NULL) {
            break;
        }
        cursor = comma + 1;
    }
    if (fieldCount < 3 || startIndex < 0 || endIndex < 0 || textIndex != fieldCount - 1) {
        return NO;
    }
    *outFieldCount = fieldCount;
    *outStartIndex = startIndex;
    *outEndIndex = endIndex;
    return YES;
}

static BOOL SFXExtractDialogueFieldRange(
    const char *afterPrefix,
    const char *lineEnd,
    int fieldCount,
    int targetIndex,
    const char **outStart,
    const char **outEnd
) {
    if (afterPrefix == NULL || lineEnd == NULL || afterPrefix > lineEnd || targetIndex < 0 || targetIndex >= fieldCount) {
        return NO;
    }
    const char *cursor = afterPrefix;
    for (int col = 0; col < fieldCount; col++) {
        if (col == fieldCount - 1) {
            if (col == targetIndex) {
                *outStart = cursor;
                *outEnd = lineEnd;
                return YES;
            }
            return NO;
        }
        const char *comma = (const char *)memchr(cursor, ',', (size_t)(lineEnd - cursor));
        if (comma == NULL) {
            return NO;
        }
        if (col == targetIndex) {
            *outStart = cursor;
            *outEnd = comma;
            return YES;
        }
        cursor = comma + 1;
    }
    return NO;
}

static BOOL SFXIsValidUTF8WithoutNulls(const uint8_t *bytes, size_t length) {
    if (bytes == NULL || length == 0) {
        return NO;
    }
    if (length >= 2 && ((bytes[0] == 0xFF && bytes[1] == 0xFE) || (bytes[0] == 0xFE && bytes[1] == 0xFF))) {
        return NO;
    }
    if (length >= 4 && bytes[0] == 0x00 && bytes[1] == 0x00 && bytes[2] == 0xFE && bytes[3] == 0xFF) {
        return NO;
    }
    size_t i = 0;
    while (i < length) {
        uint8_t b0 = bytes[i];
        if (b0 == 0x00) {
            return NO;
        }
        if (b0 < 0x80) {
            i += 1;
            continue;
        }
        if (b0 >= 0xC2 && b0 <= 0xDF) {
            if (i + 1 >= length) {
                return NO;
            }
            uint8_t b1 = bytes[i + 1];
            if ((b1 & 0xC0) != 0x80) {
                return NO;
            }
            i += 2;
            continue;
        }
        if (b0 >= 0xE0 && b0 <= 0xEF) {
            if (i + 2 >= length) {
                return NO;
            }
            uint8_t b1 = bytes[i + 1];
            uint8_t b2 = bytes[i + 2];
            if ((b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80) {
                return NO;
            }
            if (b0 == 0xE0 && b1 < 0xA0) {
                return NO;
            }
            if (b0 == 0xED && b1 >= 0xA0) {
                return NO;
            }
            i += 3;
            continue;
        }
        if (b0 >= 0xF0 && b0 <= 0xF4) {
            if (i + 3 >= length) {
                return NO;
            }
            uint8_t b1 = bytes[i + 1];
            uint8_t b2 = bytes[i + 2];
            uint8_t b3 = bytes[i + 3];
            if ((b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80 || (b3 & 0xC0) != 0x80) {
                return NO;
            }
            if (b0 == 0xF0 && b1 < 0x90) {
                return NO;
            }
            if (b0 == 0xF4 && b1 >= 0x90) {
                return NO;
            }
            i += 4;
            continue;
        }
        return NO;
    }
    return YES;
}

static ASS_Track * _Nullable SFXReadASSMemory(
    ASS_Library *library,
    const char *bytes,
    size_t length,
    SFXASSScriptRewriterBlock _Nullable scriptRewriter
) {
    if (library == NULL || bytes == NULL || length == 0) {
        return NULL;
    }
    if (scriptRewriter != nil) {
        @autoreleasepool {
            NSString *chunk = [[NSString alloc] initWithBytes:bytes
                                                       length:length
                                                     encoding:NSUTF8StringEncoding];
            if (chunk != nil) {
                NSString *rewritten = scriptRewriter(chunk);
                NSData *utf8Data = [rewritten dataUsingEncoding:NSUTF8StringEncoding];
                if (utf8Data != nil && utf8Data.length > 0) {
                    char *copy = (char *)malloc(utf8Data.length);
                    if (copy == NULL) {
                        return NULL;
                    }
                    memcpy(copy, utf8Data.bytes, utf8Data.length);
                    ASS_Track *track = ass_read_memory(library, copy, utf8Data.length, NULL);
                    free(copy);
                    return track;
                }
            }
        }
    }
    char *copy = (char *)malloc(length);
    if (copy == NULL) {
        return NULL;
    }
    memcpy(copy, bytes, length);
    ASS_Track *track = ass_read_memory(library, copy, length, NULL);
    free(copy);
    return track;
}

static BOOL SFXMapFileAtPath(NSString *path, const char **outBytes, size_t *outLength) {
    int fd = open([path fileSystemRepresentation], O_RDONLY);
    if (fd < 0) {
        return NO;
    }
    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_size <= 0) {
        close(fd);
        return NO;
    }
    size_t length = (size_t)st.st_size;
    void *mapped = mmap(NULL, length, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    if (mapped == MAP_FAILED) {
        return NO;
    }
    *outBytes = (const char *)mapped;
    *outLength = length;
    return YES;
}

@implementation SFXASSRenderOutput

- (instancetype)initWithRGBAData:(NSData *)rgbaData
                           width:(NSInteger)width
                          height:(NSInteger)height
                          stride:(NSInteger)stride
                      imageCount:(NSInteger)imageCount
                         changed:(BOOL)changed {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    _rgbaData = [rgbaData copy];
    _width = width;
    _height = height;
    _stride = stride;
    _imageCount = imageCount;
    _changed = changed;
    return self;
}

- (BOOL)writePNGToPath:(NSString *)path error:(NSError **)error {
    if (path.length == 0) {
        SFXASSSetError(error, SFXASSRenderingErrorInvalidInput, @"PNG output path is required.");
        return NO;
    }

    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)self.rgbaData);
    if (provider == NULL) {
        SFXASSSetError(error, SFXASSRenderingErrorPNGWriteFailed, @"Could not create a PNG data provider.");
        return NO;
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == NULL) {
        CGDataProviderRelease(provider);
        SFXASSSetError(error, SFXASSRenderingErrorPNGWriteFailed, @"Could not create a PNG color space.");
        return NO;
    }

    CGImageRef image = CGImageCreate(
        (size_t)self.width,
        (size_t)self.height,
        8,
        32,
        (size_t)self.stride,
        colorSpace,
        kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast,
        provider,
        NULL,
        false,
        kCGRenderingIntentDefault
    );

    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);

    if (image == NULL) {
        SFXASSSetError(error, SFXASSRenderingErrorPNGWriteFailed, @"Could not create a PNG image.");
        return NO;
    }

    NSURL *url = [NSURL fileURLWithPath:path];
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)url, CFSTR("public.png"), 1, NULL);
    if (destination == NULL) {
        CGImageRelease(image);
        SFXASSSetError(error, SFXASSRenderingErrorPNGWriteFailed, @"Could not create a PNG destination.");
        return NO;
    }

    CGImageDestinationAddImage(destination, image, NULL);
    BOOL success = CGImageDestinationFinalize(destination);

    CFRelease(destination);
    CGImageRelease(image);

    if (!success) {
        SFXASSSetError(error, SFXASSRenderingErrorPNGWriteFailed, @"Could not finalize the PNG file.");
        return NO;
    }

    return YES;
}

@end

@implementation SFXASSCroppedRenderOutput

- (instancetype)initWithRGBAData:(NSData *)rgbaData
                            width:(NSInteger)width
                           height:(NSInteger)height
                           stride:(NSInteger)stride
                     destinationX:(NSInteger)destinationX
                     destinationY:(NSInteger)destinationY
                       frameWidth:(NSInteger)frameWidth
                      frameHeight:(NSInteger)frameHeight
                       imageCount:(NSInteger)imageCount
                          changed:(BOOL)changed
        unchangedFromMilliseconds:(NSInteger)unchangedFromMilliseconds
       unchangedUntilMilliseconds:(NSInteger)unchangedUntilMilliseconds
    activeEventSetFromMilliseconds:(NSInteger)activeEventSetFromMilliseconds
   activeEventSetUntilMilliseconds:(NSInteger)activeEventSetUntilMilliseconds {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    _rgbaData = [rgbaData copy];
    _width = width;
    _height = height;
    _stride = stride;
    _destinationX = destinationX;
    _destinationY = destinationY;
    _frameWidth = frameWidth;
    _frameHeight = frameHeight;
    _imageCount = imageCount;
    _changed = changed;
    _unchangedFromMilliseconds = unchangedFromMilliseconds;
    _unchangedUntilMilliseconds = unchangedUntilMilliseconds;
    _activeEventSetFromMilliseconds = activeEventSetFromMilliseconds;
    _activeEventSetUntilMilliseconds = activeEventSetUntilMilliseconds;
    return self;
}

@end

@implementation SFXASSRendererSession {
    ASS_Library *_library;
    ASS_Renderer *_renderer;
    ASS_Track *_track;
    BOOL _usesPooledEngine;
    NSUInteger _enginePoolGeneration;
    BOOL _ownsMappedFile;
    NSData *_scriptUTF8Data;
    const char *_mappedScriptBytes;
    size_t _mappedScriptLength;
    SFXASSScriptRewriterBlock _scriptRewriter;
    SFXASSWindowEventLinesProviderBlock _windowEventLinesProvider;
    NSData *_rewrittenHeaderData;
    SFXASSEventSlice *_eventSlices;
    size_t _eventSliceCount;
    BOOL _usesWindowedEvents;
    NSInteger _loadedWindowStartMilliseconds;
    NSInteger _loadedWindowEndMilliseconds;
    uint8_t *_eventAnimatedFlags;
    NSMutableData *_reusableCropBuffer;
    BOOL _hasRenderedCroppedFrame;
    NSInteger _lastUnchangedFromMilliseconds;
    NSInteger _lastUnchangedUntilMilliseconds;
    NSInteger _lastActiveEventSetFromMilliseconds;
    NSInteger _lastActiveEventSetUntilMilliseconds;
}

- (nullable instancetype)initWithASSFileAtPath:(NSString *)path
                                    frameWidth:(NSInteger)frameWidth
                                   frameHeight:(NSInteger)frameHeight
                                         error:(NSError **)error {
    return [self initWithASSFileAtPath:path
                            frameWidth:frameWidth
                           frameHeight:frameHeight
                        scriptRewriter:nil
                                 error:error];
}

- (nullable instancetype)initWithASSFileAtPath:(NSString *)path
                                    frameWidth:(NSInteger)frameWidth
                                   frameHeight:(NSInteger)frameHeight
                                scriptRewriter:(nullable SFXASSScriptRewriterBlock)scriptRewriter
                                         error:(NSError **)error {
    if (!SFXASSValidateSourcePath(path, error) || !SFXASSValidateFrameSize(frameWidth, frameHeight, error)) {
        return nil;
    }

    self = [super init];
    if (self == nil) {
        return nil;
    }

    _sourcePath = [path copy];
    _frameWidth = frameWidth;
    _frameHeight = frameHeight;
    _scriptRewriter = [scriptRewriter copy];
    _loadedWindowStartMilliseconds = -1;
    _loadedWindowEndMilliseconds = -1;
    _lastUnchangedFromMilliseconds = -1;
    _lastUnchangedUntilMilliseconds = -1;
    _lastActiveEventSetFromMilliseconds = -1;
    _lastActiveEventSetUntilMilliseconds = -1;

    NSString *failureMessage = [NSString stringWithFormat:@"libass could not load ASS source file: %@", path];
    if (!SFXMapFileAtPath(path, &_mappedScriptBytes, &_mappedScriptLength)) {
        SFXASSSetError(error, SFXASSRenderingErrorLoadFailed, failureMessage);
        [self cleanup];
        return nil;
    }
    _ownsMappedFile = YES;

    if (!SFXIsValidUTF8WithoutNulls((const uint8_t *)_mappedScriptBytes, _mappedScriptLength)) {
        SFXASSSetError(error, SFXASSRenderingErrorLoadFailed, failureMessage);
        [self cleanup];
        return nil;
    }

    BOOL hasEmbeddedFonts = SFXBytesContainEmbeddedFontsSection(_mappedScriptBytes, _mappedScriptLength);
    if (!SFXCheckoutASSEngineContext(hasEmbeddedFonts, frameWidth, frameHeight, &_library, &_renderer, &_usesPooledEngine, &_enginePoolGeneration, error)) {
        [self cleanup];
        return nil;
    }

    if (![self initializeTrackFromMappedScriptWithFailureMessage:failureMessage error:error]) {
        SFXASSSetError(error, SFXASSRenderingErrorLoadFailed, failureMessage);
        [self cleanup];
        return nil;
    }

    return self;
}

- (nullable instancetype)initWithASSScript:(NSString *)script
                          sourceIdentifier:(NSString *)sourceIdentifier
                                frameWidth:(NSInteger)frameWidth
                               frameHeight:(NSInteger)frameHeight
                                     error:(NSError **)error {
    if (!SFXASSValidateScript(script, sourceIdentifier, error)
        || !SFXASSValidateFrameSize(frameWidth, frameHeight, error)) {
        return nil;
    }

    self = [super init];
    if (self == nil) {
        return nil;
    }

    _sourcePath = [sourceIdentifier copy];
    _frameWidth = frameWidth;
    _frameHeight = frameHeight;
    _loadedWindowStartMilliseconds = -1;
    _loadedWindowEndMilliseconds = -1;
    _lastUnchangedFromMilliseconds = -1;
    _lastUnchangedUntilMilliseconds = -1;
    _lastActiveEventSetFromMilliseconds = -1;
    _lastActiveEventSetUntilMilliseconds = -1;

    NSData *utf8Data = [script dataUsingEncoding:NSUTF8StringEncoding];
    if (utf8Data == nil || utf8Data.length == 0) {
        SFXASSSetError(error, SFXASSRenderingErrorLoadFailed, @"Could not encode ASS script text.");
        [self cleanup];
        return nil;
    }
    _scriptUTF8Data = utf8Data;
    _mappedScriptBytes = (const char *)_scriptUTF8Data.bytes;
    _mappedScriptLength = _scriptUTF8Data.length;
    _ownsMappedFile = NO;

    BOOL hasEmbeddedFonts = SFXBytesContainEmbeddedFontsSection(_mappedScriptBytes, _mappedScriptLength);
    if (!SFXCheckoutASSEngineContext(hasEmbeddedFonts, frameWidth, frameHeight, &_library, &_renderer, &_usesPooledEngine, &_enginePoolGeneration, error)) {
        [self cleanup];
        return nil;
    }

    NSString *failureMessage = [NSString stringWithFormat:@"libass could not load ASS script: %@", sourceIdentifier];
    if (![self initializeTrackFromMappedScriptWithFailureMessage:failureMessage error:error]) {
        [self cleanup];
        return nil;
    }

    return self;
}

- (nullable instancetype)initWithASSHeader:(NSString *)headerScript
                          sourceIdentifier:(NSString *)sourceIdentifier
                                frameWidth:(NSInteger)frameWidth
                               frameHeight:(NSInteger)frameHeight
                  windowEventLinesProvider:(SFXASSWindowEventLinesProviderBlock)windowEventLinesProvider
                                     error:(NSError **)error {
    if (!SFXASSValidateScript(headerScript, sourceIdentifier, error)
        || !SFXASSValidateFrameSize(frameWidth, frameHeight, error)) {
        return nil;
    }
    if (windowEventLinesProvider == nil) {
        SFXASSSetError(error, SFXASSRenderingErrorInvalidInput, @"Window event lines provider is required.");
        return nil;
    }

    self = [super init];
    if (self == nil) {
        return nil;
    }

    _sourcePath = [sourceIdentifier copy];
    _frameWidth = frameWidth;
    _frameHeight = frameHeight;
    _windowEventLinesProvider = [windowEventLinesProvider copy];
    _loadedWindowStartMilliseconds = -1;
    _loadedWindowEndMilliseconds = -1;
    _lastUnchangedFromMilliseconds = -1;
    _lastUnchangedUntilMilliseconds = -1;
    _lastActiveEventSetFromMilliseconds = -1;
    _lastActiveEventSetUntilMilliseconds = -1;

    NSData *headerData = [headerScript dataUsingEncoding:NSUTF8StringEncoding];
    NSString *failureMessage = [NSString stringWithFormat:@"libass could not load indexed ASS header: %@", sourceIdentifier];
    if (headerData == nil
        || headerData.length == 0
        || !SFXBytesContainEventsFormat((const char *)headerData.bytes, headerData.length)) {
        SFXASSSetError(error, SFXASSRenderingErrorLoadFailed, failureMessage);
        [self cleanup];
        return nil;
    }

    if (!SFXCheckoutASSEngineContext(NO, frameWidth, frameHeight, &_library, &_renderer, &_usesPooledEngine, &_enginePoolGeneration, error)) {
        [self cleanup];
        return nil;
    }

    _rewrittenHeaderData = SFXEnsureTrailingNewlineData(headerData);
    _track = SFXReadASSMemory(_library, (const char *)_rewrittenHeaderData.bytes, _rewrittenHeaderData.length, nil);
    if (_track == NULL) {
        SFXASSSetError(error, SFXASSRenderingErrorLoadFailed, failureMessage);
        [self cleanup];
        return nil;
    }

    _usesWindowedEvents = YES;
    return self;
}

- (BOOL)initializeTrackFromMappedScriptWithFailureMessage:(NSString *)failureMessage
                                                    error:(NSError **)error {
    if (_mappedScriptBytes == NULL || _mappedScriptLength == 0) {
        SFXASSSetError(error, SFXASSRenderingErrorLoadFailed, failureMessage);
        return NO;
    }

    size_t bodyStart = 0;
    if (_mappedScriptLength >= 3
        && (uint8_t)_mappedScriptBytes[0] == 0xEF
        && (uint8_t)_mappedScriptBytes[1] == 0xBB
        && (uint8_t)_mappedScriptBytes[2] == 0xBF) {
        bodyStart = 3;
    }

    size_t headerEnd = 0;
    BOOL isInsideEventsSection = NO;
    BOOL hasEventsFormat = NO;
    int eventsFormatFieldCount = 0;
    int eventsStartFieldIndex = -1;
    int eventsEndFieldIndex = -1;
    BOOL hasWindowableEventsFormat = NO;
    BOOL foundFirstDialogue = NO;
    BOOL canUseWindowedEvents = YES;
    size_t sliceCapacity = 0;
    size_t pos = bodyStart;

    while (pos < _mappedScriptLength) {
        const char *lineStart = _mappedScriptBytes + pos;
        const char *newline = (const char *)memchr(lineStart, '\n', _mappedScriptLength - pos);
        size_t lineLen = newline != NULL
            ? (size_t)(newline - lineStart + 1)
            : (_mappedScriptLength - pos);
        const char *lineEnd = lineStart + lineLen;

        const char *trimmed = lineStart;
        while (trimmed < lineEnd && (*trimmed == ' ' || *trimmed == '\t')) {
            trimmed++;
        }
        const char *contentEnd = lineEnd;
        while (contentEnd > trimmed
               && (contentEnd[-1] == ' ' || contentEnd[-1] == '\t' || contentEnd[-1] == '\r' || contentEnd[-1] == '\n')) {
            contentEnd--;
        }
        size_t trimmedLen = (size_t)(lineEnd - trimmed);
        size_t contentLen = (size_t)(contentEnd - trimmed);

        if (contentLen >= 2 && trimmed[0] == '[' && contentEnd[-1] == ']') {
            isInsideEventsSection = (contentLen == 8 && strncasecmp(trimmed, "[Events]", 8) == 0);
            if (foundFirstDialogue) {
                canUseWindowedEvents = NO;
                break;
            }
        } else if (isInsideEventsSection && contentLen >= 7 && strncasecmp(trimmed, "Format:", 7) == 0) {
            hasEventsFormat = YES;
            if (foundFirstDialogue) {
                canUseWindowedEvents = NO;
                break;
            }
            hasWindowableEventsFormat = SFXParseEventsFormatColumns(
                trimmed + 7,
                contentEnd,
                &eventsFormatFieldCount,
                &eventsStartFieldIndex,
                &eventsEndFieldIndex
            );
            if (!hasWindowableEventsFormat) {
                canUseWindowedEvents = NO;
            }
        } else if (isInsideEventsSection && hasEventsFormat && trimmedLen >= 9 && strncasecmp(trimmed, "Dialogue:", 9) == 0) {
            if (!foundFirstDialogue) {
                headerEnd = pos;
                foundFirstDialogue = YES;
            }
            if (!canUseWindowedEvents || !hasWindowableEventsFormat) {
                canUseWindowedEvents = NO;
                break;
            }
            const char *startFieldStart = NULL;
            const char *startFieldEnd = NULL;
            const char *endFieldStart = NULL;
            const char *endFieldEnd = NULL;
            int32_t startMs = 0;
            int32_t endMs = 0;
            if (SFXExtractDialogueFieldRange(
                    trimmed + 9,
                    lineEnd,
                    eventsFormatFieldCount,
                    eventsStartFieldIndex,
                    &startFieldStart,
                    &startFieldEnd
                )
                && SFXExtractDialogueFieldRange(
                    trimmed + 9,
                    lineEnd,
                    eventsFormatFieldCount,
                    eventsEndFieldIndex,
                    &endFieldStart,
                    &endFieldEnd
                )
                && SFXParseASSTimestampMilliseconds(startFieldStart, startFieldEnd, &startMs)
                && SFXParseASSTimestampMilliseconds(endFieldStart, endFieldEnd, &endMs)
                && pos <= UINT32_MAX
                && lineLen <= UINT32_MAX) {
                if (_eventSliceCount == sliceCapacity) {
                    size_t nextCapacity = sliceCapacity == 0 ? 1024 : sliceCapacity * 2;
                    SFXASSEventSlice *grown = (SFXASSEventSlice *)realloc(
                        _eventSlices,
                        nextCapacity * sizeof(SFXASSEventSlice)
                    );
                    if (grown == NULL) {
                        canUseWindowedEvents = NO;
                        break;
                    }
                    _eventSlices = grown;
                    sliceCapacity = nextCapacity;
                }
                _eventSlices[_eventSliceCount].startMs = startMs;
                _eventSlices[_eventSliceCount].endMs = endMs;
                _eventSlices[_eventSliceCount].offset = (uint32_t)pos;
                _eventSlices[_eventSliceCount].length = (uint32_t)lineLen;
                _eventSliceCount++;
            } else {
                canUseWindowedEvents = NO;
                break;
            }
        } else if (foundFirstDialogue) {
            if (contentLen > 0
                && *trimmed != ';'
                && !(trimmedLen >= 8 && strncasecmp(trimmed, "Comment:", 8) == 0)) {
                canUseWindowedEvents = NO;
                break;
            }
        }

        pos += lineLen;
    }

    if (!hasEventsFormat) {
        if (_eventSlices != NULL) {
            free(_eventSlices);
            _eventSlices = NULL;
            _eventSliceCount = 0;
        }
        SFXASSSetError(error, SFXASSRenderingErrorLoadFailed, failureMessage);
        return NO;
    }

    if (canUseWindowedEvents && foundFirstDialogue && _eventSliceCount > 0 && headerEnd > bodyStart) {
        size_t headerLength = headerEnd - bodyStart;
        NSData *headerData = nil;
        if (_scriptRewriter != nil) {
            @autoreleasepool {
                NSString *chunk = [[NSString alloc] initWithBytes:_mappedScriptBytes + bodyStart
                                                           length:headerLength
                                                         encoding:NSUTF8StringEncoding];
                if (chunk != nil) {
                    NSString *rewritten = _scriptRewriter(chunk);
                    headerData = [rewritten dataUsingEncoding:NSUTF8StringEncoding];
                }
            }
        }
        if (headerData == nil || headerData.length == 0) {
            headerData = [NSData dataWithBytes:_mappedScriptBytes + bodyStart length:headerLength];
        }
        _rewrittenHeaderData = SFXEnsureTrailingNewlineData(headerData);
        _track = SFXReadASSMemory(_library, (const char *)_rewrittenHeaderData.bytes, _rewrittenHeaderData.length, nil);
        if (_track != NULL) {
            _usesWindowedEvents = YES;
            _loadedWindowStartMilliseconds = -1;
            _loadedWindowEndMilliseconds = -1;
            return YES;
        }
    }

    if (_eventSlices != NULL) {
        free(_eventSlices);
        _eventSlices = NULL;
        _eventSliceCount = 0;
    }

    size_t fullLength = _mappedScriptLength - bodyStart;
    if (fullLength > 0) {
        _track = SFXReadASSMemory(_library, _mappedScriptBytes + bodyStart, fullLength, _scriptRewriter);
    }
    if (_track == NULL) {
        SFXASSSetError(error, SFXASSRenderingErrorLoadFailed, failureMessage);
        return NO;
    }
    _eventAnimatedFlags = SFXBuildASSEventAnimatedFlags(_track);
    return YES;
}

- (BOOL)ensureEventsLoadedForTimestampMilliseconds:(NSInteger)timestampMilliseconds
                                             error:(NSError **)error {
    if (!_usesWindowedEvents || _track == NULL) {
        return YES;
    }
    if (_windowEventLinesProvider == nil && _mappedScriptBytes == NULL) {
        return YES;
    }
    NSInteger clampedTimestamp = MAX(0, timestampMilliseconds);
    if (_loadedWindowEndMilliseconds > _loadedWindowStartMilliseconds
        && clampedTimestamp >= _loadedWindowStartMilliseconds
        && clampedTimestamp < _loadedWindowEndMilliseconds) {
        return YES;
    }

    NSInteger winStart = (clampedTimestamp / kSFXASSEventWindowDurationMilliseconds)
        * kSFXASSEventWindowDurationMilliseconds;
    NSInteger winEnd = winStart + kSFXASSEventWindowDurationMilliseconds;

    NSArray<NSString *> *providedLines = nil;
    if (_windowEventLinesProvider != nil) {
        NSError *providerError = nil;
        providedLines = _windowEventLinesProvider(winStart, winEnd, &providerError);
        if (providedLines == nil) {
            if (error != NULL) {
                *error = providerError ?: SFXASSRenderingError(
                    SFXASSRenderingErrorLoadFailed,
                    @"Indexed ASS window event provider failed."
                );
            }
            return NO;
        }
    }

    BOOL canFeedFirstWindowDirectly = (
        _loadedWindowEndMilliseconds <= _loadedWindowStartMilliseconds
        && _track->n_events == 0
    );
    if (!canFeedFirstWindowDirectly) {
        if (_rewrittenHeaderData.length > 0) {
            if (_track != NULL) {
                ass_free_track(_track);
                _track = NULL;
            }
            _track = SFXReadASSMemory(_library, (const char *)_rewrittenHeaderData.bytes, _rewrittenHeaderData.length, nil);
            if (_track == NULL) {
                SFXASSSetError(error, SFXASSRenderingErrorRenderFailed, @"libass failed to reload ASS header for window.");
                return NO;
            }
        } else {
            ass_flush_events(_track);
        }
    }

    if (providedLines != nil) {
        for (NSString *line in providedLines) {
            @autoreleasepool {
                NSData *lineData = [line dataUsingEncoding:NSUTF8StringEncoding];
                if (lineData != nil && lineData.length > 0 && lineData.length <= (NSUInteger)(INT_MAX - 1)) {
                    ass_process_data(_track, (char *)lineData.bytes, (int)lineData.length);
                    const char *bytes = (const char *)lineData.bytes;
                    if (bytes[lineData.length - 1] != '\n') {
                        ass_process_data(_track, "\n", 1);
                    }
                }
            }
        }
    } else {
        for (size_t i = 0; i < _eventSliceCount; i++) {
            if ((NSInteger)_eventSlices[i].endMs >= winStart
                && (NSInteger)_eventSlices[i].startMs <= winEnd) {
                const char *lineBytes = _mappedScriptBytes + _eventSlices[i].offset;
                size_t lineLength = (size_t)_eventSlices[i].length;
                if (_scriptRewriter != nil && memmem(lineBytes, lineLength, "\\fn", 3) != NULL) {
                    @autoreleasepool {
                        NSString *lineString = [[NSString alloc] initWithBytes:lineBytes
                                                                        length:lineLength
                                                                      encoding:NSUTF8StringEncoding];
                        NSString *rewrittenLine = lineString != nil ? _scriptRewriter(lineString) : nil;
                        NSData *rewrittenData = [rewrittenLine dataUsingEncoding:NSUTF8StringEncoding];
                        if (rewrittenData != nil && rewrittenData.length > 0 && rewrittenData.length <= INT_MAX) {
                            ass_process_data(_track, (char *)rewrittenData.bytes, (int)rewrittenData.length);
                        } else {
                            ass_process_data(_track, (char *)lineBytes, (int)lineLength);
                        }
                    }
                } else {
                    ass_process_data(_track, (char *)lineBytes, (int)lineLength);
                }
            }
        }
    }

    for (int i = 0; i < _track->n_events; i++) {
        _track->events[i].ReadOrder = i;
    }

    if (_eventAnimatedFlags != NULL) {
        free(_eventAnimatedFlags);
        _eventAnimatedFlags = NULL;
    }
    _eventAnimatedFlags = SFXBuildASSEventAnimatedFlags(_track);
    _loadedWindowStartMilliseconds = winStart;
    _loadedWindowEndMilliseconds = winEnd;
    _lastUnchangedFromMilliseconds = -1;
    _lastUnchangedUntilMilliseconds = -1;
    _lastActiveEventSetFromMilliseconds = -1;
    _lastActiveEventSetUntilMilliseconds = -1;
    return YES;
}

- (nullable SFXASSRenderOutput *)renderFrameAtTimestampMilliseconds:(NSInteger)timestampMilliseconds
                                                              error:(NSError **)error {
    if (timestampMilliseconds < 0) {
        SFXASSSetError(error, SFXASSRenderingErrorInvalidInput, @"Timestamp must be non-negative.");
        return nil;
    }
    if (_renderer == NULL || _track == NULL) {
        SFXASSSetError(error, SFXASSRenderingErrorRenderFailed, @"libass renderer session is not initialized.");
        return nil;
    }

    if (![self ensureEventsLoadedForTimestampMilliseconds:timestampMilliseconds error:error]) {
        return nil;
    }
    _lastUnchangedFromMilliseconds = -1;
    _lastUnchangedUntilMilliseconds = -1;
    _lastActiveEventSetFromMilliseconds = -1;
    _lastActiveEventSetUntilMilliseconds = -1;

    NSInteger stride = self.frameWidth * 4;
    NSMutableData *rgbaData = [NSMutableData dataWithLength:(NSUInteger)(stride * self.frameHeight)];
    if (rgbaData == nil) {
        SFXASSSetError(error, SFXASSRenderingErrorRenderFailed, @"Could not allocate ASS render output buffer.");
        return nil;
    }

    int detectChange = 0;
    ASS_Image *images = ass_render_frame(_renderer, _track, (long long)timestampMilliseconds, &detectChange);
    NSInteger imageCount = SFXCompositeASSImages(
        images,
        (uint8_t *)rgbaData.mutableBytes,
        self.frameWidth,
        self.frameHeight,
        stride
    );

    return [[SFXASSRenderOutput alloc] initWithRGBAData:rgbaData
                                                  width:self.frameWidth
                                                 height:self.frameHeight
                                                 stride:stride
                                             imageCount:imageCount
                                                changed:detectChange != 0];
}

- (nullable SFXASSCroppedRenderOutput *)renderCroppedImageAtTimestampMilliseconds:(NSInteger)timestampMilliseconds
                                                                            error:(NSError **)error {
    if (timestampMilliseconds < 0) {
        SFXASSSetError(error, SFXASSRenderingErrorInvalidInput, @"Timestamp must be non-negative.");
        return nil;
    }
    if (_renderer == NULL || _track == NULL) {
        SFXASSSetError(error, SFXASSRenderingErrorRenderFailed, @"libass renderer session is not initialized.");
        return nil;
    }

    if (![self ensureEventsLoadedForTimestampMilliseconds:timestampMilliseconds error:error]) {
        return nil;
    }

    if (_hasRenderedCroppedFrame
        && _lastUnchangedUntilMilliseconds > _lastUnchangedFromMilliseconds
        && timestampMilliseconds >= _lastUnchangedFromMilliseconds
        && timestampMilliseconds < _lastUnchangedUntilMilliseconds) {
        NSInteger cachedActiveSetFrom = _lastActiveEventSetUntilMilliseconds > _lastActiveEventSetFromMilliseconds
            ? _lastActiveEventSetFromMilliseconds
            : _lastUnchangedFromMilliseconds;
        NSInteger cachedActiveSetUntil = _lastActiveEventSetUntilMilliseconds > _lastActiveEventSetFromMilliseconds
            ? _lastActiveEventSetUntilMilliseconds
            : _lastUnchangedUntilMilliseconds;
        return [[SFXASSCroppedRenderOutput alloc] initWithRGBAData:[NSData data]
                                                             width:0
                                                            height:0
                                                            stride:0
                                                      destinationX:0
                                                      destinationY:0
                                                        frameWidth:self.frameWidth
                                                       frameHeight:self.frameHeight
                                                        imageCount:0
                                                           changed:NO
                                         unchangedFromMilliseconds:_lastUnchangedFromMilliseconds
                                        unchangedUntilMilliseconds:_lastUnchangedUntilMilliseconds
                                    activeEventSetFromMilliseconds:cachedActiveSetFrom
                                   activeEventSetUntilMilliseconds:cachedActiveSetUntil];
    }

    NSInteger unchangedFromMs = timestampMilliseconds;
    NSInteger unchangedUntilMs = timestampMilliseconds < NSIntegerMax ? timestampMilliseconds + 1 : NSIntegerMax;
    NSInteger activeSetFromMs = unchangedFromMs;
    NSInteger activeSetUntilMs = unchangedUntilMs;
    SFXComputeASSRenderWindows(
        _track,
        _eventAnimatedFlags,
        timestampMilliseconds,
        &unchangedFromMs,
        &unchangedUntilMs,
        &activeSetFromMs,
        &activeSetUntilMs
    );
    if (_usesWindowedEvents) {
        SFXClampASSWindowToRange(
            &unchangedFromMs,
            &unchangedUntilMs,
            _loadedWindowStartMilliseconds,
            _loadedWindowEndMilliseconds,
            timestampMilliseconds
        );
        SFXClampASSWindowToRange(
            &activeSetFromMs,
            &activeSetUntilMs,
            _loadedWindowStartMilliseconds,
            _loadedWindowEndMilliseconds,
            timestampMilliseconds
        );
    }

    int detectChange = 0;
    ASS_Image *images = ass_render_frame(_renderer, _track, (long long)timestampMilliseconds, &detectChange);
    BOOL changed = detectChange != 0 || !_hasRenderedCroppedFrame;

    _hasRenderedCroppedFrame = YES;
    _lastUnchangedFromMilliseconds = unchangedFromMs;
    _lastUnchangedUntilMilliseconds = unchangedUntilMs;
    _lastActiveEventSetFromMilliseconds = activeSetFromMs;
    _lastActiveEventSetUntilMilliseconds = activeSetUntilMs;

    if (!changed) {
        return [[SFXASSCroppedRenderOutput alloc] initWithRGBAData:[NSData data]
                                                             width:0
                                                            height:0
                                                            stride:0
                                                      destinationX:0
                                                      destinationY:0
                                                        frameWidth:self.frameWidth
                                                       frameHeight:self.frameHeight
                                                        imageCount:0
                                                           changed:NO
                                         unchangedFromMilliseconds:unchangedFromMs
                                        unchangedUntilMilliseconds:unchangedUntilMs
                                    activeEventSetFromMilliseconds:activeSetFromMs
                                   activeEventSetUntilMilliseconds:activeSetUntilMs];
    }

    NSInteger minX = 0;
    NSInteger minY = 0;
    NSInteger maxX = 0;
    NSInteger maxY = 0;
    NSInteger imageCount = 0;
    BOOL hasVisibleBounds = SFXASSVisibleBounds(
        images,
        self.frameWidth,
        self.frameHeight,
        &minX,
        &minY,
        &maxX,
        &maxY,
        &imageCount
    );

    if (!hasVisibleBounds) {
        return [[SFXASSCroppedRenderOutput alloc] initWithRGBAData:[NSData data]
                                                             width:0
                                                            height:0
                                                            stride:0
                                                      destinationX:0
                                                      destinationY:0
                                                        frameWidth:self.frameWidth
                                                       frameHeight:self.frameHeight
                                                        imageCount:0
                                                           changed:YES
                                         unchangedFromMilliseconds:unchangedFromMs
                                        unchangedUntilMilliseconds:unchangedUntilMs
                                    activeEventSetFromMilliseconds:activeSetFromMs
                                   activeEventSetUntilMilliseconds:activeSetUntilMs];
    }

    NSInteger cropWidth = maxX - minX;
    NSInteger cropHeight = maxY - minY;
    NSInteger stride = cropWidth * 4;
    if (cropWidth <= 0 || cropHeight <= 0 || cropHeight > NSIntegerMax / stride) {
        SFXASSSetError(error, SFXASSRenderingErrorRenderFailed, @"Computed ASS cropped output dimensions are invalid.");
        return nil;
    }

    NSUInteger requiredBytes = (NSUInteger)(stride * cropHeight);
    if (_reusableCropBuffer == nil
        || (_reusableCropBuffer.length > requiredBytes * 2 && _reusableCropBuffer.length > 262144)) {
        _reusableCropBuffer = [NSMutableData dataWithLength:requiredBytes];
    } else {
        if (_reusableCropBuffer.length < requiredBytes) {
            _reusableCropBuffer.length = requiredBytes;
        }
        memset(_reusableCropBuffer.mutableBytes, 0, requiredBytes);
    }
    if (_reusableCropBuffer == nil) {
        SFXASSSetError(error, SFXASSRenderingErrorRenderFailed, @"Could not allocate ASS cropped render output buffer.");
        return nil;
    }

    SFXCompositeASSImagesIntoCrop(
        images,
        (uint8_t *)_reusableCropBuffer.mutableBytes,
        minX,
        minY,
        maxX,
        maxY,
        stride
    );

    NSData *outputData = [NSData dataWithBytes:_reusableCropBuffer.bytes length:requiredBytes];
    return [[SFXASSCroppedRenderOutput alloc] initWithRGBAData:outputData
                                                         width:cropWidth
                                                        height:cropHeight
                                                        stride:stride
                                                  destinationX:minX
                                                  destinationY:minY
                                                    frameWidth:self.frameWidth
                                                   frameHeight:self.frameHeight
                                                    imageCount:imageCount
                                                       changed:YES
                                     unchangedFromMilliseconds:unchangedFromMs
                                    unchangedUntilMilliseconds:unchangedUntilMs
                                activeEventSetFromMilliseconds:activeSetFromMs
                               activeEventSetUntilMilliseconds:activeSetUntilMs];
}

- (BOOL)updateFrameWidth:(NSInteger)frameWidth
             frameHeight:(NSInteger)frameHeight {
    if (_renderer == NULL || _track == NULL || !SFXASSValidateFrameSize(frameWidth, frameHeight, NULL)) {
        return NO;
    }
    if (_frameWidth == frameWidth && _frameHeight == frameHeight) {
        return YES;
    }
    SFXApplyASSRendererFrameSize(_renderer, frameWidth, frameHeight);
    _frameWidth = frameWidth;
    _frameHeight = frameHeight;
    _hasRenderedCroppedFrame = NO;
    _lastUnchangedFromMilliseconds = -1;
    _lastUnchangedUntilMilliseconds = -1;
    _lastActiveEventSetFromMilliseconds = -1;
    _lastActiveEventSetUntilMilliseconds = -1;
    return YES;
}

- (void)dealloc {
    [self cleanup];
}

- (void)close {
    [self cleanup];
}

- (void)cleanup {
    _reusableCropBuffer = nil;
    _scriptRewriter = nil;
    _windowEventLinesProvider = nil;
    _rewrittenHeaderData = nil;
    if (_eventAnimatedFlags != NULL) {
        free(_eventAnimatedFlags);
        _eventAnimatedFlags = NULL;
    }
    if (_eventSlices != NULL) {
        free(_eventSlices);
        _eventSlices = NULL;
        _eventSliceCount = 0;
    }
    if (_mappedScriptBytes != NULL) {
        if (_ownsMappedFile && _mappedScriptLength > 0) {
            munmap((void *)_mappedScriptBytes, _mappedScriptLength);
        }
        _mappedScriptBytes = NULL;
        _mappedScriptLength = 0;
    }
    _ownsMappedFile = NO;
    _scriptUTF8Data = nil;
    _usesWindowedEvents = NO;
    _loadedWindowStartMilliseconds = -1;
    _loadedWindowEndMilliseconds = -1;
    if (_track != NULL) {
        ass_free_track(_track);
        _track = NULL;
    }
    if (_renderer != NULL || _library != NULL) {
        ASS_Library *library = _library;
        ASS_Renderer *renderer = _renderer;
        BOOL usesPool = _usesPooledEngine;
        NSUInteger enginePoolGeneration = _enginePoolGeneration;
        _library = NULL;
        _renderer = NULL;
        _usesPooledEngine = NO;
        _enginePoolGeneration = 0;
        SFXReturnOrDestroyASSEngineContext(library, renderer, usesPool, enginePoolGeneration);
    }
}

@end

@implementation SFXASSRenderer

+ (NSString *)libassVersionString {
    int version = ass_library_version();
    int major = (version >> 28) & 0x0f;
    int minor = (version >> 20) & 0xff;
    int patch = (version >> 12) & 0xff;
    return [NSString stringWithFormat:@"%x.%x.%x", major, minor, patch];
}

+ (void)warmUpFontEnvironment {
    SFXWarmUpASSFontEnvironment();
}

+ (void)invalidateFontEnvironmentPool {
    SFXInvalidateASSFontEnvironmentPool();
}

+ (NSUInteger)engineInitializationCountForTesting {
    pthread_mutex_lock(&gSFXASSEnginePoolMutex);
    NSUInteger count = gSFXASSEngineInitCountForTesting;
    pthread_mutex_unlock(&gSFXASSEnginePoolMutex);
    return count;
}

+ (void)resetFontEnvironmentPoolForTesting {
    SFXASSEngineContext toDestroy[kSFXASSEnginePoolCapacity];
    NSUInteger destroyCount = 0;

    pthread_mutex_lock(&gSFXASSEnginePoolMutex);
    while (gSFXASSIsWarmingUp) {
        pthread_cond_wait(&gSFXASSEnginePoolCond, &gSFXASSEnginePoolMutex);
    }
    destroyCount = gSFXASSEnginePoolCount;
    for (NSUInteger i = 0; i < destroyCount; i++) {
        toDestroy[i] = gSFXASSEnginePool[i];
        gSFXASSEnginePool[i].library = NULL;
        gSFXASSEnginePool[i].renderer = NULL;
    }
    gSFXASSEnginePoolCount = 0;
    gSFXASSHasCompletedWarmup = NO;
    gSFXASSEnginePoolGeneration += 1;
    gSFXASSEngineInitCountForTesting = 0;
    pthread_mutex_unlock(&gSFXASSEnginePoolMutex);

    for (NSUInteger i = 0; i < destroyCount; i++) {
        if (toDestroy[i].renderer != NULL) {
            ass_renderer_done(toDestroy[i].renderer);
        }
        if (toDestroy[i].library != NULL) {
            ass_library_done(toDestroy[i].library);
        }
    }
}

+ (nullable SFXASSRenderOutput *)renderASSFileAtPath:(NSString *)path
                                          frameWidth:(NSInteger)frameWidth
                                         frameHeight:(NSInteger)frameHeight
                               timestampMilliseconds:(NSInteger)timestampMilliseconds
                                               error:(NSError **)error {
    SFXASSRendererSession *session = [[SFXASSRendererSession alloc] initWithASSFileAtPath:path
                                                                               frameWidth:frameWidth
                                                                              frameHeight:frameHeight
                                                                                    error:error];
    if (session == nil) {
        return nil;
    }

    return [session renderFrameAtTimestampMilliseconds:timestampMilliseconds error:error];
}

@end
