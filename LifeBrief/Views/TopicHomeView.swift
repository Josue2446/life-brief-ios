import SwiftUI
import SwiftData

/// The primary reading surface for a topic: latest edition, previous editions, and story cards.
struct TopicHomeView: View {
    @Bindable var topic: Topic
    @Binding var showingOrganizer: Bool
    @Binding var showingSettings: Bool

    @Query private var editions: [Edition]
    @State private var showingSaved = false

    init(
        topic: Topic,
        showingOrganizer: Binding<Bool>,
        showingSettings: Binding<Bool>
    ) {
        self.topic = topic
        self._showingOrganizer = showingOrganizer
        self._showingSettings = showingSettings

        let topicID = topic.id
        _editions = Query(
            filter: #Predicate<Edition> { edition in
                edition.topic?.id == topicID
            },
            sort: \Edition.date,
            order: .reverse
        )
    }

    private var latestEdition: Edition? {
        editions.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let edition = latestEdition {
                    EditionView(edition: edition)
                } else {
                    ContentUnavailableView(
                        "No Editions Yet",
                        systemImage: "newspaper",
                        description: Text("Editions published for \(topic.name) will appear here.")
                    )
                }
            }
            .navigationTitle(topic.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingOrganizer = true
                    } label: {
                        Image(systemName: "square.grid.2x2")
                    }
                    .accessibilityLabel("Organize topics")
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingSaved = true
                    } label: {
                        Image(systemName: "bookmark")
                    }
                    .accessibilityLabel("Saved stories")

                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingSaved) {
                NavigationStack {
                    SavedStoriesView()
                }
            }
        }
    }
}

/// Renders a single edition's sections vertically with native spacing.
struct EditionView: View {
    @Bindable var edition: Edition
    @Query private var allItems: [StoryItem]

    init(edition: Edition) {
        self.edition = edition
        let editionID = edition.id
        _allItems = Query(
            filter: #Predicate<StoryItem> { item in
                item.section?.edition?.id == editionID
            },
            sort: \StoryItem.sortOrder
        )
    }

    private var sortedSections: [BriefSection] {
        edition.sections.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                header

                ForEach(sortedSections) { section in
                    let sectionID = section.id
                    let sectionItems = allItems.filter { $0.section?.id == sectionID }
                    SectionView(section: section, items: sectionItems)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 96) // Inset comfortably above floating glass capsule
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(edition.dateLabel.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            if !edition.theme.isEmpty {
                Text(edition.theme)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
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
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(items) { item in
                            ExpandableText(
                                text: item.body.isEmpty ? item.headline : item.body,
                                lineLimit: 3,
                                font: .body,
                                foregroundStyle: .primary,
                                lineSpacing: 5
                            )
                        }
                    }
                }
            }
        }
    }
}

/// A concise card that prioritizes headline, unread dot indicator, source metadata, and expandable snippets.
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
                            lineLimit: 2,
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
