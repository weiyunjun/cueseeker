// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SubFinderXNative",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SubFinderX", targets: ["SubFinderXApp"])
    ],
    targets: [
        .target(
            name: "SubFinderXCore",
            path: "Sources/SubFinderXCore",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .systemLibrary(
            name: "CMpv",
            path: "Sources/CMpv",
            providers: [
                .brew(["mpv"])
            ]
        ),
        .target(
            name: "SubFinderXPlayback",
            dependencies: ["CMpv"],
            path: "Sources/SubFinderXPlayback",
            linkerSettings: [
                .unsafeFlags(["-L", "/opt/homebrew/lib"]),
                .linkedLibrary("mpv")
            ]
        ),
        .executableTarget(
            name: "SubFinderXApp",
            dependencies: [
                "SubFinderXCore",
                "SubFinderXPlayback"
            ],
            path: "Sources/SubFinderXApp"
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
