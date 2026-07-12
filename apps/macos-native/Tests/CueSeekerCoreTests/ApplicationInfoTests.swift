import Testing
import CueSeekerCore

@Test
func applicationInfoDefinesNativeAppName() {
    #expect(ApplicationInfo.name == "CueSeeker")
}

@Test
func applicationInfoDefinesBundleAndSharedPreferencesIdentifiers() {
    #expect(ApplicationInfo.bundleIdentifier == "com.cueseeker.macos-native")
    #expect(ApplicationInfo.preferencesSuiteIdentifier == "com.cueseeker.shared")
}

@Test
func applicationInfoDefinesMinimumMacOSVersion() {
    #expect(ApplicationInfo.minimumMacOSVersion == "13.0")
}
