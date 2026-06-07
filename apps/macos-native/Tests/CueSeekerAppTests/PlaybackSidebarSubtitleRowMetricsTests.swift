import Testing
@testable import CueSeekerApp

@Test
func playbackSubtitleSidebarRowHeightExpandsForMultipleLines() {
    let singleLineHeight = PlaybackSidebarSubtitleRowMetrics.rowHeight(
        forDisplayLines: ["大丈夫"],
        rowWidth: 284
    )
    let bilingualHeight = PlaybackSidebarSubtitleRowMetrics.rowHeight(
        forDisplayLines: ["大丈夫", "I'm okay."],
        rowWidth: 284
    )

    #expect(singleLineHeight >= PlaybackSidebarSubtitleRowMetrics.minimumRowHeight)
    #expect(bilingualHeight > singleLineHeight)
}

@Test
func playbackSubtitleSidebarRowHeightExpandsForWrappedText() {
    let longLine = "これは横幅が狭い字幕リストで折り返される長い字幕テキストです"
    let wideHeight = PlaybackSidebarSubtitleRowMetrics.rowHeight(
        forDisplayLines: [longLine],
        rowWidth: 284
    )
    let narrowHeight = PlaybackSidebarSubtitleRowMetrics.rowHeight(
        forDisplayLines: [longLine],
        rowWidth: 120
    )

    #expect(narrowHeight > wideHeight)
}
