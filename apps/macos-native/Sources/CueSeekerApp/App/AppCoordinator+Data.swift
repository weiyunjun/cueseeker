import Foundation
import CueSeekerCore

@MainActor
extension AppCoordinator {
    func indexedContentTree() async throws -> [IndexedContentRoot] {
        guard let indexedContentDatabase else {
            throw NSError(
                domain: "CueSeeker.Data",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Database is not initialized"]
            )
        }

        return try await Self.runCancellableDetached(priority: .userInitiated) {
            try indexedContentDatabase.contentTree()
        }
    }
}
