import XCTest
@testable import HabitShared

final class HabitRepositoryTests: XCTestCase {
    func testSharedSnapshotExcludesNotesAndPreservesProgress() throws {
        var habit = Habit(name: "Work", type: .build, trackingMode: .timer, goal: 60, notes: "Private detail")
        habit.entries["2026-10-08"] = HabitEntry(value: 1800, completed: false)
        habit.timerStartedAt = Date(timeIntervalSince1970: 1000)
        habit.timerStartedFor = habit.timerStartedAt
        let snapshot = SharedHabitSnapshot(habit: habit, ownerName: "Bryce")
        let data = try JSONEncoder().encode(snapshot)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let shared = try XCTUnwrap(object["habit"] as? [String: Any])
        XCTAssertNil(shared["notes"])
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("Private detail"))
        let decoded = try JSONDecoder().decode(SharedHabitSnapshot.self, from: data)
        XCTAssertEqual(decoded.habit.entries, habit.entries)
        XCTAssertEqual(decoded.habit.timerStartedAt, habit.timerStartedAt)
        XCTAssertEqual(decoded.ownerName, "Bryce")
        XCTAssertEqual(habit.notes, "Private detail")
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
