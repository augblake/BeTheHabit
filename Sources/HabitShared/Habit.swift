import Foundation

public enum HabitType: String, Codable, CaseIterable, Identifiable {
    case build
    case remove

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .build: return "Build"
        case .remove: return "Remove"
        }
    }

    public var description: String {
        switch self {
        case .build:
            return "Something you want to do more of."
        case .remove:
            return "Something you want to avoid."
        }
    }
}

public enum TrackingMode: String, Codable, CaseIterable, Identifiable {
    case yesNo
    case number
    case timer

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .yesNo: return "Yes / No"
        case .number: return "Number"
        case .timer: return "Timer"
        }
    }

    public var icon: String {
        switch self {
        case .yesNo: return "checkmark.circle"
        case .number: return "number"
        case .timer: return "timer"
        }
    }
}

public struct HabitEntry: Codable, Equatable {
    public var value: Double
    public var completed: Bool

    public init(value: Double, completed: Bool) {
        self.value = value
        self.completed = completed
    }
}

public struct TrackingHistory: Codable, Equatable {
    public var entries: [String: HabitEntry]
    public var goal: Double?

    public init(entries: [String: HabitEntry], goal: Double?) {
        self.entries = entries
        self.goal = goal
    }
}

public struct Habit: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var type: HabitType
    public var trackingMode: TrackingMode
    public var goal: Double?
    public var entries: [String: HabitEntry]
    public var notes: String?
    public var iconName: String?
    public var iconColorHex: String?
    public var archivedTrackingHistory: [String: TrackingHistory]?
    public var timerStartedAt: Date?
    public var timerStartedFor: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        type: HabitType,
        trackingMode: TrackingMode,
        goal: Double? = nil,
        notes: String? = nil,
        iconName: String? = nil,
        iconColorHex: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.trackingMode = trackingMode
        self.goal = goal
        self.entries = [:]
        self.notes = notes
        self.iconName = iconName
        self.iconColorHex = iconColorHex
        self.archivedTrackingHistory = nil
        self.timerStartedAt = nil
        self.timerStartedFor = nil
    }

    public mutating func changeTrackingMode(to newMode: TrackingMode) {
        guard newMode != trackingMode else { return }
        var history = archivedTrackingHistory ?? [:]
        history[trackingMode.rawValue] = TrackingHistory(entries: entries, goal: goal)
        let restored = history.removeValue(forKey: newMode.rawValue)
        entries = restored?.entries ?? [:]
        goal = restored?.goal
        trackingMode = newMode
        timerStartedAt = nil
        timerStartedFor = nil
        archivedTrackingHistory = history
    }

    public func entry(for date: Date) -> HabitEntry? {
        entries[Self.dateKey(date)]
    }

    public func isComplete(on date: Date) -> Bool {
        entry(for: date)?.completed ?? false
    }

    public func currentStreak(today: Date = Date()) -> Int {
        var streak = 0
        var date = Calendar.current.startOfDay(for: today)

        while let current = entry(for: date) {
            guard trackingMode != .yesNo || current.completed else { break }
            let previous = Calendar.current.date(byAdding: .day, value: -1, to: date)
            if trackingMode != .yesNo, let previous, let earlier = entry(for: previous) {
                let movingInRightDirection = type == .build
                    ? current.value >= earlier.value
                    : current.value <= earlier.value
                guard movingInRightDirection else { break }
            }
            streak += 1
            guard let previous else { break }
            date = previous
        }

        return streak
    }

    public func visibleStreak(today: Date = Date()) -> Int {
        let current = currentStreak(today: today)
        if current > 0 { return current }
        // A recorded miss ends the streak immediately. Only an untracked day
        // gets the grace period for yesterday's completed streak.
        if entry(for: today) != nil { return 0 }
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) else { return 0 }
        return currentStreak(today: yesterday)
    }

    public static func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
