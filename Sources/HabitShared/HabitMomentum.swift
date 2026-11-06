import Foundation

public enum HabitMomentum {
    public static func recordedDays(habits: [Habit], at now: Date = Date()) -> Set<String> {
        let today = Habit.dateKey(now)
        var days = Set<String>()
        for habit in habits {
            days.formUnion(habit.entries.keys.filter { $0 <= today })
            days.formUnion((habit.oppositeTimerEntries ?? [:]).keys.filter { $0 <= today })
            for history in habit.archivedTrackingHistory?.values ?? Dictionary<String, TrackingHistory>().values {
                days.formUnion(history.entries.keys.filter { $0 <= today })
            }
            if habit.trackingMode == .timer, let start = habit.timerStartedAt,
               let day = habit.timerStartedFor,
               min(now, habit.timerCutoff() ?? now) > start,
               Habit.dateKey(day) <= today {
                days.insert(Habit.dateKey(day))
            }
        }
        return days
    }

    public static func currentStreak(habits: [Habit], at now: Date = Date()) -> Int {
        let days = recordedDays(habits: habits, at: now)
        let calendar = Calendar.current
        var date = calendar.startOfDay(for: now)
        // Give the current day time to be tracked, as with individual habit streaks.
        if !days.contains(Habit.dateKey(date)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date) else { return 0 }
            date = yesterday
        }
        var count = 0
        while days.contains(Habit.dateKey(date)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previous
        }
        return count
    }
}
