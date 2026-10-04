import SwiftUI
import SwiftData

/// Home of one topic: its latest edition, with search, native pull-to-refresh, and clean editorial hierarchy.
struct TopicHomeView: View {
    @Bindable var topic: Topic
    @Binding var showingOrganizer: Bool
    @Binding var showingSettings: Bool
    @State private var showingFavorites = false
    @State private var showingSearch = false
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
            .searchable(text: $searchText, isPresented: $showingSearch, prompt: "Search \(topic.name)")
            .onChange(of: showingSearch) { _, isPresented in
                if !isPresented {
                    searchText = ""
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingSearch.toggle()
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search")
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingFavorites = true
                    } label: {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(LinearGradient.instagramHeart)
                    }
                    .accessibilityLabel("Favorites")

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
            .sheet(isPresented: $showingFavorites) {
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
                Label(edition.conciseDateLabel, systemImage: "calendar")
                    .lineLimit(1)
                Text("•")
                Text("\(totalStoryCount) \(totalStoryCount == 1 ? "story" : "stories")")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .lineLimit(1)
            .minimumScaleFactor(0.85)

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

/// An Apple Glass reading surface with native material backdrop and continuous rounded corner styling.
struct BriefCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 20, style: .continuous))
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

                        FavoriteHeartButton(item: item)
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
                item.isFavorite.toggle()
            } label: {
                Label(
                    item.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: item.isFavorite ? "heart.slash" : "heart.fill"
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

/// Instagram-style animated favorite heart button with Apple keyframe spring pop and vibrant gradient fill.
struct FavoriteHeartButton: View {
    @Bindable var item: StoryItem
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    @State private var bounceTrigger = 0

    var body: some View {
        Button {
            let willBeFavorite = !item.isFavorite
            item.isFavorite = willBeFavorite

            if willBeFavorite {
                bounceTrigger += 1
            }
        } label: {
            Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    item.isFavorite
                        ? AnyShapeStyle(LinearGradient.instagramHeart)
                        : AnyShapeStyle(Color.secondary)
                )
                .symbolEffect(.bounce.up, value: bounceTrigger)
                .keyframeAnimator(
                    initialValue: 1.0,
                    trigger: bounceTrigger
                ) { content, scale in
                    content.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(0.82, duration: 0.06)
                        SpringKeyframe(1.35, duration: 0.18, spring: .init(response: 0.3, dampingRatio: 0.4))
                        SpringKeyframe(1.0, duration: 0.16, spring: .init(response: 0.3, dampingRatio: 0.6))
                    }
                }
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.impact(weight: .medium, intensity: 1.0), trigger: bounceTrigger) { _, _ in
            hapticsEnabled
        }
        .accessibilityLabel(item.isFavorite ? "Remove from Favorites" : "Add to Favorites")
    }
}
