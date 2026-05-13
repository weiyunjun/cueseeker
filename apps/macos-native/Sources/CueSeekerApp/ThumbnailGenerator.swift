import AppKit
import Foundation

public actor ThumbnailGenerator {
    public static let shared = ThumbnailGenerator()
    
    private let maxConcurrent = 20
    private var activeCount = 0
    
    private struct PendingTask {
        let id: UUID
        let action: () -> Void
    }
    private var pendingQueue: [PendingTask] = []
    
    public init() {}
    
    public func generate(request: ThumbnailRequest, cacheKey: String) async -> Data? {
        if let cached = await ThumbnailCache.shared.image(forKey: cacheKey) {
            return cached
        }
        
        let id = UUID()
        return await withTaskCancellationHandler {
            return await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
                let action = {
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
        if activeCount < maxConcurrent {
            activeCount += 1
            task.action()
        } else {
            pendingQueue.append(task)
        }
    }
    
    private func cancel(id: UUID) {
        pendingQueue.removeAll { $0.id == id }
    }
    
    private func taskDidFinish() {
        activeCount -= 1
        if !pendingQueue.isEmpty {
            let task = pendingQueue.removeFirst()
            activeCount += 1
            task.action()
        }
    }
    
    private func executeFFmpeg(request: ThumbnailRequest, cacheKey: String) async -> Data? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".avif")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        
        let seconds = Double(request.timestampMilliseconds) / 1000.0
        let timeString = String(format: "%.3f", seconds)
        
        process.arguments = [
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
        
        process.qualityOfService = .utility
        
        let isTaskCancelled = await withTaskCancellationHandler {
            return Task.isCancelled
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }
        
        if isTaskCancelled {
            return nil
        }
        
        do {
            let start = DispatchTime.now()
            try process.run()
            
            setpriority(PRIO_PROCESS, id_t(process.processIdentifier), 19)
            
            process.waitUntilExit()
            let end = DispatchTime.now()
            let ms = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0
            
            if process.terminationStatus == 0 {
                return await ThumbnailCache.shared.commitFile(at: tempURL, forKey: cacheKey)
            } else {
                print("CUESEEKER_PERF_THUMBNAILS: ffmpeg exit \(process.terminationStatus), \(ms)ms, \(request.videoPath)")
            }
        } catch {
            print("CUESEEKER_PERF_THUMBNAILS: ffmpeg failed \(error)")
        }
        
        try? FileManager.default.removeItem(at: tempURL)
        return nil
    }
}
