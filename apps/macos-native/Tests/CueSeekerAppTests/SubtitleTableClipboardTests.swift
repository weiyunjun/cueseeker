import Testing
@testable import CueSeekerApp

@Test
func subtitleTableClipboardCopiesHeadersAndExpandsCueLines() {
    let columns = SubtitleTableClipboard.columns(from: [
        WorkbenchTableColumn(id: "rowNumber", title: "#", kind: .rowNumber, width: .fixed(84)),
        WorkbenchTableColumn(id: "display", title: "Display Title", kind: .text, width: .fixed(300)),
        WorkbenchTableColumn(id: "time", title: "Time", kind: .text, width: .fixed(190)),
        WorkbenchTableColumn(id: "cues", title: "Cues", kind: .text, width: .flexible(min: 580)),
    ])
    let rows = [
        SubtitleTableRow(
            id: 1,
            displayTitle: "Episode 01",
            startTime: "00:01",
            endTime: "00:02",
            cues: "line one\nline two"
        ),
        SubtitleTableRow(
            id: 2,
            displayTitle: "Episode 02",
            startTime: "00:04",
            endTime: "00:06",
            cues: "single line"
        ),
    ]

    let text = SubtitleTableClipboard.tsv(rows: rows, columns: columns)
    let expected = [
        "Display Title\tTime\tCues",
        "Episode 01\t00:01 - 00:02\tline one",
        "\t\tline two",
        "Episode 02\t00:04 - 00:06\tsingle line",
    ].joined(separator: "\n")

    #expect(text == expected)
}

@Test
func subtitleTableClipboardCopiesCrossHourTimeRangeWithFullFormat() {
    let columns = SubtitleTableClipboard.columns(from: [
        WorkbenchTableColumn(id: "time", title: "Time", kind: .text, width: .fixed(190)),
    ])
    let row = SubtitleTableRow(
        id: 1,
        displayTitle: "Episode 01",
        startTime: "15:18",
        endTime: "01:16:32",
        cues: "cue"
    )

    let text = SubtitleTableClipboard.tsv(rows: [row], columns: columns)
    let expected = [
        "Time",
        "00:15:18 - 01:16:32",
    ].joined(separator: "\n")

    #expect(text == expected)
}

@Test
func subtitleTableClipboardBuilderAppendsRows() {
    let columns = SubtitleTableClipboard.columns(from: [
        WorkbenchTableColumn(id: "display", title: "Display Title", kind: .text, width: .fixed(300)),
        WorkbenchTableColumn(id: "cues", title: "Cues", kind: .text, width: .flexible(min: 580)),
    ])
    let rows = [
        SubtitleTableRow(
            id: 1,
            displayTitle: "Episode 01",
            cues: "first\nsecond"
        ),
        SubtitleTableRow(
            id: 2,
            displayTitle: "Episode 02",
            cues: "third"
        ),
    ]

    var builder = SubtitleTableClipboard.TSVBuilder(columns: columns)
    builder.append(rows: [rows[0]])
    builder.append(rows: [rows[1]])

    let expected = [
        "Display Title\tCues",
        "Episode 01\tfirst",
        "\tsecond",
        "Episode 02\tthird",
    ].joined(separator: "\n")

    #expect(builder.text == expected)
}

@Test
func subtitleTableClipboardExpandsMultilineNonCueColumns() {
    let columns = SubtitleTableClipboard.columns(from: [
        WorkbenchTableColumn(id: "dateAdded", title: "Date Added", kind: .text, width: .fixed(190)),
        WorkbenchTableColumn(id: "display", title: "Display Title", kind: .text, width: .fixed(300)),
        WorkbenchTableColumn(id: "cues", title: "Cues", kind: .text, width: .flexible(min: 580)),
    ])
    let rows = [
        SubtitleTableRow(
            id: 1,
            dateAdded: "2026-06-29",
            displayTitle: "Main Title\nAlias Title",
            cues: "cue"
        ),
    ]

    let text = SubtitleTableClipboard.tsv(rows: rows, columns: columns)
    let expected = [
        "Date Added\tDisplay Title\tCues",
        "2026-06-29\tMain Title\tcue",
        "\tAlias Title\t",
    ].joined(separator: "\n")

    #expect(text == expected)
}

@Test
func subtitleTableClipboardCopiesVisibleTagColumnsAsText() {
    let columns = SubtitleTableClipboard.columns(from: [
        WorkbenchTableColumn(id: "speaker", title: "Speaker", kind: .text, width: .fixed(180)),
        WorkbenchTableColumn(id: "language", title: "Language", kind: .text, width: .fixed(160)),
        WorkbenchTableColumn(id: "tags", title: "Tags", kind: .text, width: .fixed(180)),
    ])
    let row = SubtitleTableRow(
        id: 1,
        displayTitle: "Episode",
        cues: "cue",
        tags: [
            WorkbenchTag(key: "ja", label: "Japanese"),
            WorkbenchTag(key: "zh-Hans", label: "Simplified Chinese"),
        ],
        speakerTags: [
            WorkbenchTag(key: "Tomori"),
            WorkbenchTag(key: "Anon"),
        ],
        shioriTags: [
            WorkbenchTag(key: "7", label: "Review", colorID: .gray),
            WorkbenchTag(key: "8", label: "Grammar", colorID: .gray),
        ]
    )

    let text = SubtitleTableClipboard.tsv(rows: [row], columns: columns)
    let expected = [
        "Speaker\tLanguage\tTags",
        "Tomori, Anon\tJapanese, Simplified Chinese\tReview, Grammar",
    ].joined(separator: "\n")

    #expect(text == expected)
}

@Test
func subtitleTableClipboardSanitizesTabsAndCarriageReturns() {
    let columns = SubtitleTableClipboard.columns(from: [
        WorkbenchTableColumn(id: "display", title: "Display\tTitle", kind: .text, width: .fixed(300)),
        WorkbenchTableColumn(id: "cues", title: "Cues", kind: .text, width: .flexible(min: 580)),
    ])
    let row = SubtitleTableRow(
        id: 1,
        displayTitle: "Episode\t01",
        cues: "first\r\nsecond\rthird"
    )

    let text = SubtitleTableClipboard.tsv(rows: [row], columns: columns)
    let expected = [
        "Display Title\tCues",
        "Episode 01\tfirst",
        "\tsecond",
        "\tthird",
    ].joined(separator: "\n")

    #expect(text == expected)
}
