import Foundation
import Testing
@testable import CueSeekerApp
@testable import CueSeekerCore

@MainActor
struct SelectionActionOverlayInvalidItemsTests {
    private func makeExcerpt(id: Int64, isValid: Bool = true) -> Excerpt {
        Excerpt(
            id: id,
            subtitlePath: "/sub.srt",
            subtitleFormat: .srt,
            videoPath: "/vid.mkv",
            videoName: "vid.mkv",
            startMilliseconds: 1000,
            endMilliseconds: 2000,
            content: "Line \(id)",
            isValid: isValid,
            createdAt: "2026-10-02"
        )
    }

    private func makeRow(id: Int, cueID: Int64, isUnavailable: Bool = false) -> SubtitleTableRow {
        SubtitleTableRow(
            id: id,
            primaryCueID: cueID,
            displayTitle: "Video",
            primaryCueText: "Line \(id)",
            cueGroupTexts: ["Line \(id)"],
            primaryGroupIndex: 0,
            cueState: isUnavailable ? .unavailable(.cueMissing) : .normal
        )
    }

    @Test
    func searchSelectionActionAllInvalidSingleRowTriggersSingularToast() {
        let toastCenter = ToastCenter()
        let selectedRows = [0]
        let row = makeRow(id: 10, cueID: 100)
        let rows = [row]
        let liveCueIDs: Set<Int64> = [] // None in library

        let validRows = rows.filter { r in
            guard let id = r.primaryCueID else { return false }
            return liveCueIDs.contains(id)
        }

        #expect(validRows.isEmpty)
        let toast = TableToastRequest.cueNotInLibrary(count: selectedRows.count)
        toastCenter.show(toast)

        #expect(toast.message == "Cue Not in Library")
        #expect(toast.icon == .warning)
        #expect(toast.duration == 3.0)
        #expect(toastCenter.visibleItems.last?.request == TableToastRequest.cueNotInLibrary)
    }

    @Test
    func searchSelectionActionAllInvalidMultipleRowsTriggersPluralToast() {
        let toastCenter = ToastCenter()
        let selectedRows = [0, 1]
        let row1 = makeRow(id: 10, cueID: 100)
        let row2 = makeRow(id: 11, cueID: 101)
        let rows = [row1, row2]
        let liveCueIDs: Set<Int64> = [] // None in library

        let validRows = rows.filter { r in
            guard let id = r.primaryCueID else { return false }
            return liveCueIDs.contains(id)
        }

        #expect(validRows.isEmpty)
        let toast = TableToastRequest.cueNotInLibrary(count: selectedRows.count)
        toastCenter.show(toast)

        #expect(toast.message == "Cues Not in Library")
        #expect(toast.icon == .warning)
        #expect(toast.duration == 3.0)
        #expect(toastCenter.visibleItems.last?.request == TableToastRequest.cuesNotInLibrary)
    }

    @Test
    func searchSelectionActionPartiallyInvalidFiltersToValidRowsOnly() {
        let selectedRows = [0, 1]
        let row1 = makeRow(id: 10, cueID: 100)
        let row2 = makeRow(id: 11, cueID: 101)
        let rows = [row1, row2]
        let liveCueIDs: Set<Int64> = [101] // Only row2 is live

        let validRows = rows.filter { r in
            guard let id = r.primaryCueID else { return false }
            return liveCueIDs.contains(id)
        }

        #expect(validRows.count == 1)
        #expect(validRows.first?.id == 11)
        // Selection remains untouched
        #expect(selectedRows == [0, 1])
    }

    @Test
    func excerptSelectionActionAllInvalidSingleRowTriggersSingularToast() {
        let toastCenter = ToastCenter()
        let selectedRows = [0]
        let excerpt = makeExcerpt(id: 50, isValid: true)
        let row = makeRow(id: 50, cueID: 500)
        let excerptsByEntryID = [50: excerpt]
        let validExcerptIDs: Set<Int64> = [] // None in library

        let validRows = [row].filter { r in
            guard !r.cueState.isUnavailable,
                  let exc = excerptsByEntryID[r.id],
                  exc.isValid,
                  validExcerptIDs.contains(Int64(r.id))
            else {
                return false
            }
            return true
        }

        #expect(validRows.isEmpty)
        let toast = TableToastRequest.cueNotInLibrary(count: selectedRows.count)
        toastCenter.show(toast)

        #expect(toast.message == "Cue Not in Library")
        #expect(toastCenter.visibleItems.last?.request == TableToastRequest.cueNotInLibrary)
    }

    @Test
    func excerptSelectionActionAllInvalidMultipleRowsTriggersPluralToast() {
        let toastCenter = ToastCenter()
        let selectedRows = [0, 1]
        let exc1 = makeExcerpt(id: 51, isValid: true)
        let exc2 = makeExcerpt(id: 52, isValid: false)
        let row1 = makeRow(id: 51, cueID: 501)
        let row2 = makeRow(id: 52, cueID: 502)
        let excerptsByEntryID = [51: exc1, 52: exc2]
        let validExcerptIDs: Set<Int64> = [] // Neither in library

        let validRows = [row1, row2].filter { r in
            guard !r.cueState.isUnavailable,
                  let exc = excerptsByEntryID[r.id],
                  exc.isValid,
                  validExcerptIDs.contains(Int64(r.id))
            else {
                return false
            }
            return true
        }

        #expect(validRows.isEmpty)
        let toast = TableToastRequest.cueNotInLibrary(count: selectedRows.count)
        toastCenter.show(toast)

        #expect(toast.message == "Cues Not in Library")
        #expect(toastCenter.visibleItems.last?.request == TableToastRequest.cuesNotInLibrary)
    }

    @Test
    func excerptSelectionActionPartiallyInvalidFiltersToValidRowsOnly() {
        let selectedRows = [0, 1]
        let exc1 = makeExcerpt(id: 51, isValid: true)
        let exc2 = makeExcerpt(id: 52, isValid: true)
        let row1 = makeRow(id: 51, cueID: 501)
        let row2 = makeRow(id: 52, cueID: 502)
        let excerptsByEntryID = [51: exc1, 52: exc2]
        let validExcerptIDs: Set<Int64> = [52] // Only exc2 is in library

        let validRows = [row1, row2].filter { r in
            guard !r.cueState.isUnavailable,
                  let exc = excerptsByEntryID[r.id],
                  exc.isValid,
                  validExcerptIDs.contains(Int64(r.id))
            else {
                return false
            }
            return true
        }

        #expect(validRows.count == 1)
        #expect(validRows.first?.id == 52)
        #expect(selectedRows == [0, 1])
    }

    @Test
    func searchCopyTableCopiesAllSelectedRowsRegardlessOfValidity() {
        let toastCenter = ToastCenter()
        let selectedRows = [0, 1]
        let row1 = makeRow(id: 10, cueID: 100)
        let row2 = makeRow(id: 11, cueID: 101)
        let rows = [row1, row2]

        // Copy Table does not filter by library presence
        let columns = SubtitleTableClipboard.columns(from: SchemaWorkbenchSearchDefaults.columns)
        var builder = SubtitleTableClipboard.TSVBuilder(columns: columns)
        builder.append(rows: rows)
        toastCenter.show(TableToastRequest.copyTable)

        #expect(!builder.representations.isEmpty)
        #expect(toastCenter.visibleItems.last?.request == TableToastRequest.copyTable)
        #expect(selectedRows == [0, 1])
    }

    @Test
    func excerptCopyTableCopiesAllSelectedRowsRegardlessOfValidity() {
        let toastCenter = ToastCenter()
        let selectedRows = [0, 1]
        let row1 = makeRow(id: 20, cueID: 200, isUnavailable: true)
        let row2 = makeRow(id: 21, cueID: 201)
        let rows = [row1, row2]

        // Copy Table does not filter by validity/library presence
        let columns = SubtitleTableClipboard.columns(from: SchemaWorkbenchSearchDefaults.excerptColumns)
        var builder = SubtitleTableClipboard.TSVBuilder(columns: columns)
        builder.append(rows: rows)
        toastCenter.show(TableToastRequest.copyTable)

        #expect(!builder.representations.isEmpty)
        #expect(toastCenter.visibleItems.last?.request == TableToastRequest.copyTable)
        #expect(selectedRows == [0, 1])
    }
}

