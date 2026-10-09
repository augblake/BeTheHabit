import HabitShared
import SwiftUI

struct HabitIntroductionView: View {
    let onFinish: () -> Void

    @State private var page = 0

    private let pages: [(symbol: String, title: String, detail: String)] = [
        ("calendar", "Build your rhythm", "Add habits you want to build or break. Choose a simple check, a number, or a stopwatch to track each one."),
        ("hand.tap", "Track every day", "Tap a day to record it. Move across the week to update past dates, and tap a habit’s icon for notes, goals, and its full history."),
        ("chart.xyaxis.line", "See your progress", "Your week and streaks make steady progress easy to see. Long-press a habit to move it up or down whenever you like.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onFinish)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: pages[index].symbol)
                            .font(.system(size: 64, weight: .medium))
                            .foregroundStyle(Color.accent)
                            .frame(width: 132, height: 132)
                            .background(Color.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 36))

                        Text(pages[index].title)
                            .font(.system(size: 27, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(pages[index].detail)
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 32)
                        Spacer()
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if page == pages.count - 1 {
                    onFinish()
                } else {
                    withAnimation { page += 1 }
                }
            } label: {
                Text(page == pages.count - 1 ? "Get Started" : "Next")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.accent, in: Capsule())
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .background(Color.background.ignoresSafeArea())
    }
}
