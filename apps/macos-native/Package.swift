// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CueSeekerNative",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CueSeeker", targets: ["CueSeekerApp"]),
        .executable(name: "NativePlaybackProbe", targets: ["NativePlaybackProbe"]),
        .executable(name: "ASSRenderingProbe", targets: ["ASSRenderingProbe"]),
        .executable(name: "PlaybackSyncProbe", targets: ["PlaybackSyncProbe"])
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
            name: "CASSRendering",
            path: "Sources/CASSRendering",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-I", "/opt/homebrew/include"])
            ],
            linkerSettings: [
                .unsafeFlags(["-L", "/opt/homebrew/lib"]),
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
            linkerSettings: [
                .linkedFramework("Security")
            ]
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
            name: "CASSRenderingTests",
            dependencies: ["CASSRendering"],
            path: "Tests/CASSRenderingTests",
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
