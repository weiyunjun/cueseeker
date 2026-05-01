// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SubFinderXNative",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SubFinderX", targets: ["SubFinderXApp"]),
        .executable(name: "NativePlaybackProbe", targets: ["NativePlaybackProbe"])
    ],
    targets: [
        .target(
            name: "SubFinderXCore",
            path: "Sources/SubFinderXCore",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .target(
            name: "CNativePlayback",
            path: "Sources/CNativePlayback",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-I", "/opt/homebrew/include"])
            ],
            linkerSettings: [
                .unsafeFlags(["-L", "/opt/homebrew/lib"]),
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
            name: "SubFinderXPlayback",
            dependencies: [
                "CNativePlayback"
            ],
            path: "Sources/SubFinderXPlayback"
        ),
        .executableTarget(
            name: "SubFinderXApp",
            dependencies: [
                "SubFinderXCore",
                "SubFinderXPlayback"
            ],
            path: "Sources/SubFinderXApp"
        ),
        .executableTarget(
            name: "NativePlaybackProbe",
            path: "Sources/NativePlaybackProbe",
            cSettings: [
                .unsafeFlags(["-I", "/opt/homebrew/include"])
            ],
            linkerSettings: [
                .unsafeFlags(["-L", "/opt/homebrew/lib"]),
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
        .testTarget(
            name: "SubFinderXCoreTests",
            dependencies: ["SubFinderXCore"],
            path: "Tests/SubFinderXCoreTests",
            resources: [
                .process("Fixtures")
            ]
        ),
        .testTarget(
            name: "SubFinderXPlaybackTests",
            dependencies: ["SubFinderXPlayback"],
            path: "Tests/SubFinderXPlaybackTests"
        )
    ]
)
