import Testing
import SubFinderXCore

@Test
func applicationInfoDefinesNativeAppName() {
    #expect(ApplicationInfo.name == "SubFinderX")
}

@Test
func applicationInfoDefinesMinimumMacOSVersion() {
    #expect(ApplicationInfo.minimumMacOSVersion == "13.0")
}

