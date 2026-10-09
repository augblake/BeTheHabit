import CloudKit
import Foundation
import HabitShared
import SwiftUI
import UIKit

struct FriendHabit: Identifiable, Codable {
    var id: String { "\(owner)/\(zone)/\(record)" }
    let owner: String
    let zone: String
    let record: String
    var snapshot: SharedHabitSnapshot
    var recordID: CKRecord.ID {
        CKRecord.ID(recordName: record, zoneID: .init(zoneName: zone, ownerName: owner))
    }
}

struct HabitSharePresentation: Identifiable {
    let id = UUID()
    let share: CKShare
    let container: CKContainer
}

@MainActor
final class CloudHabitSharing: ObservableObject {
    static let shared = CloudHabitSharing()
    static let containerIdentifier = "iCloud.com.bryceblake.BeHabit"
    @Published private(set) var friends: [FriendHabit] = []
    @Published var message: String?
    @Published private(set) var busy = false
    private let defaults = UserDefaults.standard
    private var owned: Set<UUID> = []
    private var syncTask: Task<Void, Never>?
    private var syncing = false
    private var refreshing = false
    private var latestHabits: [Habit] = []
    private let zoneID = CKRecordZone.ID(zoneName: "BeHabitShares", ownerName: CKCurrentUserDefaultName)

    // Enabled only after the container and matching provisioning are configured.
    var enabled: Bool { Bundle.main.object(forInfoDictionaryKey: "BeHabitCloudSharingEnabled") as? Bool == true }
    private var container: CKContainer { CKContainer(identifier: Self.containerIdentifier) }
    var ownerName: String {
        get { defaults.string(forKey: "behabit.shareName") ?? "" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "behabit.shareName") }
    }

    private init() {
        if let data = defaults.data(forKey: "behabit.friendHabits"),
           let saved = try? JSONDecoder().decode([FriendHabit].self, from: data) { friends = saved }
        owned = Set((defaults.stringArray(forKey: "behabit.ownedShares") ?? []).compactMap(UUID.init(uuidString:)))
    }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(friends), forKey: "behabit.friendHabits")
        defaults.set(owned.map(\.uuidString), forKey: "behabit.ownedShares")
    }

    private func requireAccount() async throws {
        guard enabled else { throw SharingError.setupRequired }
        guard try await container.accountStatus() == .available else {
            friends = []
            defaults.removeObject(forKey: "behabit.friendHabits")
            throw SharingError.iCloudRequired
        }
        let account = try await container.userRecordID().recordName
        if let previous = defaults.string(forKey: "behabit.shareAccount"), previous != account {
            friends = []
            owned = []
            persist()
        }
        defaults.set(account, forKey: "behabit.shareAccount")
    }

    func prepareShare(for habit: Habit) async -> HabitSharePresentation? {
        guard !busy else { return nil }
        busy = true
        defer { busy = false }
        do {
            try await requireAccount()
            guard !ownerName.isEmpty else { throw SharingError.nameRequired }
            let db = container.privateCloudDatabase
            _ = try await db.save(CKRecordZone(zoneID: zoneID))
            let id = CKRecord.ID(recordName: habit.id.uuidString, zoneID: zoneID)
            let root: CKRecord
            do { root = try await db.record(for: id) }
            catch let error as CKError where error.code == .unknownItem {
                root = CKRecord(recordType: "SharedHabit", recordID: id)
            }
            root["snapshot"] = try JSONEncoder().encode(SharedHabitSnapshot(habit: habit, ownerName: ownerName)) as CKRecordValue
            let share: CKShare
            if let reference = root.share {
                guard let existing = try await db.record(for: reference.recordID) as? CKShare else { throw SharingError.invalidInvitation }
                share = existing
            }
            else { share = CKShare(rootRecord: root) }
            share.publicPermission = .none
            share[CKShare.SystemFieldKey.title] = habit.name as CKRecordValue
            let result = try await db.modifyRecords(saving: [root, share], deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: true)
            for value in result.saveResults.values { _ = try value.get() }
            owned.insert(habit.id)
            persist()
            guard let savedShare = try result.saveResults[share.recordID]?.get() as? CKShare else { throw SharingError.invalidInvitation }
            return HabitSharePresentation(share: savedShare, container: container)
        } catch { message = error.localizedDescription; return nil }
    }

    func changed(_ habits: [Habit]) {
        latestHabits = habits
        guard enabled else { return }
        syncTask?.cancel()
        syncTask = Task {
            do { try await Task.sleep(for: .seconds(1)) }
            catch { return }
            await synchronize()
        }
    }

    func refresh(_ habits: [Habit]) async {
        latestHabits = habits
        guard enabled, !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        await synchronize()
        do {
            try await requireAccount()
            // Discover accepted shares after reinstall and shares accepted on another device.
            let zones = try await container.sharedCloudDatabase.allRecordZones()
            for zone in zones {
                let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zone.zoneID], configurationsByRecordZoneID: nil)
                var records: [CKRecord] = []
                // Use a serial operation queue callback bridge; collect under a lock.
                let collector = SharedRecordCollector()
                operation.recordWasChangedBlock = { _, result in
                    if case .success(let record) = result { collector.append(record) }
                }
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    operation.fetchRecordZoneChangesResultBlock = { result in continuation.resume(with: result) }
                    self.container.sharedCloudDatabase.add(operation)
                }
                records = collector.records
                for record in records where record.recordType == "SharedHabit" { try cache(record) }
            }
            // Fetch known roots directly, so revocations remove stale cached rows.
            for friend in friends {
                do { try cache(try await container.sharedCloudDatabase.record(for: friend.recordID)) }
                catch let error as CKError where error.code == .unknownItem || error.code == .permissionFailure || error.code == .zoneNotFound {
                    friends.removeAll { $0.id == friend.id }
                }
            }
            persist()
        } catch { message = "Sharing could not refresh. \(error.localizedDescription)" }
    }

    private func cache(_ record: CKRecord) throws {
        guard let data = record["snapshot"] as? Data else { return }
        let snapshot = try JSONDecoder().decode(SharedHabitSnapshot.self, from: data)
        let zone = record.recordID.zoneID
        let friend = FriendHabit(owner: zone.ownerName, zone: zone.zoneName, record: record.recordID.recordName, snapshot: snapshot)
        if let index = friends.firstIndex(where: { $0.id == friend.id }) { friends[index] = friend }
        else { friends.append(friend) }
    }

    private func synchronize() async {
        guard enabled, !syncing else { return }
        syncing = true
        defer { syncing = false }
        do {
            try await requireAccount()
            for id in Array(owned) {
                let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
                guard let habit = latestHabits.first(where: { $0.id == id }) else {
                    _ = try await container.privateCloudDatabase.deleteRecord(withID: recordID)
                    owned.remove(id)
                    persist()
                    continue
                }
                let root: CKRecord
                do { root = try await container.privateCloudDatabase.record(for: recordID) }
                catch let error as CKError where error.code == .unknownItem {
                    owned.remove(id); persist(); continue
                }
                guard root.share != nil else { owned.remove(id); persist(); continue }
                let previous = (root["snapshot"] as? Data).flatMap { try? JSONDecoder().decode(SharedHabitSnapshot.self, from: $0) }
                let updated = SharedHabitSnapshot(habit: habit, ownerName: ownerName)
                guard previous?.habit != updated.habit || previous?.ownerName != updated.ownerName else { continue }
                root["snapshot"] = try JSONEncoder().encode(updated) as CKRecordValue
                _ = try await container.privateCloudDatabase.save(root)
            }
        } catch { message = "Sharing could not sync. \(error.localizedDescription)" }
    }

    func accept(_ metadata: CKShare.Metadata) async {
        do {
            try await requireAccount()
            guard metadata.containerIdentifier == Self.containerIdentifier,
                  let rootID = metadata.hierarchicalRootRecordID else { throw SharingError.invalidInvitation }
            _ = try await container.accept(metadata)
            try cache(try await container.sharedCloudDatabase.record(for: rootID))
            persist()
        } catch { message = error.localizedDescription }
    }

    func stoppedSharing(_ share: CKShare) {
        // Next sync reads the authoritative root/share relationship.
        changed(latestHabits)
    }
}

private final class SharedRecordCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [CKRecord] = []
    func append(_ record: CKRecord) { lock.lock(); defer { lock.unlock() }; values.append(record) }
    var records: [CKRecord] { lock.lock(); defer { lock.unlock() }; return values }
}

private enum SharingError: LocalizedError {
    case setupRequired, iCloudRequired, nameRequired, invalidInvitation
    var errorDescription: String? {
        switch self {
        case .setupRequired: return "Friend sharing is waiting for iCloud setup."
        case .iCloudRequired: return "Sign in to iCloud in Settings to share habits."
        case .nameRequired: return "Enter the name your friends will see."
        case .invalidInvitation: return "This invitation is not a BeTheHabit habit share."
        }
    }
}

struct CloudSharingSheet: UIViewControllerRepresentable {
    let presentation: HabitSharePresentation
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: presentation.share, container: presentation.container)
        controller.availablePermissions = [.allowPrivate, .allowReadOnly]
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}
    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func itemTitle(for controller: UICloudSharingController) -> String? { controller.share?[CKShare.SystemFieldKey.title] as? String }
        func cloudSharingController(_ controller: UICloudSharingController, failedToSaveShareWithError error: Error) {
            CloudHabitSharing.shared.message = error.localizedDescription
        }
        func cloudSharingControllerDidStopSharing(_ controller: UICloudSharingController) {
            if let share = controller.share { CloudHabitSharing.shared.stoppedSharing(share) }
        }
    }
}

final class SharingAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: session.role)
        config.delegateClass = SharingSceneDelegate.self
        return config
    }
    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        Task { await CloudHabitSharing.shared.accept(metadata) }
    }
}

final class SharingSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        if let metadata = options.cloudKitShareMetadata { Task { await CloudHabitSharing.shared.accept(metadata) } }
    }
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        Task { await CloudHabitSharing.shared.accept(metadata) }
    }
}
