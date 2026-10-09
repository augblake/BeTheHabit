// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "HabitQuest",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HabitQuest", targets: ["HabitQuest"]),
        .library(name: "BeHabitWidget", targets: ["BeHabitWidget"])
    ],
    targets: [
        .target(name: "HabitShared"),
        .target(name: "HabitQuest", dependencies: ["HabitShared"]),
        .target(name: "BeHabitWidget", dependencies: ["HabitShared"]),
        .testTarget(name: "HabitSharedTests", dependencies: ["HabitShared"])
    ]
)
