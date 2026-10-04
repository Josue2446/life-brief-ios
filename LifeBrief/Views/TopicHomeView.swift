import SwiftUI
import SwiftData

/// Home of one topic: its latest edition, with search, native pull-to-refresh, and clean editorial hierarchy.
struct TopicHomeView: View {
    @Bindable var topic: Topic
    @Binding var showingOrganizer: Bool
    @Binding var showingSettings: Bool
    @State private var showingSavedStories = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if let edition = topic.latestEdition {
                    EditionView(edition: edition, searchText: searchText)
                } else {
                    ContentUnavailableView(
                        "\(topic.name) is on its way",
                        systemImage: topic.systemImage,
                        description: Text("New briefings will appear here automatically.")
                    )
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(topic.name)
            .toolbarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search \(topic.name)")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingSavedStories = true
                    } label: {
                        Image(systemName: "bookmark")
                    }
                    .accessibilityLabel("Saved stories")

                    Menu {
                        Button {
                            showingOrganizer = true
                        } label: {
                            Label("Organize Topics", systemImage: "slider.horizontal.3")
                        }

                        Button {
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More Options")
                }
            }
            .sheet(isPresented: $showingSavedStories) {
                NavigationStack {
                    SavedStoriesView()
                }
            }
        }
    }
}

/// Renders a single edition with clear editorial hierarchy, pull-to-refresh, and smooth scrolling.
struct EditionView: View {
    @Bindable var edition: Edition
    var searchText: String

    @Environment(\.modelContext) private var context
    @AppStorage("feedURLString") private var feedURLString = BriefStore.defaultFeedURLString
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    private struct FilteredSectionResult: Identifiable {
        var id: UUID { section.id }
        var section: BriefSection
        var matchingItems: [StoryItem]
    }

    private var filteredResults: [FilteredSectionResult] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return edition.sortedSections.compactMap { section in
            let items: [StoryItem]
            if query.isEmpty {
                items = section.sortedItems
            } else {
                items = section.sortedItems.filter {
                    $0.headline.localizedCaseInsensitiveContains(query)
                        || $0.body.localizedCaseInsensitiveContains(query)
                }
            }
            guard !items.isEmpty else { return nil }
            return FilteredSectionResult(section: section, matchingItems: items)
        }
    }

    private var totalStoryCount: Int {
        edition.sortedSections.reduce(0) { $0 + $1.sortedItems.count }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if !searchText.isEmpty && filteredResults.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .padding(.top, 60)
                } else {
                    if searchText.isEmpty {
                        editionHeader
                    }

                    ForEach(filteredResults) { result in
                        SectionView(section: result.section, items: result.matchingItems)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 96) // Inset comfortably above floating glass capsule
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(Color(uiColor: .systemGroupedBackground))
        .refreshable {
            try? await Task.sleep(nanoseconds: 600_000_000)
            _ = try? await BriefStore.refreshFeed(from: feedURLString, into: context)
        }
    }

    private var editionHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(edition.dateLabel, systemImage: "calendar")
                Text("•")
                Text("\(totalStoryCount) \(totalStoryCount == 1 ? "story" : "stories")")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)

            if !edition.theme.isEmpty {
                ExpandableText(
                    text: edition.theme,
                    font: .title3.weight(.medium),
                    foregroundStyle: .primary,
                    lineSpacing: 4
                )
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// An Apple Glass reading surface with frosted translucency, subtle specular rim highlight, and soft ambient depth.
struct BriefCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(colorScheme == .dark ? 0.22 : 0.45), location: 0),
                                .init(color: .white.opacity(colorScheme == .dark ? 0.06 : 0.15), location: 0.35),
                                .init(color: Color.clear, location: 0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.04),
                radius: 12,
                x: 0,
                y: 4
            )
    }
}

/// Renders a section according to its kind with the exact matching items.
struct SectionView: View {
    @Bindable var section: BriefSection
    var items: [StoryItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(section.title, systemImage: section.kind.systemImage)
                .font(.headline)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            switch section.kind {
            case .stories:
                ForEach(items) { item in
                    StoryCard(item: item)
                }
            case .ohsu:
                BriefCard {
                    OHSUSectionView(items: items)
                }
            case .community:
                CommunitySectionView(items: items)
            case .summary:
                BriefCard {
                    SummarySectionView(items: items)
                }
            case .overview, .custom:
                BriefCard {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(items) { item in
                            ExpandableText(
                                text: item.headline,
                                font: .subheadline,
                                foregroundStyle: .secondary,
                                lineSpacing: 3
                            )
                        }
                    }
                }
            }
        }
    }
}

/// Individual story card with continuous glass surface, image presentation, and unread indicator.
struct StoryCard: View {
    @Bindable var item: StoryItem
    @Environment(\.openURL) private var openURL
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    var body: some View {
        NavigationLink {
            StoryDetailView(item: item)
        } label: {
            BriefCard {
                VStack(alignment: .leading, spacing: 12) {
                    if let url = item.imageLinkURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 180)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.2),
                                                        Color.white.opacity(0.04),
                                                        Color.clear
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ),
                                                lineWidth: 0.5
                                            )
                                    }
                            case .failure:
                                EmptyView()
                            case .empty:
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(uiColor: .tertiarySystemFill))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 180)
                                    .overlay {
                                        ProgressView()
                                    }
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }

                    HStack(alignment: .top, spacing: 10) {
                        if !item.isRead {
                            Circle()
                                .fill(Color.primary)
                                .frame(width: 8, height: 8)
                                .padding(.top, 6)
                        }

                        Text(item.headline)
                            .font(.headline)
                            .foregroundStyle(item.isRead ? .secondary : .primary)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)

                        if let reaction = item.reaction {
                            Image(systemName: reaction.filledSystemImage)
                                .font(.subheadline)
                                .foregroundStyle(Color.primary)
                        }

                        Image(systemName: item.isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.subheadline)
                            .foregroundStyle(item.isBookmarked ? AnyShapeStyle(Color.primary) : AnyShapeStyle(.tertiary))
                    }

                    if !item.body.isEmpty {
                        ExpandableText(
                            text: item.body,
                            font: .subheadline,
                            foregroundStyle: .secondary,
                            lineSpacing: 4,
                            allowSelection: false
                        )
                        .multilineTextAlignment(.leading)
                        .padding(.leading, item.isRead ? 0 : 18)
                    }

                    if let sourceName = item.sourceName {
                        Label(sourceName, systemImage: "arrow.up.right")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.leading, item.isRead ? 0 : 18)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                item.isRead.toggle()
            } label: {
                Label(
                    item.isRead ? "Mark as Unread" : "Mark as Read",
                    systemImage: item.isRead ? "envelope.badge" : "envelope.open"
                )
            }

            Button {
                item.isBookmarked.toggle()
            } label: {
                Label(
                    item.isBookmarked ? "Remove Bookmark" : "Bookmark",
                    systemImage: item.isBookmarked ? "bookmark.slash" : "bookmark"
                )
            }

            Divider()

            Button {
                toggleReaction(.like)
            } label: {
                Label(
                    item.reaction == .like ? "Remove Helpful Rating" : "Mark as Helpful",
                    systemImage: item.reaction == .like ? "hand.thumbsup.fill" : "hand.thumbsup"
                )
            }

            Button {
                toggleReaction(.dislike)
            } label: {
                Label(
                    item.reaction == .dislike ? "Remove Not Helpful Rating" : "Mark as Not Helpful",
                    systemImage: item.reaction == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown"
                )
            }

            if let url = item.sourceLinkURL {
                Divider()
                Button {
                    openURL(url)
                } label: {
                    Label("Open Original Article", systemImage: "safari")
                }
            }
        }
    }

    private func toggleReaction(_ reaction: ReactionType) {
        if item.reaction == reaction {
            item.reaction = nil
        } else {
            item.reaction = reaction
        }
        FeedbackStore.recordFeedback(for: item, reaction: item.reaction, comment: item.userComment)
    }
}

struct BookmarkButton: View {
    @Bindable var item: StoryItem
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    var body: some View {
        Button {
            item.isBookmarked.toggle()
        } label: {
            Image(systemName: item.isBookmarked ? "bookmark.fill" : "bookmark")
        }
        .sensoryFeedback(.selection, trigger: item.isBookmarked) { _, _ in hapticsEnabled }
        .accessibilityLabel(item.isBookmarked ? "Remove bookmark" : "Bookmark")
    }
}
