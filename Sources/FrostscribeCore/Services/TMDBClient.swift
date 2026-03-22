import Foundation

/// Client for the TMDB v3 REST API.
public final class TMDBClient: Sendable {
    public enum MediaType: String, Sendable {
        case movie
        case tv
    }

    public struct SearchResult: Sendable {
        public var id: Int
        public var title: String
        public var year: String
        public var mediaType: MediaType
    }

    private let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public var isConfigured: Bool { !apiKey.isEmpty }

    /// Searches TMDB for movies and TV shows matching the query.
    /// Returns up to 5 results.
    public func searchMulti(query: String) async throws -> [SearchResult] {
        guard isConfigured else { return [] }
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }

        let url = URL(string: "https://api.themoviedb.org/3/search/multi?query=\(encoded)&language=en-US&page=1")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(MultiSearchResponse.self, from: data)

        return response.results
            .filter { $0.mediaType == "movie" || $0.mediaType == "tv" }
            .prefix(5)
            .compactMap { result -> SearchResult? in
                guard let mediaType = MediaType(rawValue: result.mediaType) else { return nil }
                let title = result.title ?? result.name ?? "Unknown"
                let date = result.releaseDate ?? result.firstAirDate ?? ""
                let year = String(date.prefix(4))
                return SearchResult(id: result.id, title: title, year: year, mediaType: mediaType)
            }
    }

    /// Returns the number of episodes in a given TV season.
    public func seasonEpisodeCount(tvId: Int, season: Int) async throws -> Int? {
        guard isConfigured else { return nil }

        let url = URL(string: "https://api.themoviedb.org/3/tv/\(tvId)/season/\(season)?language=en-US")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SeasonResponse.self, from: data)
        return response.episodes?.count
    }

    // MARK: - Private response types

    private struct MultiSearchResponse: Decodable {
        var results: [MultiSearchResult]
    }

    private struct MultiSearchResult: Decodable {
        var id: Int
        var mediaType: String
        var title: String?
        var name: String?
        var releaseDate: String?
        var firstAirDate: String?

        enum CodingKeys: String, CodingKey {
            case id
            case mediaType = "media_type"
            case title
            case name
            case releaseDate = "release_date"
            case firstAirDate = "first_air_date"
        }
    }

    private struct SeasonResponse: Decodable {
        var episodes: [Episode]?
        struct Episode: Decodable {}
    }
}
