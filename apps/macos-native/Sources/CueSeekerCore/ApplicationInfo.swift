import Darwin
import Foundation

public enum ApplicationInfo {
    public static let name = "CueSeeker"
    public static let bundleIdentifier = "com.cueseeker.app"
    public static let minimumMacOSVersion = "13.0"

    public static var preferencesSuiteIdentifier: String {
        preferencesSuiteIdentifier(for: .current)
    }

    public static func preferencesSuiteIdentifier(
        for configuration: AppBuildConfiguration = .current
    ) -> String {
        "com.cueseeker.\(configuration.rawValue)"
    }

    public static func applicationSupportDirectoryURL(
        for configuration: AppBuildConfiguration = .current,
        baseApplicationSupportDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) -> URL {
        let baseDirectory = baseApplicationSupportDirectoryURL
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(
                "Library/Application Support",
                isDirectory: true
            )
        return baseDirectory
            .appendingPathComponent(name, isDirectory: true)
            .appendingPathComponent(configuration.rawValue, isDirectory: true)
    }

    public static func cachesDirectoryURL(
        for configuration: AppBuildConfiguration = .current,
        baseCachesDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) -> URL {
        let baseDirectory = baseCachesDirectoryURL
            ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(
                "Library/Caches",
                isDirectory: true
            )
        return baseDirectory
            .appendingPathComponent(name, isDirectory: true)
            .appendingPathComponent(configuration.rawValue, isDirectory: true)
    }

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

    public static let unitTestApplicationSupportDirectoryURL: URL = {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "CueSeekerUnitTestAppSupport-\(ProcessInfo.processInfo.processIdentifier)",
                isDirectory: true
            )
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        atexit {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "CueSeekerUnitTestAppSupport-\(ProcessInfo.processInfo.processIdentifier)",
                    isDirectory: true
                )
            try? FileManager.default.removeItem(at: url)
        }
        return url
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

    public static let unitTestCachesDirectoryURL: URL = {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "CueSeekerUnitTestCaches-\(ProcessInfo.processInfo.processIdentifier)",
                isDirectory: true
            )
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        atexit {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "CueSeekerUnitTestCaches-\(ProcessInfo.processInfo.processIdentifier)",
                    isDirectory: true
                )
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }()

    public static func defaultSharedUserDefaults(
        for configuration: AppBuildConfiguration = .current
    ) -> UserDefaults {
        if isRunningInUnitTestProcess {
            return UserDefaults(suiteName: unitTestSharedDefaultsPath) ?? .standard
        }
        return UserDefaults(suiteName: preferencesSuiteIdentifier(for: configuration)) ?? .standard
    }
}
