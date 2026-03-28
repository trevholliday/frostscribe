import Foundation

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
        public var posterPath: String?
        public var backdropPath: String?

        public var posterURL: URL? {
            guard let path = posterPath else { return nil }
            return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
        }

        public var backdropURL: URL? {
            guard let path = backdropPath else { return nil }
            return URL(string: "https://image.tmdb.org/t/p/w1280\(path)")
        }
    }

    private let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public var isConfigured: Bool { !apiKey.isEmpty }

    public func searchMulti(query: String) async throws -> [SearchResult] {
        guard isConfigured else { return [] }
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }

        let url = URL(string: "https://api.themoviedb.org/3/search/multi?api_key=\(apiKey)&query=\(encoded)&language=en-US&page=1")!
        let request = URLRequest(url: url)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
        guard let decoded = try? JSONDecoder().decode(MultiSearchResponse.self, from: data) else { return [] }

        return decoded.results
            .filter { $0.mediaType == "movie" || $0.mediaType == "tv" }
            .prefix(5)
            .compactMap { result -> SearchResult? in
                guard let mediaType = MediaType(rawValue: result.mediaType) else { return nil }
                let title = result.title ?? result.name ?? "Unknown"
                let date = result.releaseDate ?? result.firstAirDate ?? ""
                let year = String(date.prefix(4))
                return SearchResult(id: result.id, title: title, year: year, mediaType: mediaType,
                                   posterPath: result.posterPath, backdropPath: result.backdropPath)
            }
    }

    /// Fetches all backdrop URLs for a movie or TV show, up to `limit`.
    public func backdrops(id: Int, mediaType: MediaType, limit: Int = 12) async throws -> [URL] {
        guard isConfigured else { return [] }
        let type = mediaType == .movie ? "movie" : "tv"
        let url = URL(string: "https://api.themoviedb.org/3/\(type)/\(id)/images?api_key=\(apiKey)")!
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
        guard let decoded = try? JSONDecoder().decode(ImagesResponse.self, from: data) else { return [] }
        return decoded.backdrops
            .sorted { $0.voteAverage > $1.voteAverage }
            .prefix(limit)
            .compactMap { URL(string: "https://image.tmdb.org/t/p/w1280\($0.filePath)") }
    }

    /// Fetches full details (tagline, overview, genres, runtime, certification, crew) for a movie or TV show.
    public func details(id: Int, mediaType: MediaType) async throws -> MediaDetails {
        guard isConfigured else { return MediaDetails() }
        let type = mediaType == .movie ? "movie" : "tv"
        let append = mediaType == .movie ? "credits,release_dates" : "credits,content_ratings"
        let url = URL(string: "https://api.themoviedb.org/3/\(type)/\(id)?api_key=\(apiKey)&language=en-US&append_to_response=\(append)")!
        let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))

        if mediaType == .movie {
            guard let r = try? JSONDecoder().decode(MovieDetailResponse.self, from: data) else { return MediaDetails() }
            let usRelease = r.releaseDates?.results.first(where: { $0.iso31661 == "US" })?
                .releaseDates.first(where: { $0.type == 3 || $0.type == 4 || $0.type == 5 })
            let cert = usRelease?.certification
            let releaseDate = usRelease?.releaseDate.prefix(10).description
                .replacingOccurrences(of: #"(\d{4})-(\d{2})-(\d{2})"#,
                                      with: "$2/$3/$1", options: .regularExpression)
            let crew: [MediaDetails.CrewMember] = (r.credits?.crew ?? [])
                .filter { ["Director", "Screenplay", "Writer", "Story"].contains($0.job) }
                .map { MediaDetails.CrewMember(name: $0.name, job: $0.job) }
            return MediaDetails(
                tagline: r.tagline.flatMap { $0.isEmpty ? nil : $0 },
                overview: r.overview.flatMap { $0.isEmpty ? nil : $0 },
                runtimeMinutes: r.runtime,
                genres: r.genres.map(\.name),
                releaseDate: releaseDate.map { "\($0) (US)" },
                certification: cert.flatMap { $0.isEmpty ? nil : $0 },
                crew: crew
            )
        } else {
            guard let r = try? JSONDecoder().decode(TVDetailResponse.self, from: data) else { return MediaDetails() }
            let cert = r.contentRatings?.results.first(where: { $0.iso31661 == "US" })?.rating
            var crew: [MediaDetails.CrewMember] = (r.createdBy ?? [])
                .map { MediaDetails.CrewMember(name: $0.name, job: "Creator") }
            crew += (r.credits?.crew ?? [])
                .filter { ["Director", "Screenplay", "Writer", "Story"].contains($0.job) }
                .prefix(4)
                .map { MediaDetails.CrewMember(name: $0.name, job: $0.job) }
            return MediaDetails(
                tagline: r.tagline.flatMap { $0.isEmpty ? nil : $0 },
                overview: r.overview.flatMap { $0.isEmpty ? nil : $0 },
                runtimeMinutes: r.episodeRunTime?.first,
                genres: r.genres.map(\.name),
                releaseDate: nil,
                certification: cert.flatMap { $0.isEmpty ? nil : $0 },
                crew: crew
            )
        }
    }

    public func seasonEpisodeCount(tvId: Int, season: Int) async throws -> Int? {
        guard isConfigured else { return nil }

        let url = URL(string: "https://api.themoviedb.org/3/tv/\(tvId)/season/\(season)?api_key=\(apiKey)&language=en-US")!
        let request = URLRequest(url: url)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SeasonResponse.self, from: data)
        return response.episodes?.count
    }

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
        var posterPath: String?
        var backdropPath: String?

        enum CodingKeys: String, CodingKey {
            case id
            case mediaType = "media_type"
            case title
            case name
            case releaseDate = "release_date"
            case firstAirDate = "first_air_date"
            case posterPath = "poster_path"
            case backdropPath = "backdrop_path"
        }
    }

    private struct ImagesResponse: Decodable {
        var backdrops: [ImageEntry]
        struct ImageEntry: Decodable {
            var filePath: String
            var voteAverage: Double
            enum CodingKeys: String, CodingKey {
                case filePath = "file_path"
                case voteAverage = "vote_average"
            }
        }
    }

    private struct SeasonResponse: Decodable {
        var episodes: [Episode]?
        struct Episode: Decodable {}
    }

    // MARK: - Details response types

    private struct Genre: Decodable { var name: String }
    private struct CrewEntry: Decodable { var name: String; var job: String }
    private struct Credits: Decodable { var crew: [CrewEntry] }

    private struct MovieDetailResponse: Decodable {
        var tagline: String?
        var overview: String?
        var runtime: Int?
        var genres: [Genre]
        var releaseDates: ReleaseDatesWrapper?
        var credits: Credits?
        enum CodingKeys: String, CodingKey {
            case tagline, overview, runtime, genres
            case releaseDates = "release_dates"
            case credits
        }
        struct ReleaseDatesWrapper: Decodable {
            var results: [ReleaseDateCountry]
        }
        struct ReleaseDateCountry: Decodable {
            var iso31661: String
            var releaseDates: [ReleaseDate]
            enum CodingKeys: String, CodingKey {
                case iso31661 = "iso_3166_1"
                case releaseDates = "release_dates"
            }
        }
        struct ReleaseDate: Decodable {
            var certification: String
            var releaseDate: String
            var type: Int
            enum CodingKeys: String, CodingKey {
                case certification
                case releaseDate = "release_date"
                case type
            }
        }
    }

    private struct TVDetailResponse: Decodable {
        var tagline: String?
        var overview: String?
        var episodeRunTime: [Int]?
        var genres: [Genre]
        var createdBy: [Creator]?
        var contentRatings: ContentRatingsWrapper?
        var credits: Credits?
        enum CodingKeys: String, CodingKey {
            case tagline, overview, genres, credits
            case episodeRunTime = "episode_run_time"
            case createdBy = "created_by"
            case contentRatings = "content_ratings"
        }
        struct Creator: Decodable { var name: String }
        struct ContentRatingsWrapper: Decodable { var results: [ContentRating] }
        struct ContentRating: Decodable {
            var iso31661: String
            var rating: String
            enum CodingKeys: String, CodingKey {
                case iso31661 = "iso_3166_1"
                case rating
            }
        }
    }
}
