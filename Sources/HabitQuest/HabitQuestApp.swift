import HabitShared
import SwiftUI

@main
struct HabitQuestApp: App {
    @UIApplicationDelegateAdaptor(SharingAppDelegate.self) private var appDelegate
    @StateObject private var sharing = CloudHabitSharing.shared
    @StateObject private var backup = CloudHabitBackup.shared
    @StateObject private var store = HabitStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
                ContentView()
                    .environmentObject(store)
                    .tint(.habitGreen)
                    .task {
                        backup.begin(with: store)
                        while !Task.isCancelled {
                            if scenePhase == .active {
                                store.refresh()
                                backup.begin(with: store)
                                await sharing.refresh(store.habits)
                            }
                            do { try await Task.sleep(for: .seconds(30)) } catch { break }
                        }
                    }
                    .onChange(of: store.habits) { habits in sharing.changed(habits) }
                    .onChange(of: scenePhase) { phase in
                        if phase == .active {
                            store.refresh()
                            backup.begin(with: store)
                            Task { await sharing.refresh(store.habits) }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                        backup.changed()
                    }
        }
    }
}
