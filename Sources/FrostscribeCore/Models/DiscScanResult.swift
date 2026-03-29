import Foundation

public struct DiscScanResult: Codable, Sendable {
    public var titles: [DiscTitle]
    public var discName: String?
    public var discType: DiscType

    public init(titles: [DiscTitle], discName: String?, discType: DiscType) {
        self.titles = titles
        self.discName = discName
        self.discType = discType
    }
}
