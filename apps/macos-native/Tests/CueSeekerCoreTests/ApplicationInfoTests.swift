import Testing
import CueSeekerCore

@Test
func applicationInfoDefinesNativeAppName() {
    #expect(ApplicationInfo.name == "CueSeeker")
}

@Test
func applicationInfoDefinesMinimumMacOSVersion() {
    #expect(ApplicationInfo.minimumMacOSVersion == "13.0")
}

