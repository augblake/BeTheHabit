import HabitShared
import Charts
import SwiftUI
import UIKit

struct HabitDetailsView: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sharing = CloudHabitSharing.shared

    private let originalHabit: Habit
    @State private var notes: String
    @State private var iconName: String
    @State private var goalText: String
    @State private var displayedMonth: Date
    @State private var selectedDate: Date
    @State private var confirmingDelete = false
    @State private var showingShare = false
    @State private var widgetMessage: String?

    init(habit: Habit) {
        originalHabit = habit
        _notes = State(initialValue: habit.notes ?? "")
        _iconName = State(initialValue: habit.iconName ?? HabitIconCatalog.defaultSymbol(for: habit))
        _goalText = State(initialValue: habit.goal.map(Self.formatGoal) ?? "")
        _displayedMonth = State(initialValue: Date())
        _selectedDate = State(initialValue: Calendar.current.startOfDay(for: Date()))
    }

    private var habit: Habit {
        store.habits.first(where: { $0.id == originalHabit.id }) ?? originalHabit
    }

    private var hasNumericTarget: Bool {
        habit.trackingMode == .number || habit.trackingMode == .timer
    }

    private var goalUnit: String {
        habit.trackingMode == .timer ? "minutes per day" : "per day"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    identityCard
                    notesCard
                    if hasNumericTarget {
                        targetCard
                    }
                    trendCard
                    historyCard

                    Button {
                        do {
                            try store.showInWidget(habit)
                            widgetMessage = "\(habit.name) is your default widget habit. If your widget already has a different habit selected, hold it and choose Edit Widget to select \(habit.name)."
                        } catch {
                            widgetMessage = "The widget could not access your habits. Please reopen BeTheHabit and try again."
                        }
                    } label: {
                        Label("Show in Widget", systemImage: "square.grid.2x2")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    if sharing.enabled {
                        Button { showingShare = true } label: {
                            Label("Share with Friend", systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete Habit", systemImage: "trash")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .padding(.top, 4)
                }
                .padding(16)
            }
            .sheet(isPresented: $showingShare) { ShareHabitView(habit: habit) }
            .background(Color.background.ignoresSafeArea())
            .navigationTitle("Habit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Edit") {
                        EditHabitView(habit: habit) {
                            guard let updated = store.habits.first(where: { $0.id == originalHabit.id }) else { return }
                            iconName = updated.iconName ?? HabitIconCatalog.defaultSymbol(for: updated)
                            goalText = updated.goal.map(Self.formatGoal) ?? ""
                        }
                    }
                }
            }
            .alert("BeTheHabit Widget", isPresented: Binding(
                get: { widgetMessage != nil },
                set: { if !$0 { widgetMessage = nil } }
            )) {
                Button("OK", role: .cancel) { widgetMessage = nil }
            } message: { Text(widgetMessage ?? "") }
            .confirmationDialog(
                "Delete \(habit.name)?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete Habit", role: .destructive) {
                    store.deleteHabit(habit)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently remove the habit and its history.")
            }
        }
        .onChange(of: notes) { newValue in
            saveDetails(notes: newValue)
        }
        .onChange(of: goalText) { _ in
            saveDetails(goal: Double(goalText))
        }
        .presentationDetents([.large])
    }

    private var identityCard: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 60, height: 60)
                .background(Color.habitSurface, in: RoundedRectangle(cornerRadius: 17))

            VStack(alignment: .leading, spacing: 5) {
                Text(habit.name)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("\(habit.type.title) · \(habit.trackingMode.title)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                if visibleStreak > 0 {
                    Label("\(visibleStreak) day streak", systemImage: "sparkle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.habitGold)
                }
            }

            Spacer()

        }
        .padding(16)
        .background(
            visibleStreak > 0 ? Color.habitGold.opacity(0.07) : Color.habitSurface,
            in: RoundedRectangle(cornerRadius: 17)
        )
        .overlay {
            if visibleStreak > 0 {
                RoundedRectangle(cornerRadius: 17)
                    .strokeBorder(Color.habitGold, lineWidth: visibleStreak >= 4 ? 2 : 1)
                    .shadow(color: Color.habitGold.opacity(visibleStreak >= 4 ? 0.3 : 0), radius: 8)
            }
        }
    }

    private var visibleStreak: Int {
        habit.visibleStreak()
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Notes", systemImage: "note.text")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            TextEditor(text: $notes)
                .scrollContentBackground(.hidden)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .frame(minHeight: 92)
                .padding(8)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("Add a note, reminder, or reason for this habit…")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary.opacity(0.7))
                            .padding(.leading, 14)
                            .padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Goal or target", systemImage: "scope")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            HStack(spacing: 10) {
                TextField(
                    habit.trackingMode == .timer
                        ? "Target time"
                        : (habit.type == .remove ? "Maximum" : "Minimum"),
                    text: $goalText
                )
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

                Text(goalUnit)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            Text(targetDescription)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var targetDescription: String {
        if habit.trackingMode == .timer {
            return "Timer entries count as reaching the target when they meet this many minutes. Leave blank for any recorded time to count."
        }
        if habit.type == .remove {
            return "A day is successful when the value is at or below this limit."
        }
        return "A day is successful when the value reaches this minimum."
    }

    private var trendCard: some View {
        let trend = HabitTrend(habit: habit)
        let color: Color = trend.direction == .falling ? .primary : .habitGreen

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Consistency trend", systemImage: "chart.xyaxis.line")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Label(trendTitle(trend.direction), systemImage: trendSymbol(trend.direction))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text("Rolling 7-day completion rate · Last 28 days")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if trend.points.isEmpty {
                Text("Record your first day to start the graph.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                Chart {
                    ForEach(trend.points) { point in
                        AreaMark(
                            x: .value("Day", point.date),
                            y: .value("Completion rate", point.percent)
                        )
                        .foregroundStyle(color.opacity(0.15))

                        LineMark(
                            x: .value("Day", point.date),
                            y: .value("Completion rate", point.percent)
                        )
                        .foregroundStyle(color)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    }
                    if let latest = trend.points.last {
                        PointMark(
                            x: .value("Day", latest.date),
                            y: .value("Completion rate", latest.percent)
                        )
                        .foregroundStyle(color)
                        .symbolSize(65)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100]) {
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 170)
                .accessibilityLabel("Consistency trend for \(habit.name)")

                if let recent = trend.recentPercent, let previous = trend.previousPercent {
                    Text("Last 7 days \(Int(recent.rounded()))% · Previous 7 days \(Int(previous.rounded()))%")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Keep tracking to compare your last two weeks.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private func trendTitle(_ direction: HabitTrendDirection) -> String {
        switch direction {
        case .building: return "Building trend"
        case .rising: return "Bull trend"
        case .falling: return "Bear trend"
        case .steady: return "Holding steady"
        }
    }

    private func trendSymbol(_ direction: HabitTrendDirection) -> String {
        switch direction {
        case .building: return "chart.line.uptrend.xyaxis"
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .steady: return "arrow.right"
        }
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("History", systemImage: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(minWidth: 112)
                    .multilineTextAlignment(.center)

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.habitGreen)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 5) {
                ForEach(weekdayHeaders.indices, id: \.self) { index in
                    Text(weekdayHeaders[index])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(calendarSlots.enumerated()), id: \.offset) { slot in
                    if let date = slot.element {
                        calendarDay(date)
                    } else {
                        Color.clear.frame(height: 52)
                    }
                }
            }

            selectedDaySummary
        }
        .padding(16)
        .background(cardBackground)
    }

    private func calendarDay(_ date: Date) -> some View {
        let entry = store.entry(for: habit, on: date)
        let selected = Calendar.current.isDate(date, inSameDayAs: selectedDate)

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 3) {
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 12, weight: selected ? .bold : .regular))
                    .foregroundStyle(selected ? Color.habitGreen : Color.primary.opacity(0.8))
                    .frame(height: 15)

                calendarStatus(entry, on: date)
                    .frame(height: 19)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                selected ? Color.habitGreen.opacity(0.1) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityValue(calendarAccessibilityValue(entry, on: date))
    }

    @ViewBuilder
    private func calendarStatus(_ entry: HabitEntry?, on date: Date) -> some View {
        switch habit.trackingMode {
        case .yesNo:
            if entry?.completed == true {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.habitGreen)
            } else if entry?.completed == false {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            } else if date <= Calendar.current.startOfDay(for: Date()) {
                Text("·")
                    .foregroundStyle(.secondary)
            }
        case .number:
            if let entry {
                Text(Self.formatCalendarNumber(entry.value))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            } else {
                Text("·").foregroundStyle(.secondary)
            }
        case .timer:
            if let entry, entry.value > 0 {
                Text(Self.formatCompactTime(entry.value))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            } else {
                Text("·").foregroundStyle(.secondary)
            }
        }
    }

    private var selectedDaySummary: some View {
        let entry = store.entry(for: habit, on: selectedDate)

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "calendar.day.timeline.left")
                .foregroundStyle(Color.habitGreen)

            VStack(alignment: .leading, spacing: 4) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(summaryText(entry))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.top, 4)
    }

    private func summaryText(_ entry: HabitEntry?) -> String {
        switch habit.trackingMode {
        case .yesNo:
            return entry?.completed == true ? "Completed" : "Not completed"
        case .number:
            let value = entry?.value ?? 0
            return "\(Self.formatCalendarNumber(value)) recorded · \(entry?.completed == true ? "target reached" : "target not reached")"
        case .timer:
            let value = store.timerElapsed(habit, on: selectedDate)
            let running = store.timerIsRunning(habit)
                && Calendar.current.isDate(store.timerDate(habit, fallback: selectedDate), inSameDayAs: selectedDate)
            let time = Self.formatDuration(value)
            return running ? "Recording · \(time)" : "\(time) recorded · \(entry?.completed == true ? "target reached" : "target not reached")"
        }
    }

    private func calendarAccessibilityValue(_ entry: HabitEntry?, on date: Date) -> String {
        switch habit.trackingMode {
        case .yesNo:
            return entry?.completed == true ? "Complete" : "Not complete"
        case .number:
            return "\(Self.formatCalendarNumber(entry?.value ?? 0)) recorded"
        case .timer:
            return "\(Self.formatDuration(entry?.value ?? 0)) recorded"
        }
    }

    private var weekdayHeaders: [String] {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        let first = Calendar.current.firstWeekday - 1
        return (0..<7).map { symbols[(first + $0) % 7] }
    }

    private var calendarSlots: [Date?] {
        var calendar = Calendar.current
        calendar.firstWeekday = Calendar.current.firstWeekday
        guard let start = calendar.dateInterval(of: .month, for: displayedMonth)?.start,
              let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: start)
        let leadingBlanks = (weekday - calendar.firstWeekday + 7) % 7
        var slots = [Date?](repeating: nil, count: leadingBlanks)
        slots += dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: start)
        }.map(Optional.some)
        return slots
    }

    private var cardBackground: some ShapeStyle {
        Color.habitSurface
    }

    private func changeMonth(by amount: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: amount, to: displayedMonth) {
            displayedMonth = next
        }
    }

    private func saveDetails(
        notes newNotes: String? = nil,
        iconName newIcon: String? = nil,
        goal newGoal: Double? = nil
    ) {
        let target: Double?
        if hasNumericTarget {
            target = newGoal ?? Double(goalText)
        } else {
            target = nil
        }

        store.updateDetails(
            for: habit,
            notes: newNotes ?? notes,
            iconName: newIcon ?? iconName,
            iconColorHex: habit.iconColorHex,
            goal: target
        )
    }

    private static func formatGoal(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    private static func formatCalendarNumber(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    private static func formatCompactTime(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        if totalMinutes >= 60 { return "\(totalMinutes / 60)h" }
        if totalMinutes > 0 { return "\(totalMinutes)m" }
        return "\(max(1, Int(interval)))s"
    }

    private static func formatDuration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
    }
}

struct HabitIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String

    @State private var selectedCategory = "All"
    @State private var searchText = ""

    private var symbols: [String] {
        let available = selectedCategory == "All"
            ? HabitIconCatalog.allSymbols
            : (HabitIconCatalog.categories.first(where: { $0.name == selectedCategory })?.symbols ?? [])
        var seen = Set<String>()
        let filtered = available.filter { symbol in
            UIImage(systemName: symbol) != nil && seen.insert(symbol).inserted
        }
        guard !searchText.isEmpty else { return filtered }
        return filtered.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Picker("Category", selection: $selectedCategory) {
                    Text("All").tag("All")
                    ForEach(HabitIconCatalog.categories) { category in
                        Text(category.name).tag(category.name)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.accent)
                .frame(maxWidth: .infinity, alignment: .leading)

                TextField("Search icons", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    ForEach(symbols, id: \.self) { symbol in
                        Button {
                            selectedIcon = symbol
                        } label: {
                            VStack(spacing: 6) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: symbol)
                                        .font(.system(size: 23, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                                }
                                .frame(height: 28)

                                Text(symbol.replacingOccurrences(of: ".", with: " "))
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 62)
                            .background(
                                selectedIcon == symbol ? Color.habitGreen.opacity(0.12) : Color.habitSurface,
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(symbol.replacingOccurrences(of: ".", with: " "))
                        .accessibilityAddTraits(selectedIcon == symbol ? .isSelected : [])
                    }
                }
            }
            .padding(16)
        }
        .background(Color.background.ignoresSafeArea())
        .navigationTitle("Choose Icon")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

struct HabitPresetPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (HabitPreset) -> Void

    @State private var searchText = ""

    private var filteredPresets: [HabitPreset] {
        guard !searchText.isEmpty else { return HabitPresetCatalog.all }
        return HabitPresetCatalog.all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.category.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            ForEach(HabitPresetCatalog.categories, id: \.self) { category in
                let presets = filteredPresets.filter { $0.category == category }
                if !presets.isEmpty {
                    Section(category) {
                        ForEach(presets) { preset in
                            presetRow(preset)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.background.ignoresSafeArea())
        .searchable(text: $searchText, prompt: "Search habit ideas")
        .navigationTitle("Habit Ideas")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func presetRow(_ preset: HabitPreset) -> some View {
        let symbol = HabitPresetCatalog.availableSymbol(for: preset)

        return Button {
            onSelect(preset)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.name)
                        .foregroundStyle(.primary)
                    Text("\(preset.suggestedType.title) · \(preset.suggestedTrackingMode.title)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.name)
    }
}
