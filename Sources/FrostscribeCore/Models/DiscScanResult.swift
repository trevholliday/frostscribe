import Foundation

public struct DiscScanResult: Sendable {
    public var titles: [DiscTitle]
    public var discName: String?
    public var discType: String?

    public init(titles: [DiscTitle], discName: String?, discType: String?) {
        self.titles = titles
        self.discName = discName
        self.discType = discType
    }
}
