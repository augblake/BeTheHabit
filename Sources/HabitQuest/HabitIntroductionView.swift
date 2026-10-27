import SwiftUI

struct HabitIntroductionView: View {
    let onFinish: () -> Void

    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("BeTheHabit")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.habitGold)
                Spacer()
                if page < 2 {
                    Button("Skip", action: onFinish)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .frame(height: 52, alignment: .top)

            TabView(selection: $page) {
                introductionPage(
                    visual: chooseVisual,
                    title: "Choose what matters",
                    detail: "Build up a habit or get rid of a habit. Give it a name and icon that feel like yours."
                ).tag(0)

                introductionPage(
                    visual: trackingVisual,
                    title: "Track your way",
                    detail: "Keep it simple with a check, record a number, or run a stopwatch. You can change how a habit is tracked later."
                ).tag(1)

                introductionPage(
                    visual: progressVisual,
                    title: "Keep going",
                    detail: "See your week, notice your progress, and come back tomorrow. Every faithful step counts.",
                    showsVerse: true
                ).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.accent : Color.primary.opacity(0.15))
                        .frame(width: index == page ? 19 : 7, height: 7)
                }
            }
            .accessibilityLabel("Page \(page + 1) of 3")
            .padding(.bottom, 18)

            Button {
                if page == 2 {
                    onFinish()
                } else {
                    withAnimation { page += 1 }
                }
            } label: {
                HStack {
                    Spacer()
                    Text(page == 2 ? "Get started" : "Next")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.background)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(Color.accent, in: Capsule())
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .background(Color.background.ignoresSafeArea())
    }

    private func introductionPage<Visual: View>(
        visual: Visual,
        title: String,
        detail: String,
        showsVerse: Bool = false
    ) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            visual.frame(maxWidth: 360)
            Text(title)
                .font(.system(size: 27, weight: .bold))
                .padding(.top, showsVerse ? 20 : 28)
            Text(detail)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 10)
            if showsVerse {
                Text("“And let us not be weary in well doing: for in due season we shall reap, if we faint not.”")
                    .font(.system(size: 15, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 22)
                Text("Galatians 6:9 · KJV")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.top, 7)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
    }

    private var chooseVisual: some View {
        VStack(spacing: 0) {
            exampleHabit("Daily walk", symbol: "figure.walk", checked: true)
            Divider()
            exampleHabit("Read Scripture", symbol: "book.closed.fill", checked: false)
            Divider()
            exampleHabit("Less screen time", symbol: "hourglass", checked: false)
            Text("＋ Add a habit")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accent)
                .padding(.top, 14)
        }
        .padding(16)
        .frame(height: 216)
        .background(Color.habitSurface, in: RoundedRectangle(cornerRadius: 24))
        .accessibilityLabel("Example habits: Daily walk, Read Scripture, Less screen time")
    }

    private func exampleHabit(_ name: String, symbol: String, checked: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .background(Color.background, in: RoundedRectangle(cornerRadius: 9))
            Text(name)
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Image(systemName: checked ? "checkmark" : "circle")
                .font(.system(size: checked ? 16 : 13, weight: .semibold))
                .foregroundStyle(checked ? Color.habitGreen : Color.secondary)
        }
        .frame(height: 47)
    }

    private var trackingVisual: some View {
        VStack(spacing: 9) {
            trackingRow("Yes or no", detail: "Mark today complete", symbol: "checkmark", value: "✓")
            trackingRow("Count", detail: "Record a daily number", symbol: "number", value: "8")
            trackingRow("Stopwatch", detail: "Time what you do", symbol: "stopwatch", value: "12:34")
        }
        .padding(16)
        .frame(height: 216)
        .background(Color.habitSurface, in: RoundedRectangle(cornerRadius: 24))
        .accessibilityLabel("Track a habit with yes or no, a count, or a stopwatch")
    }

    private func trackingRow(_ name: String, detail: String, symbol: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 2)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(value == "✓" ? Color.habitGreen : Color.primary)
        }
        .padding(.horizontal, 10)
        .frame(height: 52)
        .background(Color.background, in: RoundedRectangle(cornerRadius: 12))
    }

    private var progressVisual: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                ForEach(Array("MTWTFSS".enumerated()), id: \.offset) { _, day in
                    Text(String(day))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 0) {
                ForEach(0..<7) { day in
                    Image(systemName: day < 4 ? "checkmark" : "circle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(day < 4 ? Color.habitGreen : Color.primary.opacity(0.15))
                        .frame(maxWidth: .infinity)
                }
            }
            Text("4 day streak")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.habitGold)
        }
        .padding(16)
        .frame(height: 160)
        .background(Color.habitGold.opacity(0.07), in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.habitGold, lineWidth: 2)
        }
        .accessibilityLabel("Example weekly progress: four completed days and a four day streak")
    }
}
