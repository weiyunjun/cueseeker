#import "SFXNativePlaybackInternal.h"

@implementation SFXNativePlaybackView {
    AVSampleBufferDisplayLayer *_displayLayer;
    NSUInteger _displayImageRemovalCount;
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

    return self;
}

- (AVSampleBufferDisplayLayer *)displayLayer {
    return _displayLayer;
}

- (void)layout {
    [super layout];

    [self updateDisplayLayerFrameWithLogName:@"SFXNativePlaybackView.layout"];
}

- (void)updateDisplayLayerFrameWithLogName:(NSString *)logName {
    CFTimeInterval start = SFXPerformanceNow();
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _displayLayer.frame = self.bounds;
    [_displayLayer setNeedsLayout];
    [_displayLayer layoutIfNeeded];
    [CATransaction commit];
    SFXLogIfSlow(logName, start, 8);
}

- (void)flush {
    CFTimeInterval start = SFXPerformanceNow();
    [_displayLayer flushAndRemoveImage];
    @synchronized (self) {
        _displayImageRemovalCount += 1;
    }
    SFXLogIfSlow(@"SFXNativePlaybackView.flush", start, 16);
}

- (NSUInteger)displayImageRemovalCount {
    @synchronized (self) {
        return _displayImageRemovalCount;
    }
}

@end

@implementation SFXNativePlaybackFrameSnapshot {
    CVPixelBufferRef _pixelBuffer;
}

- (instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    _pixelBuffer = CVPixelBufferRetain(pixelBuffer);
    return self;
}

- (void)dealloc {
    if (_pixelBuffer != NULL) {
        CVPixelBufferRelease(_pixelBuffer);
        _pixelBuffer = NULL;
    }
}

- (CVPixelBufferRef)pixelBuffer {
    return _pixelBuffer;
}

- (NSInteger)width {
    return SFXDisplayVideoWidthForPixelBuffer(_pixelBuffer);
}

- (NSInteger)height {
    return _pixelBuffer == NULL ? 0 : (NSInteger)CVPixelBufferGetHeight(_pixelBuffer);
}

@end
