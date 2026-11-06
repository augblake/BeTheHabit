import Foundation
import XCTest
@testable import HabitShared

final class MidnightTimerTests: XCTestCase {
    private var midnight: Date { Calendar.current.startOfDay(for: Date()) }
    private var late: Date { midnight.addingTimeInterval(-120) }
    private var morning: Date { midnight.addingTimeInterval(8 * 3600) }

    private func alternating(opposite: Bool) -> Habit {
        var habit = Habit(name: "Work", type: .build, trackingMode: .timer, goal: 1)
        habit.alternatingTimerEnabled = true
        habit.oppositeTimerName = "Leisure"
        habit.timerStartedAt = late
        habit.timerStartedFor = Calendar.current.startOfDay(for: late)
        habit.timerIsOpposite = opposite
        return habit
    }

    func testBothSidesCapAtMidnightEvenBeforeStorageRefresh() {
        for opposite in [false, true] {
            let habit = alternating(opposite: opposite)
            XCTAssertEqual(habit.timerSeconds(on: late, opposite: opposite, at: morning), 120)
            XCTAssertEqual(habit.timerSeconds(on: morning, opposite: opposite, at: morning), 0)
            XCTAssertFalse(habit.timerIsActive(at: midnight))
            XCTAssertTrue(habit.timerIsActive(at: midnight.addingTimeInterval(-1)))
        }
    }

    func testMidnightSavesExactlyOnceAndStopsBothSides() {
        for opposite in [false, true] {
            var habit = alternating(opposite: opposite)
            XCTAssertFalse(habit.expireAlternatingTimer(at: midnight.addingTimeInterval(-1)))
            XCTAssertTrue(habit.expireAlternatingTimer(at: midnight))
            XCTAssertNil(habit.timerStartedAt)
            XCTAssertNil(habit.timerStartedFor)
            XCTAssertNil(habit.timerIsOpposite)
            XCTAssertEqual(habit.timerSeconds(on: late, opposite: opposite, at: morning), 120)
            let stopped = habit
            XCTAssertFalse(habit.expireAlternatingTimer(at: morning))
            XCTAssertEqual(habit, stopped)
        }
    }

    func testMorningReadPersistsStopWithoutStartingTimer() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = HabitRepository(directory: url)
        let habit = alternating(opposite: true)
        _ = try repository.update { $0 = [habit] }
        let widget = try XCTUnwrap(repository.widgetHabit(now: morning))
        XCTAssertNil(widget.timerStartedAt)
        let stopped = try XCTUnwrap(repository.load(now: morning).first)
        XCTAssertNil(stopped.timerStartedAt)
        XCTAssertEqual(stopped.oppositeTimerEntries?[Habit.dateKey(late)]?.value, 120)
        XCTAssertNil(stopped.entry(for: morning))
        let readAgain = try repository.load(now: morning.addingTimeInterval(900))
        XCTAssertEqual(readAgain, [stopped])
    }

    func testFirstMorningWidgetTapStartsOriginalSideToday() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = HabitRepository(directory: url)
        let habit = alternating(opposite: true)
        _ = try repository.update { $0 = [habit] }
        // No preceding load: a stale widget action must also apply the cutoff.
        try repository.activate(id: habit.id, now: morning)
        let started = try XCTUnwrap(repository.load(now: morning).first)
        XCTAssertEqual(started.timerStartedAt, morning)
        XCTAssertEqual(started.timerStartedFor, midnight)
        XCTAssertFalse(started.runningOpposite)
        XCTAssertEqual(started.oppositeTimerEntries?[Habit.dateKey(late)]?.value, 120)
        XCTAssertEqual(started.timerSeconds(on: morning, at: morning.addingTimeInterval(30)), 30)
    }

    func testSwitchBeforeMidnightStillUsesBothSidesAndSameCutoff() {
        var habit = alternating(opposite: false)
        habit.activateTimer(on: late, at: midnight.addingTimeInterval(-60))
        XCTAssertTrue(habit.runningOpposite)
        XCTAssertEqual(habit.entry(for: late)?.value, 60)
        XCTAssertEqual(habit.timerCutoff(), midnight)
        habit.expireAlternatingTimer(at: morning)
        XCTAssertEqual(habit.oppositeTimerEntries?[Habit.dateKey(late)]?.value, 60)
        XCTAssertNil(habit.timerStartedAt)
    }

    func testLateFinishDoesNotAddOvernightTime() {
        var habit = alternating(opposite: false)
        habit.finishTimer(at: morning)
        XCTAssertEqual(habit.entry(for: late)?.value, 120)
        XCTAssertEqual(habit.entry(for: late)?.completed, true)
        XCTAssertNil(habit.timerStartedAt)
    }

    func testOrdinaryStopwatchStillContinuesOvernight() {
        var habit = alternating(opposite: false)
        habit.alternatingTimerEnabled = false
        XCTAssertNil(habit.timerCutoff())
        XCTAssertFalse(habit.expireAlternatingTimer(at: morning))
        XCTAssertTrue(habit.timerIsActive(at: morning))
        XCTAssertEqual(habit.timerSeconds(on: late, at: morning), morning.timeIntervalSince(late))
    }

    func testCutoffUsesLocalCalendarAcrossDaylightSavingChanges() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        for (month, day, hours) in [(3, 8, 23), (11, 1, 25)] {
            let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: month, day: day)))
            var habit = alternating(opposite: false)
            habit.timerStartedAt = start
            let cutoff = try XCTUnwrap(habit.timerCutoff(calendar: calendar))
            XCTAssertEqual(cutoff.timeIntervalSince(start), Double(hours * 3600))
            XCTAssertEqual(calendar.component(.hour, from: cutoff), 0)
        }
    }

    func testEditingEnabledTimerNextMorningDoesNotRestartIt() {
        var habit = alternating(opposite: true)
        habit.configureAlternatingTimer(enabled: true, name: "Leisure", at: morning)
        XCTAssertNil(habit.timerStartedAt)
        XCTAssertEqual(habit.oppositeTimerEntries?[Habit.dateKey(late)]?.value, 120)
    }
}
