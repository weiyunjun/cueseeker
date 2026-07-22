import Testing
@testable import CueSeekerCore

@Test
func searchQueryPlannerBuildsLatinPrefixPlan() throws {
    let plan = try #require(SearchQueryPlanner.plan(for: "  Mag  "))

    #expect(plan.ftsQuery == "mag*")
    #expect(SearchQueryPlanner.matchRuleName(plan.lineMatchRule) == "latinPrefix")
    #expect(SearchQueryPlanner.matches("magic circle", rule: plan.lineMatchRule))
    #expect(!SearchQueryPlanner.matches("image", rule: plan.lineMatchRule))
}

@Test
func searchQueryPlannerPreservesOrderedLatinMatching() throws {
    let plan = try #require(SearchQueryPlanner.plan(for: "alpha beta"))

    #expect(plan.ftsQuery == "alpha AND beta")
    #expect(SearchQueryPlanner.matches("alpha middle beta", rule: plan.lineMatchRule))
    #expect(!SearchQueryPlanner.matches("beta then alpha", rule: plan.lineMatchRule))
}

@Test
func searchQueryPlannerSegmentsCJKAndMatchesOriginalText() throws {
    let plan = try #require(SearchQueryPlanner.plan(for: "一級"))

    #expect(plan.ftsQuery == "\"一 級\"")
    #expect(SearchQueryPlanner.matches("一級試験", rule: plan.lineMatchRule))
    #expect(!SearchQueryPlanner.matches("二級試験", rule: plan.lineMatchRule))
}

@Test
func searchQueryPlannerExtractsUniqueVocabularyTerms() {
    #expect(
        SearchQueryPlanner.vocabularyTerms(in: "Shared AND shared 一級")
            == ["shared", "一", "級"]
    )
}
