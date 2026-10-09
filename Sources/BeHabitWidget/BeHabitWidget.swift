import SwiftUI
import WidgetKit
import AppIntents
import HabitShared

struct HabitEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"
    static let defaultQuery = HabitQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct HabitQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [HabitEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }
    func suggestedEntities() async throws -> [HabitEntity] {
        try HabitRepository.shared().load().map { HabitEntity(id: $0.id.uuidString, name: $0.name) }
    }
    func entities(matching string: String) async throws -> [HabitEntity] {
        try await suggestedEntities().filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
    func defaultResult() async -> HabitEntity? {
        guard let habit = try? HabitRepository.shared().widgetHabit() else { return nil }
        return HabitEntity(id: habit.id.uuidString, name: habit.name)
    }
}

struct ChooseHabit: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose a habit"
    static let description = IntentDescription("Choose the habit shown on this widget.")
    @Parameter(title: "Habit") var habit: HabitEntity?
    static var parameterSummary: some ParameterSummary { Summary("Habit") { \.$habit } }
}

struct ActivateHabit: AppIntent {
    static let title: LocalizedStringResource = "Track habit"
    static let openAppWhenRun = false
    @Parameter(title: "Habit ID") var habitID: String
    init() {}
    init(id: UUID) { habitID = id.uuidString }
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: habitID) {
            try HabitRepository.shared().activate(id: id)
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}

struct HabitTimelineEntry: TimelineEntry {
    let date: Date
    let habit: Habit?
}

struct HabitProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HabitTimelineEntry {
        HabitTimelineEntry(date: Date(), habit: Habit(name: "Daily walk", type: .build, trackingMode: .yesNo))
    }
    func snapshot(for configuration: ChooseHabit, in context: Context) async -> HabitTimelineEntry {
        context.isPreview ? placeholder(in: context) : entry(configuration)
    }
    func timeline(for configuration: ChooseHabit, in context: Context) async -> Timeline<HabitTimelineEntry> {
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: now)!)
        return Timeline(entries: [entry(configuration)], policy: .after(min(midnight, now.addingTimeInterval(900))))
    }
    private func entry(_ configuration: ChooseHabit) -> HabitTimelineEntry {
        let habits = (try? HabitRepository.shared().load()) ?? []
        let selected = configuration.habit.map { chosen in habits.first { $0.id.uuidString == chosen.id } }
            ?? (try? HabitRepository.shared().widgetHabit())
        return HabitTimelineEntry(date: Date(), habit: selected)
    }
}

struct HabitWidgetView: View {
    let entry: HabitTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let habit = entry.habit {
                HStack {
                    Image(systemName: habit.iconName ?? "checkmark.circle").foregroundStyle(.teal)
                    Text(habit.name).font(.headline).lineLimit(2)
                }
                if habit.trackingMode == .timer {
                    timer(habit)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .accessibilityLabel("Elapsed time")
                } else {
                    HStack {
                        ZStack {
                            Circle().stroke(.teal.opacity(0.18), lineWidth: 4)
                            Circle().trim(from: 0, to: weeklyProgress(habit))
                                .stroke(.teal, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(Int(weeklyProgress(habit) * 7))/7").font(.caption2)
                        }.frame(width: 34, height: 34)
                        Text("\(habit.currentStreak(today: entry.date)) day streak").font(.caption)
                    }
                }
                Spacer(minLength: 0)
                if habit.trackingMode == .number {
                    Text("Open BeTheHabit to log a number").font(.caption2)
                } else {
                    Button(intent: ActivateHabit(id: habit.id)) {
                        Label(actionTitle(habit), systemImage: habit.trackingMode == .timer
                            ? (habit.timerStartedAt == nil ? "play.fill" : "stop.fill")
                            : (habit.isComplete(on: entry.date) ? "checkmark.circle.fill" : "circle"))
                            .font(.caption.bold()).frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).tint(.teal)
                }
            } else {
                Image(systemName: "checkmark.circle").font(.title).foregroundStyle(.teal)
                Text("BeTheHabit").font(.headline)
                Text("Open the app to add a habit, then edit this widget to choose it.").font(.caption)
            }
        }
        .containerBackground(.background, for: .widget)
    }

    @ViewBuilder private func timer(_ habit: Habit) -> some View {
        let date = habit.timerStartedFor ?? entry.date
        let seconds = habit.entry(for: date)?.value ?? 0
        if let started = habit.timerStartedAt {
            Text(started.addingTimeInterval(-seconds), style: .timer).monospacedDigit()
        } else {
            Text(String(format: "%02d:%02d:%02d", Int(seconds) / 3600, Int(seconds) / 60 % 60, Int(seconds) % 60))
                .monospacedDigit().foregroundStyle(seconds == 0 ? .red : .primary)
        }
    }

    private func actionTitle(_ habit: Habit) -> String {
        if habit.trackingMode == .timer { return habit.timerStartedAt == nil ? "Start" : "Stop" }
        return habit.isComplete(on: entry.date) ? "Undo check-in" : "Check in"
    }
    private func weeklyProgress(_ habit: Habit) -> Double {
        let interval = Calendar.current.dateInterval(of: .weekOfYear, for: entry.date)!
        let count = (0..<7).filter { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: interval.start) else { return false }
            return habit.isComplete(on: date)
        }.count
        return Double(count) / 7
    }
}

@main
struct BeHabitWidget: Widget {
    let kind = "BeHabitWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ChooseHabit.self, provider: HabitProvider()) { entry in
            HabitWidgetView(entry: entry)
        }
        .configurationDisplayName("BeTheHabit")
        .description("Track a habit, check in, or run its stopwatch.")
        .supportedFamilies([.systemSmall])
    }
}
