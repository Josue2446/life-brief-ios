import SwiftUI
import SwiftData

/// All bookmarked stories across all topics, searchable and manageable in one place.
struct SavedStoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<StoryItem> { $0.isBookmarked },
        sort: \StoryItem.headline
    ) private var savedStories: [StoryItem]

    @State private var searchText = ""

    private var filteredStories: [StoryItem] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return savedStories
        }
        return savedStories.filter { item in
            item.headline.localizedCaseInsensitiveContains(searchText) ||
            item.body.localizedCaseInsensitiveContains(searchText) ||
            (item.sourceName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        Group {
            if savedStories.isEmpty {
                ContentUnavailableView(
                    "No Saved Stories",
                    systemImage: "bookmark",
                    description: Text("Stories you bookmark while reading will appear here.")
                )
            } else if filteredStories.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    ForEach(filteredStories) { item in
                        NavigationLink {
                            StoryDetailView(item: item)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                if let source = item.sourceName {
                                    Text(source)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
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
                                    item.isBookmarked = false
                                }
                            } label: {
                                Label("Remove", systemImage: "bookmark.slash")
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
        .navigationTitle("Saved Stories")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search Saved Stories")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}
