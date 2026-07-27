import Testing
@testable import CueSeekerApp

@Test
func schemaWorkbenchStartsWithoutFilterRules() {
    #expect(SchemaWorkbenchSearchDefaults.defaultFilterRules.isEmpty)
}

@Test
func schemaWorkbenchColumnVisibilityMenuLocksCuesAndSkipsCheckboxColumn() {
    let items = SchemaWorkbenchColumnVisibilityMenu.items(
        columns: SchemaWorkbenchSearchDefaults.columns,
        visibleColumnIDs: ["display", "time"]
    )

    #expect(items.map(\.id) == ["display", "cues", "time"])
    #expect(items.map(\.title) == ["Display Title", "Cues", "Time Range"])

    let cues = items.first { $0.id == "cues" }
    #expect(cues?.isSelected == true)
    #expect(cues?.isEnabled == false)

    let time = items.first { $0.id == "time" }
    #expect(time?.isSelected == true)
    #expect(time?.isEnabled == true)
}

@Test
func schemaWorkbenchColumnVisibilityMenuUsesShioriColumnOrder() {
    let items = SchemaWorkbenchColumnVisibilityMenu.items(
        columns: SchemaWorkbenchSearchDefaults.shioriColumns,
        visibleColumnIDs: SchemaWorkbenchSearchDefaults.initialVisibleShioriColumnIDs
    )

    #expect(items.map(\.id) == ["display", "cues", "tags", "time", "dateAdded"])
    #expect(items.map(\.title) == ["Display Title", "Cues", "Tags", "Time Range", "Date Added"])
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

@MainActor
@Test
func searchAndShioriKeepIndependentSessionFilterRules() {
    let searchRule = SchemaWorkbenchSearchDefaults.makeFilterRule(
        id: "search-rule",
        join: nil,
        fieldID: "display",
        operatorID: .contains,
        value: "Ave"
    )
    let shioriRule = SchemaWorkbenchSearchDefaults.makeFilterRule(
        id: "shiori-rule",
        join: nil,
        fieldID: "cues",
        operatorID: .contains,
        value: "星"
    )
    let search = SearchStore()
    let shiori = ShioriStore()

    search.tableFilterRules = [searchRule]
    shiori.tableFilterRules = [shioriRule]

    #expect(search.tableFilterRules == [searchRule])
    #expect(shiori.tableFilterRules == [shioriRule])
    #expect(SearchStore().tableFilterRules.isEmpty)
    #expect(ShioriStore().tableFilterRules.isEmpty)
}
