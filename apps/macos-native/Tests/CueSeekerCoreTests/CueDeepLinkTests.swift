import Testing
@testable import CueSeekerCore

@Test
func cueDeepLinkNormalizesLineBreaksAndEscapesMarkdownLabel() {
    let lineBreakText = [
        "  first  ",
        "second",
        "",
        "third",
        "fourth",
        "fifth",
        "sixth",
        "seventh  ",
    ].joined(separator: "\r\n")
        + "\rthird-cr\u{000B}third-vt\u{000C}third-ff\u{0085}third-nel"
        + "\u{2028}third-ls\u{2029}third-ps"

    #expect(
        CueDeepLink.markdownLink(cueText: lineBreakText, cueID: 42)
            == "[first second third fourth fifth sixth seventh third-cr third-vt third-ff third-nel third-ls third-ps](cueseeker://cue?id=42)"
    )
    #expect(
        CueDeepLink.markdownLink(
            cueText: "slash\\ brackets[] angle<> emphasis*_ code` strike~ entity& pipe|",
            cueID: 42
        )
            == "[slash\\\\ brackets\\[\\] angle\\<\\> emphasis\\*\\_ code\\` strike\\~ entity\\& pipe\\|](cueseeker://cue?id=42)"
    )
    #expect(
        CueDeepLink.markdownLink(
            cueText: " \t\u{00A0}\r\n\u{3000} ",
            cueID: 42
        )
            == "[Cue #42](cueseeker://cue?id=42)"
    )
    #expect(CueDeepLink.markdownLink(cueText: "cue", cueID: 0) == nil)
}

@Test
func cueDeepLinksPreserveInputOrderAndRejectPartialOutput() {
    #expect(
        CueDeepLink.markdownLinks([
            ("second\nline", 2),
            ("first", 1),
        ])
            == """
            [second line](cueseeker://cue?id=2)
            [first](cueseeker://cue?id=1)
            """
    )
    #expect(CueDeepLink.markdownLinks([]) == nil)
    #expect(
        CueDeepLink.markdownLinks([
            ("valid", 1),
            ("invalid", 0),
        ]) == nil
    )
}
