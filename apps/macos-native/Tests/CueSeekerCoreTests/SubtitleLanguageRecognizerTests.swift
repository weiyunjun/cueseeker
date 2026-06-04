import Testing
import CueSeekerCore

@Test
func recognizesSingleLanguagesWithHighConfidence() {
    let recognizer = SubtitleLanguageRecognizer()

    let japanese = recognizer.detectLanguages(in: [
        "今日はとても良い天気です。明日は友達と映画を見に行きます。",
        "日本語の字幕として十分な長さの文章をここに用意します。"
    ])
    #expect(japanese.languages == [.japanese])
    #expect(japanese.confidence >= SubtitleLanguageRecognizer.defaultConfidenceThreshold)
    #expect(japanese.confidenceBand == .veryHigh || japanese.confidenceBand == .high)

    let english = recognizer.detectLanguages(in: [
        "This subtitle line contains clear English words and complete grammar.",
        "Another sentence gives the local language recognizer enough context."
    ])
    #expect(english.languages == [.english])
    #expect(english.confidence >= SubtitleLanguageRecognizer.defaultConfidenceThreshold)
    #expect(english.confidenceBand == .veryHigh || english.confidenceBand == .high)
}

@Test
func recognizesSimplifiedAndTraditionalChineseSeparately() {
    let recognizer = SubtitleLanguageRecognizer()

    let simplified = recognizer.detectLanguages(in: [
        "这是一段简体中文字幕，用来测试语言识别是否能够稳定返回简体中文。",
        "我们需要保存字幕语言，方便搜索时筛选对应的结果。"
    ])
    #expect(simplified.languages == [.simplifiedChinese])
    #expect(simplified.confidence >= SubtitleLanguageRecognizer.defaultConfidenceThreshold)

    let traditional = recognizer.detectLanguages(in: [
        "這是一段繁體中文字幕，用來測試語言識別是否能夠穩定返回繁體中文。",
        "我們需要保存字幕語言，方便搜尋時篩選對應的結果。"
    ])
    #expect(traditional.languages == [.traditionalChinese])
    #expect(traditional.confidence >= SubtitleLanguageRecognizer.defaultConfidenceThreshold)
}

@Test
func returnsLanguageSetForMixedSubtitleSegments() {
    let recognizer = SubtitleLanguageRecognizer()

    let result = recognizer.detectLanguages(in: [
        "今日はライブの準備をします。みんなで新しい曲を練習しましょう。",
        "我们今天准备演出，大家一起练习新的歌曲。",
        "明日は学校のあとでスタジオに集まります。",
        "明天放学之后我们会在录音室集合。"
    ])

    #expect(result.languages.contains(.japanese))
    #expect(result.languages.contains(.simplifiedChinese))
    #expect(!result.languages.contains(.unknown))
    #expect(result.confidence >= SubtitleLanguageRecognizer.defaultConfidenceThreshold)
}

@Test
func returnsUnknownForInsufficientText() {
    let recognizer = SubtitleLanguageRecognizer()

    let result = recognizer.detectLanguages(in: [
        "",
        "OK",
        "12345",
        "?!..."
    ])

    #expect(result.languages == [.unknown])
    #expect(result.isUnknown)
    #expect(result.confidence == 0)
    #expect(result.confidenceBand == .none)
}

@Test
func mapsNaturalLanguageIdentifiersToSupportedCodes() {
    #expect(SubtitleLanguageRecognizer.languageCode(forNaturalLanguageIdentifier: "ja") == .japanese)
    #expect(SubtitleLanguageRecognizer.languageCode(forNaturalLanguageIdentifier: "en") == .english)
    #expect(SubtitleLanguageRecognizer.languageCode(forNaturalLanguageIdentifier: "zh-Hans") == .simplifiedChinese)
    #expect(SubtitleLanguageRecognizer.languageCode(forNaturalLanguageIdentifier: "zh-Hant") == .traditionalChinese)
    #expect(SubtitleLanguageRecognizer.languageCode(forNaturalLanguageIdentifier: "fr") == nil)
}
