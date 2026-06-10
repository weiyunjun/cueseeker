// swift-tools-version: 6.0

import PackageDescription
import Foundation

let homebrewRoot = "/opt/homebrew"
let localPatchedFFmpegRoot = "/private/tmp/cueseeker-ffmpeg-8.1-patched"

func hasRequiredFFmpegHeaders(_ root: String) -> Bool {
    [
        "\(root)/include/libavformat/avformat.h",
        "\(root)/include/libavcodec/avcodec.h",
        "\(root)/include/libavutil/avutil.h",
        "\(root)/include/libswresample/swresample.h",
        "\(root)/include/libswscale/swscale.h",
    ].allSatisfy { FileManager.default.fileExists(atPath: $0) }
}

func hasRequiredFFmpegLibraries(_ root: String) -> Bool {
    [
        "\(root)/lib/libavformat.dylib",
        "\(root)/lib/libavcodec.dylib",
        "\(root)/lib/libavutil.dylib",
        "\(root)/lib/libswresample.dylib",
        "\(root)/lib/libswscale.dylib",
    ].allSatisfy { FileManager.default.fileExists(atPath: $0) }
}

let defaultFFmpegIncludeRoot = hasRequiredFFmpegHeaders(localPatchedFFmpegRoot)
    ? localPatchedFFmpegRoot
    : homebrewRoot
let defaultFFmpegLibraryRoot = hasRequiredFFmpegLibraries(localPatchedFFmpegRoot)
    ? localPatchedFFmpegRoot
    : homebrewRoot
let ffmpegRootOverride = Context.environment["CUESEEKER_FFMPEG_ROOT"]
let ffmpegIncludePath = "\(ffmpegRootOverride ?? defaultFFmpegIncludeRoot)/include"
let ffmpegLibraryPath = "\(ffmpegRootOverride ?? defaultFFmpegLibraryRoot)/lib"
let libassLibraryPath = "\(homebrewRoot)/opt/libass/lib"

let package = Package(
    name: "CueSeekerNative",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CueSeeker", targets: ["CueSeekerApp"]),
        .executable(name: "NativePlaybackProbe", targets: ["NativePlaybackProbe"]),
        .executable(name: "NativePlayerSeekProbe", targets: ["NativePlayerSeekProbe"]),
        .executable(name: "ASSRenderingProbe", targets: ["ASSRenderingProbe"]),
        .executable(name: "PlaybackSyncProbe", targets: ["PlaybackSyncProbe"]),
        .executable(name: "SearchBench", targets: ["SearchBench"]),
        .executable(name: "SpeakerImport", targets: ["SpeakerImport"])
    ],
    targets: [
        .target(
            name: "CueSeekerCore",
            path: "Sources/CueSeekerCore",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .target(
            name: "CNativePlayback",
            path: "Sources/CNativePlayback",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-I", ffmpegIncludePath])
            ],
            linkerSettings: [
                .unsafeFlags(["-L", ffmpegLibraryPath]),
                .linkedLibrary("avformat"),
                .linkedLibrary("avcodec"),
                .linkedLibrary("avutil"),
                .linkedLibrary("swresample"),
                .linkedLibrary("swscale"),
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("QuartzCore")
            ]
        ),
        .target(
            name: "CASSRendering",
            path: "Sources/CASSRendering",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-I", "\(homebrewRoot)/include"])
            ],
            linkerSettings: [
                .unsafeFlags(["-L", libassLibraryPath]),
                .linkedLibrary("ass"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Foundation"),
                .linkedFramework("ImageIO")
            ]
        ),
        .target(
            name: "CueSeekerPlayback",
            dependencies: [
                "CueSeekerCore",
                "CNativePlayback",
                "CASSRendering"
            ],
            path: "Sources/CueSeekerPlayback"
        ),
        .executableTarget(
            name: "CueSeekerApp",
            dependencies: [
                "CueSeekerCore",
                "CueSeekerPlayback"
            ],
            path: "Sources/CueSeekerApp"
        ),
        .executableTarget(
            name: "NativePlaybackProbe",
            path: "Sources/NativePlaybackProbe",
            cSettings: [
                .unsafeFlags(["-I", ffmpegIncludePath])
            ],
            linkerSettings: [
                .unsafeFlags(["-L", ffmpegLibraryPath]),
                .linkedLibrary("avformat"),
                .linkedLibrary("avcodec"),
                .linkedLibrary("avutil"),
                .linkedLibrary("swresample"),
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("QuartzCore")
            ]
        ),
        .executableTarget(
            name: "NativePlayerSeekProbe",
            dependencies: [
                "CNativePlayback"
            ],
            path: "Sources/NativePlayerSeekProbe",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("QuartzCore")
            ]
        ),
        .executableTarget(
            name: "ASSRenderingProbe",
            dependencies: [
                "CASSRendering"
            ],
            path: "Sources/ASSRenderingProbe"
        ),
        .executableTarget(
            name: "PlaybackSyncProbe",
            dependencies: [
                "CueSeekerCore",
                "CueSeekerPlayback"
            ],
            path: "Sources/PlaybackSyncProbe",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("QuartzCore")
            ]
        ),
        .executableTarget(
            name: "SearchBench",
            dependencies: ["CueSeekerCore"],
            path: "Sources/SearchBench",
            exclude: ["TestThumbnails.swift"]
        ),
        .executableTarget(
            name: "SpeakerImport",
            dependencies: ["CueSeekerCore"],
            path: "Sources/SpeakerImport"
        ),
        .testTarget(
            name: "CueSeekerCoreTests",
            dependencies: ["CueSeekerCore"],
            path: "Tests/CueSeekerCoreTests",
            resources: [
                .process("Fixtures")
            ]
        ),
        .testTarget(
            name: "CueSeekerPlaybackTests",
            dependencies: ["CueSeekerPlayback"],
            path: "Tests/CueSeekerPlaybackTests"
        ),
        .testTarget(
            name: "CueSeekerAppTests",
            dependencies: ["CueSeekerApp"],
            path: "Tests/CueSeekerAppTests"
        ),
        .testTarget(
            name: "CASSRenderingTests",
            dependencies: ["CASSRendering"],
            path: "Tests/CASSRenderingTests",
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
