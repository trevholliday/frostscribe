import Foundation

public struct EncodeInput: Sendable {
    public let outputURL: URL
    public let preset: String
    public let title: String
    public let episode: String?
    public let selectedAudioTracks: [Int]?

    public init(
        outputURL: URL,
        preset: String,
        title: String,
        episode: String? = nil,
        selectedAudioTracks: [Int]? = nil
    ) {
        self.outputURL = outputURL
        self.preset = preset
        self.title = title
        self.episode = episode
        self.selectedAudioTracks = selectedAudioTracks
    }
}

public final class EncodeUseCase: Sendable {
    private let queue: any QueueManaging

    public init(queue: any QueueManaging) {
        self.queue = queue
    }

    /// Adds an encode job to the queue using the MKV produced by RipUseCase.
    public func execute(_ input: EncodeInput, inputMKV: URL) throws {
        try queue.add(
            input: inputMKV,
            output: input.outputURL,
            preset: input.preset,
            title: input.title,
            episode: input.episode,
            audioTracks: input.selectedAudioTracks
        )
    }
}
