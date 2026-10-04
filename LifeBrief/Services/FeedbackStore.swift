import Foundation
import UIKit

// MARK: - Feedback Models

enum ReactionType: String, Codable, CaseIterable {
    case like
    case dislike

    var title: String {
        switch self {
        case .like: return "Helpful"
        case .dislike: return "Not Helpful"
        }
    }

    var systemImage: String {
        switch self {
        case .like: return "hand.thumbsup"
        case .dislike: return "hand.thumbsdown"
        }
    }

    var filledSystemImage: String {
        switch self {
        case .like: return "hand.thumbsup.fill"
        case .dislike: return "hand.thumbsdown.fill"
        }
    }
}

struct FeedbackEntry: Codable, Identifiable {
    var id: UUID
    var storyID: String
    var storyHeadline: String
    var storySourceName: String?
    var storySourceURL: String?
    var storyTag: String?
    var topicName: String?
    var topicID: String?
    var editionDateLabel: String?
    var sectionTitle: String?
    var reaction: String?
    var comment: String?
    var timestamp: String
    var appVersion: String
    var systemVersion: String

    init(
        id: UUID = UUID(),
        storyID: String,
        storyHeadline: String,
        storySourceName: String? = nil,
        storySourceURL: String? = nil,
        storyTag: String? = nil,
        topicName: String? = nil,
        topicID: String? = nil,
        editionDateLabel: String? = nil,
        sectionTitle: String? = nil,
        reaction: String? = nil,
        comment: String? = nil,
        timestamp: String = ISO8601DateFormatter().string(from: Date()),
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
        systemVersion: String = UIDevice.current.systemVersion
    ) {
        self.id = id
        self.storyID = storyID
        self.storyHeadline = storyHeadline
        self.storySourceName = storySourceName
        self.storySourceURL = storySourceURL
        self.storyTag = storyTag
        self.topicName = topicName
        self.topicID = topicID
        self.editionDateLabel = editionDateLabel
        self.sectionTitle = sectionTitle
        self.reaction = reaction
        self.comment = comment
        self.timestamp = timestamp
        self.appVersion = appVersion
        self.systemVersion = systemVersion
    }
}

struct FeedbackFeed: Codable {
    var version: String
    var updatedAt: String
    var entriesCount: Int
    var entries: [FeedbackEntry]

    init(
        version: String = "1.0",
        updatedAt: String = ISO8601DateFormatter().string(from: Date()),
        entries: [FeedbackEntry] = []
    ) {
        self.version = version
        self.updatedAt = updatedAt
        self.entriesCount = entries.count
        self.entries = entries
    }
}

// MARK: - Feedback Store

enum FeedbackStore {
    private static let isoFormatter = ISO8601DateFormatter()

    static var feedbackFileURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("feedback.json")
    }

    static func loadFeed() -> FeedbackFeed {
        let url = feedbackFileURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let feed = try? JSONDecoder().decode(FeedbackFeed.self, from: data) else {
            return FeedbackFeed(entries: [])
        }
        return feed
    }

    @discardableResult
    static func recordFeedback(
        for item: StoryItem,
        reaction: ReactionType?,
        comment: String?
    ) -> FeedbackEntry {
        var feed = loadFeed()
        let trimmedComment = comment?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalComment = (trimmedComment?.isEmpty ?? true) ? nil : trimmedComment

        let section = item.section
        let edition = section?.edition
        let topic = edition?.topic

        let entry = FeedbackEntry(
            storyID: item.id.uuidString,
            storyHeadline: item.headline,
            storySourceName: item.sourceName,
            storySourceURL: item.sourceURL,
            storyTag: item.tag,
            topicName: topic?.name,
            topicID: topic?.feedID,
            editionDateLabel: edition?.dateLabel,
            sectionTitle: section?.title,
            reaction: reaction?.rawValue,
            comment: finalComment,
            timestamp: isoFormatter.string(from: Date())
        )

        // Replace previous feedback for the same story if it exists, or append new
        if let existingIndex = feed.entries.firstIndex(where: { $0.storyID == item.id.uuidString }) {
            var updated = entry
            updated.id = feed.entries[existingIndex].id
            feed.entries[existingIndex] = updated
        } else {
            feed.entries.append(entry)
        }

        saveFeed(feed)
        return entry
    }

    static func clearAllFeedback() {
        let empty = FeedbackFeed(entries: [])
        saveFeed(empty)
    }

    static func deleteFeedback(for storyID: String) {
        var feed = loadFeed()
        feed.entries.removeAll(where: { $0.storyID == storyID })
        saveFeed(feed)
    }

    private static func saveFeed(_ feed: FeedbackFeed) {
        var updatedFeed = feed
        updatedFeed.updatedAt = isoFormatter.string(from: Date())
        updatedFeed.entriesCount = updatedFeed.entries.count

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(updatedFeed) else { return }
        try? data.write(to: feedbackFileURL, options: [.atomic])

        // Automatically trigger debounced background sync to GitHub Gist
        Task { @MainActor in
            FeedbackSyncService.shared.scheduleDebouncedSync()
        }
    }
}
