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

    /// Clean, concise date label suited for editorial mastheads without wrapping.
    /// e.g. "Week of September 28 - October 4, 2026" -> "Sep 28 – Oct 4, 2026"
    /// and "Saturday, October 3, 2026" -> "Sat, Oct 3, 2026"
    var conciseDateLabel: String {
        var text = dateLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return date.formatted(.dateTime.month(.abbreviated).day().year())
        }

        // Remove "Week of " prefix
        if text.lowercased().hasPrefix("week of ") {
            text = String(text.dropFirst(8))
        }

        // Abbreviate month names
        let monthReplacements = [
            ("September", "Sep"),
            ("October", "Oct"),
            ("November", "Nov"),
            ("December", "Dec"),
            ("January", "Jan"),
            ("February", "Feb"),
            ("March", "Mar"),
            ("April", "Apr"),
            ("August", "Aug")
        ]
        for (full, abbr) in monthReplacements {
            text = text.replacingOccurrences(of: full, with: abbr)
        }

        // Abbreviate day of week
        let dayReplacements = [
            ("Monday, ", "Mon, "),
            ("Tuesday, ", "Tue, "),
            ("Wednesday, ", "Wed, "),
            ("Thursday, ", "Thu, "),
            ("Friday, ", "Fri, "),
            ("Saturday, ", "Sat, "),
            ("Sunday, ", "Sun, ")
        ]
        for (full, abbr) in dayReplacements {
            text = text.replacingOccurrences(of: full, with: abbr)
        }

        // Standard typographic en-dash
        text = text.replacingOccurrences(of: " - ", with: " – ")

        return text
    }
}
