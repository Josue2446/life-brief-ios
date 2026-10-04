import Foundation
import SwiftData

/// The kind of a section determines how it is rendered.
/// New kinds can be added without touching existing screens.
enum SectionKind: String, Codable, CaseIterable {
    case overview
    case stories
    case ohsu
    case community
    case summary
    case custom

    var defaultTitle: String {
        switch self {
        case .overview: return "Overview"
        case .stories: return "Top Stories"
        case .ohsu: return "OHSU"
        case .community: return "Community"
        case .summary: return "Summary"
        case .custom: return "Section"
        }
    }

    /// SF Symbol used in section headers.
    var systemImage: String {
        switch self {
        case .overview: return "newspaper"
        case .stories: return "list.bullet.rectangle"
        case .ohsu: return "cross.case"
        case .community: return "bubble.left.and.bubble.right"
        case .summary: return "checklist"
        case .custom: return "square.grid.2x2"
        }
    }
}

/// A section inside an edition (stories, OHSU, community buzz, summary...).
@Model
final class BriefSection {
    @Attribute(.unique) var id: UUID
    private var kindRaw: String
    var title: String
    var sortOrder: Int

    var edition: Edition?

    @Relationship(deleteRule: .cascade, inverse: \StoryItem.section)
    var items: [StoryItem] = []

    init(
        id: UUID = UUID(),
        kind: SectionKind = .custom,
        title: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.title = title ?? kind.defaultTitle
        self.sortOrder = sortOrder
    }

    var kind: SectionKind {
        get { SectionKind(rawValue: kindRaw) ?? .custom }
        set { kindRaw = newValue.rawValue }
    }

    var sortedItems: [StoryItem] {
        items.sorted { $0.sortOrder < $1.sortOrder }
    }
}
