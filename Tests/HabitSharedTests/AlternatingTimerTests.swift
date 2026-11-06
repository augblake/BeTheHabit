import Foundation
import XCTest
@testable import HabitShared

final class AlternatingTimerTests: XCTestCase {
    private var start: Date { Calendar.current.startOfDay(for: Date()).addingTimeInterval(3600) }

    func testOppositeIconPersistsAndChangesWithActiveSide() throws {
        var habit = Habit(name: "Work", type: .build, trackingMode: .timer, iconName: "briefcase")
        habit.configureAlternatingTimer(enabled: true, name: "Leisure", iconName: "gamecontroller", at: start)
        XCTAssertNil(habit.timerStartedAt)
        habit = try JSONDecoder().decode(Habit.self, from: JSONEncoder().encode(habit))
        XCTAssertEqual(habit.oppositeTimerIconName, "gamecontroller")
        habit.activateTimer(on: start, at: start.addingTimeInterval(10))
        XCTAssertEqual(habit.activeTimerIconName, "briefcase")
        habit.activateTimer(on: start, at: start.addingTimeInterval(20))
        XCTAssertEqual(habit.activeTimerIconName, "gamecontroller")
    }

    func testExistingHabitDecodesWithoutNewFields() throws {
        let original = Habit(name: "Work", type: .build, trackingMode: .timer)
        let restored = try JSONDecoder().decode(Habit.self, from: JSONEncoder().encode(original))
        XCTAssertFalse(restored.tracksBothSides)
        XCTAssertFalse(restored.runningOpposite)
        XCTAssertNil(restored.oppositeTimerEntries)
    }

    func testOrdinaryTimerStillStops() {
        var habit = Habit(name: "Work", type: .build, trackingMode: .timer, goal: 1)
        habit.activateTimer(on: start, at: start)
        habit.activateTimer(on: start, at: start.addingTimeInterval(90))
        XCTAssertNil(habit.timerStartedAt)
        XCTAssertEqual(habit.entry(for: start)?.value, 90)
        XCTAssertEqual(habit.entry(for: start)?.completed, true)
    }

    func testSwitchesAccumulateSeparatelyWithoutGaps() {
        var habit = Habit(name: "Entertainment", type: .remove, trackingMode: .timer)
        habit.activateTimer(on: start, at: start)
        habit.configureAlternatingTimer(enabled: true, name: "No entertainment", at: start.addingTimeInterval(5))
        habit.activateTimer(on: start, at: start.addingTimeInterval(60))
        XCTAssertTrue(habit.runningOpposite)
        XCTAssertEqual(habit.timerStartedAt, start.addingTimeInterval(60))
        XCTAssertEqual(habit.timerSeconds(on: start, at: start.addingTimeInterval(90)), 60)
        XCTAssertEqual(habit.timerSeconds(on: start, opposite: true, at: start.addingTimeInterval(90)), 30)
        habit.activateTimer(on: start, at: start.addingTimeInterval(90))
        XCTAssertFalse(habit.runningOpposite)
        XCTAssertEqual(habit.oppositeTimerEntries?[Habit.dateKey(start)]?.value, 30)
        XCTAssertEqual(habit.timerSeconds(on: start, at: start.addingTimeInterval(100)), 70)
    }

    func testOptInWhileStoppedWaitsForStartAndSurvivesReload() throws {
        var habit = Habit(name: "Work", type: .build, trackingMode: .timer)
        habit.configureAlternatingTimer(enabled: true, name: "Leisure", at: start)
        let restored = try JSONDecoder().decode(Habit.self, from: JSONEncoder().encode(habit))
        XCTAssertTrue(restored.tracksBothSides)
        XCTAssertFalse(restored.runningOpposite)
        XCTAssertNil(restored.timerStartedAt)
        XCTAssertEqual(restored.activeTimerName, "Work")
        XCTAssertEqual(restored.timerSeconds(on: start, opposite: true, at: start.addingTimeInterval(300)), 0)
        XCTAssertEqual(restored.timerSeconds(on: start, at: start.addingTimeInterval(300)), 0)
    }

    func testDisablingOppositeSavesItsTimeAndKeepsHistory() {
        var habit = Habit(name: "Work", type: .build, trackingMode: .timer)
        habit.configureAlternatingTimer(enabled: true, name: "Leisure", at: start)
        habit.activateTimer(on: start, at: start)
        habit.activateTimer(on: start, at: start.addingTimeInterval(10))
        habit.configureAlternatingTimer(enabled: false, name: "Leisure", at: start.addingTimeInterval(45))
        XCTAssertFalse(habit.tracksBothSides)
        XCTAssertNil(habit.timerStartedAt)
        XCTAssertEqual(habit.oppositeTimerEntries?[Habit.dateKey(start)]?.value, 35)
        habit.configureAlternatingTimer(enabled: true, name: "Rest", at: start.addingTimeInterval(90))
        XCTAssertNil(habit.timerStartedAt)
        XCTAssertEqual(habit.timerSeconds(on: start, opposite: true, at: start.addingTimeInterval(100)), 35)
    }

    func testDisablingDuringPrimaryKeepsItsExistingSession() {
        var habit = Habit(name: "Work", type: .build, trackingMode: .timer)
        habit.activateTimer(on: start, at: start)
        habit.configureAlternatingTimer(enabled: true, name: "Leisure", at: start)
        habit.configureAlternatingTimer(enabled: false, name: "Leisure", at: start.addingTimeInterval(10))
        XCTAssertEqual(habit.timerStartedAt, start)
        habit.activateTimer(on: start, at: start.addingTimeInterval(30))
        XCTAssertNil(habit.timerStartedAt)
        XCTAssertEqual(habit.entry(for: start)?.value, 30)
    }

    func testWidgetUsesSameAlternatingStateAfterReload() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = HabitRepository(directory: url)
        var habit = Habit(name: "Work", type: .build, trackingMode: .timer)
        habit.configureAlternatingTimer(enabled: true, name: "Leisure", at: start)
        _ = try repository.update { $0 = [habit] }
        try repository.activate(id: habit.id, now: start)
        try repository.activate(id: habit.id, now: start.addingTimeInterval(40))
        let switched = try XCTUnwrap(repository.load(now: start.addingTimeInterval(40)).first)
        XCTAssertTrue(switched.runningOpposite)
        XCTAssertEqual(switched.timerStartedAt, start.addingTimeInterval(40))
        XCTAssertEqual(switched.entry(for: start)?.value, 40)
    }

    func testNewDayTapStartsFreshInsteadOfContinuingYesterday() {
        var habit = Habit(name: "Work", type: .build, trackingMode: .timer)
        let beforeMidnight = Calendar.current.startOfDay(for: start).addingTimeInterval(-30)
        habit.activateTimer(on: beforeMidnight, at: beforeMidnight)
        habit.configureAlternatingTimer(enabled: true, name: "Leisure", at: beforeMidnight)
        habit.activateTimer(on: start, at: beforeMidnight.addingTimeInterval(90))
        XCTAssertEqual(habit.entry(for: beforeMidnight)?.value, 30)
        XCTAssertEqual(habit.timerStartedFor, Calendar.current.startOfDay(for: start))
        XCTAssertFalse(habit.runningOpposite)
    }
}
