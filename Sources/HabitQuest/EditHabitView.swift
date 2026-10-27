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
    @State private var iconName: String

    init(habit: Habit, onSave: @escaping () -> Void) {
        self.habit = habit
        self.onSave = onSave
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
                    Label("Icon", systemImage: iconName)
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
        onSave()
        dismiss()
    }

    private static func formatGoal(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

}
