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
    public var alternatingTimerEnabled: Bool?
    public var oppositeTimerName: String?
    public var oppositeTimerIconName: String?
    public var oppositeTimerEntries: [String: HabitEntry]?
    public var timerIsOpposite: Bool?

    public var tracksBothSides: Bool { trackingMode == .timer && alternatingTimerEnabled == true }
    public var runningOpposite: Bool { tracksBothSides && timerIsOpposite == true }
    public var oppositeName: String {
        let name = oppositeTimerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Other time" : name
    }
    public var activeTimerIconName: String {
        (runningOpposite ? oppositeTimerIconName : iconName) ?? iconName ?? "timer"
    }
    public var activeTimerName: String { runningOpposite ? oppositeName : name }

    // The cutoff uses the actual start day, rather than a possibly backdated log day.
    // Calendar day intervals also handle 23/25-hour daylight-saving days.
    public func timerCutoff(calendar: Calendar = .current) -> Date? {
        guard tracksBothSides, let start = timerStartedAt else { return nil }
        return calendar.dateInterval(of: .day, for: start)?.end
    }

    public func timerIsActive(at now: Date = Date()) -> Bool {
        guard timerStartedAt != nil else { return false }
        return timerCutoff().map { now < $0 } ?? true
    }

    @discardableResult
    public mutating func expireAlternatingTimer(at now: Date = Date()) -> Bool {
        guard let cutoff = timerCutoff(), now >= cutoff else { return false }
        finishTimer(at: cutoff)
        return true
    }

    public func timerSeconds(on date: Date, opposite: Bool = false, at now: Date = Date()) -> TimeInterval {
        let key = Self.dateKey(date)
        let saved = opposite ? (oppositeTimerEntries?[key]?.value ?? 0) : (entries[key]?.value ?? 0)
        guard let start = timerStartedAt, let day = timerStartedFor,
              Self.dateKey(day) == key, (timerIsOpposite == true) == opposite else { return saved }
        return saved + max(0, min(now, timerCutoff() ?? now).timeIntervalSince(start))
    }

    public mutating func finishTimer(at now: Date = Date()) {
        guard let start = timerStartedAt else { return }
        let key = Self.dateKey(timerStartedFor ?? now)
        let elapsed = max(0, min(now, timerCutoff() ?? now).timeIntervalSince(start))
        if timerIsOpposite == true {
            var other = oppositeTimerEntries ?? [:]
            let total = (other[key]?.value ?? 0) + elapsed
            other[key] = HabitEntry(value: total, completed: total > 0)
            oppositeTimerEntries = other
        } else {
            let total = (entries[key]?.value ?? 0) + elapsed
            entries[key] = HabitEntry(value: total, completed: total > 0 && (goal.map { total >= $0 * 60 } ?? true))
        }
        timerStartedAt = nil
        timerStartedFor = nil
        timerIsOpposite = nil
    }

    public mutating func activateTimer(on date: Date, at now: Date = Date()) {
        guard trackingMode == .timer else { return }
        expireAlternatingTimer(at: now)
        if timerStartedAt != nil {
            let nextOpposite = !runningOpposite
            let sessionDay = timerStartedFor ?? date
            finishTimer(at: now)
            if tracksBothSides {
                timerStartedAt = now
                timerStartedFor = Calendar.current.startOfDay(for: sessionDay)
                timerIsOpposite = nextOpposite
            }
        } else {
            timerStartedAt = now
            timerStartedFor = Calendar.current.startOfDay(for: tracksBothSides ? now : date)
            timerIsOpposite = false
        }
    }

    public mutating func clearTimerDay(on date: Date, at now: Date = Date()) {
        guard trackingMode == .timer else { return }
        expireAlternatingTimer(at: now)
        let key = Self.dateKey(date)
        if tracksBothSides {
            if let sessionDay = timerStartedFor, Self.dateKey(sessionDay) == key {
                finishTimer(at: now)
            }
            // Delete both sides only for the explicitly selected day.
            oppositeTimerEntries?.removeValue(forKey: key)
        }
        entries.removeValue(forKey: key)
    }

    public mutating func configureAlternatingTimer(enabled: Bool, name: String, iconName: String? = nil, at now: Date = Date()) {
        expireAlternatingTimer(at: now)
        if !enabled && timerIsOpposite == true { finishTimer(at: now) }
        if let iconName { oppositeTimerIconName = iconName }
        oppositeTimerName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        alternatingTimerEnabled = enabled && trackingMode == .timer
        // Configuration never starts a timer. The user must press Start.
    }


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
        timerIsOpposite = nil
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
