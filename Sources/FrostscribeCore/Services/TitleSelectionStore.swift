import Foundation
import GRDB

// MARK: - GRDB conformance

extension TitleSelectionRecord: FetchableRecord {
    public init(row: Row) throws {
        id               = UUID(uuidString: row["id"]) ?? UUID()
        selectionId      = UUID(uuidString: row["selection_id"]) ?? UUID()
        timestamp        = row["timestamp"]
        discType         = row["disc_type"]
        mediaType        = row["media_type"]
        discName         = row["disc_name"]
        totalTitleCount  = row["total_title_count"]
        isSelected       = row["is_selected"]
        titleNumber      = row["title_number"]
        durationMinutes  = row["duration_minutes"]
        chapters         = row["chapters"]
        sizeBytes        = row["size_bytes"]
        angle            = row["angle"]
        audioTrackCount  = row["audio_track_count"]
        hasLosslessAudio = row["has_lossless_audio"]
        videoWidth       = row["video_width"]
        videoHeight      = row["video_height"]
        subtitleCount    = row["subtitle_count"]
        orderWeight      = row["order_weight"]
        segmentsMap      = row["segments_map"]
        titleDescription = row["title_description"]
        durationRank     = row["duration_rank"]
        sizeRank         = row["size_rank"]
    }
}

extension TitleSelectionRecord: MutablePersistableRecord {
    public static let databaseTableName = "title_selections"

    public func encode(to container: inout PersistenceContainer) throws {
        container["id"]               = id.uuidString
        container["selection_id"]     = selectionId.uuidString
        container["timestamp"]        = timestamp
        container["disc_type"]        = discType
        container["media_type"]       = mediaType
        container["disc_name"]        = discName
        container["total_title_count"] = totalTitleCount
        container["is_selected"]      = isSelected
        container["title_number"]     = titleNumber
        container["duration_minutes"] = durationMinutes
        container["chapters"]         = chapters
        container["size_bytes"]       = sizeBytes
        container["angle"]            = angle
        container["audio_track_count"] = audioTrackCount
        container["has_lossless_audio"] = hasLosslessAudio
        container["video_width"]      = videoWidth
        container["video_height"]     = videoHeight
        container["subtitle_count"]   = subtitleCount
        container["order_weight"]     = orderWeight
        container["segments_map"]     = segmentsMap
        container["title_description"] = titleDescription
        container["duration_rank"]    = durationRank
        container["size_rank"]        = sizeRank
    }
}

// MARK: - Store

public struct TitleSelectionStore: Sendable {
    private let dbQueue: DatabaseQueue?

    public init(appSupportURL: URL) {
        let dbURL = appSupportURL.appending(path: "titleselections.db")
        do {
            let queue = try DatabaseQueue(path: dbURL.path)
            try Self.migrate(queue)
            self.dbQueue = queue
        } catch {
            self.dbQueue = nil
        }
    }

    private static func migrate(_ db: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "title_selections", ifNotExists: true) { t in
                t.primaryKey("id", .text)
                t.column("selection_id", .text).notNull().indexed()
                t.column("timestamp", .datetime).notNull()
                t.column("disc_type", .text).notNull()
                t.column("media_type", .text).notNull()
                t.column("disc_name", .text)
                t.column("total_title_count", .integer).notNull()
                t.column("is_selected", .boolean).notNull()
                t.column("title_number", .integer).notNull()
                t.column("duration_minutes", .integer).notNull()
                t.column("chapters", .integer).notNull()
                t.column("size_bytes", .integer).notNull()
                t.column("angle", .integer).notNull()
                t.column("audio_track_count", .integer).notNull()
                t.column("has_lossless_audio", .boolean).notNull()
                t.column("video_width", .integer).notNull()
                t.column("video_height", .integer).notNull()
                t.column("subtitle_count", .integer).notNull()
                t.column("order_weight", .integer).notNull()
                t.column("duration_rank", .integer).notNull()
                t.column("size_rank", .integer).notNull()
            }
        }
        migrator.registerMigration("v2") { db in
            try db.alter(table: "title_selections") { t in
                t.add(column: "segments_map", .text)
            }
        }
        migrator.registerMigration("v3") { db in
            try db.alter(table: "title_selections") { t in
                t.add(column: "title_description", .text)
            }
        }
        try migrator.migrate(db)
    }

    // MARK: - Write

    /// Records a full disc scan selection event — one row per title, `isSelected`
    /// set on the title the user chose.
    public func record(
        selected: DiscTitle,
        allTitles: [DiscTitle],
        discType: DiscType,
        mediaType: RipJob.MediaType,
        discName: String?
    ) {
        guard let dbQueue else { return }
        let selectionId = UUID()
        let now = Date.now

        let sortedByDuration = allTitles.sorted { $0.durationMinutes > $1.durationMinutes }
        let sortedBySize     = allTitles.sorted { $0.sizeBytes > $1.sizeBytes }

        let durationRankMap = Dictionary(uniqueKeysWithValues:
            sortedByDuration.enumerated().map { ($0.element.number, $0.offset + 1) })
        let sizeRankMap = Dictionary(uniqueKeysWithValues:
            sortedBySize.enumerated().map { ($0.element.number, $0.offset + 1) })

        var records = allTitles.map { title -> TitleSelectionRecord in
            let res = title.videoResolution.flatMap { r -> (Int, Int)? in
                let parts = r.split(separator: "x").compactMap { Int($0) }
                return parts.count == 2 ? (parts[0], parts[1]) : nil
            }
            return TitleSelectionRecord(
                selectionId:      selectionId,
                timestamp:        now,
                discType:         discType.rawValue,
                mediaType:        mediaType.rawValue,
                discName:         discName,
                totalTitleCount:  allTitles.count,
                isSelected:       title.number == selected.number,
                titleNumber:      title.number,
                durationMinutes:  title.durationMinutes,
                chapters:         Int(title.chapters) ?? 0,
                sizeBytes:        title.sizeBytes,
                angle:            title.angle ?? 0,
                audioTrackCount:  title.audioTracks.count,
                hasLosslessAudio: title.audioTracks.contains(where: \.isLossless),
                videoWidth:       res?.0 ?? 0,
                videoHeight:      res?.1 ?? 0,
                subtitleCount:    title.subtitleCount,
                orderWeight:      title.orderWeight,
                segmentsMap:      title.segmentsMap,
                titleDescription: title.titleDescription,
                durationRank:     durationRankMap[title.number] ?? allTitles.count,
                sizeRank:         sizeRankMap[title.number] ?? allTitles.count
            )
        }

        try? dbQueue.write { db in
            for i in records.indices {
                try records[i].insert(db)
            }
        }
    }

    // MARK: - Read

    public func load() -> [TitleSelectionRecord] {
        guard let dbQueue else { return [] }
        return (try? dbQueue.read { db in
            try TitleSelectionRecord.order(Column("timestamp").desc).fetchAll(db)
        }) ?? []
    }

    public var selectionCount: Int {
        guard let dbQueue else { return 0 }
        return (try? dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(DISTINCT selection_id) FROM title_selections") ?? 0
        }) ?? 0
    }

    // MARK: - CSV export for Create ML

    /// Exports all records as a CSV file to a temp location.
    /// Feed this into Create ML → Tabular Classifier with target column `is_selected`.
    @discardableResult
    public func exportCSV(to url: URL? = nil) throws -> URL {
        let dest = url ?? FileManager.default.temporaryDirectory
            .appending(path: "frostscribe_title_selections_\(Int(Date().timeIntervalSince1970)).csv")

        let header = [
            "is_selected", "disc_type", "media_type", "total_title_count",
            "duration_minutes", "chapters", "size_bytes", "angle",
            "audio_track_count", "has_lossless_audio",
            "video_width", "video_height", "subtitle_count", "order_weight",
            "duration_rank", "size_rank"
        ].joined(separator: ",")

        let rows = load().map { r in
            [
                r.isSelected ? "1" : "0",
                r.discType, r.mediaType,
                "\(r.totalTitleCount)",
                "\(r.durationMinutes)", "\(r.chapters)", "\(r.sizeBytes)", "\(r.angle)",
                "\(r.audioTrackCount)", r.hasLosslessAudio ? "1" : "0",
                "\(r.videoWidth)", "\(r.videoHeight)", "\(r.subtitleCount)", "\(r.orderWeight)",
                "\(r.durationRank)", "\(r.sizeRank)"
            ].joined(separator: ",")
        }

        let csv = ([header] + rows).joined(separator: "\n")
        try csv.write(to: dest, atomically: true, encoding: .utf8)
        return dest
    }
}
