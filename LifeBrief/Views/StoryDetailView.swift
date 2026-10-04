import SwiftUI

/// Full story reader with focused typography, Safari Reader integration, and standard iOS actions.
struct StoryDetailView: View {
    @Bindable var item: StoryItem
    @Environment(\.openURL) private var openURL
    @State private var showingSafari = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if !item.body.isEmpty {
                    Text(item.body)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                }

                if let url = item.sourceLinkURL {
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            showingSafari = true
                        } label: {
                            HStack {
                                Label(item.sourceName ?? "Read Original Article", systemImage: "safari")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.capsule)
                        .accessibilityHint("Opens the full article in reader view.")

                        // Secondary action to open in external Safari
                        Button {
                            openURL(url)
                        } label: {
                            Text("Open in Safari Browser")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.top, 12)
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(item.sourceName ?? "Story")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    item.isRead.toggle()
                } label: {
                    Image(systemName: item.isRead ? "envelope.badge" : "envelope.open")
                }
                .accessibilityLabel(item.isRead ? "Mark as unread" : "Mark as read")

                BookmarkButton(item: item)

                ShareLink(item: shareText, preview: SharePreview(item.headline)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingSafari) {
            if let url = item.sourceLinkURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            item.isRead = true
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                if let sourceName = item.sourceName {
                    Label(sourceName, systemImage: "newspaper")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tint)
                        .textCase(.uppercase)
                }

                if let tag = item.tag, !tag.isEmpty {
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Text(tag)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Text(item.headline)
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }

    private var shareText: String {
        var text = item.headline
        if !item.body.isEmpty {
            text += "\n\n\(item.body)"
        }
        if let url = item.sourceLinkURL {
            text += "\n\n\(url.absoluteString)"
        }
        return text
    }
}
