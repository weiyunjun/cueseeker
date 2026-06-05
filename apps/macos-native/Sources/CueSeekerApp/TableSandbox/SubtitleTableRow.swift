import Foundation

/// Row view-model for the table sandbox. Phase B feeds this from static sample
/// data; Phase C will map it from real search results / Shiori entries
/// (name = contract alias, cues = merged same-timestamp subtitle text).
struct SubtitleTableRow: Identifiable, Equatable {
    let id: Int
    let name: String
    /// Merged subtitle text for one timestamp. Bilingual entries keep one line
    /// per language, joined with "\n", so the cell wraps to multiple lines.
    let cues: String
}

enum SubtitleTableSampleData {
    static let rows: [SubtitleTableRow] = [
        SubtitleTableRow(
            id: 1,
            name: "The Shawshank Redemption (1994)",
            cues: "Hope is a good thing, maybe the best of things.\n希望是美好的，也许是人间至善。"
        ),
        SubtitleTableRow(
            id: 2,
            name: "Spirited Away",
            cues: "Once you've met someone you never really forget them.\n一度出会った人のことは忘れないものさ。"
        ),
        SubtitleTableRow(
            id: 3,
            name: "A Very Long Documentary Title That Will Not Fit On A Single Line And Must Wrap Across Several Lines",
            cues: "This is an intentionally long single-language line used to verify that the cue column wraps cleanly across multiple lines and that the row grows to fit its tallest cell while every cell stays anchored to the top."
        ),
        SubtitleTableRow(
            id: 4,
            name: "Your Name.",
            cues: "I was searching for someone.\nずっと何かを、誰かを探している。"
        ),
        SubtitleTableRow(
            id: 5,
            name: "Interstellar",
            cues: "Love is the one thing we're capable of perceiving that transcends dimensions of time and space."
        ),
        SubtitleTableRow(
            id: 6,
            name: "千と千尋の神隠し / Spirited Away (extended alias to test name wrapping behaviour)",
            cues: "Nothing that happens is ever forgotten, even if you can't remember it.\n起こったことは決して忘れない。思い出せないだけ。"
        ),
        SubtitleTableRow(
            id: 7,
            name: "Coco",
            cues: "Remember me."
        ),
        SubtitleTableRow(
            id: 8,
            name: "The Grand Budapest Hotel",
            cues: "There are still faint glimmers of civilization left in this barbaric slaughterhouse that was once known as humanity."
        ),
    ]
}
