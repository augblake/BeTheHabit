import Foundation

/// The owner's complete private archive. Unlike friend snapshots, this includes notes.
public struct HabitBackup: Codable, Equatable {
    public let version: Int
    public let habits: [Habit]
    public let selectedWidgetHabitID: UUID?
    public let lightAppearance: Bool
    public let introductionSeen: Bool
    public let momentumDaysData: Data?
    public let momentumHistorySeeded: Bool
    // Optional so archives written before sharing setup was included still decode.
    public let sharingOwnerName: String?
    public let ownedShareIDs: [UUID]?

    public init(
        habits: [Habit],
        selectedWidgetHabitID: UUID?,
        lightAppearance: Bool,
        introductionSeen: Bool,
        momentumDaysData: Data?,
        momentumHistorySeeded: Bool,
        sharingOwnerName: String? = nil,
        ownedShareIDs: [UUID]? = nil
    ) {
        self.version = 1
        self.habits = habits
        self.selectedWidgetHabitID = selectedWidgetHabitID
        self.lightAppearance = lightAppearance
        self.introductionSeen = introductionSeen
        self.momentumDaysData = momentumDaysData
        self.momentumHistorySeeded = momentumHistorySeeded
        self.sharingOwnerName = sharingOwnerName
        self.ownedShareIDs = ownedShareIDs
    }
}
