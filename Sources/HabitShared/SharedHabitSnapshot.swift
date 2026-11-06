import Foundation

/// Friend snapshots exclude notes and archived modes; private backups are separate.
public struct SharedHabitSnapshot: Codable, Equatable {
    public let ownerName: String
    public let updatedAt: Date
    public let habit: Habit

    public init(habit: Habit, ownerName: String, updatedAt: Date = Date()) {
        var shared = habit
        shared.notes = nil
        shared.archivedTrackingHistory = nil
        self.habit = shared
        self.ownerName = ownerName
        self.updatedAt = updatedAt
    }
}
