import Foundation

public enum HabitValidation {
    public static func isSafeNumber(_ value: Double) -> Bool {
        value.isFinite && abs(value) < Double(Int.max) / 4
    }

    public static func isSafeGoal(_ goal: Double?, mode: TrackingMode) -> Bool {
        guard let goal else { return true }
        return isSafeNumber(goal) && (mode != .timer || isSafeNumber(goal * 60))
    }

    public static func validate(_ habits: [Habit]) throws {
        var ids = Set<UUID>()
        for habit in habits {
            guard ids.insert(habit.id).inserted,
                  isSafeGoal(habit.goal, mode: habit.trackingMode),
                  habit.entries.values.allSatisfy({ isSafeNumber($0.value) && (habit.trackingMode != .timer || $0.value >= 0) }),
                  (habit.oppositeTimerEntries ?? [:]).values.allSatisfy({ isSafeNumber($0.value) && $0.value >= 0 }) else {
                throw HabitRepository.RepositoryError.corruptData
            }
            for date in [habit.timerStartedAt, habit.timerStartedFor].compactMap({ $0 }) {
                guard date.timeIntervalSince1970.isFinite, date >= Date.distantPast, date <= Date.distantFuture else {
                    throw HabitRepository.RepositoryError.corruptData
                }
            }
            for (mode, history) in habit.archivedTrackingHistory ?? [:] {
                let timer = mode == TrackingMode.timer.rawValue
                guard isSafeGoal(history.goal, mode: timer ? .timer : .number),
                      history.entries.values.allSatisfy({ isSafeNumber($0.value) && (!timer || $0.value >= 0) }) else {
                    throw HabitRepository.RepositoryError.corruptData
                }
            }
        }
    }
}

public enum HabitTimerAction {
    case start
    case switchSide
    case stop
    case clearDay
    case configure(enabled: Bool, name: String, iconName: String?)
}
