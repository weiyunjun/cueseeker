import Foundation

@main
struct TestApp {
    static func main() async {
        let videoPath = "/Volumes/Seagate/影视/Ave Mujica/[DBD-Raws][BanG Dream! Ave Mujica][01][1080P][BDRip][HEVC-10bit][FLAC].mkv"
        let request = ThumbnailRequest(videoPath: videoPath, fileSize: 1000, modifiedAt: 0, timestampMilliseconds: 10000)
        let cacheKey = await ThumbnailCache.shared.cacheKey(for: request)
        print("Generating thumbnail...")
        let start = Date()
        if let data = await ThumbnailGenerator.shared.generate(request: request, cacheKey: cacheKey) {
            print("Success! Data size: \(data.count) bytes in \(Date().timeIntervalSince(start))s")
        } else {
            print("Failed to generate in \(Date().timeIntervalSince(start))s")
        }
    }
}
