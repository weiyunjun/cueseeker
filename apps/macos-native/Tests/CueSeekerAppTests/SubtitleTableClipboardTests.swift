import AppKit
import Testing
@testable import CueSeekerApp

@Test
func subtitleTableClipboardCopiesHeadersAndPreservesMultilineCueCell() {
    let columns = SubtitleTableClipboard.columns(from: [
        WorkbenchTableColumn(id: "rowNumber", title: "#", kind: .rowNumber, width: .fixed(84)),
        WorkbenchTableColumn(id: "display", title: "Display Title", kind: .text, width: .fixed(300)),
        WorkbenchTableColumn(id: "time", title: "Time Range", kind: .text, width: .fixed(190)),
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
        "Display Title\tTime Range\tCues",
        "Episode 01\t00:01 - 00:02\t\"line one\nline two\"",
        "Episode 02\t00:04 - 00:06\tsingle line",
    ].joined(separator: "\n")

    #expect(text == expected)
}

@Test
func subtitleTableClipboardCopiesCrossHourTimeRangeWithFullFormat() {
    let columns = SubtitleTableClipboard.columns(from: [
        WorkbenchTableColumn(id: "time", title: "Time Range", kind: .text, width: .fixed(190)),
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
        "Time Range",
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
        "Episode 01\t\"first\nsecond\"",
        "Episode 02\tthird",
    ].joined(separator: "\n")

    #expect(builder.text == expected)
}

@Test
func subtitleTableClipboardPreservesMultilineNonCueCell() {
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
        "2026-06-29\t\"Main Title\nAlias Title\"\tcue",
    ].joined(separator: "\n")

    #expect(text == expected)
}

@Test
func subtitleTableClipboardCopiesVisibleLanguageColumnAsText() {
    let columns = SubtitleTableClipboard.columns(from: [
        WorkbenchTableColumn(id: "language", title: "Language", kind: .text, width: .fixed(160)),
    ])
    let row = SubtitleTableRow(
        id: 1,
        displayTitle: "Episode",
        cues: "cue",
        tags: [
            WorkbenchTag(key: "ja", label: "Japanese"),
            WorkbenchTag(key: "zh-Hans", label: "Simplified Chinese"),
        ]
    )

    let text = SubtitleTableClipboard.tsv(rows: [row], columns: columns)
    let expected = [
        "Language",
        "Japanese, Simplified Chinese",
    ].joined(separator: "\n")

    #expect(text == expected)
}

@Test
func subtitleTableClipboardQuotesTabsAndNormalizesCarriageReturns() {
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
        "\"Display\tTitle\"\tCues",
        "\"Episode\t01\"\t\"first\nsecond\nthird\"",
    ].joined(separator: "\n")

    #expect(text == expected)
}

@Test
func subtitleTableClipboardAlwaysUsesCompletePrimaryCueInsteadOfCueGroup() {
    let columns = SubtitleTableClipboard.columns(from: [
        WorkbenchTableColumn(id: "cues", title: "Cues", kind: .text, width: .flexible(min: 580)),
    ])
    let longLine = String(repeating: "x", count: 520)
    let primaryLines = [
        "primary line 0",
        "",
        longLine,
        "primary line 3",
        "primary line 4",
        "primary line 5",
        "primary line 6",
        "primary line 7",
    ]
    let primaryText = primaryLines.joined(separator: "\n")
    let row = SubtitleTableRow(
        id: 1,
        displayTitle: "Episode 01",
        primaryCueText: primaryText,
        cueGroupTexts: ["extra upper", primaryText, "extra lower"],
        primaryGroupIndex: 1
    )

    let text = SubtitleTableClipboard.tsv(rows: [row], columns: columns)

    #expect(text == "Cues\n\"\(primaryText)\"")
    #expect(!text.contains("extra upper"))
    #expect(!text.contains("extra lower"))
}

@Test
func subtitleTableClipboardRepresentationsPreserveGridAndEscapeContent() {
    var builder = SubtitleTableClipboard.RepresentationBuilder()
    builder.append(cells: ["Cues", "Tags"], isHeader: true)
    builder.append(cells: ["<first>\r\nsecond & \"third\"", "A\tB"])

    let representations = builder.representations

    #expect(
        representations.tabularText
            == "Cues\tTags\n\"<first>\nsecond & \"\"third\"\"\"\t\"A\tB\""
    )
    #expect(representations.plainText == representations.tabularText)
    #expect(
        representations.html.contains(
            "<th style=\"mso-number-format:'\\@';white-space:pre-wrap\">Cues</th>"
        )
    )
    #expect(representations.html.contains("&lt;first&gt;<br>second &amp; &quot;third&quot;"))
    #expect(representations.html.contains("A&#9;B"))
    #expect(representations.html.components(separatedBy: "<tr>").count - 1 == 2)
}

@Test
func subtitleTableClipboardWritesOnePasteboardItemWithAllRepresentations() throws {
    var builder = SubtitleTableClipboard.RepresentationBuilder()
    builder.append(cells: ["Cues"], isHeader: true)
    builder.append(cells: ["first\nsecond"])
    let representations = builder.representations
    let pasteboard = NSPasteboard(name: .init("SubtitleTableClipboard-\(UUID().uuidString)"))
    defer { pasteboard.clearContents() }

    #expect(SubtitleTableClipboard.copy(representations: representations, to: pasteboard))
    let item = try #require(pasteboard.pasteboardItems?.first)

    #expect(pasteboard.pasteboardItems?.count == 1)
    #expect(item.string(forType: .html) == representations.html)
    #expect(item.string(forType: .tabularText) == representations.tabularText)
    #expect(item.string(forType: .string) == representations.plainText)
}

@Test
func subtitleTableTextCopyPreservesAbsoluteColumnsForPartialCrossRowSelection() {
    let columns = [
        SubtitleTableTextCopyColumn(id: "display", title: "Display Title"),
        SubtitleTableTextCopyColumn(id: "cues", title: "Cues"),
        SubtitleTableTextCopyColumn(id: "time", title: "Time Range"),
    ]
    let rows = [
        SubtitleTableRow(
            id: 1,
            displayTitle: "Episode 01",
            startTime: "00:01",
            endTime: "00:02",
            cues: "first cue"
        ),
        SubtitleTableRow(
            id: 2,
            displayTitle: "Episode 02",
            startTime: "00:03",
            endTime: "00:04",
            cues: "second cue"
        ),
    ]
    var selection = SubtitleTableTextSelectionState()
    selection.begin(at: SubtitleTableTextPosition(
        row: .body(0),
        columnIndex: 1,
        utf16Offset: 3
    ))
    selection.updateFocus(to: SubtitleTableTextPosition(
        row: .body(1),
        columnIndex: 0,
        utf16Offset: 7
    ))
    let request = SubtitleTableTextCopyRequest(
        selection: selection,
        columns: columns,
        rowCount: rows.count,
        showsCueGroup: false
    )
    var builder = SubtitleTableTextCopyBuilder(request: request)
    builder.append(rows: rows, startingAt: 0)

    #expect(
        builder.representations.tabularText
            == "\tst cue\t00:01 - 00:02\nEpisode\t\t"
    )
}

@Test
func subtitleTableTextCopySelectAllIncludesHeaderAndDisplayedCueGroup() {
    let columns = [
        SubtitleTableTextCopyColumn(id: "display", title: "Display Title"),
        SubtitleTableTextCopyColumn(id: "cues", title: "Cues"),
    ]
    let primary = "primary\nline"
    let row = SubtitleTableRow(
        id: 1,
        displayTitle: "Episode",
        primaryCueText: primary,
        cueGroupTexts: ["extra", primary],
        primaryGroupIndex: 1
    )
    var selection = SubtitleTableTextSelectionState()
    selection.selectAll()
    let request = SubtitleTableTextCopyRequest(
        selection: selection,
        columns: columns,
        rowCount: 1,
        showsCueGroup: true
    )
    var builder = SubtitleTableTextCopyBuilder(request: request)
    builder.append(rows: [row], startingAt: 0)

    #expect(
        builder.representations.tabularText
            == "Display Title\tCues\nEpisode\t\"primary\nline\nextra\""
    )
}

@Test
func subtitleTableTextCopyHeaderRangeAndEmojiStayStructurallySafe() {
    let columns = [
        SubtitleTableTextCopyColumn(id: "display", title: "Display Title"),
        SubtitleTableTextCopyColumn(id: "cues", title: "Cues"),
    ]
    var selection = SubtitleTableTextSelectionState()
    selection.begin(at: SubtitleTableTextPosition(
        row: .header,
        columnIndex: 0,
        utf16Offset: 8
    ))
    selection.updateFocus(to: SubtitleTableTextPosition(
        row: .body(0),
        columnIndex: 0,
        utf16Offset: 2
    ))
    let request = SubtitleTableTextCopyRequest(
        selection: selection,
        columns: columns,
        rowCount: 1,
        showsCueGroup: false
    )
    let row = SubtitleTableRow(id: 1, displayTitle: "😀A", cues: "cue")
    var builder = SubtitleTableTextCopyBuilder(request: request)
    builder.append(rows: [row], startingAt: 0)

    #expect(builder.representations.tabularText == "Title\tCues\n😀\t")
    #expect(builder.representations.html.contains("<th"))
    #expect(builder.representations.html.contains("<td"))
}
