import Foundation
import XCTest
@testable import HabitShared

final class TimerControlsTests: XCTestCase {
    private var start: Date { Calendar.current.startOfDay(for: Date()).addingTimeInterval(3600) }

    private func habit() -> Habit {
        var value = Habit(name: "Work", type: .build, trackingMode: .timer)
        value.configureAlternatingTimer(enabled: true, name: "Rest", at: start)
        return value
    }

    func testStopSavesEitherSideWithoutStartingOtherSide() {
        for opposite in [false, true] {
            var value = habit()
            value.activateTimer(on: start, at: start)
            if opposite { value.activateTimer(on: start, at: start.addingTimeInterval(10)) }
            value.finishTimer(at: start.addingTimeInterval(60))
            XCTAssertNil(value.timerStartedAt)
            XCTAssertFalse(value.runningOpposite)
            XCTAssertEqual(value.timerSeconds(on: start, opposite: opposite, at: start.addingTimeInterval(100)), opposite ? 50 : 60)
            value.activateTimer(on: start, at: start.addingTimeInterval(120))
            XCTAssertFalse(value.runningOpposite)
            XCTAssertEqual(value.timerStartedAt, start.addingTimeInterval(120))
        }
    }

    func testDeleteWhileEitherSideRunsClearsDayAndWaitsForStart() {
        for opposite in [false, true] {
            var value = habit()
            let previous = Calendar.current.date(byAdding: .day, value: -1, to: start)!
            value.entries[Habit.dateKey(previous)] = HabitEntry(value: 100, completed: true)
            value.oppositeTimerEntries = [Habit.dateKey(previous): HabitEntry(value: 200, completed: true)]
            value.activateTimer(on: start, at: start)
            if opposite { value.activateTimer(on: start, at: start.addingTimeInterval(10)) }
            value.clearTimerDay(on: start, at: start.addingTimeInterval(60))
            XCTAssertNil(value.timerStartedAt)
            XCTAssertNil(value.entry(for: start))
            XCTAssertNil(value.oppositeTimerEntries?[Habit.dateKey(start)])
            XCTAssertEqual(value.entry(for: previous)?.value, 100)
            XCTAssertEqual(value.oppositeTimerEntries?[Habit.dateKey(previous)]?.value, 200)
            XCTAssertEqual(value.timerSeconds(on: start, opposite: true, at: start.addingTimeInterval(300)), 0)
            value.configureAlternatingTimer(enabled: true, name: "Rest", at: start.addingTimeInterval(300))
            XCTAssertNil(value.timerStartedAt)
            value.activateTimer(on: start, at: start.addingTimeInterval(400))
            XCTAssertFalse(value.runningOpposite)
            XCTAssertEqual(value.timerStartedAt, start.addingTimeInterval(400))
        }
    }

    func testDeleteHistoryDoesNotStopTodaysSession() {
        var value = habit()
        value.activateTimer(on: start, at: start)
        let previous = Calendar.current.date(byAdding: .day, value: -1, to: start)!
        value.clearTimerDay(on: previous, at: start.addingTimeInterval(60))
        XCTAssertEqual(value.timerStartedAt, start)
        XCTAssertEqual(value.timerSeconds(on: start, at: start.addingTimeInterval(60)), 60)
    }

    func testWidgetStartThenStopKeepsAlternatingUntilMidnight() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = HabitRepository(directory: url)
        let initial = habit()
        _ = try repository.update { $0 = [initial] }
        XCTAssertNil(try repository.load(now: start).first?.timerStartedAt)
        try repository.activate(id: initial.id, now: start)
        XCTAssertFalse(try XCTUnwrap(repository.load(now: start).first).runningOpposite)
        try repository.activate(id: initial.id, now: start.addingTimeInterval(10))
        XCTAssertTrue(try XCTUnwrap(repository.load(now: start.addingTimeInterval(10)).first).runningOpposite)
        try repository.activate(id: initial.id, now: start.addingTimeInterval(20))
        XCTAssertFalse(try XCTUnwrap(repository.load(now: start.addingTimeInterval(20)).first).runningOpposite)
        let midnight = try XCTUnwrap(initialTimerCutoff(start))
        XCTAssertNil(try repository.load(now: midnight).first?.timerStartedAt)
    }

    private func initialTimerCutoff(_ date: Date) -> Date? {
        Calendar.current.dateInterval(of: .day, for: date)?.end
    }
}
