import HabitShared
import SwiftUI

struct EditHabitView: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    private let habit: Habit
    private let onSave: () -> Void
    @State private var name: String
    @State private var trackingMode: TrackingMode
    @State private var goalText: String
    @State private var tracksBothSides: Bool
    @State private var oppositeName: String
    @State private var oppositeIconName: String
    @State private var iconName: String

    init(habit: Habit, onSave: @escaping () -> Void) {
        self.habit = habit
        self.onSave = onSave
        _tracksBothSides = State(initialValue: habit.tracksBothSides)
        _oppositeIconName = State(initialValue: habit.oppositeTimerIconName ?? habit.iconName ?? "timer")
        _oppositeName = State(initialValue: habit.oppositeName)
        _name = State(initialValue: habit.name)
        _trackingMode = State(initialValue: habit.trackingMode)
        _goalText = State(initialValue: habit.goal.map(Self.formatGoal) ?? "")
        _iconName = State(initialValue: habit.iconName ?? HabitIconCatalog.defaultSymbol(for: habit))
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Habit name", text: $name)
                    .textInputAutocapitalization(.sentences)
            }

            Section("Appearance") {
                NavigationLink {
                    HabitIconPickerView(selectedIcon: $iconName)
                } label: {
                    Label { Text("Icon") } icon: { HabitSymbol(iconName) }
                        .foregroundStyle(.primary)
                }

            }

            Section("Tracking") {
                Picker("Track with", selection: $trackingMode) {
                    ForEach(TrackingMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.icon).tag(mode)
                    }
                }
                if trackingMode != .yesNo {
                    TextField(
                        trackingMode == .timer ? "Target minutes per day" : "Daily goal",
                        text: $goalText
                    )
                    .keyboardType(.decimalPad)
                }
                if trackingMode == .timer {
                    Toggle("Track both sides", isOn: $tracksBothSides)
                    if tracksBothSides {
                        TextField("Opposite side name", text: $oppositeName)
                        NavigationLink {
                            HabitIconPickerView(selectedIcon: $oppositeIconName)
                        } label: {
                            Label { Text("Opposite side icon") } icon: { HabitSymbol(oppositeIconName) }
                                .foregroundStyle(.primary)
                        }
                        Text("Press Start to begin. Switch changes sides, and Stop in the app pauses both. The widget’s Stop button switches sides. Both stop at midnight.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Each tracking type keeps its own history. Switching back restores its previous entries and target.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Edit Habit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onChange(of: trackingMode) { newMode in
            let target = newMode == habit.trackingMode
                ? habit.goal
                : habit.archivedTrackingHistory?[newMode.rawValue]?.goal
            goalText = target.map(Self.formatGoal) ?? ""
        }
    }

    private func save() {
        store.editHabit(
            habit,
            name: name,
            trackingMode: trackingMode,
            goal: trackingMode == .yesNo ? nil : Double(goalText),
            iconName: iconName,
            iconColorHex: habit.iconColorHex ?? HabitIconPalette.defaultHex
        )
        store.configureAlternatingTimer(habit, enabled: tracksBothSides && trackingMode == .timer, name: oppositeName, iconName: oppositeIconName)
        onSave()
        dismiss()
    }

    private static func formatGoal(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

}
