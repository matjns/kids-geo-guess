// swift-tools-version:5.9
import PackageDescription

// The app target needs macOS 14. Linux CI and `swift test` only build the
// logic module; an empty platform list lets that succeed here.
#if os(macOS)
let packagePlatforms: [SupportedPlatform] = [.macOS(.v14)]
#else
let packagePlatforms: [SupportedPlatform]? = nil
#endif

let package = Package(
    name: "GeoGuess",
    platforms: packagePlatforms,
    products: [
        .library(name: "GeoGuessCore", targets: ["GeoGuessCore"]),
        .executable(name: "GeoGuess", targets: ["GeoGuess"]),
    ],
    targets: [
        .target(name: "GeoGuessCore"),
        .executableTarget(
            name: "GeoGuess",
            dependencies: ["GeoGuessCore"],
            linkerSettings: [
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("SwiftUI", .when(platforms: [.macOS])),
                .linkedFramework("MapKit", .when(platforms: [.macOS])),
                .linkedFramework("Network", .when(platforms: [.macOS])),
            ]
        ),
        .testTarget(
            name: "GeoGuessCoreTests",
            dependencies: ["GeoGuessCore"]
        ),
    ]
)
