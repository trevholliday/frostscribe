import Foundation

public struct RipRecord: Codable, Sendable, Identifiable {
    public var id: UUID
    public var timestamp: Date
    public var discType: DiscType
    public var titleSizeBytes: Int
    public var ripDurationSeconds: Double
    public var jobLabel: String
    public var success: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        discType: DiscType,
        titleSizeBytes: Int,
        ripDurationSeconds: Double,
        jobLabel: String,
        success: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.discType = discType
        self.titleSizeBytes = titleSizeBytes
        self.ripDurationSeconds = ripDurationSeconds
        self.jobLabel = jobLabel
        self.success = success
    }
}
