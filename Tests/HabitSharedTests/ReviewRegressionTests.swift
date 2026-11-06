import Foundation
import XCTest
@testable import HabitShared

final class ReviewRegressionTests: XCTestCase {
    private var start: Date { Calendar.current.startOfDay(for: Date()).addingTimeInterval(3600) }
    private func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }

    func testDuplicateIDsAreRejectedBeforeDictionaryConstruction() throws {
        let url = directory()
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = HabitRepository(directory: url)
        let habit = Habit(name: "Walk", type: .build, trackingMode: .yesNo)
        _ = try repository.update { $0 = [habit] }
        XCTAssertThrowsError(try repository.save([habit], baseline: [habit, habit]))
        XCTAssertEqual(try repository.load(), [habit])
    }

    func testDuplicateIDsInFileFailWithoutOverwritingFile() throws {
        let url = directory()
        defer { try? FileManager.default.removeItem(at: url) }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let habit = Habit(name: "Walk", type: .build, trackingMode: .yesNo)
        let data = try JSONEncoder().encode([habit, habit])
        let file = url.appendingPathComponent("habits.json")
        try data.write(to: file)
        XCTAssertThrowsError(try HabitRepository(directory: url).load())
        XCTAssertEqual(try Data(contentsOf: file), data)
    }

    func testNonFiniteAndUnsafeNumbersAreRejected() {
        for value in [Double.nan, Double.infinity, -Double.infinity, 1e100, Double(Int.max)] {
            XCTAssertFalse(HabitValidation.isSafeNumber(value))
        }
        XCTAssertTrue(HabitValidation.isSafeNumber(0))
        XCTAssertTrue(HabitValidation.isSafeNumber(-2.5))
        XCTAssertFalse(HabitValidation.isSafeGoal(1e100, mode: .timer))
    }

    func testInvalidUpdateDoesNotReplaceExistingData() throws {
        let url = directory()
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = HabitRepository(directory: url)
        var habit = Habit(name: "Count", type: .build, trackingMode: .number)
        _ = try repository.update { $0 = [habit] }
        habit.entries[Habit.dateKey(start)] = HabitEntry(value: 1e100, completed: true)
        XCTAssertThrowsError(try repository.update { $0 = [habit] })
        XCTAssertTrue(try XCTUnwrap(repository.load().first).entries.isEmpty)
    }

    func testAppStopUsesLatestWidgetSideWithoutLosingEitherTotal() throws {
        let url = directory()
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = HabitRepository(directory: url)
        var habit = Habit(name: "Work", type: .build, trackingMode: .timer)
        habit.configureAlternatingTimer(enabled: true, name: "Rest", at: start)
        _ = try repository.update { $0 = [habit] }
        _ = try repository.performTimerAction(id: habit.id, action: .start, on: start, now: start)
        // The app still displays primary. The widget switches to the other side.
        try repository.activate(id: habit.id, now: start.addingTimeInterval(60))
        let stopped = try XCTUnwrap(repository.performTimerAction(id: habit.id, action: .stop, on: start, now: start.addingTimeInterval(90)).first)
        XCTAssertEqual(stopped.entry(for: start)?.value, 60)
        XCTAssertEqual(stopped.oppositeTimerEntries?[Habit.dateKey(start)]?.value, 30)
        XCTAssertNil(stopped.timerStartedAt)
    }

    func testStaleStartDoesNotRestartAlreadyRunningWidgetTimer() throws {
        let url = directory()
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = HabitRepository(directory: url)
        let habit = Habit(name: "Work", type: .build, trackingMode: .timer)
        _ = try repository.update { $0 = [habit] }
        try repository.activate(id: habit.id, now: start)
        let running = try XCTUnwrap(repository.performTimerAction(id: habit.id, action: .start, on: start, now: start.addingTimeInterval(30)).first)
        XCTAssertEqual(running.timerStartedAt, start)
    }

    func testNegativeTimerRecordsAndExtremeDatesAreRejected() {
        var habit = Habit(name: "Work", type: .build, trackingMode: .timer)
        habit.entries[Habit.dateKey(start)] = HabitEntry(value: -1, completed: false)
        XCTAssertThrowsError(try HabitValidation.validate([habit]))
        habit.entries = [:]
        habit.timerStartedAt = Date(timeIntervalSince1970: 1e100)
        XCTAssertThrowsError(try HabitValidation.validate([habit]))
    }
}
