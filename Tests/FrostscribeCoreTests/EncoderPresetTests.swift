import Testing
@testable import FrostscribeCore

@Suite("EncoderPreset")
struct EncoderPresetTests {

    // MARK: - preset(for:)

    @Test func blurayDiscTypeReturnsBlurayPreset() {
        #expect(EncoderPreset.preset(for: "Blu-ray") == EncoderPreset.bluray)
        #expect(EncoderPreset.preset(for: "blu-ray disc") == EncoderPreset.bluray)
    }

    @Test func dvdDiscTypeReturnsDvdPreset() {
        #expect(EncoderPreset.preset(for: "DVD") == EncoderPreset.dvd)
    }

    @Test func nilDiscTypeReturnsDvdPreset() {
        #expect(EncoderPreset.preset(for: nil) == EncoderPreset.dvd)
    }

    // MARK: - arguments(input:output:preset:audioTracks:)

    @Test func nilAudioTracksUsesDefaultDualTrack() {
        let args = EncoderPreset.arguments(
            input: "/tmp/in.mkv",
            output: "/tmp/out.mkv",
            preset: EncoderPreset.dvd,
            audioTracks: nil
        )
        #expect(args.contains("--audio"))
        let idx = args.firstIndex(of: "--audio")!
        #expect(args[idx + 1] == "1,1")
        let encIdx = args.firstIndex(of: "--aencoder")!
        #expect(args[encIdx + 1] == "ca_aac,copy:ac3")
    }

    @Test func emptyAudioTracksUsesDefaultDualTrack() {
        let args = EncoderPreset.arguments(
            input: "/tmp/in.mkv",
            output: "/tmp/out.mkv",
            preset: EncoderPreset.dvd,
            audioTracks: []
        )
        let idx = args.firstIndex(of: "--audio")!
        #expect(args[idx + 1] == "1,1")
    }

    @Test func selectedAudioTracksGeneratesOneEncoderPerTrack() {
        let args = EncoderPreset.arguments(
            input: "/tmp/in.mkv",
            output: "/tmp/out.mkv",
            preset: EncoderPreset.dvd,
            audioTracks: [1, 3]
        )
        let audioIdx = args.firstIndex(of: "--audio")!
        #expect(args[audioIdx + 1] == "1,3")

        let encIdx = args.firstIndex(of: "--aencoder")!
        #expect(args[encIdx + 1] == "ca_aac,ca_aac")

        let abIdx = args.firstIndex(of: "--ab")!
        #expect(args[abIdx + 1] == "160,160")

        let nameIdx = args.firstIndex(of: "--aname")!
        #expect(args[nameIdx + 1] == "Track 1,Track 3")
    }

    @Test func singleSelectedTrackGeneratesOneEncoder() {
        let args = EncoderPreset.arguments(
            input: "/tmp/in.mkv",
            output: "/tmp/out.mkv",
            preset: EncoderPreset.dvd,
            audioTracks: [2]
        )
        let audioIdx = args.firstIndex(of: "--audio")!
        #expect(args[audioIdx + 1] == "2")

        let encIdx = args.firstIndex(of: "--aencoder")!
        #expect(args[encIdx + 1] == "ca_aac")
    }

    @Test func argumentsAlwaysContainsInputOutputPreset() {
        let args = EncoderPreset.arguments(
            input: "/in.mkv",
            output: "/out.mkv",
            preset: "My Preset"
        )
        #expect(args.contains("-i"))
        #expect(args.contains("/in.mkv"))
        #expect(args.contains("-o"))
        #expect(args.contains("/out.mkv"))
        #expect(args.contains("--preset"))
        #expect(args.contains("My Preset"))
    }

    @Test func subtitleNoneIsAlwaysPresent() {
        let args = EncoderPreset.arguments(input: "/in.mkv", output: "/out.mkv", preset: EncoderPreset.dvd)
        #expect(args.contains("--subtitle"))
        let idx = args.firstIndex(of: "--subtitle")!
        #expect(args[idx + 1] == "none")
    }
}
