import AppKit
import CueSeekerCore
import Darwin
import Foundation

/// Indexing reads the database, then scans and parses for a long time outside any
/// transaction, then writes back. Two instances of the same build configuration
/// doing that against the same database can publish stale results over newer ones,
/// so each environment (`release` vs `debug`) holds its own exclusive lock file.
enum SingleInstanceGuard {
    static let lockFileName = "CueSeeker.instance.lock"

    final class LockHandle: @unchecked Sendable {
        private var fileDescriptor: Int32
        private let lock = NSLock()

        init(fileDescriptor: Int32) {
            self.fileDescriptor = fileDescriptor
        }

        func release() {
            lock.lock()
            defer { lock.unlock() }
            guard fileDescriptor >= 0 else { return }
            _ = flock(fileDescriptor, LOCK_UN)
            close(fileDescriptor)
            fileDescriptor = -1
        }

        deinit {
            release()
        }
    }

    enum AcquisitionResult {
        case acquired(LockHandle?)
        case alreadyRunning(holderPID: pid_t?)
    }

    static func acquireLock(
        in supportDirectoryURL: URL = ApplicationInfo.applicationSupportDirectoryURL(),
        currentPID: pid_t = getpid()
    ) -> AcquisitionResult {
        try? FileManager.default.createDirectory(
            at: supportDirectoryURL,
            withIntermediateDirectories: true
        )
        let lockFileURL = supportDirectoryURL.appendingPathComponent(lockFileName, isDirectory: false)
        let fd = open(lockFileURL.path, O_RDWR | O_CREAT | O_CLOEXEC, 0o600)
        guard fd >= 0 else {
            return .acquired(nil)
        }

        if flock(fd, LOCK_EX | LOCK_NB) == 0 {
            writeHolderPID(currentPID, to: fd)
            return .acquired(LockHandle(fileDescriptor: fd))
        }

        let lockErrno = errno
        if lockErrno == EWOULDBLOCK || lockErrno == EAGAIN {
            let holderPID = readHolderPID(from: fd)
            close(fd)
            return .alreadyRunning(holderPID: holderPID)
        }

        close(fd)
        return .acquired(nil)
    }

    static func runningApplication(forHolderPID holderPID: pid_t?) -> NSRunningApplication? {
        guard let holderPID, holderPID > 0, holderPID != getpid() else {
            return nil
        }
        return NSRunningApplication(processIdentifier: holderPID)
    }

    private static func writeHolderPID(_ pid: pid_t, to fd: Int32) {
        _ = ftruncate(fd, 0)
        _ = lseek(fd, 0, SEEK_SET)
        let text = "\(pid)\n"
        _ = text.withCString { pointer in
            write(fd, pointer, strlen(pointer))
        }
        _ = fsync(fd)
    }

    private static func readHolderPID(from fd: Int32) -> pid_t? {
        for attempt in 0..<2 {
            if let pid = readSingleHolderPIDAttempt(from: fd) {
                return pid
            }
            if attempt == 0 {
                usleep(10_000)
            }
        }
        return nil
    }

    private static func readSingleHolderPIDAttempt(from fd: Int32) -> pid_t? {
        guard lseek(fd, 0, SEEK_SET) >= 0 else {
            return nil
        }
        var buffer = [UInt8](repeating: 0, count: 64)
        let bytesRead = read(fd, &buffer, buffer.count)
        guard bytesRead > 0 else {
            return nil
        }
        let raw = String(decoding: buffer.prefix(bytesRead), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = Int32(raw), parsed > 0 else {
            return nil
        }
        return pid_t(parsed)
    }
}
