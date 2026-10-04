import SwiftUI
import SwiftData

/// Full-screen detail view for a story item: large hero, full editorial body,
/// external link launch, and seamless feedback collection directly saved to feedback.json.
struct StoryDetailView: View {
    @Bindable var item: StoryItem

    @Environment(\.openURL) private var openURL
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    @State private var commentText: String = ""
    @State private var feedbackStatusMessage: String?
    @State private var showingSafari = false
    @FocusState private var isCommentFocused: Bool

    private var shareText: String {
        var text = "\(item.headline)\n\n\(item.body)"
        if let url = item.sourceLinkURL {
            text += "\n\nRead more: \(url.absoluteString)"
        }
        return text
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if let url = item.imageLinkURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: 280)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(uiColor: .tertiarySystemFill))
                                .frame(maxWidth: .infinity)
                                .frame(height: 220)
                                .overlay {
                                    ProgressView()
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                }

                if !item.body.isEmpty {
                    ExpandableText(
                        text: item.body,
                        font: .body,
                        foregroundStyle: .primary,
                        lineSpacing: 6
                    )
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

                feedbackSection
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 100) // Comfortable clearance above the floating tab bar
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(item.sourceName ?? "Story")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            ProgressiveGlassHeader()
        }
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
            commentText = item.userComment ?? ""
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let source = item.sourceName {
                    Text(source)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
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
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }

    private var feedbackSection: some View {
        BriefCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Your Feedback", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    if let status = feedbackStatusMessage {
                        Text(status)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }

                Text("Help calibrate your future briefing summaries with quick feedback.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    reactionButton(type: .like)
                    reactionButton(type: .dislike)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Editorial Notes")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    TextField("Add comments or insights about this story...", text: $commentText, axis: .vertical)
                        .lineLimit(3...5)
                        .focused($isCommentFocused)
                        .padding(14)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.05), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                }

                // Modern Apple-style submit button
                Button {
                    isCommentFocused = false
                    saveFeedback()
                } label: {
                    HStack {
                        Spacer()
                        Label(
                            feedbackStatusMessage != nil ? (feedbackStatusMessage ?? "Feedback Saved") : "Submit Feedback",
                            systemImage: feedbackStatusMessage != nil ? "checkmark.circle.fill" : "arrow.up.circle.fill"
                        )
                        .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Color(uiColor: .label))
                .foregroundStyle(Color(uiColor: .systemBackground))
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func reactionButton(type: ReactionType) -> some View {
        let isSelected = item.reaction == type
        Button {
            toggleReaction(type)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? type.filledSystemImage : type.systemImage)
                    .font(.subheadline.weight(.semibold))
                Text(type.title)
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(Color.primary)
            .background(
                isSelected ? Color(uiColor: .secondarySystemFill) : Color.clear,
                in: .rect(cornerRadius: 14, style: .continuous)
            )
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? LinearGradient(colors: [Color.primary.opacity(0.8), Color.primary.opacity(0.5)], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.05), Color.clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: isSelected ? 1.5 : 0.6
                    )
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: item.reaction) { _, _ in hapticsEnabled }
        .accessibilityLabel(isSelected ? "Remove \(type.title.lowercased()) rating" : "Mark as \(type.title.lowercased())")
    }

    private func toggleReaction(_ reaction: ReactionType) {
        if item.reaction == reaction {
            item.reaction = nil
            saveFeedback(status: "Rating cleared")
        } else {
            item.reaction = reaction
            saveFeedback(status: "\(reaction.title) recorded")
        }
    }

    private func saveFeedback(status: String = "Feedback saved") {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        item.userComment = trimmed.isEmpty ? nil : trimmed
        FeedbackStore.recordFeedback(for: item, reaction: item.reaction, comment: item.userComment)
        withAnimation {
            feedbackStatusMessage = status
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation {
                feedbackStatusMessage = nil
            }
        }
    }
}
