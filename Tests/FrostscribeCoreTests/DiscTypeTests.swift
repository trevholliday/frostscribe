import Testing
@testable import FrostscribeCore
import Foundation

@Suite("DiscType")
struct DiscTypeTests {

    // MARK: - makeMKVString initializer

    @Test func makeMKVStringBlurayDisc() {
        #expect(DiscType(makeMKVString: "Blu-ray disc") == .bluray)
    }

    @Test func makeMKVStringBlurayDiscLowercase() {
        #expect(DiscType(makeMKVString: "blu-ray disc") == .bluray)
    }

    @Test func makeMKVStringDVDDisc() {
        #expect(DiscType(makeMKVString: "DVD disc") == .dvd)
    }

    @Test func makeMKVStringDVDDiscLowercase() {
        #expect(DiscType(makeMKVString: "dvd disc") == .dvd)
    }

    @Test func makeMKVStringUHDBlurayDisc() {
        #expect(DiscType(makeMKVString: "UHD Blu-ray disc") == .uhd)
    }

    @Test func makeMKVStringUHDBlurayDiscLowercase() {
        #expect(DiscType(makeMKVString: "uhd blu-ray disc") == .uhd)
    }

    @Test func makeMKVStringUltraHD() {
        // "ultra" keyword maps to UHD
        #expect(DiscType(makeMKVString: "Ultra HD disc") == .uhd)
    }

    @Test func makeMKVStringUnknownString() {
        #expect(DiscType(makeMKVString: "Unknown optical disc") == .unknown)
    }

    @Test func makeMKVStringEmpty() {
        #expect(DiscType(makeMKVString: "") == .unknown)
    }

    @Test func makeMKVStringUHDTakesPrecedenceOverBluray() {
        // "UHD Blu-ray" contains both "blu" and "uhd" — UHD check is first
        #expect(DiscType(makeMKVString: "UHD Blu-ray disc") == .uhd)
    }

    @Test func makeMKVStringContainingUHD() {
        #expect(DiscType(makeMKVString: "4K UHD Disc") == .uhd)
    }

    // MARK: - displayName

    @Test func displayNameDVD() {
        #expect(DiscType.dvd.displayName == "DVD")
    }

    @Test func displayNameBluray() {
        #expect(DiscType.bluray.displayName == "Blu-ray")
    }

    @Test func displayNameUHD() {
        #expect(DiscType.uhd.displayName == "UHD")
    }

    @Test func displayNameUnknown() {
        #expect(DiscType.unknown.displayName == "Unknown")
    }

    // MARK: - rawValue round-trip

    @Test func rawValueRoundTripDVD() {
        #expect(DiscType(rawValue: "dvd") == .dvd)
    }

    @Test func rawValueRoundTripBluray() {
        #expect(DiscType(rawValue: "bluray") == .bluray)
    }

    @Test func rawValueRoundTripUHD() {
        #expect(DiscType(rawValue: "uhd") == .uhd)
    }

    @Test func rawValueRoundTripUnknown() {
        #expect(DiscType(rawValue: "unknown") == .unknown)
    }

    @Test func rawValueInvalidReturnsNil() {
        #expect(DiscType(rawValue: "laser disc") == nil)
    }

    @Test func rawValuePreservesCase() {
        // rawValue is lowercase "dvd", "bluray", "uhd", "unknown"
        #expect(DiscType.dvd.rawValue == "dvd")
        #expect(DiscType.bluray.rawValue == "bluray")
        #expect(DiscType.uhd.rawValue == "uhd")
        #expect(DiscType.unknown.rawValue == "unknown")
    }

    // MARK: - CaseIterable

    @Test func allCasesHasFourElements() {
        #expect(DiscType.allCases.count == 4)
    }

    @Test func allCasesContainsExpectedValues() {
        #expect(DiscType.allCases.contains(.dvd))
        #expect(DiscType.allCases.contains(.bluray))
        #expect(DiscType.allCases.contains(.uhd))
        #expect(DiscType.allCases.contains(.unknown))
    }
}
