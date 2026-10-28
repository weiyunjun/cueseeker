#import "SFXNativePlaybackInternal.h"

@implementation SFXNativePlaybackView {
    AVSampleBufferDisplayLayer *_displayLayer;
    NSUInteger _displayImageRemovalCount;
    SFXVideoOrientation _videoOrientation;
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self == nil) {
        return nil;
    }

    _videoOrientation = SFXVideoOrientationUp;
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

- (SFXVideoOrientation)videoOrientation {
    @synchronized (self) {
        return _videoOrientation;
    }
}

- (void)setVideoOrientation:(SFXVideoOrientation)videoOrientation {
    SFXVideoOrientation sanitized = (videoOrientation >= SFXVideoOrientationUp && videoOrientation <= SFXVideoOrientationLeft)
        ? videoOrientation
        : SFXVideoOrientationUp;
    BOOL changed = NO;
    @synchronized (self) {
        if (_videoOrientation != sanitized) {
            _videoOrientation = sanitized;
            changed = YES;
        }
    }
    if (!changed) {
        return;
    }
    if (NSThread.isMainThread) {
        [self updateDisplayLayerFrameWithLogName:@"SFXNativePlaybackView.setVideoOrientation"];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateDisplayLayerFrameWithLogName:@"SFXNativePlaybackView.setVideoOrientation"];
        });
    }
}

- (void)layout {
    [super layout];

    [self updateDisplayLayerFrameWithLogName:@"SFXNativePlaybackView.layout"];
}

- (void)updateDisplayLayerFrameWithLogName:(NSString *)logName {
    CFTimeInterval start = SFXPerformanceNow();
    NSRect viewBounds = self.bounds;
    CGFloat width = NSWidth(viewBounds);
    CGFloat height = NSHeight(viewBounds);
    SFXVideoOrientation orientation = self.videoOrientation;
    BOOL swapsDimensions = SFXVideoOrientationSwapsDimensions(orientation);
    CGRect layerBounds = swapsDimensions
        ? CGRectMake(0.0, 0.0, height, width)
        : CGRectMake(0.0, 0.0, width, height);
    CGPoint center = CGPointMake(NSMidX(viewBounds), NSMidY(viewBounds));
    CGAffineTransform transform = SFXLayerAffineTransformForVideoOrientation(orientation);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _displayLayer.affineTransform = CGAffineTransformIdentity;
    _displayLayer.bounds = layerBounds;
    _displayLayer.position = center;
    _displayLayer.affineTransform = transform;
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
    return SFXDisplayVideoHeightForPixelBuffer(_pixelBuffer);
}

@end
