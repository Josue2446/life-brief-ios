import Foundation
import SwiftData

/// One published edition of a topic's briefing (e.g. "Week of Oct 5").
@Model
final class Edition {
    @Attribute(.unique) var id: UUID
    /// Stable identifier used by the content feed.
    var feedID: String?
    var date: Date
    /// Human-readable label, e.g. "Week of October 5 - 11, 2026".
    var dateLabel: String
    /// The 2-4 sentence overview shown at the top of the edition.
    var theme: String

    var topic: Topic?

    @Relationship(deleteRule: .cascade, inverse: \BriefSection.edition)
    var sections: [BriefSection] = []

    init(
        id: UUID = UUID(),
        feedID: String? = nil,
        date: Date = .now,
        dateLabel: String = "",
        theme: String = ""
    ) {
        self.id = id
        self.feedID = feedID
        self.date = date
        self.dateLabel = dateLabel
        self.theme = theme
    }

    var sortedSections: [BriefSection] {
        sections.sorted { $0.sortOrder < $1.sortOrder }
    }
}
