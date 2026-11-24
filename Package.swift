// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YoobLiveKit",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "YoobLiveKit", targets: ["YoobLiveKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Yoob-com/yoob-ios-sdk-spm.git", from: "0.7.5"),
        .package(url: "https://github.com/livekit/client-sdk-swift.git", exact: "2.17.0"),
    ],
    targets: [
        .target(name: "YoobLiveKit",
                dependencies: [.product(name: "Yoob", package: "yoob-ios-sdk-spm"),
                               .product(name: "LiveKit", package: "client-sdk-swift")],
                swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "YoobLiveKitTests", dependencies: ["YoobLiveKit", .product(name: "Yoob", package: "yoob-ios-sdk-spm")]),
    ]
)
