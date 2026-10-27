import HabitShared
import SwiftUI
import UIKit

struct ContentView: View {
    @ObservedObject private var sharing = CloudHabitSharing.shared
    @ObservedObject private var backup = CloudHabitBackup.shared
    @EnvironmentObject private var store: HabitStore

    @State private var activeSheet: ActiveSheet?
    @State private var numberHabit: Habit?
    @State private var numberText = ""
    @State private var numberDate = Date()
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var today = Date()
    @State private var showingAboutPopup = false
    @State private var showingIntroduction = false
    @State private var showPreviewAfterIntroduction = false
    @State private var showingMomentumPreview = false
    @State private var momentumPreviewOpacity = 1.0
    @State private var momentumPreviewReady = false
    @State private var momentumPreviewFading = false
    @State private var draggingHabitID: UUID?
    @State private var focusedHabitID: UUID?
    @State private var isSelectingHabits = false
    @State private var selectedHabitIDs: Set<UUID> = []
    @State private var habitIDsPendingDeletion: Set<UUID> = []
    @State private var showingDeleteConfirmation = false
    @State private var showingSharingUnavailable = false
    @State private var dragStartIndex = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var suppressHabitTapUntil = Date.distantPast
    @GestureState private var reorderGestureActive = false
    @AppStorage("habitquest.lightAppearance") private var lightAppearance = false
    @AppStorage("habitquest.introductionSeen") private var introductionSeen = false
    @AppStorage("habitquest.momentumDays") private var momentumDaysData = Data()
    @AppStorage("habitquest.momentumHistorySeeded") private var momentumHistorySeeded = false

    private let habitNameWidth: CGFloat = 120
    private let visibleDayCount = 5

    private enum ActiveSheet: Identifiable {
        case createHabit
        case stopwatch(Habit, Date)
        case details(Habit)
        case editHabit(Habit)
        case shareHabit(Habit)

        var id: String {
            switch self {
            case .createHabit:
                return "create-habit"
            case .stopwatch(let habit, _):
                return "stopwatch-\(habit.id)"
            case .details(let habit):
                return "details-\(habit.id)"
            case .editHabit(let habit):
                return "edit-\(habit.id)"
            case .shareHabit(let habit):
                return "share-\(habit.id)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if let focusedHabit = store.habits.first(where: { $0.id == focusedHabitID }),
                       !isSelectingHabits {
                        habitActionBar(for: focusedHabit)
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if sharing.message != nil {
                                SharingErrorView().padding()
                            }
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
                .animation(.easeInOut(duration: 0.2), value: focusedHabitID)
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .createHabit:
                    CreateHabitView()
                case .stopwatch(let habit, let date):
                    StopwatchView(habit: habit, selectedDate: date)
                case .details(let habit):
                    HabitDetailsView(habit: habit)
                case .editHabit(let habit):
                    NavigationStack {
                        EditHabitView(habit: habit) { }
                    }
                case .shareHabit(let habit):
                    ShareHabitView(habit: habit)
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
            .confirmationDialog(
                habitIDsPendingDeletion.count == 1 ? "Delete habit?" : "Delete \(habitIDsPendingDeletion.count) habits?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(habitIDsPendingDeletion.count == 1 ? "Delete Habit" : "Delete Habits", role: .destructive) {
                    store.deleteHabits(ids: habitIDsPendingDeletion)
                    habitIDsPendingDeletion.removeAll()
                    selectedHabitIDs.removeAll()
                    isSelectingHabits = false
                    focusedHabitID = nil
                }
                Button("Cancel", role: .cancel) {
                    habitIDsPendingDeletion.removeAll()
                }
            } message: {
                Text("This permanently removes the selected habits and their history.")
            }
            .fullScreenCover(isPresented: $showingIntroduction, onDismiss: {
                if showPreviewAfterIntroduction {
                    showPreviewAfterIntroduction = false
                    startMomentumPreview()
                }
            }) {
                HabitIntroductionView {
                    introductionSeen = true
                    showPreviewAfterIntroduction = true
                    showingIntroduction = false
                }
            }
            .onAppear {
                today = Date()
                recordMomentumUse()
                if !introductionSeen {
                    showingIntroduction = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                today = Date()
                recordMomentumUse()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                today = Date()
                recordMomentumUse()
            }
            .onOpenURL(perform: openWidgetHabit)
        }
        .overlay {
            if showingMomentumPreview {
                MomentumPreviewView(readyToContinue: momentumPreviewReady)
                    .opacity(momentumPreviewOpacity)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: dismissMomentumPreview)
                    .allowsHitTesting(true)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityAction(named: "Continue") { dismissMomentumPreview() }
            }
        }
        .preferredColorScheme(lightAppearance ? .light : .dark)
    }

    private func startMomentumPreview() {
        momentumPreviewOpacity = 1
        momentumPreviewReady = false
        momentumPreviewFading = false
        showingMomentumPreview = true

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard showingMomentumPreview else { return }
            withAnimation(.easeIn(duration: 0.25)) { momentumPreviewReady = true }
        }
    }

    private func dismissMomentumPreview() {
        guard momentumPreviewReady, !momentumPreviewFading else { return }
        momentumPreviewFading = true
        withAnimation(.easeInOut(duration: 2)) {
            momentumPreviewOpacity = 0
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.1))
            showingMomentumPreview = false
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("BeTheHabit")
                    .font(.system(size: momentumTitleSize, weight: momentumTitleWeight))
                    .foregroundStyle(momentumDays >= 14 ? streakGold : Color.primary)
                    .shadow(
                        color: momentumDays >= 7 ? streakGold.opacity(momentumDays >= 14 ? 0.5 : 0.25) : .clear,
                        radius: momentumDays >= 14 ? 12 : 6
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("\(momentumDays) \(momentumDays == 1 ? "day" : "days") of momentum")
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
                Button(backup.status, systemImage: "icloud") { }
                    .disabled(true)

                Divider()

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

                Link("Privacy Policy", destination: URL(string: "https://augblake.github.io/BeTheHabit-support/privacy.html")!)
                Link("Support", destination: URL(string: "https://augblake.github.io/BeTheHabit-support/support.html")!)

                Divider()

                Button("View Introduction", systemImage: "questionmark.circle") {
                    showingIntroduction = true
                }

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
            .accessibilityLabel("App options")
            .alert("Thanks for using the app, Bryce Blake!", isPresented: $showingAboutPopup) {
                Button("Close", role: .cancel) { }
            } message: {
                Text("“And let us not be weary in well doing: for in due season we shall reap, if we faint not.”\n— Galatians 6:9 (KJV)\n\nBryce Blake")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 24)
    }

    private func habitActionBar(for habit: Habit) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: habit.iconName ?? HabitIconCatalog.defaultSymbol(for: habit))
                    .foregroundStyle(Color.accent)
                Text(habit.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button {
                    focusedHabitID = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Close habit actions")
            }

            HStack(spacing: 8) {
                habitAction("Edit", symbol: "pencil") {
                    activeSheet = .editHabit(habit)
                }
                habitAction("Invite Friend", symbol: "person.badge.plus") {
                    if sharing.enabled {
                        activeSheet = .shareHabit(habit)
                    } else {
                        showingSharingUnavailable = true
                    }
                }
                habitAction("Delete", symbol: "trash", destructive: true) {
                    confirmDelete([habit.id])
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Actions for \(habit.name)")
        .alert("Friend sharing unavailable", isPresented: $showingSharingUnavailable) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This build needs iCloud sharing enabled before you can invite a friend.")
        }
    }

    private func habitAction(
        _ title: String,
        symbol: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    destructive ? Color.red.opacity(0.12) : Color.primary.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 11)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(destructive ? Color.red : Color.primary)
    }

    private var momentumDays: Int {
        max(1, Set((try? JSONDecoder().decode([String].self, from: momentumDaysData)) ?? []).count)
    }

    private var momentumTitleSize: CGFloat {
        min(30, 26 + CGFloat(max(0, momentumDays - 1)) / 7)
    }

    private var momentumTitleWeight: Font.Weight {
        switch momentumDays {
        case ..<2: .light
        case 2..<4: .regular
        case 4..<7: .medium
        case 7..<14: .semibold
        case 14..<30: .bold
        default: .heavy
        }
    }

    private func recordMomentumUse() {
        let todayKey = Habit.dateKey(Date())
        var days = Set((try? JSONDecoder().decode([String].self, from: momentumDaysData)) ?? [])

        if !momentumHistorySeeded {
            for habit in store.habits {
                days.formUnion(habit.entries.keys.filter { $0 <= todayKey })
                for history in habit.archivedTrackingHistory?.values ?? Dictionary<String, TrackingHistory>().values {
                    days.formUnion(history.entries.keys.filter { $0 <= todayKey })
                }
            }
            momentumHistorySeeded = true
        }

        days.insert(todayKey)
        if let encoded = try? JSONEncoder().encode(days.sorted()), encoded != momentumDaysData {
            momentumDaysData = encoded
        }
    }

    private var calendarGrid: some View {
        let habits = store.habits

        return VStack(spacing: 3) {
            if !habits.isEmpty {
                HStack {
                    if isSelectingHabits {
                        Button("Cancel") {
                            isSelectingHabits = false
                            selectedHabitIDs.removeAll()
                        }
                        Spacer()
                        Text("\(selectedHabitIDs.count) selected")
                            .foregroundStyle(.secondary)
                        Button("Delete") {
                            confirmDelete(selectedHabitIDs)
                        }
                        .foregroundStyle(.red)
                        .disabled(selectedHabitIDs.isEmpty)
                    } else {
                        Spacer()
                        Button("Select") {
                            focusedHabitID = nil
                            isSelectingHabits = true
                        }
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            }

            HStack(spacing: 3) {
                Color.clear
                    .frame(width: habitNameWidth, height: 60)

                ForEach(visibleDays, id: \.self) { date in
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)

                    Button {
                        selectedDate = Calendar.current.startOfDay(for: date)
                    } label: {
                        VStack(spacing: 4) {
                            Text(dayLetter(date))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(isSelected ? completionGreen : Color.secondary)

                            Text(dayNumber(date))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(isSelected ? completionGreen : Color.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            isSelected ? completionGreen.opacity(0.1) : Color.clear,
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
                        let streak = visibleStreak(for: habit)

                        HStack(spacing: 3) {
                            habitNameCell(habit)

                            ForEach(visibleDays, id: \.self) { date in
                                habitDayCell(habit, date: date)
                            }
                        }
                        .frame(height: 62)
                        .background(
                            selectedHabitIDs.contains(habit.id) ? Color.accentColor.opacity(0.14) :
                            focusedHabitID == habit.id ? Color.accentColor.opacity(0.10) :
                            streak > 0 ? streakGold.opacity(streak >= 4 ? 0.08 : 0.03) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 17)
                        )
                        .overlay {
                            if streak > 0 {
                                RoundedRectangle(cornerRadius: 17)
                                    .strokeBorder(
                                        streakGold.opacity(streak >= 4 ? 1 : 0.65),
                                        lineWidth: streak >= 14 ? 3 : (streak >= 4 ? 2.5 : (streak >= 2 ? 1.5 : 1))
                                    )
                                    .shadow(
                                        color: streakGold.opacity(streak >= 14 ? 0.55 : (streak >= 4 ? 0.35 : 0)),
                                        radius: streak >= 14 ? 14 : 8
                                    )
                                    .allowsHitTesting(false)
                            }
                        }
                        .overlay(alignment: .trailing) {
                            if isSelectingHabits {
                                Button {
                                    toggleSelection(habit)
                                } label: {
                                    Image(systemName: selectedHabitIDs.contains(habit.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 23, weight: .semibold))
                                        .foregroundStyle(selectedHabitIDs.contains(habit.id) ? Color.accentColor : Color.secondary)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                                        .padding(.trailing, 12)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(selectedHabitIDs.contains(habit.id) ? "Deselect" : "Select") \(habit.name)")
                            }
                        }
                        .contentShape(Rectangle())
                        .opacity(draggingHabitID == habit.id ? 0.65 : 1)
                        .offset(y: rowDragOffset(habit))
                        .zIndex(draggingHabitID == habit.id ? 1 : 0)
                        .shadow(color: .black.opacity(draggingHabitID == habit.id ? 0.2 : 0), radius: 8, y: 3)
                        .transaction { transaction in
                            if draggingHabitID == habit.id { transaction.animation = nil }
                        }
                        .simultaneousGesture(reorderGesture(habit))
                        .accessibilityAction(named: "Habit Actions") { focusedHabitID = habit.id }
                        .accessibilityAction(named: "Move Up") { store.moveHabit(habit, by: -1) }
                        .accessibilityAction(named: "Move Down") { store.moveHabit(habit, by: 1) }
                    }
                }
                .coordinateSpace(name: "habitRows")
                .animation(.spring(response: 0.25, dampingFraction: 0.9), value: store.habits.map(\.id))
                .onChange(of: reorderGestureActive) { active in
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
                    guard !isSelectingHabits else { return }
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
        guard !isSelectingHabits, draggingHabitID == nil,
              let index = store.habits.firstIndex(where: { $0.id == habit.id }) else { return }
        focusedHabitID = habit.id
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

    private func toggleSelection(_ habit: Habit) {
        if selectedHabitIDs.contains(habit.id) {
            selectedHabitIDs.remove(habit.id)
        } else {
            selectedHabitIDs.insert(habit.id)
        }
    }

    private func confirmDelete(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        habitIDsPendingDeletion = ids
        showingDeleteConfirmation = true
    }

    private func habitNameCell(_ habit: Habit) -> some View {
        let streak = visibleStreak(for: habit)
        return Button {
            guard !isSelectingHabits, draggingHabitID == nil, Date() >= suppressHabitTapUntil else { return }
            focusedHabitID = nil
            activeSheet = .details(habit)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if streak > 0 {
                    Label("\(streak) day streak", systemImage: "sparkle")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(streakGold)
                }
            }
            .padding(.horizontal, 10)
            .frame(width: habitNameWidth, height: 62, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Details for \(habit.name)")
        .accessibilityValue("\(habit.isComplete(on: today) ? "Completed today" : "Not completed today")\(streak > 0 ? ", \(streak) day streak" : "")")
    }

    private func habitDayCell(_ habit: Habit, date: Date) -> some View {
        let entry = store.entry(for: habit, on: date)
        let isRunningOnDate = habit.trackingMode == .timer
            && store.timerIsRunning(habit)
            && Calendar.current.isDate(store.timerDate(habit, fallback: date), inSameDayAs: date)

        return Button {
            guard !isSelectingHabits, draggingHabitID == nil, Date() >= suppressHabitTapUntil else { return }
            focusedHabitID = nil
            selectedDate = Calendar.current.startOfDay(for: date)
            handleTap(habit, on: date)
        } label: {
            GeometryReader { geometry in
                Group {
                    if habit.trackingMode == .number, let entry {
                        Text(formatValue(entry.value))
                            .font(.system(size: 15, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    } else if isRunningOnDate {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(formatGridDuration(store.timerElapsed(habit, on: date, at: context.date)))
                                .contentTransition(.numericText())
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    } else if habit.trackingMode == .timer, let entry, entry.value > 0 {
                        Text(formatGridDuration(entry.value))
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    } else if habit.trackingMode == .yesNo, entry?.completed == true {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(completionGreen)
                    } else if habit.trackingMode == .yesNo, entry?.completed == false {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("·")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: geometry.size.width, height: 62)
                .contentShape(Rectangle())
            }
            .frame(height: 62)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(habit.name), \(date.formatted(.dateTime.month(.wide).day()))")
        .accessibilityValue(isRunningOnDate ? "Stopwatch running" : (entry?.completed == true ? "Complete" : "Not complete"))
    }

    private func visibleStreak(for habit: Habit) -> Int {
        habit.visibleStreak(today: today)
    }

    private var streakGold: Color {
        .habitGold
    }

    private var completionGreen: Color {
        .habitGreen
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

    private func openWidgetHabit(_ url: URL) {
        guard url.scheme == "bethehabit", url.host == "habit",
              let id = UUID(uuidString: url.lastPathComponent) else { return }
        store.refresh()
        guard let habit = store.habits.first(where: { $0.id == id }) else { return }
        selectedDate = Calendar.current.startOfDay(for: Date())
        focusedHabitID = habit.id
        if habit.trackingMode == .number {
            numberHabit = habit
            numberDate = Date()
            numberText = habit.entry(for: numberDate).map { $0.value.formatted() } ?? ""
        } else if habit.trackingMode == .timer {
            activeSheet = .stopwatch(habit, Date())
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
                    .foregroundStyle(Color.background)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 13)
                    .background(Color.accent, in: Capsule())
            }

            Spacer(minLength: 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 36)
    }

    private var visibleDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let start = calendar.date(
            byAdding: .day,
            value: -(visibleDayCount - 1),
            to: today
        ) else {
            return [today]
        }

        return (0..<visibleDayCount).compactMap {
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

    private func formatGridDuration(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration))
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
        }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
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
                        .foregroundStyle(isRunning ? Color.primary : Color.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(isRunning ? Color.primary.opacity(0.1) : Color.accent, in: Capsule())
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

    static let habitGreen = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.44, green: 0.86, blue: 0.67, alpha: 1)
            : UIColor(red: 0.09, green: 0.50, blue: 0.37, alpha: 1)
    })

    static let habitGold = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.91, green: 0.75, blue: 0.44, alpha: 1)
            : UIColor(red: 0.61, green: 0.41, blue: 0.12, alpha: 1)
    })

    static let habitSurface = Color.primary.opacity(0.045)
    static let accent = habitGreen
}

#Preview {
    ContentView()
        .environmentObject(HabitStore())
}
