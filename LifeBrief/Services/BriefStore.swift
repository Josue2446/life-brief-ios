import Foundation
import SwiftData

// MARK: - Feed DTOs
//
// The JSON contract between the publishing pipeline and the app.
// The weekly and daily briefing jobs publish this shape; the app
// imports it without any code changes, for any topic.

struct FeedTopicDTO: Codable {
    var id: String
    var name: String
    var systemImage: String
    var summary: String
    var editions: [FeedEditionDTO]
}

struct FeedEditionDTO: Codable {
    var id: String
    var date: String          // ISO-8601, e.g. "2026-10-05"
    var dateLabel: String     // e.g. "Week of October 5 - 11, 2026"
    var theme: String
    var sections: [FeedSectionDTO]
}

struct FeedSectionDTO: Codable {
    var kind: String           // matches SectionKind raw values
    var title: String
    var items: [FeedItemDTO]
}

struct FeedItemDTO: Codable {
    var headline: String
    var body: String?
    var sourceName: String?
    var sourceURL: String?
    var tag: String?
    var imageURL: String?
}

// MARK: - Feed service

/// Fetches published editions over the network using modern async/await.
/// Falls back gracefully: a failed fetch never destroys local content.
enum FeedService {
    enum FeedError: LocalizedError {
        case badStatus(Int)
        case decodingFailed(Error)

        var errorDescription: String? {
            switch self {
            case .badStatus(let code): return "Feed returned HTTP \(code)."
            case .decodingFailed(let error): return "Could not read feed: \(error.localizedDescription)"
            }
        }
    }

    static func fetchTopics(from url: URL) async throws -> [FeedTopicDTO] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FeedError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        do {
            return try JSONDecoder().decode([FeedTopicDTO].self, from: data)
        } catch {
            throw FeedError.decodingFailed(error)
        }
    }
}

// MARK: - Store

/// Owns seeding and importing briefing content into SwiftData.
enum BriefStore {
    static let defaultFeedURLString = "https://gist.githubusercontent.com/Josue2446/07ad9349799c1e8d5560508ba4b7a21c/raw/feed.json"

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    /// Seeds bundled editions on first launch, or migrates legacy data on subsequent launches.
    static func seedIfNeeded(_ context: ModelContext) {
        let descriptor = FetchDescriptor<Topic>()
        let existing = (try? context.fetch(descriptor)) ?? []
        
        if existing.isEmpty {
            let seeds = ["portland-2026-10-02", "ai-tech-2026-10-03"]
            var order = 0
            for name in seeds {
                guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
                      let data = try? Data(contentsOf: url),
                      let dto = try? JSONDecoder().decode(FeedTopicDTO.self, from: data) else { continue }
                insert(dto, sortOrder: order, into: context)
                order += 1
            }
            // Politics ships as an empty topic, ready to be filled in later.
            let politics = Topic(
                feedID: "politics",
                name: "Politics",
                systemImage: "building.columns",
                sortOrder: order,
                summary: "Political coverage, coming soon."
            )
            context.insert(politics)
            try? context.save()
        } else {
            // Self-healing migration: update any invalid legacy symbols (e.g. "landmark" -> "building.columns")
            var changed = false
            for topic in existing where topic.systemImage == "landmark" {
                topic.systemImage = "building.columns"
                changed = true
            }
            if changed {
                try? context.save()
            }
        }
    }

    /// Attempts to refresh the feed from the remote URL.
    @discardableResult
    static func refreshFeed(from urlString: String, into context: ModelContext) async throws -> Int {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https" || url.scheme == "http" else {
            return 0
        }
        let dtos = try await FeedService.fetchTopics(from: url)
        return importFeed(dtos, into: context)
    }

    /// Imports feed topics. New editions are appended; existing ones
    /// (matched by feedID) are preserved without duplicating.
    /// Returns the number of newly imported editions.
    @discardableResult
    static func importFeed(_ dtos: [FeedTopicDTO], into context: ModelContext) -> Int {
        var newEditionsCount = 0

        for dto in dtos {
            let topic: Topic
            if let found = fetchTopic(feedID: dto.id, in: context) {
                topic = found
                topic.name = dto.name
                topic.systemImage = dto.systemImage
                topic.summary = dto.summary
            } else {
                let nextOrder = (try? context.fetch(FetchDescriptor<Topic>()))?.count ?? 0
                topic = Topic(feedID: dto.id, name: dto.name, systemImage: dto.systemImage,
                              sortOrder: nextOrder, summary: dto.summary)
                context.insert(topic)
            }

            for editionDTO in dto.editions {
                if let existingEdition = topic.editions.first(where: { $0.feedID == editionDTO.id }) {
                    // Edition already imported; enrich existing items with any new image URLs
                    existingEdition.dateLabel = editionDTO.dateLabel
                    existingEdition.theme = editionDTO.theme
                    for sectionDTO in editionDTO.sections {
                        if let section = existingEdition.sections.first(where: { $0.title == sectionDTO.title }) {
                            for itemDTO in sectionDTO.items {
                                if let item = section.items.first(where: { $0.headline == itemDTO.headline }) {
                                    if item.imageURL == nil, let imageURL = itemDTO.imageURL {
                                        item.imageURL = imageURL
                                    }
                                }
                            }
                        }
                    }
                } else {
                    let edition = makeEdition(from: editionDTO, into: context)
                    topic.editions.append(edition)
                    newEditionsCount += 1
                }
            }
        }
        try? context.save()
        return newEditionsCount
    }

    // MARK: Private

    private static func fetchTopic(feedID: String, in context: ModelContext) -> Topic? {
        var descriptor = FetchDescriptor<Topic>(predicate: #Predicate { $0.feedID == feedID })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func insert(_ dto: FeedTopicDTO, sortOrder: Int, into context: ModelContext) {
        let topic = Topic(feedID: dto.id, name: dto.name, systemImage: dto.systemImage,
                          sortOrder: sortOrder, summary: dto.summary)
        context.insert(topic)
        for editionDTO in dto.editions {
            let edition = makeEdition(from: editionDTO, into: context)
            topic.editions.append(edition)
        }
        try? context.save()
    }

    private static func makeEdition(from dto: FeedEditionDTO, into context: ModelContext) -> Edition {
        let edition = Edition(
            feedID: dto.id,
            date: isoFormatter.date(from: dto.date) ?? .now,
            dateLabel: dto.dateLabel,
            theme: dto.theme
        )
        context.insert(edition)
        for (sectionIndex, sectionDTO) in dto.sections.enumerated() {
            let section = BriefSection(
                kind: SectionKind(rawValue: sectionDTO.kind) ?? .custom,
                title: sectionDTO.title,
                sortOrder: sectionIndex
            )
            context.insert(section)
            edition.sections.append(section)
            for (itemIndex, itemDTO) in sectionDTO.items.enumerated() {
                let item = StoryItem(
                    headline: itemDTO.headline,
                    body: itemDTO.body ?? "",
                    sourceName: itemDTO.sourceName,
                    sourceURL: itemDTO.sourceURL,
                    tag: itemDTO.tag,
                    imageURL: itemDTO.imageURL,
                    sortOrder: itemIndex
                )
                context.insert(item)
                section.items.append(item)
            }
        }
        return edition
    }
}
