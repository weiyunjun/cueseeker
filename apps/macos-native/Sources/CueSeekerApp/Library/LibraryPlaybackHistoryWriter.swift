import Foundation
import CueSeekerCore

struct LibraryPlaybackHistorySnapshot: Sendable {
    let videoPath: String
    let positionMilliseconds: Int
    let duration: Double?
    let markStarted: Bool
    let markCompleted: Bool

    init(
        videoPath: String,
        positionMilliseconds: Int,
        duration: Double?,
        markStarted: Bool = true,
        markCompleted: Bool = false
    ) {
        self.videoPath = videoPath
        self.positionMilliseconds = positionMilliseconds
        self.duration = duration
        self.markStarted = markStarted
        self.markCompleted = markCompleted
    }
}

struct LibraryWatchStateSnapshot: Sendable {
    let videoPath: String
    let duration: Double?
    let state: LibraryWatchState
}

final class LibraryPlaybackHistoryWriter: @unchecked Sendable {
    let database: LibraryDatabase?
    let queue = DispatchQueue(
        label: "app.cueseeker.library-playback-history",
        qos: .utility
    )

    init(database: LibraryDatabase?) {
        self.database = database
    }

    func save(_ snapshot: LibraryPlaybackHistorySnapshot) {
        queue.async { [weak self] in
            self?.write(snapshot)
        }
    }

    func saveAndWait(_ snapshot: LibraryPlaybackHistorySnapshot) {
        queue.sync {
            write(snapshot)
        }
    }

    func flush() {
        queue.sync {}
    }

    func write(_ snapshot: LibraryPlaybackHistorySnapshot) {
        guard let database else {
            return
        }

        do {
            try database.upsertLibraryPlaybackHistory(
                videoFile: URL.fromMediaPath(snapshot.videoPath),
                positionMilliseconds: snapshot.positionMilliseconds,
                duration: snapshot.duration,
                markStarted: snapshot.markStarted,
                markCompleted: snapshot.markCompleted
            )
        } catch {
            print("Failed to save Library playback history: \(error)")
        }
    }

    func setWatchStatesAndWait(_ snapshots: [LibraryWatchStateSnapshot]) {
        queue.sync {
            setWatchStates(snapshots)
        }
    }

    private func setWatchStates(_ snapshots: [LibraryWatchStateSnapshot]) {
        guard let database else {
            return
        }

        for snapshot in snapshots {
            do {
                try database.setLibraryWatchState(
                    videoFile: URL.fromMediaPath(snapshot.videoPath),
                    duration: snapshot.duration,
                    state: snapshot.state
                )
            } catch {
                print("Failed to set Library watch state: \(error)")
            }
        }
    }
}
