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
    private static let base: [(name: String, cues: String)] = [
        (
            "The Shawshank Redemption (1994)",
            "Hope is a good thing, maybe the best of things.\n希望是美好的，也许是人间至善。"
        ),
        (
            "Spirited Away",
            "Once you've met someone you never really forget them.\n一度出会った人のことは忘れないものさ。"
        ),
        (
            "A Very Long Documentary Title That Will Not Fit On A Single Line And Must Wrap Across Several Lines",
            "This is an intentionally long single-language line used to verify that the cue column wraps cleanly across multiple lines and that the row grows to fit its tallest cell while every cell stays anchored to the top."
        ),
        (
            "Your Name.",
            "I was searching for someone.\nずっと何かを、誰かを探している。"
        ),
        (
            "Interstellar",
            "Love is the one thing we're capable of perceiving that transcends dimensions of time and space."
        ),
        (
            "千と千尋の神隠し / Spirited Away (extended alias to test name wrapping behaviour)",
            "Nothing that happens is ever forgotten, even if you can't remember it.\n起こったことは決して忘れない。思い出せないだけ。"
        ),
        (
            "Coco",
            "Remember me."
        ),
        (
            "The Grand Budapest Hotel",
            "There are still faint glimmers of civilization left in this barbaric slaughterhouse that was once known as humanity."
        ),
    ]

    /// The 8 base rows repeated 10 times (80 rows) so the sandbox has enough
    /// content to test scrolling and drag auto-scroll. Ids are sequential.
    static let rows: [SubtitleTableRow] = {
        var result: [SubtitleTableRow] = []
        var id = 1
        for _ in 0..<10 {
            for entry in base {
                result.append(SubtitleTableRow(id: id, name: entry.name, cues: entry.cues))
                id += 1
            }
        }
        return result
    }()
}
