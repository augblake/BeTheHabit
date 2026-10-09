import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public struct HabitRepository: Sendable {
    public static let appGroup = "group.XTL-MXQT5L922T.com.example.behabit"
    public static let storageKey = "habitquest.habits"
    private let directory: URL

    public init(directory: URL) { self.directory = directory }

    public static func shared() throws -> Self {
        #if os(iOS)
        guard let directory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
        ) else { throw RepositoryError.unavailable }
        return Self(directory: directory)
        #else
        throw RepositoryError.unavailable
        #endif
    }

    public enum RepositoryError: Error { case unavailable, lockFailed, corruptData }

    private func locked<T>(_ action: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = open(directory.appendingPathComponent("habits.lock").path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw RepositoryError.lockFailed }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw RepositoryError.lockFailed }
        defer { flock(descriptor, LOCK_UN) }
        return try action()
    }

    private var file: URL { directory.appendingPathComponent("habits.json") }
    private func read() throws -> [Habit] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        return try JSONDecoder().decode([Habit].self, from: Data(contentsOf: file))
    }
    public func load() throws -> [Habit] { try locked { try read() } }

    public func selectWidgetHabit(id: UUID) throws {
        try locked {
            guard try read().contains(where: { $0.id == id }) else { return }
            try JSONEncoder().encode(id).write(to: directory.appendingPathComponent("widget-habit.json"), options: .atomic)
        }
    }

    public func widgetHabit() throws -> Habit? {
        try locked {
            let habits = try read()
            let setting = directory.appendingPathComponent("widget-habit.json")
            if FileManager.default.fileExists(atPath: setting.path),
               let id = try? JSONDecoder().decode(UUID.self, from: Data(contentsOf: setting)),
               let habit = habits.first(where: { $0.id == id }) { return habit }
            return habits.first(where: { $0.trackingMode == .timer }) ?? habits.first
        }
    }

    // Keep the original defaults as a backup. Only the containing app migrates.
    public func migrate(legacyData: Data?) throws {
        try locked {
            guard !FileManager.default.fileExists(atPath: file.path) else { return }
            let habits = try legacyData.map { try JSONDecoder().decode([Habit].self, from: $0) } ?? []
            try JSONEncoder().encode(habits).write(to: file, options: .atomic)
        }
    }

    public func update(_ action: (inout [Habit]) throws -> Void) throws -> [Habit] {
        try locked {
            var habits = try read()
            try action(&habits)
            try JSONEncoder().encode(habits).write(to: file, options: .atomic)
            return habits
        }
    }

    // Merge only fields edited by the app, preserving concurrent widget actions.
    public func save(_ updated: [Habit], baseline: [Habit]) throws -> [Habit] {
        try update { current in
            let old = Dictionary(uniqueKeysWithValues: baseline.map { ($0.id, $0) })
            let desired = Set(updated.map(\.id))
            current.removeAll { old[$0.id] != nil && !desired.contains($0.id) }
            for habit in updated {
                guard let before = old[habit.id] else {
                    if !current.contains(where: { $0.id == habit.id }) { current.append(habit) }
                    continue
                }
                guard let index = current.firstIndex(where: { $0.id == habit.id }) else { continue }
                let encoder = JSONEncoder()
                func object(_ value: Habit) throws -> [String: Any] {
                    guard let result = try JSONSerialization.jsonObject(with: encoder.encode(value)) as? [String: Any] else {
                        throw RepositoryError.corruptData
                    }
                    return result
                }
                let a = try object(before), b = try object(habit)
                var merged = try object(current[index])
                for key in Set(a.keys).union(b.keys) {
                    if key == "entries" {
                        let previous = a[key] as? [String: Any] ?? [:]
                        let next = b[key] as? [String: Any] ?? [:]
                        var entries = merged[key] as? [String: Any] ?? [:]
                        for date in Set(previous.keys).union(next.keys) where !Self.equal(previous[date], next[date]) {
                            entries[date] = next[date]
                        }
                        merged[key] = entries
                    } else if !Self.equal(a[key], b[key]) { merged[key] = b[key] }
                }
                current[index] = try JSONDecoder().decode(Habit.self, from: JSONSerialization.data(withJSONObject: merged))
            }
            let order = Dictionary(uniqueKeysWithValues: updated.enumerated().map { ($0.element.id, $0.offset) })
            current.sort { (order[$0.id] ?? Int.max) < (order[$1.id] ?? Int.max) }
        }
    }

    private static func equal(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case let (a?, b?): return (a as? NSObject)?.isEqual(b) ?? false
        default: return false
        }
    }

    public func activate(id: UUID, now: Date = Date()) throws {
        _ = try update { habits in
            guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
            var habit = habits[index]
            switch habit.trackingMode {
            case .yesNo:
                let key = Habit.dateKey(now)
                let old = habit.entries[key]
                habit.entries[key] = HabitEntry(value: old?.value ?? (habit.type == .remove ? 0 : 1), completed: !(old?.completed ?? false))
            case .timer:
                if let start = habit.timerStartedAt {
                    let key = Habit.dateKey(habit.timerStartedFor ?? now)
                    let seconds = (habit.entries[key]?.value ?? 0) + max(0, now.timeIntervalSince(start))
                    habit.entries[key] = HabitEntry(value: seconds, completed: seconds > 0 && (habit.goal.map { seconds >= $0 * 60 } ?? true))
                    habit.timerStartedAt = nil
                    habit.timerStartedFor = nil
                } else {
                    habit.timerStartedAt = now
                    habit.timerStartedFor = Calendar.current.startOfDay(for: now)
                }
            case .number: return
            }
            habits[index] = habit
        }
    }
}
