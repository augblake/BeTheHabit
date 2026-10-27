import SwiftUI

/// A visual example only. Nothing here is saved to HabitStore.
struct MomentumPreviewView: View {
    let readyToContinue: Bool

    private let days = (0..<5).reversed().compactMap {
        Calendar.current.date(byAdding: .day, value: -$0, to: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BeTheHabit")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(Color.habitGold)
                        .shadow(color: Color.habitGold.opacity(0.5), radius: 12)

                    Text("30 days of momentum")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "plus")
                    .frame(width: 46, height: 46)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))

                Image(systemName: "ellipsis")
                    .frame(width: 42, height: 46)
            }
            .font(.system(size: 20, weight: .semibold))
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 24)

            VStack(spacing: 4) {
                HStack(spacing: 3) {
                    Color.clear.frame(width: 120, height: 60)

                    ForEach(days, id: \.self) { day in
                        let isToday = Calendar.current.isDateInToday(day)
                        VStack(spacing: 4) {
                            Text(day.formatted(.dateTime.weekday(.narrow)))
                                .font(.system(size: 12, weight: .medium))
                            Text(day.formatted(.dateTime.day()))
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(isToday ? Color.habitGreen : Color.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            isToday ? Color.habitGreen.opacity(0.1) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 15)
                        )
                    }
                }

                previewRow("Read Scripture", values: ["checkmark", "checkmark", "checkmark", "checkmark", "checkmark"], kind: .check)
                previewRow("Daily Steps", values: ["8", "10", "12", "12", "15"], kind: .number)
                previewRow("Prayer Time", values: ["18:20", "20:15", "22:05", "25:10", "30:00"], kind: .stopwatch)
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 0)

            Text("Tap anywhere to begin")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 30)
                .opacity(readyToContinue ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.background.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview: 30 days of momentum. Read Scripture, Daily Steps, and Prayer Time each have a 30 day streak. Tap anywhere to begin when prompted.")
    }

    private enum PreviewKind {
        case check, number, stopwatch
    }

    private func previewRow(_ name: String, values: [String], kind: PreviewKind) -> some View {
        HStack(spacing: 3) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Label("30 day streak", systemImage: "sparkle")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.habitGold)
            }
            .padding(.horizontal, 10)
            .frame(width: 120, height: 62, alignment: .leading)

            ForEach(values.indices, id: \.self) { index in
                Group {
                    if kind == .check {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.habitGreen)
                    } else {
                        Text(values[index])
                            .font(.system(size: kind == .number ? 15 : 11, weight: .medium))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 62)
            }
        }
        .frame(height: 62)
        .background(Color.habitGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 17))
        .overlay {
            RoundedRectangle(cornerRadius: 17)
                .strokeBorder(Color.habitGold, lineWidth: 3)
                .shadow(color: Color.habitGold.opacity(0.55), radius: 14)
        }
    }
}
