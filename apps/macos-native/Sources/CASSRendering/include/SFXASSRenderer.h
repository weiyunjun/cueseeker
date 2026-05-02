#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const SFXASSRenderingErrorDomain;

typedef NS_ENUM(NSInteger, SFXASSRenderingErrorCode) {
    SFXASSRenderingErrorInvalidInput = 1,
    SFXASSRenderingErrorDependencyUnavailable = 2,
    SFXASSRenderingErrorLoadFailed = 3,
    SFXASSRenderingErrorRenderFailed = 4,
    SFXASSRenderingErrorPNGWriteFailed = 5
};

@interface SFXASSRenderOutput : NSObject

@property (nonatomic, copy, readonly) NSData *rgbaData;
@property (nonatomic, readonly) NSInteger width;
@property (nonatomic, readonly) NSInteger height;
@property (nonatomic, readonly) NSInteger stride;
@property (nonatomic, readonly) NSInteger imageCount;
@property (nonatomic, readonly) BOOL changed;

- (instancetype)init NS_UNAVAILABLE;
- (BOOL)writePNGToPath:(NSString *)path error:(NSError **)error
    NS_SWIFT_NAME(writePNG(toPath:));

@end

@interface SFXASSRendererSession : NSObject

@property (nonatomic, copy, readonly) NSString *sourcePath;
@property (nonatomic, readonly) NSInteger frameWidth;
@property (nonatomic, readonly) NSInteger frameHeight;

- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithASSFileAtPath:(NSString *)path
                                    frameWidth:(NSInteger)frameWidth
                                   frameHeight:(NSInteger)frameHeight
                                fontsDirectory:(nullable NSString *)fontsDirectory
                                         error:(NSError **)error
    NS_SWIFT_NAME(init(assFileAtPath:frameWidth:frameHeight:fontsDirectory:));

- (nullable SFXASSRenderOutput *)renderFrameAtTimestampMilliseconds:(NSInteger)timestampMilliseconds
                                                              error:(NSError **)error
    NS_SWIFT_NAME(renderFrame(atTimestampMilliseconds:));

@end

@interface SFXASSRenderer : NSObject

+ (NSString *)libassVersionString;

+ (nullable SFXASSRenderOutput *)renderASSFileAtPath:(NSString *)path
                                          frameWidth:(NSInteger)frameWidth
                                         frameHeight:(NSInteger)frameHeight
                               timestampMilliseconds:(NSInteger)timestampMilliseconds
                                      fontsDirectory:(nullable NSString *)fontsDirectory
                                               error:(NSError **)error
    NS_SWIFT_NAME(renderASSFile(atPath:frameWidth:frameHeight:timestampMilliseconds:fontsDirectory:));

@end

NS_ASSUME_NONNULL_END
