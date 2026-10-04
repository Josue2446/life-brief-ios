import Foundation
import SwiftData

/// A briefing topic (Portland, AI & Tech, Politics, ...).
/// Topics are data, not screens: adding a new topic never requires
/// changing the app's structure.
@Model
final class Topic {
    @Attribute(.unique) var id: UUID
    /// Stable identifier used by the content feed (e.g. "portland").
    var feedID: String?
    var name: String
    var systemImage: String
    var sortOrder: Int
    var isVisible: Bool
    var summary: String

    @Relationship(deleteRule: .cascade, inverse: \Edition.topic)
    var editions: [Edition] = []

    init(
        id: UUID = UUID(),
        feedID: String? = nil,
        name: String,
        systemImage: String,
        sortOrder: Int,
        isVisible: Bool = true,
        summary: String = ""
    ) {
        self.id = id
        self.feedID = feedID
        self.name = name
        self.systemImage = systemImage
        self.sortOrder = sortOrder
        self.isVisible = isVisible
        self.summary = summary
    }

    /// The most recent edition, shown when the topic is opened.
    var latestEdition: Edition? {
        editions.sorted { $0.date > $1.date }.first
    }
}
