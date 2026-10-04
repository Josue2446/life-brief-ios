import Foundation
import SwiftData

/// A single content item: a story, a bullet, an event, a takeaway.
/// The same shape serves every section kind, which is what keeps the
/// app flexible as new topics are added.
@Model
final class StoryItem {
    @Attribute(.unique) var id: UUID
    /// Headline, bullet text, or event title.
    var headline: String
    /// Body copy. For events: "Oct 8 · OHSU Auditorium · In person".
    var body: String
    var sourceName: String?
    var sourceURL: String?
    /// Short tag shown as a capsule, e.g. the subreddit ("r/Portland").
    var tag: String?
    /// Direct URL to a representative image for the story.
    var imageURL: String?
    var sortOrder: Int
    var isRead: Bool
    var isBookmarked: Bool

    /// User feedback attributes ("like", "dislike", nil)
    var userReaction: String?
    /// User comment or note about the story
    var userComment: String?

    var section: BriefSection?

    init(
        id: UUID = UUID(),
        headline: String,
        body: String = "",
        sourceName: String? = nil,
        sourceURL: String? = nil,
        tag: String? = nil,
        imageURL: String? = nil,
        sortOrder: Int = 0,
        isRead: Bool = false,
        isBookmarked: Bool = false,
        userReaction: String? = nil,
        userComment: String? = nil
    ) {
        self.id = id
        self.headline = headline
        self.body = body
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.tag = tag
        self.imageURL = imageURL
        self.sortOrder = sortOrder
        self.isRead = isRead
        self.isBookmarked = isBookmarked
        self.userReaction = userReaction
        self.userComment = userComment
    }

    var reaction: ReactionType? {
        get {
            guard let userReaction else { return nil }
            return ReactionType(rawValue: userReaction)
        }
        set {
            userReaction = newValue?.rawValue
        }
    }

    var sourceLinkURL: URL? {
        guard let sourceURL, let url = URL(string: sourceURL),
              url.scheme == "http" || url.scheme == "https" else { return nil }
        return url
    }

    var imageLinkURL: URL? {
        guard let imageURL, let url = URL(string: imageURL),
              url.scheme == "http" || url.scheme == "https" else { return nil }
        return url
    }
}
