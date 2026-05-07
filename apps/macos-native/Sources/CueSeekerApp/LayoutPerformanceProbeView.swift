import AppKit
import SwiftUI

struct LayoutPerformanceProbe: NSViewRepresentable {
    let name: String
    var thresholdMilliseconds: Double = 8

    func makeNSView(context: Context) -> LayoutPerformanceProbeNSView {
        LayoutPerformanceProbeNSView(
            name: name,
            thresholdMilliseconds: thresholdMilliseconds
        )
    }

    func updateNSView(_ nsView: LayoutPerformanceProbeNSView, context: Context) {
        nsView.name = name
        nsView.thresholdMilliseconds = thresholdMilliseconds
    }
}

final class LayoutPerformanceProbeNSView: NSView {
    var name: String
    var thresholdMilliseconds: Double

    init(name: String, thresholdMilliseconds: Double) {
        self.name = name
        self.thresholdMilliseconds = thresholdMilliseconds
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        AppPerformanceProbe.measure(name, thresholdMilliseconds: thresholdMilliseconds) {
            super.layout()
        }
    }
}
