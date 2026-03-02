// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CDDSwift",
    platforms: [
        .macOS(.v13),
        .macCatalyst(.v13),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(name: "CDDSwift", targets: ["CDDSwift"]),
        .executable(name: "cdd-swift", targets: ["cdd-swift-cli"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "509.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
    ] + {
        #if os(WASI)
        return []
        #else
        return [.package(url: "https://github.com/httpswift/swifter.git", from: "1.5.0")]
        #endif
    }(),
    targets: [
        .target(
            name: "CDDSwift",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .executableTarget(
            name: "cdd-swift-cli",
            dependencies: [
                "CDDSwift",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ] + {
                #if os(WASI)
                return []
                #else
                return [.product(name: "Swifter", package: "swifter")]
                #endif
            }()
        ),
        .testTarget(
            name: "CDDSwiftTests",
            dependencies: ["CDDSwift"]
        ),
    ]
)