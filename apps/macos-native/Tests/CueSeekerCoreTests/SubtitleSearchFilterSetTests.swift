import Testing
import CueSeekerCore

@Test
func filterSetAllowsExpectedOperatorsForDataTypes() {
    #expect(SubtitleSearchFilterOperator.allowed(for: .string) == [
        .is,
        .isNot,
        .contains,
        .doesNotContain,
        .isEmpty,
        .isNotEmpty,
    ])
    #expect(SubtitleSearchFilterOperator.allowed(for: .stringSet) == [
        .contains,
        .doesNotContain,
        .isEmpty,
        .isNotEmpty,
    ])
    #expect(SubtitleSearchFilterOperator.allowed(for: .number) == [
        .equals,
        .doesNotEqual,
        .greaterThan,
        .greaterThanOrEqualTo,
        .lessThan,
        .lessThanOrEqualTo,
        .isEmpty,
        .isNotEmpty,
    ])
}

@Test
func filterSetSkipsValueOperatorsWithEmptyInput() {
    let filterSet = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .display,
            operatorID: .contains,
            value: ""
        ),
    ])

    #expect(filterSet.isEffectivelyEmpty)
    #expect(filterSet.matches(display: "Any display", cues: "", languages: []))
}

@Test
func filterSetEvaluatesStringOperators() {
    let displayContains = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .display,
            operatorID: .contains,
            value: "Mujica"
        ),
    ])
    let cuesDoesNotContain = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .cues,
            operatorID: .doesNotContain,
            value: "大丈夫"
        ),
    ])

    #expect(displayContains.matches(display: "Ave Mujica", cues: "", languages: []))
    #expect(displayContains.matches(display: "AVE MUJICA", cues: "", languages: []))
    #expect(!displayContains.matches(display: "MyGO", cues: "", languages: []))
    #expect(cuesDoesNotContain.matches(display: "", cues: "今日はいい天気", languages: []))
    #expect(!cuesDoesNotContain.matches(display: "", cues: "大丈夫だよ", languages: []))

    let displayIs = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .display,
            operatorID: .is,
            value: "ave mujica"
        ),
    ])
    #expect(displayIs.matches(display: "Ave Mujica", cues: "", languages: []))
}

@Test
func filterSetEvaluatesLanguageStringSetOperators() {
    let containsJapanese = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .language,
            operatorID: .contains,
            value: "ja"
        ),
    ])
    let excludesEnglish = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .language,
            operatorID: .doesNotContain,
            value: "en"
        ),
    ])

    #expect(containsJapanese.matches(display: "", cues: "", languages: ["ja", "zh-Hans"]))
    #expect(containsJapanese.matches(display: "", cues: "", languages: ["JA-JP", "zh-Hans"]))
    #expect(!containsJapanese.matches(display: "", cues: "", languages: ["en"]))
    #expect(excludesEnglish.matches(display: "", cues: "", languages: ["ja"]))
    #expect(!excludesEnglish.matches(display: "", cues: "", languages: ["EN", "ja"]))
}

@Test
func filterSetCacheSignatureIgnoresStringValueCase() {
    let uppercaseFilterSet = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .display,
            operatorID: .contains,
            value: "MUJICA"
        ),
    ])
    let lowercaseFilterSet = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .display,
            operatorID: .contains,
            value: "mujica"
        ),
    ])

    #expect(uppercaseFilterSet.cacheSignature == lowercaseFilterSet.cacheSignature)
}

@Test
func filterSetUsesSecondRuleJoinAsSetJoin() {
    let andFilterSet = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .display,
            operatorID: .contains,
            value: "Ave"
        ),
        SubtitleSearchFilterRule(
            join: .and,
            field: .cues,
            operatorID: .contains,
            value: "大丈夫"
        ),
    ])
    let orFilterSet = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .display,
            operatorID: .contains,
            value: "Ave"
        ),
        SubtitleSearchFilterRule(
            join: .or,
            field: .cues,
            operatorID: .contains,
            value: "大丈夫"
        ),
    ])

    #expect(andFilterSet.matches(display: "Ave Mujica", cues: "大丈夫", languages: []))
    #expect(!andFilterSet.matches(display: "Ave Mujica", cues: "別の台詞", languages: []))
    #expect(orFilterSet.matches(display: "Ave Mujica", cues: "別の台詞", languages: []))
    #expect(orFilterSet.matches(display: "MyGO", cues: "大丈夫", languages: []))
    #expect(!orFilterSet.matches(display: "MyGO", cues: "別の台詞", languages: []))
}

@Test
func filterSetAppliesUnifiedCharacterNormalizationAndCacheSignatures() {
    let tildeContains = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(field: .display, operatorID: .contains, value: "  ~  ")
    ])
    #expect(tildeContains.matches(display: "1〜2週間", cues: "", languages: []))
    #expect(tildeContains.matches(display: "♪～", cues: "", languages: []))

    let ellipsisContains = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(field: .cues, operatorID: .contains, value: "...")
    ])
    #expect(ellipsisContains.matches(display: "", cues: "真的吗…", languages: []))
    #expect(ellipsisContains.matches(display: "", cues: "居中⋯省略", languages: []))

    let strictKanaAndAccents = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(field: .cues, operatorID: .contains, value: "ありかとう")
    ])
    #expect(!strictKanaAndAccents.matches(display: "", cues: "ありがとう", languages: []))

    let accentMismatch = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(field: .cues, operatorID: .contains, value: "Mere")
    ])
    #expect(!accentMismatch.matches(display: "", cues: "Ma Mère l'Oye", languages: []))

    let isRule = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(field: .display, operatorID: .is, value: "  Ｓｕｍｉｍｉ　初華  ")
    ])
    #expect(isRule.matches(display: "sumimi 初華", cues: "", languages: []))
    #expect(!isRule.matches(display: "sumimi", cues: "", languages: []))

    let isNotRule = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(field: .display, operatorID: .isNot, value: "ありかとう")
    ])
    #expect(isNotRule.matches(display: "ありがとう", cues: "", languages: []))

    let ruleA = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(field: .cues, operatorID: .contains, value: "  Ｐａｓｔｅｌ＊Ｐａｌｅｔｔｅｓ 〜 … ‘a’ “b”  ")
    ])
    let ruleB = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(field: .cues, operatorID: .contains, value: "pastel*palettes ~ ... 'a' \"b\"")
    ])
    #expect(ruleA.cacheSignature == ruleB.cacheSignature)
}
