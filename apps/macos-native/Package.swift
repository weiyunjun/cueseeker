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
            path: "Sources/SubFinderXCore"
        ),
        .executableTarget(
            name: "SubFinderXApp",
            dependencies: ["SubFinderXCore"],
            path: "Sources/SubFinderXApp"
        ),
        .testTarget(
            name: "SubFinderXCoreTests",
            dependencies: ["SubFinderXCore"],
            path: "Tests/SubFinderXCoreTests"
        )
    ]
)

