import Foundation

/// The explicit sharing boundary: personal notes never leave this device.
public struct SharedHabitSnapshot: Codable, Equatable {
    public let ownerName: String
    public let updatedAt: Date
    public let habit: Habit

    public init(habit: Habit, ownerName: String, updatedAt: Date = Date()) {
        var shared = habit
        shared.notes = nil
        self.habit = shared
        self.ownerName = ownerName
        self.updatedAt = updatedAt
    }
}
