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
