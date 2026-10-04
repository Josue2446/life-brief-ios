import SwiftUI
import SwiftData

/// All favorited stories across all topics, searchable and manageable in one place.
struct SavedStoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<StoryItem> { $0.isBookmarked },
        sort: \StoryItem.headline
    ) private var favoriteStories: [StoryItem]

    @State private var searchText = ""

    private var filteredStories: [StoryItem] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return favoriteStories
        }
        return favoriteStories.filter { item in
            item.headline.localizedCaseInsensitiveContains(searchText) ||
            item.body.localizedCaseInsensitiveContains(searchText) ||
            (item.sourceName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        Group {
            if favoriteStories.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("No Favorites")
                    } icon: {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.red)
                    }
                } description: {
                    Text("Stories you favorite while reading will appear here.")
                }
            } else if filteredStories.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    ForEach(filteredStories) { item in
                        NavigationLink {
                            StoryDetailView(item: item)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "heart.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.red)

                                    if let source = item.sourceName {
                                        Text(source)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .textCase(.uppercase)
                                    }
                                }

                                Text(item.headline)
                                    .font(.headline)
                                    .foregroundStyle(item.isRead ? .secondary : .primary)
                                    .lineLimit(2)

                                if !item.body.isEmpty {
                                    ExpandableText(
                                        text: item.body,
                                        font: .subheadline,
                                        foregroundStyle: .secondary,
                                        lineSpacing: 3,
                                        allowSelection: false
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    item.isFavorite = false
                                }
                            } label: {
                                Label("Remove", systemImage: "heart.slash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                item.isRead.toggle()
                            } label: {
                                Label(
                                    item.isRead ? "Mark as Unread" : "Mark as Read",
                                    systemImage: item.isRead ? "envelope.badge" : "envelope.open"
                                )
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search Favorites")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}
