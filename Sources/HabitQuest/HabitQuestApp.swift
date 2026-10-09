import HabitShared
import SwiftUI

@main
struct HabitQuestApp: App {
    @UIApplicationDelegateAdaptor(SharingAppDelegate.self) private var appDelegate
    @StateObject private var sharing = CloudHabitSharing.shared
    @StateObject private var store = HabitStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
                ContentView()
                    .environmentObject(store)
                    .task {
                        while !Task.isCancelled {
                            if scenePhase == .active {
                                store.refresh()
                                await sharing.refresh(store.habits)
                            }
                            do { try await Task.sleep(for: .seconds(30)) } catch { break }
                        }
                    }
                    .onChange(of: store.habits) { _, habits in sharing.changed(habits) }
                    .onChange(of: scenePhase) { _, phase in
                        if phase == .active {
                            store.refresh()
                            Task { await sharing.refresh(store.habits) }
                        }
                    }
        }
    }
}
