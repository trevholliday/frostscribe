import Testing
@testable import FrostscribeCore

@Suite("EncoderPreset")
struct EncoderPresetTests {

    // MARK: - preset(for:)

    @Test func blurayDiscTypeReturnsBlurayPreset() {
        #expect(EncoderPreset.preset(for: .bluray) == EncoderPreset.bluray)
    }

    @Test func uhdDiscTypeReturnsBlurayPreset() {
        #expect(EncoderPreset.preset(for: .uhd) == EncoderPreset.bluray)
    }

    @Test func dvdDiscTypeReturnsDvdPreset() {
        #expect(EncoderPreset.preset(for: .dvd) == EncoderPreset.dvd)
    }

    @Test func unknownDiscTypeReturnsDvdPreset() {
        #expect(EncoderPreset.preset(for: .unknown) == EncoderPreset.dvd)
    }

    // MARK: - arguments(input:output:preset:audioTracks:quality:)

    @Test func nilAudioTracksUsesDefaultDualTrack() {
        let args = EncoderPreset.arguments(
            input: "/tmp/in.mkv",
            output: "/tmp/out.mkv",
            preset: EncoderPreset.dvd,
            audioTracks: nil,
            quality: 70
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
            audioTracks: [],
            quality: 70
        )
        let idx = args.firstIndex(of: "--audio")!
        #expect(args[idx + 1] == "1,1")
    }

    @Test func selectedAudioTracksGeneratesOneEncoderPerTrack() {
        let args = EncoderPreset.arguments(
            input: "/tmp/in.mkv",
            output: "/tmp/out.mkv",
            preset: EncoderPreset.dvd,
            audioTracks: [1, 3],
            quality: 70
        )
        let audioIdx = args.firstIndex(of: "--audio")!
        #expect(args[audioIdx + 1] == "1,3")

        let encIdx = args.firstIndex(of: "--aencoder")!
        #expect(args[encIdx + 1] == "ca_aac,ca_aac")

        let abIdx = args.firstIndex(of: "--ab")!
        #expect(args[abIdx + 1] == "320,320")

        let nameIdx = args.firstIndex(of: "--aname")!
        #expect(args[nameIdx + 1] == "Track 1,Track 3")
    }

    @Test func singleSelectedTrackGeneratesOneEncoder() {
        let args = EncoderPreset.arguments(
            input: "/tmp/in.mkv",
            output: "/tmp/out.mkv",
            preset: EncoderPreset.dvd,
            audioTracks: [2],
            quality: 70
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
            preset: "My Preset",
            audioTracks: nil,
            quality: 70
        )
        #expect(args.contains("-i"))
        #expect(args.contains("/in.mkv"))
        #expect(args.contains("-o"))
        #expect(args.contains("/out.mkv"))
        #expect(args.contains("--preset"))
        #expect(args.contains("My Preset"))
    }

    @Test func subtitleTracksAreAlwaysPresent() {
        let args = EncoderPreset.arguments(
            input: "/in.mkv",
            output: "/out.mkv",
            preset: EncoderPreset.dvd,
            audioTracks: nil,
            quality: 70
        )
        #expect(args.contains("--subtitle"))
        let idx = args.firstIndex(of: "--subtitle")!
        #expect(args[idx + 1] == "1,2,3,4,5,6,7,8")
    }

    @Test func dvdArgumentsScaleToSquarePixel720p() {
        let args = EncoderPreset.arguments(
            input: "/in.mkv",
            output: "/out.mkv",
            preset: EncoderPreset.dvd,
            audioTracks: nil,
            quality: 18
        )

        #expect(args.contains("--non-anamorphic"))
        #expect(flag(args, "--height") == "720")
        #expect(flag(args, "--maxWidth") == "1280")
        #expect(args.contains("--detelecine"))
        #expect(flag(args, "--comb-detect") == "permissive")
        #expect(args.contains("--decomb"))
        #expect(flag(args, "--chroma-smooth") == "ultralight")
        #expect(flag(args, "--lapsharp") == "light")
        #expect(flag(args, "--lapsharp-tune") == "film")
        #expect(flag(args, "--color-matrix") == "601")
    }

    @Test func blurayArgumentsLeavePictureSizeToThePreset() {
        let args = EncoderPreset.arguments(
            input: "/in.mkv",
            output: "/out.mkv",
            preset: EncoderPreset.bluray,
            audioTracks: nil,
            quality: 18
        )

        #expect(!args.contains("--non-anamorphic"))
        #expect(!args.contains("--height"))
        #expect(!args.contains("--maxWidth"))
        #expect(!args.contains("--detelecine"))
        #expect(!args.contains("--lapsharp"))
        #expect(!args.contains("--chroma-smooth"))
    }

    @Test func qualityIsPassedToArguments() {
        let args = EncoderPreset.arguments(
            input: "/in.mkv",
            output: "/out.mkv",
            preset: EncoderPreset.dvd,
            audioTracks: nil,
            quality: 75
        )
        #expect(args.contains("--quality"))
        let idx = args.firstIndex(of: "--quality")!
        #expect(args[idx + 1] == "75")
    }
}

private func flag(_ args: [String], _ name: String) -> String? {
    guard let idx = args.firstIndex(of: name), args.indices.contains(idx + 1) else { return nil }
    return args[idx + 1]
}
