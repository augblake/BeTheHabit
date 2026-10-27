import HabitShared
import SwiftUI

struct FriendHabitsView: View {
    @ObservedObject private var sharing = CloudHabitSharing.shared
    var body: some View {
        if sharing.enabled && !sharing.friends.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Friends", systemImage: "person.2.fill")
                    .font(.headline)
                ForEach(sharing.friends) { friend in
                    NavigationLink {
                        FriendHabitDetailsView(friendID: friend.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(friend.snapshot.habit.name).font(.headline)
                                    Text("\(friend.snapshot.ownerName) · Read only")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                FriendHabitStreakView(habit: friend.snapshot.habit)
                                Image(systemName: "chevron.right").font(.caption)
                            }
                            FriendHabitRecentProgressView(habit: friend.snapshot.habit)
                        }
                        .padding(14)
                        .background(
                            friend.snapshot.habit.visibleStreak() > 0 ? Color.habitGold.opacity(0.07) : Color.habitSurface,
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .overlay {
                            if friend.snapshot.habit.visibleStreak() > 0 {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.habitGold, lineWidth: 1.5)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
    }
}

private struct FriendHabitStreakView: View {
    let habit: Habit

    var body: some View {
        Label("\(habit.visibleStreak()) day streak", systemImage: "sparkle")
            .font(.caption.weight(.semibold))
            .foregroundStyle(habit.visibleStreak() > 0 ? Color.habitGold : Color.secondary)
    }
}

private struct FriendHabitRecentProgressView: View {
    let habit: Habit

    private var days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (-2...0).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.self) { date in
                let entry = habit.entry(for: date)
                VStack(spacing: 6) {
                    Text(date.formatted(.dateTime.weekday(.abbreviated).day()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Group {
                        if let entry {
                            if habit.trackingMode == .yesNo {
                                Image(systemName: entry.completed ? "checkmark" : "xmark")
                                    .font(.headline)
                            } else {
                                Text(progressText(entry))
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        } else {
                            Text("—").font(.headline)
                        }
                    }
                    .foregroundStyle(
                        entry == nil ? Color.secondary
                            : (habit.trackingMode == .yesNo && entry?.completed == true ? Color.habitGreen : Color.primary)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color.habitSurface, in: RoundedRectangle(cornerRadius: 10))
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .accessibilityValue(accessibilityProgress(entry))
            }
        }
    }

    private func progressText(_ entry: HabitEntry) -> String {
        if habit.trackingMode == .timer {
            return "\((entry.value / 60).formatted(.number.precision(.fractionLength(0...1)))) min"
        }
        return entry.value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func accessibilityProgress(_ entry: HabitEntry?) -> String {
        guard let entry else { return "No progress recorded" }
        let status = entry.completed ? "Complete" : "Not complete"
        return habit.trackingMode == .yesNo ? status : "\(progressText(entry)), \(status)"
    }
}

private struct FriendHabitDetailsView: View {
    let friendID: String
    @ObservedObject private var sharing = CloudHabitSharing.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingRemoveConfirmation = false
    private var friend: FriendHabit? { sharing.friends.first { $0.id == friendID } }
    var body: some View {
        List {
            if let friend {
                let habit = friend.snapshot.habit
                Section {
                    Label("\(friend.snapshot.ownerName)’s habit", systemImage: "person.fill")
                    Text("Read only")
                    FriendHabitStreakView(habit: habit)
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
                Section("Last three days") {
                    FriendHabitRecentProgressView(habit: habit)
                }
                Section {
                    Text("Updated \(friend.snapshot.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button("Remove Shared Habit", systemImage: "person.crop.circle.badge.minus", role: .destructive) {
                        showingRemoveConfirmation = true
                    }
                    .disabled(sharing.leavingIDs.contains(friendID))
                }
            } else {
                Text("This habit is no longer shared with you.")
            }
        }
        .navigationTitle(friend?.snapshot.habit.name ?? "Friend’s Habit")
        .confirmationDialog(
            "Remove this shared habit?",
            isPresented: $showingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Shared Habit", role: .destructive) {
                Task {
                    if await sharing.leaveSharedHabit(id: friendID) { dismiss() }
                }
            }
        } message: {
            Text("It will disappear from your Friends list. Your friend's original habit stays intact.")
        }
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
                if sharing.message != nil {
                    Section { SharingErrorView() }
                }
                Section {
                    Text("Share \(habit.name) with a friend. They’ll see your last three days of progress and current streak, but cannot change your habit. Your notes stay private.")
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
            .sheet(item: $presentation) { CloudSharingSheet(presentation: $0) }
        }
    }
}

// A shared error must not be presented by competing alerts in stacked sheets.
// Keep it readable until the user explicitly dismisses it.
struct SharingErrorView: View {
    @ObservedObject private var sharing = CloudHabitSharing.shared

    var body: some View {
        if let message = sharing.message {
            VStack(alignment: .leading, spacing: 8) {
                Label("Habit Sharing", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                Text(message).textSelection(.enabled)
                Button("Dismiss") { sharing.message = nil }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
