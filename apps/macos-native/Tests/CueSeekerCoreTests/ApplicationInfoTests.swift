import Testing
import CueSeekerCore

@Test
func applicationInfoDefinesNativeAppName() {
    #expect(ApplicationInfo.name == "CueSeeker")
}

@Test
func applicationInfoDefinesSharedPersistenceIdentifier() {
    #expect(ApplicationInfo.persistenceIdentifier == "com.cueseeker.macos-native")
}

@Test
func applicationInfoDefinesMinimumMacOSVersion() {
    #expect(ApplicationInfo.minimumMacOSVersion == "13.0")
}
