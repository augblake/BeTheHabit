import HabitShared
import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class HabitStore: ObservableObject {
    @Published private(set) var habits: [Habit] = []
    @Published private(set) var storageError: String?

    private let storageKey = HabitRepository.storageKey
    private var baseline: [Habit] = []
    private var repository: HabitRepository?

    init() {
        load()
    }

    func addHabit(
        name: String,
        type: HabitType,
        trackingMode: TrackingMode,
        goal: Double?,
        iconName: String? = nil,
        iconColorHex: String? = nil,
        tracksBothSides: Bool = false,
        oppositeName: String = "Other time",
        oppositeIconName: String? = nil
    ) {
        guard HabitValidation.isSafeGoal(goal, mode: trackingMode) else { return }
        var habit = Habit(
            name: name,
            type: type,
            trackingMode: trackingMode,
            goal: goal,
            iconName: iconName,
            iconColorHex: iconColorHex
        )

        if tracksBothSides {
            habit.configureAlternatingTimer(enabled: true, name: oppositeName, iconName: oppositeIconName)
        }
        habits.append(habit)
        save()
    }

    func deleteHabit(_ habit: Habit) {
        deleteHabits(ids: [habit.id])
    }

    func deleteHabits(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        habits.removeAll { ids.contains($0.id) }
        save()
    }

    func moveHabit(_ habit: Habit, by offset: Int) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }),
              habits.indices.contains(index + offset) else { return }
        habits.swapAt(index, index + offset)
        save()
    }

    func canMoveHabit(_ habit: Habit, by offset: Int) -> Bool {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return false }
        return habits.indices.contains(index + offset)
    }

    func moveHabit(id: UUID, to target: UUID) {
        guard let source = habits.firstIndex(where: { $0.id == id }),
              let destination = habits.firstIndex(where: { $0.id == target }),
              source != destination else { return }
        let moved = habits.remove(at: source)
        habits.insert(moved, at: destination)
        save()
    }

    func showInWidget(_ habit: Habit) throws {
        let shared = try HabitRepository.shared()
        try shared.selectWidgetHabit(id: habit.id)
        WidgetCenter.shared.reloadAllTimelines()
        CloudHabitBackup.shared.changed()
    }

    func cloudBackup() throws -> HabitBackup {
        guard let repository else { throw HabitRepository.RepositoryError.unavailable }
        let defaults = UserDefaults.standard
        return HabitBackup(
            habits: try repository.load(),
            selectedWidgetHabitID: try repository.selectedWidgetHabitID(),
            lightAppearance: defaults.bool(forKey: "habitquest.lightAppearance"),
            introductionSeen: defaults.bool(forKey: "habitquest.introductionSeen"),
            momentumDaysData: defaults.data(forKey: "habitquest.momentumDays"),
            momentumHistorySeeded: defaults.bool(forKey: "habitquest.momentumHistorySeeded"),
            sharingOwnerName: defaults.string(forKey: "behabit.shareName"),
            ownedShareIDs: (defaults.stringArray(forKey: "behabit.ownedShares") ?? [])
                .compactMap(UUID.init(uuidString:)).sorted { $0.uuidString < $1.uuidString }
        )
    }

    func restoreFromCloud(_ backup: HabitBackup) throws {
        guard backup.version == 1 else { throw HabitRepository.RepositoryError.corruptData }
        guard let repository else { throw HabitRepository.RepositoryError.unavailable }
        let hadLocalHabits = !habits.isEmpty
        habits = try repository.mergeFromCloud(backup.habits, selectedWidgetID: backup.selectedWidgetHabitID)
        baseline = habits
        if !hadLocalHabits {
            let defaults = UserDefaults.standard
            defaults.set(backup.lightAppearance, forKey: "habitquest.lightAppearance")
            defaults.set(backup.introductionSeen, forKey: "habitquest.introductionSeen")
            defaults.set(backup.momentumDaysData, forKey: "habitquest.momentumDays")
            defaults.set(backup.momentumHistorySeeded, forKey: "habitquest.momentumHistorySeeded")
            if let name = backup.sharingOwnerName {
                defaults.set(name, forKey: "behabit.shareName")
            }
            if let ids = backup.ownedShareIDs {
                CloudHabitSharing.shared.restoreOwnedShares(ids, habits: habits)
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func updateDetails(
        for habit: Habit,
        notes: String,
        iconName: String,
        iconColorHex: String?,
        goal: Double?
    ) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else {
            return
        }

        guard HabitValidation.isSafeGoal(goal, mode: habits[index].trackingMode) else { return }
        habits[index].notes = notes
        habits[index].iconName = iconName
        habits[index].iconColorHex = iconColorHex
        habits[index].goal = goal

        if habits[index].trackingMode == .number || habits[index].trackingMode == .timer {
            for key in Array(habits[index].entries.keys) {
                guard var entry = habits[index].entries[key] else { continue }
                entry.completed = completionStatus(
                    type: habits[index].type,
                    mode: habits[index].trackingMode,
                    value: entry.value,
                    goal: goal
                )
                habits[index].entries[key] = entry
            }
        }

        save()
    }

    func editHabit(
        _ habit: Habit,
        name: String,
        trackingMode: TrackingMode,
        goal: Double?,
        iconName: String,
        iconColorHex: String
    ) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty, HabitValidation.isSafeGoal(goal, mode: trackingMode) else { return }

        if trackingMode != habits[index].trackingMode {
            habits[index].finishTimer()
        }

        habits[index].changeTrackingMode(to: trackingMode)
        habits[index].name = cleanedName
        habits[index].iconName = iconName
        habits[index].iconColorHex = iconColorHex
        habits[index].goal = trackingMode == .yesNo ? nil : goal
        if trackingMode != .yesNo {
            for key in Array(habits[index].entries.keys) {
                guard var entry = habits[index].entries[key] else { continue }
                entry.completed = completionStatus(
                    type: habits[index].type,
                    mode: trackingMode,
                    value: entry.value,
                    goal: habits[index].goal
                )
                habits[index].entries[key] = entry
            }
        }
        save()
    }

    func toggle(_ habit: Habit, on date: Date) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else {
            return
        }

        let key = Habit.dateKey(date)

        if let existing = habits[index].entries[key] {
            habits[index].entries[key] = HabitEntry(
                value: existing.value,
                completed: !existing.completed
            )
        } else {
            habits[index].entries[key] = HabitEntry(
                value: habit.type == .remove ? 0 : 1,
                completed: true
            )
        }

        save()
    }

    func setNumber(_ habit: Habit, value: Double, on date: Date) {
        guard HabitValidation.isSafeNumber(value) else { return }
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else {
            return
        }

        let key = Habit.dateKey(date)

        habits[index].entries[key] = HabitEntry(
            value: value,
            completed: completionStatus(
                type: habit.type,
                mode: .number,
                value: value,
                goal: habit.goal
            )
        )

        save()
    }

    private func performTimerAction(_ habit: Habit, action: HabitTimerAction, on date: Date) {
        do {
            if let repository {
                // Commit any unsaved UI edits first rather than silently losing them.
                if storageError != nil { save() }
                guard storageError == nil else { return }
                habits = try repository.performTimerAction(id: habit.id, action: action, on: date)
                baseline = habits
                WidgetCenter.shared.reloadAllTimelines()
                CloudHabitBackup.shared.changed()
            } else {
                guard let index = habits.firstIndex(where: { $0.id == habit.id }), habits[index].trackingMode == .timer else { return }
                switch action {
                case .start:
                    habits[index].expireAlternatingTimer()
                    if habits[index].timerStartedAt == nil { habits[index].activateTimer(on: date) }
                case .switchSide:
                    habits[index].expireAlternatingTimer()
                    if habits[index].timerIsActive() { habits[index].activateTimer(on: date) }
                case .stop: habits[index].finishTimer()
                case .clearDay: habits[index].clearTimerDay(on: date)
                case let .configure(enabled, name, iconName):
                    habits[index].configureAlternatingTimer(enabled: enabled, name: name, iconName: iconName)
                }
                save()
            }
        } catch { storageError = "Timer changes could not be saved. Please try again." }
    }

    func configureAlternatingTimer(_ habit: Habit, enabled: Bool, name: String, iconName: String? = nil) {
        performTimerAction(habit, action: .configure(enabled: enabled, name: name, iconName: iconName), on: Date())
    }

    func startTimer(_ habit: Habit, on date: Date) {
        performTimerAction(habit, action: .start, on: date)
    }

    func switchTimer(_ habit: Habit, on date: Date) {
        performTimerAction(habit, action: .switchSide, on: date)
    }

    func stopTimer(_ habit: Habit, on date: Date) {
        performTimerAction(habit, action: .stop, on: date)
    }

    func setTimerTime(_ habit: Habit, minutes: Double, on date: Date) {
        guard minutes >= 0, HabitValidation.isSafeNumber(minutes * 60) else { return }
        guard let index = habits.firstIndex(where: { $0.id == habit.id }),
              habits[index].trackingMode == .timer else {
            return
        }

        let key = Habit.dateKey(date)
        let seconds = max(0, minutes) * 60
        if seconds == 0 {
            habits[index].entries.removeValue(forKey: key)
        } else {
            habits[index].entries[key] = HabitEntry(
                value: seconds,
                completed: completionStatus(
                    type: habits[index].type,
                    mode: .timer,
                    value: seconds,
                    goal: habits[index].goal
                )
            )
        }

        save()
    }

    func clearTimerTime(_ habit: Habit, on date: Date) {
        performTimerAction(habit, action: .clearDay, on: date)
    }

    func timerIsRunning(_ habit: Habit) -> Bool {
        habits.first(where: { $0.id == habit.id })?.timerIsActive() ?? false
    }

    func timerDate(_ habit: Habit, fallback: Date) -> Date {
        habits.first(where: { $0.id == habit.id })?.timerStartedFor ?? fallback
    }

    func timerElapsed(_ habit: Habit, on date: Date, at now: Date = Date()) -> TimeInterval {
        guard let currentHabit = habits.first(where: { $0.id == habit.id }) else {
            return 0
        }

        return currentHabit.timerSeconds(on: date, at: now)
    }

    func entry(for habit: Habit, on date: Date) -> HabitEntry? {
        habit.entry(for: date)
    }

    private func save() {
        do {
            if let repository {
                habits = try repository.save(habits, baseline: baseline)
            } else {
                UserDefaults.standard.set(try JSONEncoder().encode(habits), forKey: storageKey)
            }
            baseline = habits
            storageError = nil
            WidgetCenter.shared.reloadAllTimelines()
            CloudHabitBackup.shared.changed()
        } catch { storageError = "Changes could not be saved. Your previous saved data is unchanged. Please try again." }
    }

    func expireAlternatingTimers(at now: Date = Date()) {
        guard habits.contains(where: { $0.timerCutoff().map { now >= $0 } ?? false }) else { return }
        // Refresh first so a newer widget switch cannot be overwritten by stale app state.
        if repository != nil { refresh() }
        var changed = false
        for index in habits.indices {
            if habits[index].expireAlternatingTimer(at: now) { changed = true }
        }
        if changed { save() }
        else { WidgetCenter.shared.reloadAllTimelines() }
    }

    func refresh() {
        // Preserve edits after a failed save instead of replacing them on the next refresh.
        guard storageError == nil, let repository else { return }
        do {
            let loaded = try repository.load()
            if loaded != habits {
                habits = loaded
                CloudHabitBackup.shared.changed()
            }
            baseline = loaded
        } catch { print("BeHabit refresh error:", error) }
    }

    private func completionStatus(
        type: HabitType,
        mode: TrackingMode,
        value: Double,
        goal: Double?
    ) -> Bool {
        switch mode {
        case .yesNo:
            return value > 0
        case .number:
            if type == .remove {
                return value <= (goal ?? 0)
            }
            return goal.map { value >= $0 } ?? (value > 0)
        case .timer:
            guard value > 0 else { return false }
            return goal.map { value >= $0 * 60 } ?? true
        }
    }

    private func load() {
        do {
            let repository = try HabitRepository.shared()
            try repository.migrate(legacyData: UserDefaults.standard.data(forKey: storageKey))
            habits = try repository.load()
            self.repository = repository
            baseline = habits
        } catch {
            // Keep the installed app usable while signing is being configured.
            if let data = UserDefaults.standard.data(forKey: storageKey) {
                do {
                    let legacy = try JSONDecoder().decode([Habit].self, from: data)
                    try HabitValidation.validate(legacy)
                    habits = legacy
                }
                catch { print("BeHabit legacy load error:", error) }
            }
            baseline = habits
            storageError = "Shared habit storage is unavailable. Existing files have been preserved."
            print("BeTheHabit shared storage unavailable:", error)
        }
    }
}
