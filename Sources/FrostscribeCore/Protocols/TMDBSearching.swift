import Foundation

public protocol TMDBSearching: Sendable {
    var isConfigured: Bool { get }
    func searchMulti(query: String) async throws -> [TMDBClient.SearchResult]
    func backdrops(id: Int, mediaType: TMDBClient.MediaType) async throws -> [URL]
    func details(id: Int, mediaType: TMDBClient.MediaType) async throws -> MediaDetails
}
