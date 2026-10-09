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
        self.timerStartedAt = nil
        self.timerStartedFor = nil
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

        while isComplete(on: date) {
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: date) else {
                break
            }
            date = previous
        }

        return streak
    }

    public static func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
