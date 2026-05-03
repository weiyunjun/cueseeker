#import "SFXASSRenderer.h"

#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>

#include <ass/ass.h>
#include <limits.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>

NSString * const SFXASSRenderingErrorDomain = @"CueSeeker.ASSRendering";

@interface SFXASSRenderOutput ()

- (instancetype)initWithRGBAData:(NSData *)rgbaData
                           width:(NSInteger)width
                          height:(NSInteger)height
                          stride:(NSInteger)stride
                      imageCount:(NSInteger)imageCount
                         changed:(BOOL)changed NS_DESIGNATED_INITIALIZER;

@end

@interface SFXASSImage ()

- (instancetype)initWithBitmapData:(NSData *)bitmapData
                              width:(NSInteger)width
                             height:(NSInteger)height
                             stride:(NSInteger)stride
                       destinationX:(NSInteger)destinationX
                       destinationY:(NSInteger)destinationY
                              color:(uint32_t)color NS_DESIGNATED_INITIALIZER;

@end

@interface SFXASSImageRenderOutput ()

- (instancetype)initWithImages:(NSArray<SFXASSImage *> *)images
                    frameWidth:(NSInteger)frameWidth
                   frameHeight:(NSInteger)frameHeight
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
                          changed:(BOOL)changed NS_DESIGNATED_INITIALIZER;

@end

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

static NSArray<SFXASSImage *> *SFXCopyASSImages(ASS_Image *images) {
    NSMutableArray<SFXASSImage *> *copiedImages = [NSMutableArray array];

    for (ASS_Image *image = images; image != NULL; image = image->next) {
        if (image->w <= 0 || image->h <= 0 || image->bitmap == NULL || image->stride <= 0) {
            continue;
        }

        NSUInteger bitmapLength = (NSUInteger)((NSInteger)image->stride * image->h);
        NSData *bitmapData = [NSData dataWithBytes:image->bitmap length:bitmapLength];
        SFXASSImage *copiedImage = [[SFXASSImage alloc] initWithBitmapData:bitmapData
                                                                     width:image->w
                                                                    height:image->h
                                                                    stride:image->stride
                                                              destinationX:image->dst_x
                                                              destinationY:image->dst_y
                                                                     color:image->color];
        [copiedImages addObject:copiedImage];
    }

    return copiedImages;
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

        for (NSInteger destinationY = imageMinY; destinationY < imageMaxY; destinationY++) {
            NSInteger sourceY = destinationY - image->dst_y;
            uint8_t *sourceRow = image->bitmap + (sourceY * image->stride);
            uint8_t *destinationRow = destination + ((destinationY - cropMinY) * destinationStride);

            for (NSInteger destinationX = imageMinX; destinationX < imageMaxX; destinationX++) {
                NSInteger sourceX = destinationX - image->dst_x;
                int mask = sourceRow[sourceX];
                int sourceAlpha = (mask * sourceOpacity + 127) / 255;
                if (sourceAlpha <= 0) {
                    continue;
                }

                uint8_t *pixel = destinationRow + ((destinationX - cropMinX) * 4);
                int inverseAlpha = 255 - sourceAlpha;

                pixel[0] = (uint8_t)((sourceRed * sourceAlpha + pixel[0] * inverseAlpha + 127) / 255);
                pixel[1] = (uint8_t)((sourceGreen * sourceAlpha + pixel[1] * inverseAlpha + 127) / 255);
                pixel[2] = (uint8_t)((sourceBlue * sourceAlpha + pixel[2] * inverseAlpha + 127) / 255);
                pixel[3] = (uint8_t)(sourceAlpha + (pixel[3] * inverseAlpha + 127) / 255);
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

@implementation SFXASSImage

- (instancetype)initWithBitmapData:(NSData *)bitmapData
                              width:(NSInteger)width
                             height:(NSInteger)height
                             stride:(NSInteger)stride
                       destinationX:(NSInteger)destinationX
                       destinationY:(NSInteger)destinationY
                              color:(uint32_t)color {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    _bitmapData = [bitmapData copy];
    _width = width;
    _height = height;
    _stride = stride;
    _destinationX = destinationX;
    _destinationY = destinationY;
    _color = color;
    return self;
}

@end

@implementation SFXASSImageRenderOutput

- (instancetype)initWithImages:(NSArray<SFXASSImage *> *)images
                    frameWidth:(NSInteger)frameWidth
                   frameHeight:(NSInteger)frameHeight
                       changed:(BOOL)changed {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    _images = [images copy];
    _frameWidth = frameWidth;
    _frameHeight = frameHeight;
    _changed = changed;
    return self;
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
                          changed:(BOOL)changed {
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
    return self;
}

@end

@implementation SFXASSRendererSession {
    ASS_Library *_library;
    ASS_Renderer *_renderer;
    ASS_Track *_track;
    BOOL _hasRenderedCroppedFrame;
}

- (nullable instancetype)initWithASSFileAtPath:(NSString *)path
                                    frameWidth:(NSInteger)frameWidth
                                   frameHeight:(NSInteger)frameHeight
                                fontsDirectory:(nullable NSString *)fontsDirectory
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

    _library = ass_library_init();
    if (_library == NULL) {
        SFXASSSetError(error, SFXASSRenderingErrorDependencyUnavailable, @"libass failed to initialize.");
        return nil;
    }

    ass_set_message_cb(_library, SFXASSMessageCallback, NULL);
    ass_set_extract_fonts(_library, 1);
    if (fontsDirectory.length > 0) {
        BOOL fontsIsDirectory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:fontsDirectory isDirectory:&fontsIsDirectory] || !fontsIsDirectory) {
            NSString *message = [NSString stringWithFormat:@"Font directory does not exist: %@", fontsDirectory];
            SFXASSSetError(error, SFXASSRenderingErrorLoadFailed, message);
            [self cleanup];
            return nil;
        }
        ass_set_fonts_dir(_library, [fontsDirectory fileSystemRepresentation]);
    }

    _renderer = ass_renderer_init(_library);
    if (_renderer == NULL) {
        SFXASSSetError(error, SFXASSRenderingErrorDependencyUnavailable, @"libass renderer failed to initialize.");
        [self cleanup];
        return nil;
    }

    ass_set_frame_size(_renderer, (int)frameWidth, (int)frameHeight);
    ass_set_storage_size(_renderer, (int)frameWidth, (int)frameHeight);
    ass_set_fonts(_renderer, NULL, "Helvetica", ASS_FONTPROVIDER_AUTODETECT, NULL, 1);

    _track = ass_read_file(_library, [path fileSystemRepresentation], NULL);
    if (_track == NULL) {
        NSString *message = [NSString stringWithFormat:@"libass could not load ASS source file: %@", path];
        SFXASSSetError(error, SFXASSRenderingErrorLoadFailed, message);
        [self cleanup];
        return nil;
    }

    return self;
}

- (nullable instancetype)initWithASSScript:(NSString *)script
                          sourceIdentifier:(NSString *)sourceIdentifier
                                frameWidth:(NSInteger)frameWidth
                               frameHeight:(NSInteger)frameHeight
                            fontsDirectory:(nullable NSString *)fontsDirectory
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

    _library = ass_library_init();
    if (_library == NULL) {
        SFXASSSetError(error, SFXASSRenderingErrorDependencyUnavailable, @"libass failed to initialize.");
        return nil;
    }

    ass_set_message_cb(_library, SFXASSMessageCallback, NULL);
    ass_set_extract_fonts(_library, 1);
    if (fontsDirectory.length > 0) {
        BOOL fontsIsDirectory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:fontsDirectory isDirectory:&fontsIsDirectory] || !fontsIsDirectory) {
            NSString *message = [NSString stringWithFormat:@"Font directory does not exist: %@", fontsDirectory];
            SFXASSSetError(error, SFXASSRenderingErrorLoadFailed, message);
            [self cleanup];
            return nil;
        }
        ass_set_fonts_dir(_library, [fontsDirectory fileSystemRepresentation]);
    }

    _renderer = ass_renderer_init(_library);
    if (_renderer == NULL) {
        SFXASSSetError(error, SFXASSRenderingErrorDependencyUnavailable, @"libass renderer failed to initialize.");
        [self cleanup];
        return nil;
    }

    ass_set_frame_size(_renderer, (int)frameWidth, (int)frameHeight);
    ass_set_storage_size(_renderer, (int)frameWidth, (int)frameHeight);
    ass_set_fonts(_renderer, NULL, "Helvetica", ASS_FONTPROVIDER_AUTODETECT, NULL, 1);

    NSMutableData *scriptData = [[script dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    if (scriptData == nil || scriptData.length == 0) {
        SFXASSSetError(error, SFXASSRenderingErrorLoadFailed, @"Could not encode ASS script text.");
        [self cleanup];
        return nil;
    }

    _track = ass_read_memory(_library, (char *)scriptData.mutableBytes, scriptData.length, NULL);
    if (_track == NULL) {
        NSString *message = [NSString stringWithFormat:@"libass could not load ASS script: %@", sourceIdentifier];
        SFXASSSetError(error, SFXASSRenderingErrorLoadFailed, message);
        [self cleanup];
        return nil;
    }

    return self;
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

- (nullable SFXASSImageRenderOutput *)renderImagesAtTimestampMilliseconds:(NSInteger)timestampMilliseconds
                                                                    error:(NSError **)error {
    if (timestampMilliseconds < 0) {
        SFXASSSetError(error, SFXASSRenderingErrorInvalidInput, @"Timestamp must be non-negative.");
        return nil;
    }
    if (_renderer == NULL || _track == NULL) {
        SFXASSSetError(error, SFXASSRenderingErrorRenderFailed, @"libass renderer session is not initialized.");
        return nil;
    }

    int detectChange = 0;
    ASS_Image *images = ass_render_frame(_renderer, _track, (long long)timestampMilliseconds, &detectChange);
    NSArray<SFXASSImage *> *copiedImages = SFXCopyASSImages(images);

    return [[SFXASSImageRenderOutput alloc] initWithImages:copiedImages
                                                frameWidth:self.frameWidth
                                               frameHeight:self.frameHeight
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

    int detectChange = 0;
    ASS_Image *images = ass_render_frame(_renderer, _track, (long long)timestampMilliseconds, &detectChange);
    BOOL changed = detectChange != 0 || !_hasRenderedCroppedFrame;

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
                                                         changed:NO];
    }

    _hasRenderedCroppedFrame = YES;

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
                                                           changed:YES];
    }

    NSInteger cropWidth = maxX - minX;
    NSInteger cropHeight = maxY - minY;
    NSInteger stride = cropWidth * 4;
    if (cropWidth <= 0 || cropHeight <= 0 || cropHeight > NSIntegerMax / stride) {
        SFXASSSetError(error, SFXASSRenderingErrorRenderFailed, @"Computed ASS cropped output dimensions are invalid.");
        return nil;
    }

    NSMutableData *rgbaData = [NSMutableData dataWithLength:(NSUInteger)(stride * cropHeight)];
    if (rgbaData == nil) {
        SFXASSSetError(error, SFXASSRenderingErrorRenderFailed, @"Could not allocate ASS cropped render output buffer.");
        return nil;
    }

    SFXCompositeASSImagesIntoCrop(
        images,
        (uint8_t *)rgbaData.mutableBytes,
        minX,
        minY,
        maxX,
        maxY,
        stride
    );

    return [[SFXASSCroppedRenderOutput alloc] initWithRGBAData:rgbaData
                                                         width:cropWidth
                                                        height:cropHeight
                                                        stride:stride
                                                  destinationX:minX
                                                  destinationY:minY
                                                    frameWidth:self.frameWidth
                                                   frameHeight:self.frameHeight
                                                    imageCount:imageCount
                                                       changed:YES];
}

- (void)dealloc {
    [self cleanup];
}

- (void)close {
    [self cleanup];
}

- (void)cleanup {
    if (_track != NULL) {
        ass_free_track(_track);
        _track = NULL;
    }
    if (_renderer != NULL) {
        ass_renderer_done(_renderer);
        _renderer = NULL;
    }
    if (_library != NULL) {
        ass_library_done(_library);
        _library = NULL;
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

+ (nullable SFXASSRenderOutput *)renderASSFileAtPath:(NSString *)path
                                          frameWidth:(NSInteger)frameWidth
                                         frameHeight:(NSInteger)frameHeight
                               timestampMilliseconds:(NSInteger)timestampMilliseconds
                                      fontsDirectory:(nullable NSString *)fontsDirectory
                                               error:(NSError **)error {
    SFXASSRendererSession *session = [[SFXASSRendererSession alloc] initWithASSFileAtPath:path
                                                                               frameWidth:frameWidth
                                                                              frameHeight:frameHeight
                                                                           fontsDirectory:fontsDirectory
                                                                                    error:error];
    if (session == nil) {
        return nil;
    }

    return [session renderFrameAtTimestampMilliseconds:timestampMilliseconds error:error];
}

@end
