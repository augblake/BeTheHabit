import HabitShared
import SwiftUI

struct FriendHabitsView: View {
    @ObservedObject private var sharing = CloudHabitSharing.shared
    var body: some View {
        if !sharing.friends.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Friends", systemImage: "person.2.fill")
                    .font(.headline)
                ForEach(sharing.friends) { friend in
                    NavigationLink {
                        FriendHabitDetailsView(friendID: friend.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: friend.snapshot.habit.iconName ?? "checkmark.circle")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(friend.snapshot.habit.name).font(.headline)
                                Text("\(friend.snapshot.ownerName) · Read only")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(friend.snapshot.habit.currentStreak()) 🔥")
                            Image(systemName: "chevron.right").font(.caption)
                        }
                        .padding(14)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
    }
}

private struct FriendHabitDetailsView: View {
    let friendID: String
    @ObservedObject private var sharing = CloudHabitSharing.shared
    private var friend: FriendHabit? { sharing.friends.first { $0.id == friendID } }
    var body: some View {
        List {
            if let friend {
                let habit = friend.snapshot.habit
                Section {
                    Label("\(friend.snapshot.ownerName)’s habit", systemImage: "person.fill")
                    Text("Read only")
                    if let goal = habit.goal {
                        Text("Goal: \(goal.formatted())\(habit.trackingMode == .timer ? " minutes" : "")")
                    }
                    if let started = habit.timerStartedAt {
                        let saved = habit.entries[Habit.dateKey(habit.timerStartedFor ?? started)]?.value ?? 0
                        HStack {
                            Text("Timer")
                            Spacer()
                            Text(started.addingTimeInterval(-saved), style: .timer).monospacedDigit()
                        }
                    }
                }
                Section("History") {
                    ForEach(habit.entries.keys.sorted(by: >), id: \.self) { day in
                        if let entry = habit.entries[day] {
                            HStack {
                                Text(day)
                                Spacer()
                                if habit.trackingMode == .number { Text(entry.value.formatted()) }
                                if habit.trackingMode == .timer { Text("\((entry.value / 60).formatted(.number.precision(.fractionLength(1)))) min") }
                                Image(systemName: entry.completed ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    }
                }
                Section {
                    Text("Updated \(friend.snapshot.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("This habit is no longer shared with you.")
            }
        }
        .navigationTitle(friend?.snapshot.habit.name ?? "Friend’s Habit")
    }
}

struct ShareHabitView: View {
    let habit: Habit
    @ObservedObject private var sharing = CloudHabitSharing.shared
    @State private var name = ""
    @State private var presentation: HabitSharePresentation?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Share \(habit.name) with a friend. They can see its progress and history, but cannot change it. Your notes stay private.")
                    TextField("Your name", text: $name).textContentType(.nickname)
                }
                Section {
                    Button {
                        sharing.ownerName = name
                        Task { presentation = await sharing.prepareShare(for: habit) }
                    } label: {
                        if sharing.busy { ProgressView() }
                        else { Label("Share with Friend", systemImage: "person.badge.plus") }
                    }
                    .disabled(sharing.busy || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section {
                    Text("You both need BeTheHabit and an iCloud account. Changes sync when BeTheHabit is open; your friend can pull down to refresh.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Share Habit")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .onAppear { name = sharing.ownerName }
            .alert("Habit Sharing", isPresented: Binding(
                get: { sharing.message != nil },
                set: { if !$0 { sharing.message = nil } }
            )) {
                Button("OK", role: .cancel) { sharing.message = nil }
            } message: { Text(sharing.message ?? "") }
            .sheet(item: $presentation) { CloudSharingSheet(presentation: $0) }
        }
    }
}
