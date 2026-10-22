import Foundation

public final class LibraryCoverDisplayRenditionCommitGate: @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0

    public init() {}

    public func beginGeneration() -> LibraryCoverDisplayRenditionCommitToken {
        lock.lock()
        generation &+= 1
        let token = LibraryCoverDisplayRenditionCommitToken(
            gate: self,
            generation: generation
        )
        lock.unlock()
        return token
    }

    public func invalidateCurrentGeneration() {
        lock.lock()
        generation &+= 1
        lock.unlock()
    }

    fileprivate func commit<Value>(
        generation expectedGeneration: UInt64,
        operation: () throws -> Value
    ) rethrows -> Value? {
        lock.lock()
        defer { lock.unlock() }
        guard generation == expectedGeneration else {
            return nil
        }
        return try operation()
    }
}

public struct LibraryCoverDisplayRenditionCommitToken: @unchecked Sendable {
    fileprivate let gate: LibraryCoverDisplayRenditionCommitGate
    fileprivate let generation: UInt64

    public func commit<Value>(
        _ operation: () throws -> Value
    ) rethrows -> Value? {
        try gate.commit(generation: generation, operation: operation)
    }
}
