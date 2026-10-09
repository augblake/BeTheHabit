// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "BeHabitStorageValidation", targets: [
    .target(name: "HabitShared", path: "Sources"),
    .testTarget(name: "HabitSharedTests", dependencies: ["HabitShared"], path: "Tests")
])
