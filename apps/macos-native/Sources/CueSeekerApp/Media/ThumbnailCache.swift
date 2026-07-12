import AppKit
import Foundation
import CryptoKit
import CueSeekerCore

public struct ThumbnailRequest: Equatable, Hashable, Sendable {
    public let videoPath: String
    public let fileSize: Int64?
    public let modifiedAt: Double?
    public let timestampMilliseconds: Int
    public let priority: Int
    
    public init(videoPath: String, fileSize: Int64?, modifiedAt: Double?, timestampMilliseconds: Int, priority: Int) {
        self.videoPath = videoPath
        self.fileSize = fileSize
        self.modifiedAt = modifiedAt
        self.timestampMilliseconds = timestampMilliseconds
        self.priority = priority
    }
}

public actor ThumbnailCache {
    public static let shared = ThumbnailCache()
    
    private let cacheDirectory: URL
    private var memoryCache: [String: Data] = [:]
    
    public init() {
        let baseDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches")
        
        self.cacheDirectory = baseDirectory
            .appendingPathComponent(ApplicationInfo.bundleIdentifier)
            .appendingPathComponent("Thumbnails")
            
        try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
    }
    
    public func cacheKey(for request: ThumbnailRequest) -> String {
        var hasher = SHA256()
        hasher.update(data: Data(request.videoPath.utf8))
        if let fileSize = request.fileSize {
            hasher.update(data: withUnsafeBytes(of: fileSize) { Data($0) })
        }
        if let modifiedAt = request.modifiedAt {
            hasher.update(data: withUnsafeBytes(of: modifiedAt) { Data($0) })
        }
        hasher.update(data: withUnsafeBytes(of: request.timestampMilliseconds) { Data($0) })
        hasher.update(data: Data("320x180_decrease_v2".utf8))
        
        let hash = hasher.finalize()
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    public func fileURL(forKey key: String) -> URL {
        cacheDirectory.appendingPathComponent("\(key).jpg")
    }
    
    public func image(forKey key: String) -> Data? {
        if let memoryData = memoryCache[key] {
            return memoryData
        }
        let url = fileURL(forKey: key)
        if let data = try? Data(contentsOf: url) {
            memoryCache[key] = data
            return data
        }
        return nil
    }
    
    public func commitFile(at tempURL: URL, forKey key: String) -> Data? {
        let url = fileURL(forKey: key)
        try? FileManager.default.removeItem(at: url)
        do {
            try FileManager.default.moveItem(at: tempURL, to: url)
            if let data = try? Data(contentsOf: url) {
                memoryCache[key] = data
                return data
            }
        } catch {
            print("Failed to move thumbnail: \(error)")
        }
        return nil
    }
    
    public func clearMemory() {
        memoryCache.removeAll()
    }
}
