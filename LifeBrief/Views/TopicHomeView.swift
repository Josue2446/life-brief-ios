import SwiftUI
import SwiftData

/// Home of one topic: its latest edition, with search and native navigation.
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
                        Label("Saved", systemImage: "bookmark")
                    }

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

/// Renders a single edition with a clear editorial hierarchy and native pull-to-refresh.
struct EditionView: View {
    @Bindable var edition: Edition
    var searchText: String
    @Environment(\.modelContext) private var context
    @AppStorage("feedURLString") private var feedURLString = BriefStore.defaultFeedURLString
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    /// Structured search result model that pairs a section with its filtered items.
    private struct FilteredSectionResult: Identifiable {
        var id: PersistentIdentifier { section.id }
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
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: .all)
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

            Text(edition.theme)
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// A solid reading surface with Apple-standard continuous corners and subtle border.
struct BriefCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color(uiColor: .separator).opacity(0.12), lineWidth: 0.5)
            }
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
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(items) { item in
                            Text(item.body.isEmpty ? item.headline : item.body)
                                .font(.body)
                        }
                    }
                }
            }
        }
    }
}

/// A concise card that prioritizes headline, unread dot indicator, source metadata, and rich context menus.
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
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            case .failure:
                                EmptyView()
                            case .empty:
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                                .fill(Color.accentColor)
                                .frame(width: 8, height: 8)
                                .padding(.top, 6)
                        }

                        Text(item.headline)
                            .font(.headline)
                            .foregroundStyle(item.isRead ? .secondary : .primary)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)

                        Image(systemName: item.isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.subheadline)
                            .foregroundStyle(item.isBookmarked ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    }

                    if !item.body.isEmpty {
                        Text(item.body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .padding(.leading, item.isRead ? 0 : 18)
                    }

                    if let sourceName = item.sourceName {
                        Label(sourceName, systemImage: "arrow.up.right")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.tint)
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

            if let url = item.sourceLinkURL {
                Button {
                    UIPasteboard.general.url = url
                } label: {
                    Label("Copy Link", systemImage: "doc.on.doc")
                }

                ShareLink(item: url, subject: Text(item.headline)) {
                    Label("Share Link", systemImage: "square.and.arrow.up")
                }
            }
        }
        .accessibilityHint("Opens the full story.")
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
