import AppKit
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func subtitleTextLayoutCapsBodyTextAtSixLines() {
    let text = (0..<20)
        .map { "line \($0)" }
        .joined(separator: "\n")
    let attributed = SubtitleTableText.body(text)

    let uncapped = SubtitleTextLayout(maximumNumberOfLines: 0)
    uncapped.update(attributedString: attributed, width: 400)

    let capped = SubtitleTextLayout()
    capped.update(attributedString: attributed, width: 400)

    let sevenLinesCapped = SubtitleTextLayout()
    sevenLinesCapped.update(
        attributedString: SubtitleTableText.body(
            (0..<(SubtitleTableMetrics.maximumBodyLineCount + 1))
                .map { "line \($0)" }
                .joined(separator: "\n")
        ),
        width: 400
    )

    #expect(capped.usedHeight < uncapped.usedHeight)
    #expect(capped.usedHeight == sevenLinesCapped.usedHeight)
}

@MainActor
@Test
func subtitleTextLayoutLeavesShortBodyTextUncapped() {
    let text = "line one\nline two"
    let attributed = SubtitleTableText.body(text)

    let uncapped = SubtitleTextLayout(maximumNumberOfLines: 0)
    uncapped.update(attributedString: attributed, width: 400)

    let capped = SubtitleTextLayout()
    capped.update(attributedString: attributed, width: 400)

    #expect(capped.usedHeight == uncapped.usedHeight)
}
