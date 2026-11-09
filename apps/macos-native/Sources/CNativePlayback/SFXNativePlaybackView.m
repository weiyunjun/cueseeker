#import "SFXNativePlaybackInternal.h"

@implementation SFXNativePlaybackView {
    AVSampleBufferDisplayLayer *_displayLayer;
    NSUInteger _displayImageRemovalCount;
    SFXVideoOrientation _videoOrientation;
    BOOL _isStreamHDR;
    BOOL _isDisplayHDRActive;
    CGFloat _displayEDRHeadroom;
    void (^_displayHDRStateDidChangeHandler)(BOOL isHDRActive, CGFloat edrHeadroom);
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self == nil) {
        return nil;
    }

    _videoOrientation = SFXVideoOrientationUp;
    _isStreamHDR = NO;
    _displayEDRHeadroom = 1.0;
    _isDisplayHDRActive = NO;
    self.wantsLayer = YES;
    self.layer.backgroundColor = NSColor.blackColor.CGColor;

    _displayLayer = [AVSampleBufferDisplayLayer layer];
    _displayLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    _displayLayer.backgroundColor = NSColor.blackColor.CGColor;
    [self.layer addSublayer:_displayLayer];

    [self refreshDisplayEDRStateNotifyingChange:NO];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(handleScreenOrWindowDidChange:)
                                               name:NSApplicationDidChangeScreenParametersNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(handleScreenOrWindowDidChange:)
                                               name:NSWindowDidChangeScreenNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(handleScreenOrWindowDidChange:)
                                               name:NSWindowDidChangeBackingPropertiesNotification
                                             object:nil];

    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self refreshDisplayEDRStateNotifyingChange:YES];
}

- (void)viewDidChangeBackingProperties {
    [super viewDidChangeBackingProperties];
    [self refreshDisplayEDRStateNotifyingChange:YES];
}

- (void)handleScreenOrWindowDidChange:(NSNotification *)notification {
    (void)notification;
    [self refreshDisplayEDRStateNotifyingChange:YES];
}

- (void)refreshDisplayEDRStateNotifyingChange:(BOOL)notifyChange {
    NSScreen *screen = self.window.screen ?: NSScreen.mainScreen ?: NSScreen.screens.firstObject;
    CGFloat maxEDR = (screen != nil) ? screen.maximumExtendedDynamicRangeColorComponentValue : 1.0;
    if (!isfinite(maxEDR) || maxEDR < 1.0) {
        maxEDR = 1.0;
    }
    BOOL displaySupportsHDR = (maxEDR > 1.01);
    BOOL stateChanged = NO;
    BOOL wantsEDR = NO;
    void (^handler)(BOOL, CGFloat) = nil;

    @synchronized (self) {
        if (_isDisplayHDRActive != displaySupportsHDR || fabs(_displayEDRHeadroom - maxEDR) > 0.05) {
            _isDisplayHDRActive = displaySupportsHDR;
            _displayEDRHeadroom = maxEDR;
            stateChanged = YES;
        }
        wantsEDR = (_isDisplayHDRActive && _isStreamHDR);
        handler = [_displayHDRStateDidChangeHandler copy];
    }

    void (^applyLayerEDR)(void) = ^{
        if (@available(macOS 14.0, *)) {
            if (self->_displayLayer.wantsExtendedDynamicRangeContent != wantsEDR) {
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                self->_displayLayer.wantsExtendedDynamicRangeContent = wantsEDR;
                [CATransaction commit];
            }
        }
    };
    if (NSThread.isMainThread) {
        applyLayerEDR();
    } else {
        dispatch_async(dispatch_get_main_queue(), applyLayerEDR);
    }

    if (notifyChange && stateChanged && handler != nil) {
        handler(displaySupportsHDR, maxEDR);
    }
}

- (BOOL)isDisplayHDRActive {
    @synchronized (self) {
        return _isDisplayHDRActive;
    }
}

- (CGFloat)displayEDRHeadroom {
    @synchronized (self) {
        return _displayEDRHeadroom;
    }
}

- (void (^)(BOOL, CGFloat))displayHDRStateDidChangeHandler {
    @synchronized (self) {
        return _displayHDRStateDidChangeHandler;
    }
}

- (void)setDisplayHDRStateDidChangeHandler:(void (^)(BOOL, CGFloat))displayHDRStateDidChangeHandler {
    @synchronized (self) {
        _displayHDRStateDidChangeHandler = [displayHDRStateDidChangeHandler copy];
    }
}

- (void)updateForStreamHDRState:(BOOL)isHDRStream {
    @synchronized (self) {
        _isStreamHDR = isHDRStream;
    }
    if (NSThread.isMainThread) {
        [self refreshDisplayEDRStateNotifyingChange:NO];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshDisplayEDRStateNotifyingChange:NO];
        });
    }
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
