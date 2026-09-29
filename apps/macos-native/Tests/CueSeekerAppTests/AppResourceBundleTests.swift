import Foundation
import Testing
import AppKit
@testable import CueSeekerApp

@Test
func appResourceBundleLoadsAvailableLocalizations() {
    let bundle = Bundle.appResources
    #expect(!bundle.bundlePath.isEmpty)

    let localizations = bundle.localizations.map { $0.lowercased() }
    #expect(localizations.contains("en"))
    #expect(localizations.contains("zh-hans"))
    #expect(localizations.contains("zh-hant"))
}

@Test
@MainActor
func appIconLoadsExpectedSVGUsingAppResourceBundle() {
    let image = AppIconStore.image(.play, size: 16)
    #expect(image != nil)
}
