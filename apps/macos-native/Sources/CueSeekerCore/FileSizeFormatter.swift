import Foundation

/// Formats a byte count using binary 1024 base with two decimal places (e.g. 1.43 GB, 102.35 KB).
public enum FileSizeFormatter {
    public static func format(bytes: Int64) -> String {
        guard bytes >= 0 else { return "0 B" }
        if bytes < 1024 {
            return "\(bytes) B"
        }
        let doubleBytes = Double(bytes)
        let kb = doubleBytes / 1024.0
        if kb < 1024.0 {
            return String(format: "%.2f KB", kb)
        }
        let mb = kb / 1024.0
        if mb < 1024.0 {
            return String(format: "%.2f MB", mb)
        }
        let gb = mb / 1024.0
        if gb < 1024.0 {
            return String(format: "%.2f GB", gb)
        }
        let tb = gb / 1024.0
        return String(format: "%.2f TB", tb)
    }
}
