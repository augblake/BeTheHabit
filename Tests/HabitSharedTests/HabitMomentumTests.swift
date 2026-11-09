import Foundation
import XCTest
@testable import HabitShared

final class HabitMomentumTests: XCTestCase {
    private var today: Date { Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600) }
    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: today)!
    }
    private func recorded(_ offsets: [Int]) -> Habit {
        var habit = Habit(name: "Read", type: .build, trackingMode: .yesNo)
        for offset in offsets { habit.entries[Habit.dateKey(day(offset))] = HabitEntry(value: 1, completed: true) }
        return habit
    }

    func testNoRecordsMeansZeroMomentum() {
        XCTAssertEqual(HabitMomentum.currentStreak(habits: [], at: today), 0)
        XCTAssertEqual(HabitMomentum.currentStreak(habits: [recorded([])], at: today), 0)
    }

    func testTwelveConsecutiveRecordedDaysMeansTwelve() {
        XCTAssertEqual(HabitMomentum.currentStreak(habits: [recorded(Array(-11...0))], at: today), 12)
    }

    func testMissedDayBreaksMomentumRatherThanAddingLifetimeDays() {
        let habit = recorded(Array(-14 ... -5) + [-2, 0])
        XCTAssertEqual(HabitMomentum.currentStreak(habits: [habit], at: today), 1)
        XCTAssertEqual(HabitMomentum.currentStreak(habits: [recorded(Array(-14 ... -3))], at: today), 0)
    }

    func testDeletingAllRecordsForOneDayRecalculatesStreak() {
        var habit = recorded([-2, -1, 0])
        XCTAssertEqual(HabitMomentum.currentStreak(habits: [habit], at: today), 3)
        habit.entries.removeValue(forKey: Habit.dateKey(day(-1)))
        XCTAssertEqual(HabitMomentum.currentStreak(habits: [habit], at: today), 1)
    }

    func testMultipleHabitsOnSameDayCountOnlyOnce() {
        XCTAssertEqual(HabitMomentum.currentStreak(habits: [recorded([-2, 0]), recorded([-1, 0])], at: today), 3)
    }

    func testLoggingZeroOrAMissStillCountsAsTracking() {
        var habit = recorded([])
        habit.entries[Habit.dateKey(today)] = HabitEntry(value: 0, completed: false)
        XCTAssertEqual(HabitMomentum.currentStreak(habits: [habit], at: today), 1)
    }

    func testOppositeSideAndArchivedHistoryAreRecordedDays() {
        var habit = recorded([0])
        habit.oppositeTimerEntries = [Habit.dateKey(day(-1)): HabitEntry(value: 60, completed: true)]
        habit.archivedTrackingHistory = ["number": TrackingHistory(entries: [Habit.dateKey(day(-2)): HabitEntry(value: 5, completed: true)], goal: nil)]
        XCTAssertEqual(HabitMomentum.currentStreak(habits: [habit], at: today), 3)
    }

    func testFutureEntriesDoNotCount() {
        XCTAssertEqual(HabitMomentum.currentStreak(habits: [recorded([1, 2, 3])], at: today), 0)
        XCTAssertEqual(HabitMomentum.recordedDays(habits: [recorded([0, 1])], at: today), [Habit.dateKey(today)])
    }

    func testYesterdayStreakHasTodayToContinueButNotAnExtraEmptyDay() {
        let habit = recorded([-3, -2, -1])
        XCTAssertEqual(HabitMomentum.currentStreak(habits: [habit], at: today), 3)
        XCTAssertEqual(HabitMomentum.currentStreak(habits: [habit], at: day(1)), 0)
    }

    func testRunningTimerCountsOnlyAfterRecordingSomeTime() {
        var habit = Habit(name: "Work", type: .build, trackingMode: .timer)
        habit.configureAlternatingTimer(enabled: true, name: "Rest", at: today)
        XCTAssertEqual(HabitMomentum.currentStreak(habits: [habit], at: today), 0)
        habit.activateTimer(on: today, at: today)
        XCTAssertEqual(HabitMomentum.currentStreak(habits: [habit], at: today), 0)
        XCTAssertEqual(HabitMomentum.currentStreak(habits: [habit], at: today.addingTimeInterval(1)), 1)
    }
}

final class HabitIconGlyphTests: XCTestCase {
    func testCustomIconsUseMonochromeSymbols() {
        XCTAssertEqual(HabitIconGlyph.icons.count, 49)
        for (id, icon) in HabitIconGlyph.icons {
            XCTAssertTrue(icon.symbol.allSatisfy(\.isASCII), id)
            XCTAssertFalse(icon.symbol.hasPrefix("custom:"), id)
        }
        XCTAssertEqual(HabitIconGlyph.icons["custom:smoking"]?.symbol, "smoke.fill")
        XCTAssertEqual(HabitIconGlyph.title(for: "custom:zombie"), "Zombie")
    }

    func testRequestedIconTopicsAreAvailableAndSearchable() {
        for (id, query) in [("custom:smoking", "nicotine"), ("custom:drugs", "drugs"),
                            ("custom:zombie", "zombie"), ("custom:brainwashed-tv", "brainwash"),
                            ("custom:phone", "social media"), ("custom:cross", "christian"),
                            ("custom:bible", "scripture"), ("custom:prayer", "prayer")] {
            XCTAssertNotNil(HabitIconGlyph.icons[id])
            XCTAssertTrue(HabitIconGlyph.matches(id, query: query))
        }
    }

    func testCustomIconsRoundTripForBothHabitSides() throws {
        var habit = Habit(name: "Smoking", type: .remove, trackingMode: .timer, iconName: "custom:smoking")
        habit.configureAlternatingTimer(enabled: true, name: "Prayer", iconName: "custom:prayer")
        let decoded = try JSONDecoder().decode(Habit.self, from: JSONEncoder().encode(habit))
        XCTAssertEqual(decoded.iconName, "custom:smoking")
        XCTAssertEqual(decoded.oppositeTimerIconName, "custom:prayer")
        XCTAssertNil(decoded.timerStartedAt)
    }
}
