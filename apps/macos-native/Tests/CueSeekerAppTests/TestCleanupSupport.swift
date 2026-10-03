import Foundation

extension UserDefaults {
    static func temporary(suiteName: String) -> UserDefaults? {
        let plistURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(suiteName).plist")
        return UserDefaults(suiteName: plistURL.path)
    }

    func removePersistentDomainAndPlist(forName suiteName: String) {
        let path = suiteName.hasPrefix("/")
            ? suiteName
            : FileManager.default.temporaryDirectory
                .appendingPathComponent("\(suiteName).plist").path
        removePersistentDomain(forName: path)
        removePersistentDomain(forName: suiteName)
        _ = synchronize()
        try? FileManager.default.removeItem(atPath: path)
        let homePlistURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/\(suiteName).plist")
        try? FileManager.default.removeItem(at: homePlistURL)
    }
}

func removeTemporaryDatabase(at url: URL) {
    let fm = FileManager.default
    try? fm.removeItem(at: url)
    try? fm.removeItem(atPath: url.path + "-wal")
    try? fm.removeItem(atPath: url.path + "-shm")
}
