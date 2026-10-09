import HabitShared
import SwiftUI
import UIKit

struct ContentView: View {
    @ObservedObject private var sharing = CloudHabitSharing.shared
    @EnvironmentObject private var store: HabitStore

    @State private var activeSheet: ActiveSheet?
    @State private var numberHabit: Habit?
    @State private var numberText = ""
    @State private var numberDate = Date()
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showingAboutPopup = false
    @State private var showingIntroduction = false
    @State private var draggingHabitID: UUID?
    @State private var dragStartIndex = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var suppressHabitTapUntil = Date.distantPast
    @GestureState private var reorderGestureActive = false
    @AppStorage("habitquest.lightAppearance") private var lightAppearance = false
    @AppStorage("habitquest.introductionSeen") private var introductionSeen = false

    private enum ActiveSheet: Identifiable {
        case createHabit
        case stopwatch(Habit, Date)
        case details(Habit)

        var id: String {
            switch self {
            case .createHabit:
                return "create-habit"
            case .stopwatch(let habit, _):
                return "stopwatch-\(habit.id)"
            case .details(let habit):
                return "details-\(habit.id)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        calendarGrid
                        FriendHabitsView()
                    }
                }
                .refreshable {
                    store.refresh()
                    await sharing.refresh(store.habits)
                }
                .scrollDisabled(draggingHabitID != nil)
            }
            .alert("Habit Sharing", isPresented: Binding(
                get: { sharing.message != nil },
                set: { if !$0 { sharing.message = nil } }
            )) {
                Button("OK", role: .cancel) { sharing.message = nil }
            } message: { Text(sharing.message ?? "") }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .createHabit:
                    CreateHabitView()
                case .stopwatch(let habit, let date):
                    StopwatchView(habit: habit, selectedDate: date)
                case .details(let habit):
                    HabitDetailsView(habit: habit)
                }
            }
            .alert(
                "Enter Number for \(numberDate.formatted(.dateTime.month(.abbreviated).day()))",
                isPresented: Binding(
                    get: { numberHabit != nil },
                    set: { if !$0 { numberHabit = nil } }
                )
            ) {
                TextField("Value", text: $numberText)
                    .keyboardType(.decimalPad)

                Button("Cancel", role: .cancel) {
                    numberHabit = nil
                }

                Button("Save") {
                    if let value = Double(numberText),
                       let habit = numberHabit {
                        store.setNumber(habit, value: value, on: numberDate)
                    }

                    numberText = ""
                    numberHabit = nil
                }
            }
            .fullScreenCover(isPresented: $showingIntroduction) {
                HabitIntroductionView {
                    introductionSeen = true
                    showingIntroduction = false
                }
            }
            .onAppear {
                if !introductionSeen {
                    showingIntroduction = true
                }
            }
        }
        .preferredColorScheme(lightAppearance ? .light : .dark)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Habits")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.primary)

                Text(selectedDateString)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                activeSheet = .createHabit
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 46, height: 46)
                    .background(
                        Color.primary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 15)
                    )
            }

            Menu {
                Button {
                    lightAppearance = true
                } label: {
                    Label("Light", systemImage: lightAppearance ? "sun.max.fill" : "sun.max")
                }

                Button {
                    lightAppearance = false
                } label: {
                    Label("Dark", systemImage: lightAppearance ? "moon" : "moon.fill")
                }

                Divider()

                Button("About", systemImage: "quote.opening") {
                    showingAboutPopup = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 42, height: 46)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("About")
            .alert("Thanks for using the app, Bryce Blake!", isPresented: $showingAboutPopup) {
                Button("Close", role: .cancel) { }
            } message: {
                Text("“Let us not grow weary of doing good, for in due season we will reap, if we do not give up.”\n— Galatians 6:9 (ESV)\n\nBryce Blake")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 24)
    }

    private var calendarGrid: some View {
        let habits = store.habits

        return VStack(spacing: 3) {
            HStack(spacing: 3) {
                Color.clear
                    .frame(width: 48, height: 60)

                ForEach(weekDays, id: \.self) { date in
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)

                    Button {
                        selectedDate = Calendar.current.startOfDay(for: date)
                    } label: {
                        VStack(spacing: 4) {
                            Text(dayLetter(date))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(isSelected ? Color.accent : Color.secondary)

                            Text(dayNumber(date))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.accent : Color.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            isSelected ? Color.accent.opacity(0.23) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 15)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.bottom, 1)

            if habits.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 4) {
                    ForEach(habits) { habit in
                        HStack(spacing: 3) {
                            habitIconCell(habit)

                            ForEach(weekDays, id: \.self) { date in
                                habitDayCell(habit, date: date)
                                }
                        }
                        .frame(height: 62)
                        .background(
                            Color.primary.opacity(0.045),
                            in: RoundedRectangle(cornerRadius: 17)
                        )
                        .contentShape(Rectangle())
                        .opacity(draggingHabitID == habit.id ? 0.65 : 1)
                        .offset(y: rowDragOffset(habit))
                        .zIndex(draggingHabitID == habit.id ? 1 : 0)
                        .shadow(color: .black.opacity(draggingHabitID == habit.id ? 0.2 : 0), radius: 8, y: 3)
                        .transaction { transaction in
                            if draggingHabitID == habit.id { transaction.animation = nil }
                        }
                        .simultaneousGesture(reorderGesture(habit))
                        .accessibilityAction(named: "Move Up") { store.moveHabit(habit, by: -1) }
                        .accessibilityAction(named: "Move Down") { store.moveHabit(habit, by: 1) }
                    }
                }
                .coordinateSpace(name: "habitRows")
                .animation(.spring(response: 0.25, dampingFraction: 0.9), value: store.habits.map(\.id))
                .onChange(of: reorderGestureActive) { _, active in
                    if !active { finishReorder() }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 24)
    }

    private func rowDragOffset(_ habit: Habit) -> CGFloat {
        guard draggingHabitID == habit.id,
              let index = store.habits.firstIndex(where: { $0.id == habit.id }) else { return 0 }
        return dragTranslation - CGFloat(index - dragStartIndex) * 66
    }

    private func reorderGesture(_ habit: Habit) -> some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("habitRows")))
            .updating($reorderGestureActive) { value, active, _ in
                switch value {
                case .first: active = false
                case .second(let pressed, _): active = pressed
                }
            }
            .onChanged { value in
                switch value {
                case .first:
                    break
                case .second(true, let drag):
                    beginReorder(habit)
                    guard let drag, draggingHabitID == habit.id else { return }
                    dragTranslation = drag.translation.height
                    let destination = min(max(dragStartIndex + Int((dragTranslation / 66).rounded()), 0), store.habits.count - 1)
                    if let index = store.habits.firstIndex(where: { $0.id == habit.id }), index != destination {
                        store.moveHabit(id: habit.id, to: store.habits[destination].id)
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                default: break
                }
            }
            .onEnded { _ in finishReorder() }
    }

    private func beginReorder(_ habit: Habit) {
        guard draggingHabitID == nil,
              let index = store.habits.firstIndex(where: { $0.id == habit.id }) else { return }
        dragStartIndex = index
        dragTranslation = 0
        draggingHabitID = habit.id
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func finishReorder() {
        if draggingHabitID != nil {
            suppressHabitTapUntil = Date().addingTimeInterval(0.2)
        }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            draggingHabitID = nil
            dragTranslation = 0
        }
    }

    private func habitIconCell(_ habit: Habit) -> some View {
        let streak = habit.currentStreak(today: selectedDate)

        return Button {
            guard draggingHabitID == nil, Date() >= suppressHabitTapUntil else { return }
            activeSheet = .details(habit)
        } label: {
            Image(systemName: icon(for: habit))
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(iconColor(for: habit))
                .frame(width: 48, height: 62)
                .overlay(alignment: .topTrailing) {
                    if streak > 0 {
                        Text("\(streak)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.accent)
                            .offset(x: 1, y: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Details for \(habit.name)")
        .accessibilityValue(streak > 0 ? "\(streak) day streak" : "")
    }

    private func habitDayCell(_ habit: Habit, date: Date) -> some View {
        let entry = store.entry(for: habit, on: date)
        let isRunningOnDate = habit.trackingMode == .timer
            && store.timerIsRunning(habit)
            && Calendar.current.isDate(store.timerDate(habit, fallback: date), inSameDayAs: date)

        return Button {
            guard draggingHabitID == nil, Date() >= suppressHabitTapUntil else { return }
            selectedDate = Calendar.current.startOfDay(for: date)
            handleTap(habit, on: date)
        } label: {
            Group {
                if habit.trackingMode == .number {
                    let value = entry?.value ?? 0
                    let isFailure = entry?.completed == false
                        || (habit.type == .build && value == 0)
                    Text(formatValue(value))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isFailure ? Color.red.opacity(0.9) : Color.primary)
                        .frame(width: 42, height: 42)
                        .background(
                            isFailure ? Color.red.opacity(0.3) : Color.blue.opacity(0.36),
                            in: Circle()
                        )
                } else if isRunningOnDate {
                    Image(systemName: "timer")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 42, height: 42)
                        .background(Color.red.opacity(0.7), in: Circle())
                } else if habit.trackingMode == .timer {
                    let value = entry?.value ?? 0
                    let hasRecordedTime = value > 0
                    Text(value > 0 ? formatCompactDuration(value) : "0")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(hasRecordedTime ? Color.primary : Color.red)
                        .frame(width: 44, height: 44)
                        .background((hasRecordedTime ? Color.blue : Color.red).opacity(0.3), in: Circle())
                } else if entry?.completed == true {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 42, height: 42)
                        .background(Color.green.opacity(0.48), in: Circle())
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color.red.opacity(0.9))
                        .frame(width: 42, height: 42)
                    .background(Color.red.opacity(0.3), in: Circle())
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(habit.name), \(date.formatted(.dateTime.month(.wide).day()))")
        .accessibilityValue(isRunningOnDate ? "Stopwatch running" : (entry?.completed == true ? "Complete" : "Not complete"))
    }

    private func icon(for habit: Habit) -> String {
        habit.iconName ?? HabitIconCatalog.defaultSymbol(for: habit)
    }

    private func iconColor(for habit: Habit) -> Color {
        if let iconColorHex = habit.iconColorHex {
            return Color(hex: iconColorHex)
        }
        if let preset = HabitPresetCatalog.preset(for: habit.name) {
            return Color(hex: preset.colorHex)
        }

        switch icon(for: habit) {
        case "drop.fill": return Color(red: 0.12, green: 0.64, blue: 0.98)
        case "figure.run": return Color(red: 1.0, green: 0.35, blue: 0.32)
        case "figure.mind.and.body": return Color(red: 0.62, green: 0.35, blue: 0.98)
        case "book.fill": return Color(red: 1.0, green: 0.64, blue: 0.12)
        case "dumbbell.fill": return Color(red: 0.55, green: 0.64, blue: 0.85)
        case "moon.fill": return Color(red: 1.0, green: 0.75, blue: 0.18)
        case "heart.fill": return Color(red: 1.0, green: 0.34, blue: 0.36)
        case "leaf.fill": return Color(red: 0.32, green: 0.76, blue: 0.35)
        default: return Color.accent
        }
    }

    private func handleTap(_ habit: Habit, on date: Date) {
        switch habit.trackingMode {
        case .yesNo:
            store.toggle(habit, on: date)

        case .number:
            numberHabit = habit
            numberDate = date
            numberText = ""

        case .timer:
            activeSheet = .stopwatch(habit, date)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 45)

            Image(systemName: "checkmark.circle")
                .font(.system(size: 42))
                .foregroundStyle(Color.accent)

            Text("Start with one habit")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.primary)

            Text("Build something good or remove something you don't want.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                activeSheet = .createHabit
            } label: {
                Text("Create Habit")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 13)
                    .background(Color.accent, in: Capsule())
            }

            Spacer(minLength: 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 36)
    }

    private var selectedDateString: String {
        selectedDate.formatted(
            .dateTime
                .weekday(.wide)
                .month(.abbreviated)
                .day()
        )
    }

    private var weekDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let start = calendar.date(
            byAdding: .day,
            value: -6,
            to: today
        ) else {
            return [today]
        }

        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }

    private func dayLetter(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }

    private func dayNumber(_ date: Date) -> String {
        date.formatted(.dateTime.day())
    }

    private func formatValue(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value))
            : String(format: "%.1f", value)
    }

    private func formatCompactDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        guard seconds >= 60 else { return "\(max(1, seconds))s" }

        let totalMinutes = seconds / 60
        let hours = totalMinutes / 60
        return hours > 0 ? "\(hours)h" : "\(totalMinutes)m"
    }
}

private struct StopwatchView: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    let habit: Habit
    let selectedDate: Date

    @State private var sessionDate: Date
    @State private var isEditingSavedTime = false
    @State private var enteredMinutes = ""
    @State private var confirmingClear = false

    init(habit: Habit, selectedDate: Date) {
        self.habit = habit
        self.selectedDate = selectedDate
        _sessionDate = State(initialValue: selectedDate)
    }

    private var isRunning: Bool {
        store.timerIsRunning(habit)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: "stopwatch.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.accent)
                    .padding(.top, 20)

                Text(habit.name)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(sessionDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Self.formatDuration(store.timerElapsed(
                        habit,
                        on: sessionDate,
                        at: context.date
                    )))
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                }

                Button {
                    if isRunning {
                        store.stopTimer(habit, on: sessionDate)
                    } else {
                        store.startTimer(habit, on: sessionDate)
                    }
                } label: {
                    Label(isRunning ? "Stop" : "Start", systemImage: isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isRunning ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(isRunning ? Color.red : Color.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)

                Text(isRunning ? "Time is being recorded." : "Elapsed time is saved when you stop.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                if isEditingSavedTime {
                    VStack(spacing: 9) {
                        HStack(spacing: 10) {
                            TextField("Minutes", text: $enteredMinutes)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)

                            Button("Save") {
                                if let minutes = Double(enteredMinutes), minutes >= 0 {
                                    store.setTimerTime(habit, minutes: minutes, on: sessionDate)
                                    isEditingSavedTime = false
                                }
                            }
                            .fontWeight(.semibold)
                        }

                        Text("Enter the total time in minutes. For example, 90 is 1 hour 30 minutes.")
                            .font(.system(size: 12))
                                .foregroundStyle(.secondary)

                        Button("Cancel") {
                            isEditingSavedTime = false
                        }
                        .font(.system(size: 14))
                    }
                    .padding(.horizontal, 28)
                } else {
                    HStack(spacing: 24) {
                        Button {
                            let savedSeconds = store.entry(for: habit, on: sessionDate)?.value ?? 0
                            enteredMinutes = String(format: "%.1f", savedSeconds / 60)
                            isEditingSavedTime = true
                        } label: {
                            Label("Edit time", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            confirmingClear = true
                        } label: {
                            Label("Delete time", systemImage: "trash")
                        }
                        .disabled(store.entry(for: habit, on: sessionDate) == nil)
                    }
                    .font(.system(size: 14, weight: .medium))
                }

                Spacer(minLength: 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.background.ignoresSafeArea())
            .navigationTitle("Stopwatch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete the saved time for this day?",
                isPresented: $confirmingClear,
                titleVisibility: .visible
            ) {
                Button("Delete Recorded Time", role: .destructive) {
                    store.clearTimerTime(habit, on: sessionDate)
                }
            }
            .onAppear {
                if isRunning {
                    sessionDate = store.timerDate(habit, fallback: selectedDate)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
    }
}

extension Color {
    static let background = Color(uiColor: .systemBackground)

    static let accent = Color(
        red: 0.25,
        green: 0.82,
        blue: 0.82
    )
}

#Preview {
    ContentView()
        .environmentObject(HabitStore())
}
