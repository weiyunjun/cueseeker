import CryptoKit
import Foundation
import CueSeekerCore

public struct LibraryCoverDisplayBackfillResult: Equatable, Sendable {
    public let eligibleMasterCoverCount: Int
    public let skippedFreshDisplayCoverCount: Int
    public let generatedDisplayCoverCount: Int
    public let clearedInvalidDisplayCoverCount: Int
    public let failedDisplayCoverCount: Int
}

public struct LibraryCoverDisplayRenditionIndexer: Sendable {
    public struct Configuration: Sendable {
        public let coverDirectory: URL
        public let maxConcurrentRenditions: Int
        public let commitToken: LibraryCoverDisplayRenditionCommitToken?

        public init(
            coverDirectory: URL,
            maxConcurrentRenditions: Int = 4,
            commitToken: LibraryCoverDisplayRenditionCommitToken? = nil
        ) {
            self.coverDirectory = coverDirectory
            self.maxConcurrentRenditions = max(1, maxConcurrentRenditions)
            self.commitToken = commitToken
        }
    }

    private struct GenerationJob: Sendable {
        let candidate: LibraryCoverDisplayCandidate
        let destinationURL: URL
    }

    private struct GenerationResult: Sendable {
        let candidate: LibraryCoverDisplayCandidate
        let destinationURL: URL
        let encodedRendition: LibraryCoverEncodedDisplayRendition?
        let errorMessage: String?
    }

    private struct CommitCounts: Sendable {
        var generated = 0
        var clearedInvalid = 0
        var failed = 0
    }

    private let configuration: Configuration

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    @discardableResult
    public func backfillDisplayRenditions(
        under folders: [URL],
        into database: any LibraryCoverPersistence
    ) async throws -> LibraryCoverDisplayBackfillResult {
        let candidates = try database.libraryCoverDisplayCandidates(
            under: folders
        )
        return try await backfillDisplayRenditions(
            candidates: candidates,
            into: database
        )
    }

    @discardableResult
    public func backfillDisplayRenditions(
        videoPaths: Set<String>,
        into database: any LibraryCoverPersistence
    ) async throws -> LibraryCoverDisplayBackfillResult {
        let candidates = try database.libraryCoverDisplayCandidates(
            videoPaths: videoPaths
        )
        return try await backfillDisplayRenditions(
            candidates: candidates,
            into: database
        )
    }

    private func backfillDisplayRenditions(
        candidates: [LibraryCoverDisplayCandidate],
        into database: any LibraryCoverPersistence
    ) async throws -> LibraryCoverDisplayBackfillResult {
        let commitToken = configuration.commitToken
            ?? LibraryCoverDisplayRenditionCommitGate().beginGeneration()
        let displayDirectory = configuration.coverDirectory
            .appendingPathComponent("Display", isDirectory: true)
            .appendingPathComponent(
                "v\(LibraryCoverDisplayProfile.current.version)",
                isDirectory: true
            )

        var jobs: [GenerationJob] = []
        var invalidDisplayCandidatesWithoutMaster: [LibraryCoverDisplayCandidate] = []
        var skippedFreshDisplayCoverCount = 0
        var failedDisplayCoverCount = 0
        for candidate in candidates {
            try Task.checkCancellation()
            if Self.isFreshDisplayRendition(candidate) {
                skippedFreshDisplayCoverCount += 1
                continue
            }
            guard FileManager.default.fileExists(atPath: candidate.masterCoverPath) else {
                failedDisplayCoverCount += 1
                if Self.hasInvalidCurrentDisplayReference(candidate) {
                    invalidDisplayCandidatesWithoutMaster.append(candidate)
                }
                continue
            }
            jobs.append(
                GenerationJob(
                    candidate: candidate,
                    destinationURL: Self.displayURL(
                        forVideoPath: candidate.videoPath,
                        in: displayDirectory
                    )
                )
            )
        }

        var clearedInvalidDisplayCoverCount = 0
        for candidate in invalidDisplayCandidatesWithoutMaster {
            try Task.checkCancellation()
            guard try commitToken.commit({
                try database.updateLibraryVideoDisplayCover(
                    videoFileID: candidate.videoFileID,
                    displayCoverPath: nil,
                    displayProfileVersion: nil
                )
                return true
            }) == true else {
                throw CancellationError()
            }
            clearedInvalidDisplayCoverCount += 1
        }

        let commitCounts = try await generateAndCommitDisplayRenditions(
            for: jobs,
            into: database,
            commitToken: commitToken
        )
        failedDisplayCoverCount += commitCounts.failed
        clearedInvalidDisplayCoverCount += commitCounts.clearedInvalid

        return LibraryCoverDisplayBackfillResult(
            eligibleMasterCoverCount: candidates.count,
            skippedFreshDisplayCoverCount: skippedFreshDisplayCoverCount,
            generatedDisplayCoverCount: commitCounts.generated,
            clearedInvalidDisplayCoverCount: clearedInvalidDisplayCoverCount,
            failedDisplayCoverCount: failedDisplayCoverCount
        )
    }

    private func generateAndCommitDisplayRenditions(
        for jobs: [GenerationJob],
        into database: any LibraryCoverPersistence,
        commitToken: LibraryCoverDisplayRenditionCommitToken
    ) async throws -> CommitCounts {
        guard !jobs.isEmpty else {
            return CommitCounts()
        }

        let limit = min(configuration.maxConcurrentRenditions, jobs.count)
        var nextIndex = 0
        return try await withThrowingTaskGroup(
            of: GenerationResult.self,
            returning: CommitCounts.self
        ) { group in
            for _ in 0..<limit {
                let job = jobs[nextIndex]
                nextIndex += 1
                group.addTask(priority: .utility) {
                    Self.generateDisplayRendition(for: job)
                }
            }

            var counts = CommitCounts()
            while let result = try await group.next() {
                try Task.checkCancellation()
                let resultCounts = try Self.commit(
                    result,
                    into: database,
                    commitToken: commitToken
                )
                counts.generated += resultCounts.generated
                counts.clearedInvalid += resultCounts.clearedInvalid
                counts.failed += resultCounts.failed

                if nextIndex < jobs.count {
                    let job = jobs[nextIndex]
                    nextIndex += 1
                    group.addTask(priority: .utility) {
                        Self.generateDisplayRendition(for: job)
                    }
                }
            }
            return counts
        }
    }

    private static func commit(
        _ result: GenerationResult,
        into database: any LibraryCoverPersistence,
        commitToken: LibraryCoverDisplayRenditionCommitToken
    ) throws -> CommitCounts {
        guard let encodedRendition = result.encodedRendition,
              result.errorMessage == nil
        else {
            var counts = CommitCounts(failed: 1)
            if hasInvalidCurrentDisplayReference(result.candidate) {
                guard try commitToken.commit({
                    try database.updateLibraryVideoDisplayCover(
                        videoFileID: result.candidate.videoFileID,
                        displayCoverPath: nil,
                        displayProfileVersion: nil
                    )
                    return true
                }) == true else {
                    throw CancellationError()
                }
                counts.clearedInvalid = 1
            }
            return counts
        }

        guard try commitToken.commit({
            try LibraryCoverDisplayRenditionGenerator.publish(
                encodedRendition.data,
                to: result.destinationURL
            )
            try database.updateLibraryVideoDisplayCover(
                videoFileID: result.candidate.videoFileID,
                displayCoverPath: result.destinationURL.path,
                displayProfileVersion: LibraryCoverDisplayProfile.current.version
            )
            return true
        }) == true else {
            throw CancellationError()
        }
        return CommitCounts(generated: 1)
    }

    private static func generateDisplayRendition(
        for job: GenerationJob
    ) -> GenerationResult {
        do {
            try Task.checkCancellation()
            let encodedRendition = try LibraryCoverDisplayRenditionGenerator().encode(
                masterURL: URL(fileURLWithPath: job.candidate.masterCoverPath)
            )
            try Task.checkCancellation()
            return GenerationResult(
                candidate: job.candidate,
                destinationURL: job.destinationURL,
                encodedRendition: encodedRendition,
                errorMessage: nil
            )
        } catch {
            return GenerationResult(
                candidate: job.candidate,
                destinationURL: job.destinationURL,
                encodedRendition: nil,
                errorMessage: String(describing: error)
            )
        }
    }

    private static func isFreshDisplayRendition(
        _ candidate: LibraryCoverDisplayCandidate
    ) -> Bool {
        guard candidate.displayProfileVersion == LibraryCoverDisplayProfile.current.version,
              let displayCoverPath = candidate.displayCoverPath,
              !displayCoverPath.isEmpty
        else {
            return false
        }
        return FileManager.default.fileExists(atPath: displayCoverPath)
    }

    private static func hasInvalidCurrentDisplayReference(
        _ candidate: LibraryCoverDisplayCandidate
    ) -> Bool {
        guard candidate.displayProfileVersion == LibraryCoverDisplayProfile.current.version,
              let displayCoverPath = candidate.displayCoverPath,
              !displayCoverPath.isEmpty
        else {
            return false
        }
        return !FileManager.default.fileExists(atPath: displayCoverPath)
    }

    private static func displayURL(
        forVideoPath videoPath: String,
        in directory: URL
    ) -> URL {
        let digest = SHA256.hash(data: Data(videoPath.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return directory.appendingPathComponent("\(digest).jpg")
    }
}
