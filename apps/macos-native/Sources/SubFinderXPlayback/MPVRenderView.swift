import AppKit
import CMpv
import OpenGL.GL3

public final class MPVRenderView: NSOpenGLView {
    private unowned let player: MPVPlayer
    private var renderContextCreated = false
    private var lastRenderError: Error?

    public init(player: MPVPlayer) {
        self.player = player

        var attributes: [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFAOpenGLProfile),
            UInt32(NSOpenGLProfileVersion3_2Core),
            UInt32(NSOpenGLPFAColorSize),
            24,
            UInt32(NSOpenGLPFAAlphaSize),
            8,
            UInt32(NSOpenGLPFADoubleBuffer),
            UInt32(NSOpenGLPFAAccelerated),
            0
        ]

        let pixelFormat = NSOpenGLPixelFormat(attributes: &attributes)
        super.init(frame: .zero, pixelFormat: pixelFormat)!

        wantsBestResolutionOpenGLSurface = true
        wantsLayer = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    public override func prepareOpenGL() {
        super.prepareOpenGL()

        guard !renderContextCreated else {
            return
        }

        openGLContext?.makeCurrentContext()

        var swapInterval: GLint = 1
        openGLContext?.setValues(&swapInterval, for: .swapInterval)

        do {
            let context = Unmanaged.passUnretained(self).toOpaque()
            try player.createOpenGLRenderContext(
                updateCallback: renderUpdateCallback,
                updateContext: context
            )
            renderContextCreated = true
        } catch {
            lastRenderError = error
        }
    }

    public override func reshape() {
        super.reshape()
        needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        openGLContext?.makeCurrentContext()

        let backingBounds = convertToBacking(bounds)
        glViewport(
            0,
            0,
            GLsizei(max(1, backingBounds.width)),
            GLsizei(max(1, backingBounds.height))
        )
        glClearColor(0, 0, 0, 1)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        if renderContextCreated {
            do {
                try player.renderOpenGL(
                    width: Int32(max(1, backingBounds.width)),
                    height: Int32(max(1, backingBounds.height))
                )
            } catch {
                lastRenderError = error
            }
        }

        openGLContext?.flushBuffer()
    }
}

private let renderUpdateCallback: mpv_render_update_fn = { context in
    guard let context else {
        return
    }

    let view = Unmanaged<MPVRenderView>
        .fromOpaque(context)
        .takeUnretainedValue()

    DispatchQueue.main.async {
        view.needsDisplay = true
    }
}
