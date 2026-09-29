// swift-tools-version: 6.0

import PackageDescription
import Foundation

let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let repositoryDirectory = packageDirectory.deletingLastPathComponent().deletingLastPathComponent()
let defaultMediaRuntimeRoot = repositoryDirectory
    .appendingPathComponent(".build/media-runtime/arm64-macos13")
    .path

func missingMediaRuntimeFiles(_ root: String) -> [String] {
    let requiredPaths = [
        "\(root)/include/libavformat/avformat.h",
        "\(root)/include/libavcodec/avcodec.h",
        "\(root)/include/libavutil/avutil.h",
        "\(root)/include/libswresample/swresample.h",
        "\(root)/include/libswscale/swscale.h",
        "\(root)/include/ass/ass.h",
        "\(root)/lib/libavformat.dylib",
        "\(root)/lib/libavcodec.dylib",
        "\(root)/lib/libavutil.dylib",
        "\(root)/lib/libswresample.dylib",
        "\(root)/lib/libswscale.dylib",
        "\(root)/lib/libdav1d.dylib",
        "\(root)/lib/libass.dylib",
        "\(root)/lib/libfreetype.dylib",
        "\(root)/lib/libfribidi.dylib",
        "\(root)/lib/libharfbuzz.dylib",
        "\(root)/lib/libunibreak.dylib",
        "\(root)/lib/libmp3lame.dylib",
    ]
    return requiredPaths.filter { !FileManager.default.fileExists(atPath: $0) }
}

let mediaRuntimeRoot = Context.environment["CUESEEKER_MEDIA_RUNTIME_ROOT"]
    ?? defaultMediaRuntimeRoot
let missingRuntimeFiles = missingMediaRuntimeFiles(mediaRuntimeRoot)
if !missingRuntimeFiles.isEmpty {
    fatalError("""
        CueSeeker controlled media runtime is incomplete at \(mediaRuntimeRoot).
        Run scripts/build_macos_media_runtime.sh from the repository root, or set
        CUESEEKER_MEDIA_RUNTIME_ROOT to a complete runtime. Missing files:
        \(missingRuntimeFiles.joined(separator: "\n"))
        """)
}
let mediaIncludePath = "\(mediaRuntimeRoot)/include"
let mediaLibraryPath = "\(mediaRuntimeRoot)/lib"
let mediaRuntimeLinkerFlags = [
    "-L", mediaLibraryPath,
    "-Xlinker", "-rpath",
    "-Xlinker", mediaLibraryPath,
    "-Xlinker", "-rpath",
    "-Xlinker", "@executable_path/../Frameworks",
]

let package = Package(
    name: "CueSeekerNative",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CueSeeker", targets: ["CueSeekerApp"]),
        .executable(name: "NativePlaybackProbe", targets: ["NativePlaybackProbe"]),
        .executable(name: "NativePlayerSeekProbe", targets: ["NativePlayerSeekProbe"]),
        .executable(name: "ASSRenderingProbe", targets: ["ASSRenderingProbe"]),
        .executable(name: "PlaybackSyncProbe", targets: ["PlaybackSyncProbe"]),
        .executable(name: "SearchBench", targets: ["SearchBench"])
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
                .unsafeFlags(["-I", mediaIncludePath])
            ],
            linkerSettings: [
                .unsafeFlags(mediaRuntimeLinkerFlags),
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
                .unsafeFlags(["-I", mediaIncludePath])
            ],
            linkerSettings: [
                .unsafeFlags(mediaRuntimeLinkerFlags),
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
            path: "Sources/CueSeekerApp",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("GameController")
            ]
        ),
        .executableTarget(
            name: "NativePlaybackProbe",
            path: "Sources/NativePlaybackProbe",
            cSettings: [
                .unsafeFlags(["-I", mediaIncludePath])
            ],
            linkerSettings: [
                .unsafeFlags(mediaRuntimeLinkerFlags),
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
            dependencies: [
                "CueSeekerPlayback",
                "CNativePlayback"
            ],
            path: "Tests/CueSeekerPlaybackTests"
        ),
        .testTarget(
            name: "CueSeekerAppTests",
            dependencies: ["CueSeekerApp"],
            path: "Tests/CueSeekerAppTests"
        ),
        .testTarget(
            name: "CASSRenderingTests",
            dependencies: ["CASSRendering", "CueSeekerCore"],
            path: "Tests/CASSRenderingTests",
            resources: [
                .process("Fixtures")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
