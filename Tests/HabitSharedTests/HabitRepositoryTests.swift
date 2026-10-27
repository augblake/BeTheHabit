import XCTest
@testable import HabitShared

final class HabitRepositoryTests: XCTestCase {
    func testPrivateBackupRestoresCompleteHabitAndSettings() throws {
        let repository = repository()
        var habit = Habit(name: "Walk", type: .build, trackingMode: .yesNo, notes: "Personal note")
        habit.entries["2026-10-26"] = HabitEntry(value: 1, completed: true)
        habit.archivedTrackingHistory = ["number": TrackingHistory(entries: ["2026-10-25": HabitEntry(value: 8, completed: true)], goal: 5)]
        let backup = HabitBackup(
            habits: [habit], selectedWidgetHabitID: habit.id, lightAppearance: true,
            introductionSeen: true, momentumDaysData: Data([1, 2, 3]), momentumHistorySeeded: true,
            sharingOwnerName: "Bryce", ownedShareIDs: [habit.id]
        )
        let downloaded = try JSONDecoder().decode(HabitBackup.self, from: JSONEncoder().encode(backup))
        XCTAssertEqual(downloaded, backup)
        XCTAssertEqual(try repository.mergeFromCloud(downloaded.habits, selectedWidgetID: downloaded.selectedWidgetHabitID), [habit])
        XCTAssertEqual(try repository.selectedWidgetHabitID(), habit.id)
        XCTAssertEqual(downloaded.sharingOwnerName, "Bryce")
        XCTAssertEqual(downloaded.ownedShareIDs, [habit.id])
    }

    func testCloudRestoreKeepsLocalChangesAndAddsMissingHabits() throws {
        let repository = repository()
        let sharedID = UUID()
        let local = Habit(id: sharedID, name: "Locally edited", type: .build, trackingMode: .yesNo)
        let oldCloud = Habit(id: sharedID, name: "Older cloud copy", type: .build, trackingMode: .yesNo)
        let cloudOnly = Habit(name: "Cloud only", type: .build, trackingMode: .yesNo)
        _ = try repository.update { $0 = [local] }
        let restored = try repository.mergeFromCloud([oldCloud, cloudOnly], selectedWidgetID: cloudOnly.id)
        XCTAssertEqual(restored, [local, cloudOnly])
        XCTAssertEqual(try repository.selectedWidgetHabitID(), cloudOnly.id)
    }

    func testBackupFromBeforeSharingSetupStillDecodes() throws {
        let backup = HabitBackup(
            habits: [], selectedWidgetHabitID: nil, lightAppearance: false,
            introductionSeen: true, momentumDaysData: nil, momentumHistorySeeded: false
        )
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(backup)) as? [String: Any])
        object.removeValue(forKey: "sharingOwnerName")
        object.removeValue(forKey: "ownedShareIDs")
        let decoded = try JSONDecoder().decode(HabitBackup.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.sharingOwnerName)
        XCTAssertNil(decoded.ownedShareIDs)
    }

    func testSharedSnapshotExcludesNotesAndPreservesProgress() throws {
        var habit = Habit(name: "Work", type: .build, trackingMode: .timer, goal: 60, notes: "Private detail")
        habit.entries["2026-10-08"] = HabitEntry(value: 1800, completed: false)
        habit.archivedTrackingHistory = ["number": TrackingHistory(entries: ["2026-10-07": HabitEntry(value: 42, completed: true)], goal: 40)]
        habit.timerStartedAt = Date(timeIntervalSince1970: 1000)
        habit.timerStartedFor = habit.timerStartedAt
        let snapshot = SharedHabitSnapshot(habit: habit, ownerName: "Bryce")
        let data = try JSONEncoder().encode(snapshot)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let shared = try XCTUnwrap(object["habit"] as? [String: Any])
        XCTAssertNil(shared["notes"])
        XCTAssertNil(shared["archivedTrackingHistory"])
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("Private detail"))
        let decoded = try JSONDecoder().decode(SharedHabitSnapshot.self, from: data)
        XCTAssertEqual(decoded.habit.entries, habit.entries)
        XCTAssertEqual(decoded.habit.timerStartedAt, habit.timerStartedAt)
        XCTAssertEqual(decoded.ownerName, "Bryce")
        XCTAssertEqual(habit.notes, "Private detail")
    }

    func testTrackingModeSwitchRestoresSeparateHistory() throws {
        var habit = Habit(name: "Read", type: .build, trackingMode: .number, goal: 20)
        habit.entries["2026-10-08"] = HabitEntry(value: 25, completed: true)
        habit.changeTrackingMode(to: .timer)
        XCTAssertTrue(habit.entries.isEmpty)
        XCTAssertNil(habit.goal)
        habit.goal = 10
        habit.entries["2026-10-09"] = HabitEntry(value: 600, completed: true)
        habit.changeTrackingMode(to: .number)
        XCTAssertEqual(habit.goal, 20)
        XCTAssertEqual(habit.entries["2026-10-08"]?.value, 25)
        XCTAssertNil(habit.entries["2026-10-09"])
        let restored = try JSONDecoder().decode(Habit.self, from: JSONEncoder().encode(habit))
        XCTAssertEqual(restored.archivedTrackingHistory?["timer"]?.entries["2026-10-09"]?.value, 600)
    }

    func testModeSwitchKeepsConcurrentWidgetEntryInArchivedMode() throws {
        let repository = repository()
        let original = Habit(name: "Read", type: .build, trackingMode: .yesNo)
        _ = try repository.update { $0 = [original] }
        let baseline = try repository.load()

        try repository.activate(id: original.id, now: Date())
        var edited = original
        edited.changeTrackingMode(to: .number)
        edited.goal = 20
        let saved = try repository.save([edited], baseline: baseline)

        XCTAssertEqual(saved[0].trackingMode, .number)
        XCTAssertTrue(saved[0].entries.isEmpty)
        XCTAssertEqual(saved[0].archivedTrackingHistory?[TrackingMode.yesNo.rawValue]?
            .entries[Habit.dateKey(Date())]?.completed, true)
    }

    func testExistingHabitWithoutModeHistoryStillLoads() throws {
        let original = Habit(name: "Walk", type: .build, trackingMode: .yesNo)
        let data = try JSONEncoder().encode(original)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "archivedTrackingHistory")
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(Habit.self, from: legacy)
        XCTAssertEqual(decoded.name, "Walk")
        XCTAssertNil(decoded.archivedTrackingHistory)
    }

    func testTrendComparesRecentWeekToPreviousWeek() throws {
        let today = Calendar.current.startOfDay(for: Date())
        var habit = Habit(name: "Walk", type: .build, trackingMode: .yesNo)
        for offset in -13...0 {
            let date = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: offset, to: today))
            habit.entries[Habit.dateKey(date)] = HabitEntry(value: 1, completed: offset >= -6)
        }
        let rising = HabitTrend(habit: habit, today: today)
        XCTAssertEqual(rising.direction, .rising)
        XCTAssertEqual(rising.recentPercent, 100)
        XCTAssertEqual(rising.previousPercent, 0)
        XCTAssertEqual(rising.points.count, 14)

        for key in habit.entries.keys {
            habit.entries[key]?.completed.toggle()
        }
        XCTAssertEqual(HabitTrend(habit: habit, today: today).direction, .falling)
    }

    func testVisibleStreakKeepsYesterdayUntilTodayIsTracked() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: today))
        let before = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -2, to: today))
        for type in HabitType.allCases {
            var habit = Habit(name: "Habit", type: type, trackingMode: .yesNo)
            habit.entries[Habit.dateKey(before)] = HabitEntry(value: 1, completed: true)
            habit.entries[Habit.dateKey(yesterday)] = HabitEntry(value: 1, completed: true)
            XCTAssertEqual(habit.currentStreak(today: today), 0)
            XCTAssertEqual(habit.visibleStreak(today: today), 2)
            habit.entries[Habit.dateKey(today)] = HabitEntry(value: 0, completed: false)
            XCTAssertEqual(habit.visibleStreak(today: today), 0)
            habit.entries[Habit.dateKey(today)] = HabitEntry(value: 1, completed: true)
            XCTAssertEqual(habit.visibleStreak(today: today), 3)
        }
    }

    func testNumericStreakFollowsHabitDirectionAndResetsOnRegression() throws {
        let today = Calendar.current.startOfDay(for: Date())
        func date(_ offset: Int) throws -> String {
            Habit.dateKey(try XCTUnwrap(Calendar.current.date(byAdding: .day, value: offset, to: today)))
        }

        var work = Habit(name: "Work", type: .build, trackingMode: .number)
        work.entries[try date(-3)] = HabitEntry(value: 4, completed: true)
        work.entries[try date(-2)] = HabitEntry(value: 5, completed: true)
        work.entries[try date(-1)] = HabitEntry(value: 3, completed: true)
        work.entries[try date(0)] = HabitEntry(value: 4, completed: true)
        XCTAssertEqual(work.currentStreak(today: today), 1)
        work.entries[try date(0)] = HabitEntry(value: 3, completed: false)
        XCTAssertEqual(work.currentStreak(today: today), 1, "Holding steady continues the streak even below a goal")

        var entertainment = Habit(name: "Entertainment", type: .remove, trackingMode: .number)
        entertainment.entries[try date(-2)] = HabitEntry(value: 3, completed: true)
        entertainment.entries[try date(-1)] = HabitEntry(value: 2, completed: true)
        entertainment.entries[try date(0)] = HabitEntry(value: 4, completed: false)
        XCTAssertEqual(entertainment.currentStreak(today: today), 0)
        XCTAssertEqual(entertainment.visibleStreak(today: today), 0)
        entertainment.entries[try date(0)] = HabitEntry(value: 2, completed: true)
        XCTAssertEqual(entertainment.currentStreak(today: today), 3)
    }

    func testTimerStreakUsesDailyDurationDirection() throws {
        let today = Calendar.current.startOfDay(for: Date())
        var timer = Habit(name: "Focus", type: .build, trackingMode: .timer)
        for (offset, seconds) in [(-2, 600.0), (-1, 900.0), (0, 900.0)] {
            let date = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: offset, to: today))
            timer.entries[Habit.dateKey(date)] = HabitEntry(value: seconds, completed: true)
        }
        XCTAssertEqual(timer.currentStreak(today: today), 3)
        timer.entries[Habit.dateKey(today)] = HabitEntry(value: 300, completed: true)
        XCTAssertEqual(timer.currentStreak(today: today), 0)
    }

    private func repository() -> HabitRepository {
        HabitRepository(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    func testMigrationKeepsExistingSharedData() throws {
        let store = repository()
        let original = Habit(name: "Walk", type: .build, trackingMode: .yesNo)
        try store.migrate(legacyData: JSONEncoder().encode([original]))
        try store.activate(id: original.id)
        try store.migrate(legacyData: JSONEncoder().encode([original]))
        XCTAssertTrue(try store.load()[0].isComplete(on: Date()))
    }

    func testAppDetailsEditPreservesWidgetCheckIn() throws {
        let store = repository()
        let original = Habit(name: "Walk", type: .build, trackingMode: .yesNo)
        try store.migrate(legacyData: JSONEncoder().encode([original]))
        try store.activate(id: original.id)
        var edited = original
        edited.notes = "Outside"
        let merged = try store.save([edited], baseline: [original])
        XCTAssertTrue(merged[0].isComplete(on: Date()))
        XCTAssertEqual(merged[0].notes, "Outside")
    }

    func testTimerPersistsAndAccumulatesAcrossMidnight() throws {
        let store = repository()
        let original = Habit(name: "Read", type: .build, trackingMode: .timer, goal: 1)
        try store.migrate(legacyData: JSONEncoder().encode([original]))
        let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-30)
        try store.activate(id: original.id, now: start)
        let running = try store.load()[0]
        XCTAssertEqual(running.timerStartedAt, start)
        try store.activate(id: original.id, now: start.addingTimeInterval(90))
        let stopped = try store.load()[0]
        XCTAssertNil(stopped.timerStartedAt)
        XCTAssertEqual(stopped.entry(for: start)?.value, 90)
        XCTAssertTrue(stopped.isComplete(on: start))
        XCTAssertNil(stopped.entry(for: start.addingTimeInterval(90)))
    }

    func testDifferentDaysMergeAndDeletion() throws {
        let store = repository()
        let original = Habit(name: "Walk", type: .build, trackingMode: .yesNo)
        let today = Date(), yesterday = today.addingTimeInterval(-86400)
        try store.migrate(legacyData: JSONEncoder().encode([original]))
        try store.activate(id: original.id, now: today)
        var edited = original
        edited.entries[Habit.dateKey(yesterday)] = HabitEntry(value: 1, completed: true)
        let merged = try store.save([edited], baseline: [original])
        XCTAssertTrue(merged[0].isComplete(on: today))
        XCTAssertTrue(merged[0].isComplete(on: yesterday))
        _ = try store.save([], baseline: merged)
        try store.activate(id: original.id)
        XCTAssertTrue(try store.load().isEmpty)
    }

    func testCheckInCanBeUndone() throws {
        let store = repository()
        let original = Habit(name: "Walk", type: .build, trackingMode: .yesNo)
        try store.migrate(legacyData: JSONEncoder().encode([original]))
        try store.activate(id: original.id)
        try store.activate(id: original.id)
        XCTAssertFalse(try store.load()[0].isComplete(on: Date()))
    }

    func testCrossTypeOrderPersistsWithoutLosingWidgetTimer() throws {
        let store = repository()
        let work = Habit(name: "Work", type: .build, trackingMode: .timer)
        let avoid = Habit(name: "Avoid", type: .remove, trackingMode: .number)
        try store.migrate(legacyData: JSONEncoder().encode([work, avoid]))
        try store.activate(id: work.id)
        _ = try store.save([avoid, work], baseline: [work, avoid])
        let saved = try store.load()
        XCTAssertEqual(saved.map(\.id), [avoid.id, work.id])
        XCTAssertNotNil(saved[1].timerStartedAt)
    }

    func testWidgetSelectionIncludesTimerAndSurvivesReordering() throws {
        let store = repository()
        let avoid = Habit(name: "Avoid", type: .remove, trackingMode: .number)
        let work = Habit(name: "Work", type: .build, trackingMode: .timer)
        try store.migrate(legacyData: JSONEncoder().encode([avoid, work]))
        XCTAssertEqual(try store.widgetHabit()?.id, work.id)
        try store.selectWidgetHabit(id: avoid.id)
        _ = try store.save([work, avoid], baseline: [avoid, work])
        XCTAssertEqual(try store.widgetHabit()?.id, avoid.id)
        _ = try store.save([work], baseline: [work, avoid])
        XCTAssertEqual(try store.widgetHabit()?.id, work.id)
    }
}
