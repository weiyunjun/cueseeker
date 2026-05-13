import AppKit
import Foundation

public actor ThumbnailGenerator {
    public static let shared = ThumbnailGenerator()
    
    private let maxConcurrent = 20
    private var activeCount = 0
    
    private struct PendingTask {
        let id: UUID
        let action: (Bool) -> Void
    }
    private var pendingQueue: [PendingTask] = []
    private var cancelledTasks: Set<UUID> = []
    
    public init() {}
    
    public func generate(request: ThumbnailRequest, cacheKey: String) async -> Data? {
        if let cached = await ThumbnailCache.shared.image(forKey: cacheKey) {
            return cached
        }
        
        let id = UUID()
        return await withTaskCancellationHandler {
            return await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
                let action: (Bool) -> Void = { isCancelled in
                    if isCancelled {
                        continuation.resume(returning: nil)
                        return
                    }
                    _ = Task {
                        let result = await self.executeFFmpeg(request: request, cacheKey: cacheKey)
                        continuation.resume(returning: result)
                        await self.taskDidFinish()
                    }
                }
                
                Task {
                    await self.enqueue(task: PendingTask(id: id, action: action))
                }
            }
        } onCancel: {
            Task {
                await self.cancel(id: id)
            }
        }
    }
    
    private func enqueue(task: PendingTask) {
        if cancelledTasks.remove(task.id) != nil {
            task.action(true)
            return
        }
        
        if activeCount < maxConcurrent {
            activeCount += 1
            task.action(false)
        } else {
            pendingQueue.append(task)
        }
    }
    
    private func cancel(id: UUID) {
        cancelledTasks.insert(id)
        if let index = pendingQueue.firstIndex(where: { $0.id == id }) {
            let task = pendingQueue.remove(at: index)
            task.action(true)
        }
    }
    
    private func taskDidFinish() {
        activeCount -= 1
        if !pendingQueue.isEmpty {
            let task = pendingQueue.removeFirst()
            activeCount += 1
            task.action(false)
        }
    }
    
    private func executeFFmpeg(request: ThumbnailRequest, cacheKey: String) async -> Data? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".avif")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        
        let seconds = Double(request.timestampMilliseconds) / 1000.0
        let timeString = String(format: "%.3f", seconds)
        
        process.arguments = [
            "-nostdin",
            "-y",
            "-ss", timeString,
            "-i", request.videoPath,
            "-vframes", "1",
            "-vf", "scale=160:90:force_original_aspect_ratio=increase,crop=160:90",
            "-c:v", "libsvtav1",
            "-crf", "35",
            "-preset", "8",
            "-f", "avif",
            tempURL.path
        ]
        
        process.standardInput = FileHandle.nullDevice
        process.qualityOfService = .utility
        
        if Task.isCancelled {
            return nil
        }
        
        let start = DispatchTime.now()
        let status = await withTaskCancellationHandler {
            await withCheckedContinuation { (cont: CheckedContinuation<Int32, Never>) in
                if Task.isCancelled {
                    cont.resume(returning: -1)
                    return
                }
                process.terminationHandler = { p in
                    cont.resume(returning: p.terminationStatus)
                }
                do {
                    try process.run()
                    setpriority(PRIO_PROCESS, id_t(process.processIdentifier), 19)
                } catch {
                    print("CUESEEKER_PERF_THUMBNAILS: ffmpeg failed \(error)")
                    cont.resume(returning: -1)
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }
        
        let end = DispatchTime.now()
        let ms = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0
        
        if status == 0 {
            return await ThumbnailCache.shared.commitFile(at: tempURL, forKey: cacheKey)
        } else {
            if status != -1 {
                print("CUESEEKER_PERF_THUMBNAILS: ffmpeg exit \(status), \(ms)ms, \(request.videoPath)")
            }
        }
        
        try? FileManager.default.removeItem(at: tempURL)
        return nil
    }
}
