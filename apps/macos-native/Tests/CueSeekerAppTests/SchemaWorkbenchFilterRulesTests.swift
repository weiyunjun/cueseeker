import Testing
@testable import CueSeekerApp

@Test
func schemaWorkbenchStartsWithoutPresetFilterSets() {
    #expect(SchemaWorkbenchSearchDefaults.defaultFilterSetID == nil)
    #expect(SchemaWorkbenchSearchDefaults.defaultFilterRules.isEmpty)
    #expect(SchemaWorkbenchSearchDefaults.filterSets.isEmpty)
}

@Test
func schemaWorkbenchFilterRulesConvertToCoreFilterSet() {
    let rules = [
        SchemaWorkbenchSearchDefaults.makeFilterRule(
            join: nil,
            fieldID: "display",
            operatorID: .contains,
            value: "Ave"
        ),
        SchemaWorkbenchSearchDefaults.makeFilterRule(
            join: .and,
            fieldID: "language",
            operatorID: .contains,
            value: "ja"
        ),
    ]
    let filterSet = rules.subtitleSearchFilterSet

    #expect(filterSet.matches(display: "Ave Mujica", cues: "", languages: ["ja"]))
    #expect(!filterSet.matches(display: "Ave Mujica", cues: "", languages: ["en"]))
    #expect(!filterSet.matches(display: "MyGO", cues: "", languages: ["ja"]))
}
