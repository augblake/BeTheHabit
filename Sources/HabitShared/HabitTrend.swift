import Foundation

public struct HabitTrendPoint: Identifiable {
    public let date: Date
    public let percent: Double

    public var id: Date { date }
}

public enum HabitTrendDirection: Equatable {
    case building
    case rising
    case falling
    case steady
}

public struct HabitTrend {
    public let points: [HabitTrendPoint]
    public let direction: HabitTrendDirection
    public let recentPercent: Double?
    public let previousPercent: Double?

    public init(habit: Habit, today: Date = Date()) {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: today)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        guard let firstEntry = habit.entries.keys.compactMap(formatter.date(from:)).min(),
              firstEntry <= end,
              let maximumStart = calendar.date(byAdding: .day, value: -27, to: end) else {
            points = []
            direction = .building
            recentPercent = nil
            previousPercent = nil
            return
        }

        let start = max(calendar.startOfDay(for: firstEntry), maximumStart)
        let dayCount = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        let dates = (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        points = dates.indices.map { index in
            let window = dates[max(0, index - 6)...index]
            let completed = window.filter { habit.isComplete(on: $0) }.count
            return HabitTrendPoint(date: dates[index], percent: Double(completed) / Double(window.count) * 100)
        }

        guard dates.count >= 14 else {
            direction = .building
            recentPercent = nil
            previousPercent = nil
            return
        }

        let recent = dates.suffix(7).filter { habit.isComplete(on: $0) }.count
        let previous = dates.dropLast(7).suffix(7).filter { habit.isComplete(on: $0) }.count
        recentPercent = Double(recent) / 7 * 100
        previousPercent = Double(previous) / 7 * 100
        if recent > previous {
            direction = .rising
        } else if recent < previous {
            direction = .falling
        } else {
            direction = .steady
        }
    }
}
