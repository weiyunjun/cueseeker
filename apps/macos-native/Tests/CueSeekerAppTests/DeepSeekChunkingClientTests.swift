import Foundation
import Testing
import CueSeekerCore
@testable import CueSeekerApp

@Test
func aiChunkingResponseParsesPlansRootAndReturnsFirstValidPlan() throws {
    let response = """
    {
      "plans": [
        {
          "items": [
            {"item": "運", "translation": "运气"},
            {"item": "も", "translation": "也"},
            {"item": "実力", "translation": "实力"}
          ]
        }
      ]
    }
    """

    let items = try DeepSeekChunkingClient.validatedItems(
        responseContent: response,
        normalizedSentence: "運も実力"
    )

    #expect(items == [
        AIChunkItem(item: "運", translation: "运气"),
        AIChunkItem(item: "も", translation: "也"),
        AIChunkItem(item: "実力", translation: "实力")
    ])
}

@Test
func aiChunkingResponseRejectsLegacyItemsRoot() {
    expectAIChunkingClientError(
        try DeepSeekChunkingClient.validatedItems(
            responseContent: """
            {
              "items": [
                {"item": "運", "translation": "运气"}
              ]
            }
            """,
            normalizedSentence: "運"
        ),
        matches: { error in
            if case .invalidJSON = error {
                return true
            }
            return false
        }
    )
}

@Test
func aiChunkingPlansMapChunksAcrossHardSpaceBoundaries() throws {
    let plans = try DeepSeekChunkingClient.validatedPlans(
        [
            [
                chunk("被告人", "被告人"),
                chunk("の", "的")
            ]
        ],
        normalizedSentence: "被告人 の"
    )

    #expect(plans == [
        AIChunkingValidatedPlan(chunks: [
            AIChunkingValidatedChunk(
                item: AIChunkItem(item: "被告人", translation: "被告人"),
                startOffset: 0,
                endOffset: 3
            ),
            AIChunkingValidatedChunk(
                item: AIChunkItem(item: "の", translation: "的"),
                startOffset: 4,
                endOffset: 5
            )
        ])
    ])
}

@Test
func aiChunkingPlansRejectChunksThatCrossHardSpaceBoundaries() {
    expectAIChunkingClientError(
        try DeepSeekChunkingClient.validatedPlans(
            [
                [
                    chunk("被告人の", "被告人的")
                ]
            ],
            normalizedSentence: "被告人 の"
        ),
        matches: { error in
            if case .noValidPlans = error {
                return true
            }
            return false
        }
    )
}

@Test
func aiChunkingPlansFilterInvalidPlansAndKeepValidPlansInOrder() throws {
    let plans = try DeepSeekChunkingClient.validatedPlans(
        [
            [
                chunk("運", "运气"),
                chunk("外", "外部文本")
            ],
            [
                chunk("運", "运气"),
                chunk("も", "也"),
                chunk("実力", "实力")
            ],
            [
                chunk("運も", "运气也"),
                chunk("実力", "实力")
            ]
        ],
        normalizedSentence: "運も実力"
    )

    #expect(plans.map(\.items) == [
        [
            AIChunkItem(item: "運", translation: "运气"),
            AIChunkItem(item: "も", translation: "也"),
            AIChunkItem(item: "実力", translation: "实力")
        ],
        [
            AIChunkItem(item: "運も", translation: "运气也"),
            AIChunkItem(item: "実力", translation: "实力")
        ]
    ])
}

@Test
func aiChunkingResponseMergesMultiplePlansBySplittingBaseChunks() throws {
    let response = """
    {
      "plans": [
        {
          "items": [
            {"item": "説明しました", "translation": "说明了"},
            {"item": "が", "translation": "但是"}
          ]
        },
        {
          "items": [
            {"item": "説明", "translation": "说明"},
            {"item": "しました", "translation": "做了"},
            {"item": "が", "translation": "但是"}
          ]
        }
      ]
    }
    """

    let items = try DeepSeekChunkingClient.validatedItems(
        responseContent: response,
        normalizedSentence: "説明しましたが"
    )

    #expect(items == [
        AIChunkItem(item: "説明", translation: "说明"),
        AIChunkItem(item: "しました", translation: "做了"),
        AIChunkItem(item: "が", translation: "但是"),
        AIChunkItem(item: "説明しました", translation: "说明了")
    ])
}

@Test
func aiChunkingResponseCanSplitOneBaseChunkAcrossMultiplePlans() throws {
    let response = """
    {
      "plans": [
        {
          "items": [
            {"item": "春日影は", "translation": "春日影是"},
            {"item": "歌です", "translation": "是歌"}
          ]
        },
        {
          "items": [
            {"item": "春日影", "translation": "春日影"},
            {"item": "は歌です", "translation": "是歌"}
          ]
        },
        {
          "items": [
            {"item": "春日影", "translation": "春日影-3"},
            {"item": "は", "translation": "主题助词"},
            {"item": "歌です", "translation": "是歌-3"}
          ]
        }
      ]
    }
    """

    let items = try DeepSeekChunkingClient.validatedItems(
        responseContent: response,
        normalizedSentence: "春日影は歌です"
    )

    #expect(items == [
        AIChunkItem(item: "春日影", translation: "春日影"),
        AIChunkItem(item: "は", translation: "主题助词"),
        AIChunkItem(item: "歌です", translation: "是歌"),
        AIChunkItem(item: "春日影は", translation: "春日影是"),
        AIChunkItem(item: "は歌です", translation: "是歌")
    ])
}

@Test
func aiChunkingResponseUsesFirstValidPlanAsMergeBase() throws {
    let response = """
    {
      "plans": [
        {
          "items": [
            {"item": "運", "translation": "运气"},
            {"item": "外", "translation": "外部文本"}
          ]
        },
        {
          "items": [
            {"item": "運も", "translation": "运气也"}
          ]
        },
        {
          "items": [
            {"item": "運", "translation": "运气"},
            {"item": "も", "translation": "也"}
          ]
        }
      ]
    }
    """

    let items = try DeepSeekChunkingClient.validatedItems(
        responseContent: response,
        normalizedSentence: "運も"
    )

    #expect(items == [
        AIChunkItem(item: "運", translation: "运气"),
        AIChunkItem(item: "も", translation: "也"),
        AIChunkItem(item: "運も", translation: "运气也")
    ])
}

@Test
func aiChunkingResponseKeepsEarlierTranslationWhenDeduplicatingPlans() throws {
    let response = """
    {
      "plans": [
        {
          "items": [
            {"item": "運も", "translation": "运气也"}
          ]
        },
        {
          "items": [
            {"item": "運", "translation": "运气-2"},
            {"item": "も", "translation": "也-2"}
          ]
        },
        {
          "items": [
            {"item": "運", "translation": "运气-3"},
            {"item": "も", "translation": "也-3"}
          ]
        }
      ]
    }
    """

    let items = try DeepSeekChunkingClient.validatedItems(
        responseContent: response,
        normalizedSentence: "運も"
    )

    #expect(items == [
        AIChunkItem(item: "運", translation: "运气-2"),
        AIChunkItem(item: "も", translation: "也-2"),
        AIChunkItem(item: "運も", translation: "运气也")
    ])
}

@Test
func aiChunkingPlansRejectAllPlansWhenCoverageIsIncomplete() {
    expectAIChunkingClientError(
        try DeepSeekChunkingClient.validatedPlans(
            [
                [
                    chunk("運", "运气"),
                    chunk("実力", "实力")
                ]
            ],
            normalizedSentence: "運も実力"
        ),
        matches: { error in
            if case .noValidPlans = error {
                return true
            }
            return false
        }
    )
}

@Test
func aiChunkingPlansRejectInvalidPlanCounts() {
    expectAIChunkingClientError(
        try DeepSeekChunkingClient.validatedPlans(
            [
                [chunk("運", "运气")],
                [chunk("運", "运气")],
                [chunk("運", "运气")],
                [chunk("運", "运气")]
            ],
            normalizedSentence: "運"
        ),
        matches: { error in
            if case .invalidPlanCount = error {
                return true
            }
            return false
        }
    )
}

private func chunk(_ item: String, _ translation: String) -> AIChunkItem {
    AIChunkItem(item: item, translation: translation)
}

private func expectAIChunkingClientError<T>(
    _ expression: @autoclosure () throws -> T,
    matches predicate: (AIChunkingClientError) -> Bool,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    do {
        _ = try expression()
        Issue.record("Expected AIChunkingClientError.", sourceLocation: sourceLocation)
    } catch let error as AIChunkingClientError {
        #expect(predicate(error), sourceLocation: sourceLocation)
    } catch {
        Issue.record("Expected AIChunkingClientError, got \(error).", sourceLocation: sourceLocation)
    }
}
