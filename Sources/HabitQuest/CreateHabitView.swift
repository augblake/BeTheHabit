import HabitShared
import SwiftUI

struct CreateHabitView: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: HabitType = .build
    @State private var trackingMode: TrackingMode = .yesNo
    @State private var goal = ""
    @State private var iconName: String?

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Habit name", text: $name)
                } header: {
                    Text("Habit")
                }

                Section {
                    NavigationLink {
                        HabitIconPickerView(
                            selectedIcon: Binding(
                                get: { iconName ?? defaultIcon },
                                set: { iconName = $0 }
                            )
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: iconName ?? defaultIcon)
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 34)

                            Text("Choose Icon")

                            Spacer()

                            Text(iconName == nil ? "Suggested" : "Selected")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Icon")
                }

                Section {
                    NavigationLink {
                        HabitPresetPickerView { preset in
                            name = preset.name
                            type = preset.suggestedType
                            trackingMode = preset.suggestedTrackingMode
                            iconName = HabitPresetCatalog.availableSymbol(for: preset)
                            goal = ""
                        }
                    } label: {
                        Label("Browse 100 Habit Ideas", systemImage: "sparkles")
                    }
                } header: {
                    Text("Get started")
                }

                Section {
                    Picker("Path", selection: $type) {
                        ForEach(HabitType.allCases) { type in
                            Text(type.title)
                                .tag(type)
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(type.title)
                            .font(.system(size: 16, weight: .medium))

                        Text(type.description)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Type")
                }

                Section {
                    Picker("Tracking", selection: $trackingMode) {
                        ForEach(TrackingMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }

                    if trackingMode == .number || trackingMode == .timer {
                        TextField(
                            trackingMode == .timer
                                ? "Target time in minutes"
                                : (type == .remove ? "Maximum allowed" : "Daily goal"),
                            text: $goal
                        )
                        .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Tracking")
                }

                Section {
                    Text(trackingMode == .timer
                        ? "Your timer target is the minimum number of minutes to record each day."
                        : (type == .remove
                            ? "Success means staying at or below your limit."
                            : "Success means reaching your goal."))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createHabit()
                    }
                    .disabled(!canCreate)
                }
            }
        }
    }

    private func createHabit() {
        let cleanedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let goalValue = trackingMode == .number || trackingMode == .timer
            ? Double(goal)
            : nil

        store.addHabit(
            name: cleanedName,
            type: type,
            trackingMode: trackingMode,
            goal: goalValue,
            iconName: iconName,
            iconColorHex: nil
        )

        dismiss()
    }

    private var defaultIcon: String {
        let draft = Habit(
            name: name,
            type: type,
            trackingMode: trackingMode
        )
        return HabitIconCatalog.defaultSymbol(for: draft)
    }

}

#Preview {
    CreateHabitView()
        .environmentObject(HabitStore())
}
