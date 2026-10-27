import CloudKit
import Foundation
import HabitShared

/// Keeps a complete private copy for reinstall recovery. Friend sharing uses separate records.
@MainActor
final class CloudHabitBackup: ObservableObject {
    static let shared = CloudHabitBackup()

    @Published private(set) var status = "iCloud backup: checking"

    private static let recordID = CKRecord.ID(recordName: "complete-habits-v1")
    private let defaults = UserDefaults.standard
    private var store: HabitStore?
    private var accountID: String?
    private var initialized = false
    private var starting = false
    private var uploading = false
    private var pending = false
    private var debounceTask: Task<Void, Never>?
    private var lastUploadedData: Data?
    private var lastSavedAt: Date?

    private var enabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "BeHabitCloudSharingEnabled") as? Bool == true
    }
    private var accountKey: String {
        "behabit.cloudBackupAccount.\(environment)"
    }
    private var environment: String {
        Bundle.main.object(forInfoDictionaryKey: "BeHabitCloudEnvironment") as? String ?? "Unknown"
    }
    private var label: String {
        environment == "Development" ? "iCloud test backup" : "iCloud backup"
    }
    private var container: CKContainer { CKContainer(identifier: CloudHabitSharing.containerIdentifier) }

    func begin(with store: HabitStore) {
        self.store = store
        if initialized {
            changed()
            return
        }
        guard !starting else { return }
        starting = true
        Task {
            await prepare()
            starting = false
        }
    }

    private func prepare() async {
        guard enabled else { status = "\(label): unavailable in this build"; return }
        guard let store else { return }
        do {
            guard try await container.accountStatus() == .available else {
                status = "\(label): sign in to iCloud"
                return
            }
            let account = try await container.userRecordID().recordName
            if let previous = defaults.string(forKey: accountKey), previous != account {
                status = "\(label) paused: iCloud account changed"
                return
            }

            let cloudRecord: CKRecord?
            do { cloudRecord = try await container.privateCloudDatabase.record(for: Self.recordID) }
            catch let error as CKError where error.code == .unknownItem { cloudRecord = nil }

            let cloudData = try cloudRecord.flatMap { try Self.archiveData(from: $0) }
            if defaults.string(forKey: accountKey) == nil, let cloudData {
                let backup = try JSONDecoder().decode(HabitBackup.self, from: cloudData)
                try store.restoreFromCloud(backup)
            }
            defaults.set(account, forKey: accountKey)
            accountID = account
            lastUploadedData = cloudData
            lastSavedAt = cloudRecord?["savedAt"] as? Date
            initialized = true
            status = cloudData == nil ? "\(label): preparing" : "\(label): checking changes"
            changed()
        } catch let error as CKError where error.code == .operationCancelled {
            status = "\(label): waiting to retry"
        } catch {
            status = "\(label) failed: \(error.localizedDescription)"
        }
    }

    func changed() {
        guard initialized else { return }
        pending = true
        status = "\(label): saving"
        // Let an in-flight upload finish; flush() will then send the newest snapshot.
        if uploading { return }
        debounceTask?.cancel()
        debounceTask = Task {
            do { try await Task.sleep(for: .seconds(1)) }
            catch { return }
            await flush()
        }
    }

    private func flush() async {
        guard !uploading, pending, let store, let accountID else { return }
        uploading = true
        defer { uploading = false }
        while pending {
            pending = false
            do {
                guard try await container.accountStatus() == .available,
                      try await container.userRecordID().recordName == accountID else {
                    status = "\(label) paused: iCloud account changed or unavailable"
                    return
                }
                let backup = try store.cloudBackup()
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                let data = try encoder.encode(backup)
                if data == lastUploadedData {
                    status = savedStatus(lastSavedAt)
                    continue
                }

                let temporary = FileManager.default.temporaryDirectory
                    .appendingPathComponent("behabit-backup-\(UUID().uuidString).json")
                try data.write(to: temporary, options: .atomic)
                defer { try? FileManager.default.removeItem(at: temporary) }

                let database = container.privateCloudDatabase
                let record: CKRecord
                do { record = try await database.record(for: Self.recordID) }
                catch let error as CKError where error.code == .unknownItem {
                    record = CKRecord(recordType: "HabitArchive", recordID: Self.recordID)
                }
                let savedAt = Date()
                record["archive"] = CKAsset(fileURL: temporary)
                record["formatVersion"] = 1 as CKRecordValue
                record["savedAt"] = savedAt as CKRecordValue
                _ = try await database.save(record)
                lastUploadedData = data
                lastSavedAt = savedAt
                status = savedStatus(savedAt)
            } catch let error as CKError where error.code == .operationCancelled {
                pending = true
                status = "\(label): waiting to retry"
                return
            } catch {
                pending = true
                status = "\(label) failed: \(error.localizedDescription)"
                return
            }
        }
    }

    private static func archiveData(from record: CKRecord) throws -> Data {
        guard let asset = record["archive"] as? CKAsset, let url = asset.fileURL else {
            throw HabitRepository.RepositoryError.corruptData
        }
        return try Data(contentsOf: url)
    }

    private func savedStatus(_ date: Date?) -> String {
        guard let date else { return "\(label): saved" }
        return "\(label): saved \(date.formatted(date: .abbreviated, time: .shortened))"
    }
}
