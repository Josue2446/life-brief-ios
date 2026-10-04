import SwiftUI
import SwiftData

/// Dedicated screen for browsing bookmarked stories, styled like Apple News "Saved Stories".
struct SavedStoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<StoryItem> { $0.isBookmarked }) private var bookmarkedStories: [StoryItem]
    @State private var searchText = ""

    private var filteredStories: [StoryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return bookmarkedStories }
        return bookmarkedStories.filter {
            $0.headline.localizedCaseInsensitiveContains(query)
                || $0.body.localizedCaseInsensitiveContains(query)
                || ($0.sourceName?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        Group {
            if bookmarkedStories.isEmpty {
                ContentUnavailableView(
                    "No Saved Stories",
                    systemImage: "bookmark",
                    description: Text("Stories you bookmark while reading will be saved here for easy reference.")
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
                                        .foregroundStyle(.tint)
                                        .textCase(.uppercase)
                                }
                                Text(item.headline)
                                    .font(.headline)
                                    .foregroundStyle(item.isRead ? .secondary : .primary)
                                    .lineLimit(2)

                                if !item.body.isEmpty {
                                    Text(item.body)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
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
                            .tint(.blue)
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
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
