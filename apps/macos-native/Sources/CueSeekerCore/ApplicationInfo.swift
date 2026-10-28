import Darwin
import Foundation

public enum ApplicationInfo {
    public static let name = "CueSeeker"
    public static let bundleIdentifier = "com.cueseeker.app"
    public static let preferencesSuiteIdentifier = "com.cueseeker.shared"
    public static let minimumMacOSVersion = "13.0"

    public static let isRunningInUnitTestProcess: Bool = {
        let processName = ProcessInfo.processInfo.processName
        if processName == "xctest" || processName.contains("swiftpm-testing-helper") {
            return true
        }
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil || env["XCTestBundlePath"] != nil {
            return true
        }
        return NSClassFromString("XCTestCase") != nil
    }()

    private static let unitTestSharedDefaultsPath: String = {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeekerUnitTestShared-\(ProcessInfo.processInfo.processIdentifier).plist")
            .path
        atexit {
            let path = FileManager.default.temporaryDirectory
                .appendingPathComponent("CueSeekerUnitTestShared-\(ProcessInfo.processInfo.processIdentifier).plist")
                .path
            if let defaults = UserDefaults(suiteName: path) {
                defaults.removePersistentDomain(forName: path)
                _ = defaults.synchronize()
            }
            try? FileManager.default.removeItem(atPath: path)
        }
        return path
    }()

    public static let unitTestSubtitleCacheDirectoryURL: URL = {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "CueSeekerUnitTestSubtitleCache-\(ProcessInfo.processInfo.processIdentifier)",
                isDirectory: true
            )
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        atexit {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "CueSeekerUnitTestSubtitleCache-\(ProcessInfo.processInfo.processIdentifier)",
                    isDirectory: true
                )
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }()

    public static func defaultSharedUserDefaults() -> UserDefaults {
        if isRunningInUnitTestProcess {
            return UserDefaults(suiteName: unitTestSharedDefaultsPath) ?? .standard
        }
        return UserDefaults(suiteName: preferencesSuiteIdentifier) ?? .standard
    }
}
