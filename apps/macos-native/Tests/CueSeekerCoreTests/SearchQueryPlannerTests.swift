import Testing
@testable import CueSeekerCore

@Test
func searchQueryPlannerBuildsCharacterExpandedLiteralFTSPlan() throws {
    let plan = try #require(SearchQueryPlanner.plan(for: "  Mag  "))

    #expect(plan.ftsQuery == "\"m a g\"")
    #expect(SearchQueryPlanner.matchRuleName(plan.lineMatchRule) == "literalSubstring")
    #expect(SearchQueryPlanner.matches("magic circle", rule: plan.lineMatchRule))
    #expect(SearchQueryPlanner.matches("image", rule: plan.lineMatchRule))
}

@Test
func searchQueryPlannerSplitsWhitespaceSegmentsWithANDAndRequiresExactNormalizedSubstring() throws {
    let plan = try #require(SearchQueryPlanner.plan(for: "alpha　beta"))

    #expect(plan.ftsQuery == "\"a l p h a\" AND \"b e t a\"")
    #expect(SearchQueryPlanner.matches("alpha beta", rule: plan.lineMatchRule))
    #expect(SearchQueryPlanner.matches("alpha\n  beta", rule: plan.lineMatchRule))
    #expect(!SearchQueryPlanner.matches("alpha middle beta", rule: plan.lineMatchRule))
    #expect(!SearchQueryPlanner.matches("beta then alpha", rule: plan.lineMatchRule))
}

@Test
func searchQueryPlannerSegmentsCJKAndMatchesOriginalText() throws {
    let plan = try #require(SearchQueryPlanner.plan(for: "一級"))

    #expect(plan.ftsQuery == "\"一 級\"")
    #expect(SearchQueryPlanner.matches("一級試験", rule: plan.lineMatchRule))
    #expect(!SearchQueryPlanner.matches("一级试验", rule: plan.lineMatchRule))
}

@Test
func searchQueryPlannerTreatsOperatorsQuotesAndAsteriskAsLiteralCharacters() throws {
    let quoted = try #require(SearchQueryPlanner.plan(for: "\"hello\""))
    #expect(quoted.ftsQuery == "\"\"\" h e l l o \"\"\"")
    #expect(SearchQueryPlanner.matches("He said \"hello\" to me.", rule: quoted.lineMatchRule))
    #expect(SearchQueryPlanner.matches("He said “hello” to me.", rule: quoted.lineMatchRule))
    #expect(!SearchQueryPlanner.matches("He said hello to me.", rule: quoted.lineMatchRule))

    let withAND = try #require(SearchQueryPlanner.plan(for: "煎菜饼 AND 米饭"))
    #expect(withAND.ftsQuery == "\"煎 菜 饼\" AND \"a n d\" AND \"米 饭\"")
    #expect(SearchQueryPlanner.matches("关西人果然还是煎菜饼 AND 米饭", rule: withAND.lineMatchRule))
    #expect(!SearchQueryPlanner.matches("关西人果然还是煎菜饼 米饭", rule: withAND.lineMatchRule))

    let withAsterisk = try #require(SearchQueryPlanner.plan(for: "Pastel*Palettes"))
    #expect(withAsterisk.ftsQuery == "\"p a s t e l * p a l e t t e s\"")
    #expect(SearchQueryPlanner.matches("睦喜欢Pastel*Palettes的歌对吧", rule: withAsterisk.lineMatchRule))
    #expect(SearchQueryPlanner.matches("睦は　Ｐａｓｔｅｌ＊Ｐａｌｅｔｔｅｓでしたっけ", rule: withAsterisk.lineMatchRule))
}

@Test
func searchQueryPlannerExtractsUniqueNormalizedSingleCharacterVocabularyTerms() {
    #expect(
        SearchQueryPlanner.vocabularyTerms(in: "Shared AND shared 一級 〜 ⋯")
            == ["s", "h", "a", "r", "e", "d", "n", "一", "級", "~", "."]
    )
}

@Test
func searchQueryPlannerNormalizationAndFastPathHandleAllCompatibilityAndPunctuationRules() {
    // Compatibility forms + halfwidth katakana voiced mark canonical composition (#01-#21)
    #expect(SearchQueryPlanner.normalizeQuery("…") == "...")
    #expect(SearchQueryPlanner.normalizeQuery("⋯") == "...")
    #expect(SearchQueryPlanner.normalizeQuery("〜") == "~")
    #expect(SearchQueryPlanner.normalizeQuery("～") == "~")
    #expect(SearchQueryPlanner.normalizeQuery("‘’“”") == "''\"\"")
    #expect(SearchQueryPlanner.normalizeQuery("‘a’ “b”") == "'a' \"b\"")
    #expect(SearchQueryPlanner.normalizeQuery("ｱｲ･ﾜｽﾞ･ｻﾞ･ｽﾁｭｰﾃﾞﾝﾄ") == "アイ・ワズ・ザ・スチューデント")
    #expect(SearchQueryPlanner.normalizeQuery("｢家賃") == "「家賃")
    #expect(SearchQueryPlanner.normalizeQuery("①② x² 第Ⅱ章") == "12 x2 第ii章")
    #expect(SearchQueryPlanner.normalizeQuery("３万円 ｓｕｍｉｍｉ ！ ＊") == "3万円 sumimi ! *")
    #expect(SearchQueryPlanner.normalizeQuery("  \u{3000}\u{00A0}\t\r\n  ") == "")
    #expect(SearchQueryPlanner.normalizeText("a\r\n　\u{00A0}\tb") == "a b")

    // Language distinctions preserved (#22-#25, #31-#33, #70-#71)
    #expect(SubtitleSearchQueryMatcher.matches("ありがとう", query: "ありかとう") == false)
    #expect(SubtitleSearchQueryMatcher.matches("やっぱり", query: "やつはり") == false)
    #expect(SubtitleSearchQueryMatcher.matches("ありがとうございます", query: "アリガトウ") == false)
    #expect(SubtitleSearchQueryMatcher.matches("一級試験", query: "一级试验") == false)
    #expect(SubtitleSearchQueryMatcher.matches("Ma Mère l'Oye", query: "Mère") == true)
    #expect(SubtitleSearchQueryMatcher.matches("Ma Mère l'Oye", query: "Mere") == false)
    #expect(SubtitleSearchQueryMatcher.matches("lässt", query: "lasst") == false)
    #expect(SubtitleSearchQueryMatcher.matches("他说“二楼的楼震太剧烈了”", query: "\"二楼") == true)
    #expect(SubtitleSearchQueryMatcher.matches("「家賃一万円アップするぞ」", query: "\"家賃") == false)

    // Un-precomposed grapheme cluster boundary protection
    #expect(SubtitleSearchQueryMatcher.matches("x\u{0302}y", query: "x") == false)
    #expect(SubtitleSearchQueryMatcher.matches("x\u{0302} and x", query: "x") == true)
    #expect(SubtitleSearchQueryMatcher.matches("x\u{0302}y", query: "x\u{0302}") == true)
    #expect(SubtitleSearchQueryMatcher.matches("あ\u{3099}", query: "あ") == false)
    #expect(SubtitleSearchQueryMatcher.matches("👨‍👩‍👧", query: "👨") == false)
    #expect(SubtitleSearchQueryMatcher.matches("🇺🇸", query: "🇺") == false)
}

@Test
func subtitleSearchQueryMatcherExposesUnifiedLiteralSubstringSemantics() {
    #expect(SubtitleSearchQueryMatcher.matches("magic circle", query: "Mag"))
    #expect(SubtitleSearchQueryMatcher.matches("image", query: "Mag"))
    #expect(!SubtitleSearchQueryMatcher.matches("alpha middle beta", query: "alpha beta"))
    #expect(!SubtitleSearchQueryMatcher.matches("beta then alpha", query: "alpha beta"))
    #expect(SubtitleSearchQueryMatcher.matches("一級試験", query: "一級"))
    #expect(!SubtitleSearchQueryMatcher.matches("any primary cue", query: "  "))
    #expect(!SubtitleSearchQueryMatcher.matches("any primary cue", query: "　\u{00A0}\n"))
}
