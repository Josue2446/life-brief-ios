import SwiftUI
import SwiftData

/// Home of one topic: its latest edition, with native Apple search, pull-to-refresh, and clean editorial hierarchy.
struct TopicHomeView: View {
    @Bindable var topic: Topic
    @Binding var showingOrganizer: Bool
    @Binding var organizerTab: OrganizerTab
    @Binding var showingSettings: Bool
    @AppStorage("accentColorTheme") private var accentColorTheme: AccentColorTheme = .pink
    @State private var showingFavorites = false
    @State private var searchText = ""
    @State private var isScrolled = false
    @State private var showingInPlaceSearch = false
    @FocusState private var isInPlaceSearchFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showingInPlaceSearch {
                    inPlaceSearchBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Group {
                    if let edition = topic.latestEdition {
                        EditionView(
                            edition: edition,
                            searchText: $searchText,
                            isScrolled: $isScrolled,
                            showingInPlaceSearch: showingInPlaceSearch
                        )
                    } else {
                        ContentUnavailableView(
                            "\(topic.name) is on its way",
                            systemImage: topic.systemImage,
                            description: Text("New briefings will appear here automatically.")
                        )
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(topic.name)
            .toolbar {
                if isScrolled {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                showingInPlaceSearch.toggle()
                                if showingInPlaceSearch {
                                    isInPlaceSearchFocused = true
                                } else {
                                    isInPlaceSearchFocused = false
                                }
                            }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(showingInPlaceSearch ? accentColorTheme.color : Color.primary)
                        }
                        .accessibilityLabel("Search")
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
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
                            organizerTab = .sections
                            showingOrganizer = true
                        } label: {
                            Label("Organize Sections", systemImage: "arrow.up.arrow.down")
                        }

                        Button {
                            organizerTab = .topics
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
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isScrolled)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: showingInPlaceSearch)
            .sheet(isPresented: $showingFavorites) {
                NavigationStack {
                    SavedStoriesView()
                }
            }
        }
    }

    // MARK: - In-Place Search Bar (Shown when tapped while scrolled)

    private var inPlaceSearchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)

                TextField("Search \(topic.name)...", text: $searchText)
                    .font(.subheadline)
                    .focused($isInPlaceSearchFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemFill), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            // Apple Glass "X" Button
            Button {
                dismissInPlaceSearch()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 34, height: 34)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.85),
                                        Color.white.opacity(0.25),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.8
                            )
                    }
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08),
                        radius: 6,
                        x: 0,
                        y: 3
                    )
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissInPlaceSearch()
                }
            )
            .accessibilityLabel("Dismiss Search")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func dismissInPlaceSearch() {
        isInPlaceSearchFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            showingInPlaceSearch = false
            searchText = ""
        }
    }
}

/// Renders a single edition with clear editorial hierarchy, pull-to-refresh, and smooth scrolling.
struct EditionView: View {
    @Bindable var edition: Edition
    @Binding var searchText: String
    @Binding var isScrolled: Bool
    var showingInPlaceSearch: Bool

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
            VStack(alignment: .leading, spacing: 16) {
                // Resting Apple search bar at top of feed (hidden when in-place search is active)
                if !showingInPlaceSearch {
                    restingSearchBar
                }

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
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 96) // Inset comfortably above floating glass capsule
        }
        .onScrollGeometryChange(for: Bool.self, of: { geometry in
            geometry.contentOffset.y > 45
        }) { oldValue, newValue in
            if oldValue != newValue {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    isScrolled = newValue
                    if !newValue && showingInPlaceSearch {
                        // Returned to top
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(Color(uiColor: .systemGroupedBackground))
        .refreshable {
            try? await Task.sleep(nanoseconds: 600_000_000)
            _ = try? await BriefStore.refreshFeed(from: feedURLString, into: context)
        }
    }

    private var restingSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)

            TextField("Search \(edition.topic?.name ?? "stories")...", text: $searchText)
                .font(.subheadline)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemFill), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
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
                TopStoriesSectionView(items: items)
            case .ohsu:
                OHSUSectionView(items: items)
            case .community:
                CommunitySectionView(items: items)
            case .summary:
                SummarySectionView(items: items)
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

/// Top Stories section featuring a lead hero story card followed by an Apple News-style
/// grouped container of compact scannable stories with collapsible expansion.
struct TopStoriesSectionView: View {
    var items: [StoryItem]
    @AppStorage("accentColorTheme") private var accentColorTheme: AccentColorTheme = .pink
    @State private var isExpanded = false

    /// Standard number of secondary stories shown before offering "Show more"
    private let initialSecondaryLimit = 3

    private var leadStory: StoryItem? {
        items.first
    }

    private var secondaryStories: [StoryItem] {
        Array(items.dropFirst())
    }

    private var visibleSecondaryStories: [StoryItem] {
        if isExpanded || secondaryStories.count <= initialSecondaryLimit {
            return secondaryStories
        } else {
            return Array(secondaryStories.prefix(initialSecondaryLimit))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. Lead Hero Story
            if let lead = leadStory {
                StoryCard(item: lead)
            }

            // 2. Grouped Compact Stories Container
            if !secondaryStories.isEmpty {
                BriefCard {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("More Top Stories")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            Spacer()

                            Text("\(secondaryStories.count)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color(uiColor: .tertiarySystemFill), in: .capsule)
                        }
                        .padding(.bottom, 12)

                        ForEach(Array(visibleSecondaryStories.enumerated()), id: \.element.id) { index, item in
                            if index > 0 {
                                Divider()
                                    .padding(.vertical, 10)
                            }
                            CompactStoryRow(item: item)
                        }

                        // Collapsible expansion toggle if there are more than 3 secondary stories
                        if secondaryStories.count > initialSecondaryLimit {
                            Divider()
                                .padding(.vertical, 10)

                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    isExpanded.toggle()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(isExpanded ? "Show fewer stories" : "Show \(secondaryStories.count - initialSecondaryLimit) more stories")
                                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                        .font(.caption2.weight(.bold))
                                }
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(accentColorTheme.color)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

/// Scannable compact row for secondary top stories.
struct CompactStoryRow: View {
    @Bindable var item: StoryItem
    @Environment(\.openURL) private var openURL
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    var body: some View {
        NavigationLink {
            StoryDetailView(item: item)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                // Unread dot
                if !item.isRead {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 7, height: 7)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let source = item.sourceName {
                        Text(source)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }

                    Text(item.headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(item.isRead ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if !item.body.isEmpty {
                        Text(item.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .center, spacing: 8) {
                    if let url = item.imageLinkURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 52, height: 52)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            default:
                                EmptyView()
                            }
                        }
                    }

                    FavoriteHeartButton(item: item)
                }
            }
            .contentShape(Rectangle())
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
