// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "MeteorAPI",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(name: "MeteorAPI", targets: ["MeteorAPI"]),
        .library(name: "MeteorAPIConcurrencySupport", targets: ["MeteorAPIConcurrencySupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.4.0"),
        .package(url: "https://github.com/WeTransfer/Mocker.git", .upToNextMajor(from: "2.3.0"))
    ],
    targets: [
        .target(
            name: "MeteorAPI",
            dependencies: ["Alamofire"]
        ),
        .target(
            name: "MeteorAPIConcurrencySupport",
            dependencies: ["MeteorAPI"]
        ),
        .testTarget(
            name: "MeteorAPITests",
            dependencies: ["MeteorAPI", "Mocker", "MeteorAPIConcurrencySupport"],
            resources: [.copy("Fixture")])
    ]
)
