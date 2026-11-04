// swift-tools-version: 5.9
// Swift Package Manager support, which Flutter uses for iOS plugins alongside CocoaPods.

import PackageDescription

let package = Package(
    name: "paystrater_flutter",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "paystrater-flutter", targets: ["paystrater_flutter"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "paystrater_flutter",
            dependencies: [],
            resources: []
        )
    ]
)
