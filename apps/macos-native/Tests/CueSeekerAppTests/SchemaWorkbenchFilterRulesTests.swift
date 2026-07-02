import AppKit
import Foundation
import Testing
@testable import CueSeekerApp

@Test
func schemaWorkbenchStartsWithoutPresetFilterSets() {
    #expect(SchemaWorkbenchSearchDefaults.defaultFilterSetID == nil)
    #expect(SchemaWorkbenchSearchDefaults.defaultFilterRules.isEmpty)
    #expect(SchemaWorkbenchSearchDefaults.filterSets.isEmpty)
}

@Test
func schemaWorkbenchColumnVisibilityMenuLocksCuesAndSkipsCheckboxColumn() {
    let items = SchemaWorkbenchColumnVisibilityMenu.items(
        columns: SchemaWorkbenchSearchDefaults.columns,
        visibleColumnIDs: ["display", "time"]
    )

    #expect(items.map(\.id) == ["display", "cues", "time"])
    #expect(items.map(\.title) == ["Display Title", "Cues", "Time"])

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

    #expect(items.map(\.id) == ["display", "cues", "time", "dateAdded"])
    #expect(items.map(\.title) == ["Display Title", "Cues", "Time", "Date Added"])
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
        SchemaWorkbenchSearchDefaults.makeFilterRule(
            join: .and,
            fieldID: "speaker",
            operatorID: .contains,
            value: "高松灯"
        ),
    ]
    let filterSet = rules.subtitleSearchFilterSet

    #expect(filterSet.matches(display: "Ave Mujica", cues: "", languages: ["ja"], speakers: ["高松灯"]))
    #expect(!filterSet.matches(display: "Ave Mujica", cues: "", languages: ["en"], speakers: ["高松灯"]))
    #expect(!filterSet.matches(display: "MyGO", cues: "", languages: ["ja"], speakers: ["高松灯"]))
    #expect(!filterSet.matches(display: "Ave Mujica", cues: "", languages: ["ja"], speakers: ["千早爱音"]))
}

@Test
func schemaWorkbenchSaveActionUpdatesActiveFilterSet() {
    let firstRule = SchemaWorkbenchSearchDefaults.makeFilterRule(
        id: "rule-1",
        join: nil,
        fieldID: "display",
        operatorID: .contains,
        value: "Ave"
    )
    let createdResult = SchemaWorkbenchFilterSetSaveAction.save(
        rules: [firstRule],
        activeFilterSetID: nil,
        existingFilterSets: [],
        makeID: { "filter-set-\($0)" }
    )

    #expect(createdResult.activeFilterSetID == "filter-set-1")
    #expect(createdResult.filterSets.count == 1)
    #expect(createdResult.filterSets[0].name == "Filter Set 1")

    let updatedRule = SchemaWorkbenchSearchDefaults.makeFilterRule(
        id: "rule-2",
        join: nil,
        fieldID: "cues",
        operatorID: .contains,
        value: "Tomori"
    )
    let updatedResult = SchemaWorkbenchFilterSetSaveAction.save(
        rules: [updatedRule],
        activeFilterSetID: createdResult.activeFilterSetID,
        existingFilterSets: createdResult.filterSets,
        makeID: { "filter-set-\($0)" }
    )

    #expect(updatedResult.activeFilterSetID == "filter-set-1")
    #expect(updatedResult.filterSets.count == 1)
    #expect(updatedResult.filterSets[0].name == "Filter Set 1")
    #expect(updatedResult.filterSets[0].rules == [updatedRule])
}

@MainActor
@Test
func settingsStorePersistsSearchFilterSetsWithoutDefaultActiveFilter() {
    withTemporaryFilterSetSettingsUserDefaults { userDefaults, service in
        let rule = SchemaWorkbenchSearchDefaults.makeFilterRule(
            id: "rule-1",
            join: nil,
            fieldID: "language",
            operatorID: .contains,
            value: "ja"
        )
        let filterSet = SchemaWorkbenchFilterSet(
            id: "filter-set-1",
            name: "Filter Set 1",
            rules: [rule]
        )
        let store = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        #expect(store.searchFilterSets.isEmpty)
        store.searchFilterSets = [filterSet]

        let reloadedStore = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        #expect(reloadedStore.searchFilterSets == [filterSet])
        #expect(SchemaWorkbenchSearchDefaults.defaultFilterSetID == nil)
        #expect(SchemaWorkbenchSearchDefaults.defaultFilterRules.isEmpty)
    }
}

@MainActor
private func withTemporaryFilterSetSettingsUserDefaults(_ body: (UserDefaults, String) throws -> Void) rethrows {
    _ = NSApplication.shared
    let suiteName = "CueSeekerFilterSetTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    try body(userDefaults, suiteName)
}
