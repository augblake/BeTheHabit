// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "BeTheHabit",
    platforms: [.iOS(.v16), .macOS(.v14)],
    products: [
        .library(name: "BeTheHabit", targets: ["BeTheHabit"]),
        .library(name: "BeHabitWidget", targets: ["BeHabitWidget"])
    ],
    targets: [
        .target(name: "HabitShared"),
        .target(name: "BeTheHabit", dependencies: ["HabitShared"]),
        .target(name: "BeHabitWidget", dependencies: ["HabitShared"]),
        .testTarget(name: "HabitSharedTests", dependencies: ["HabitShared"])
    ]
)
