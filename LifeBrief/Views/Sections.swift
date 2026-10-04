import SwiftUI

/// OHSU news and events, grouped into an easy-to-scan reading surface.
struct OHSUSectionView: View {
    var items: [StoryItem]

    private var news: [StoryItem] {
        items.filter { $0.tag != "event" && $0.headline.lowercased() != "upcoming events" }
    }

    private var events: [StoryItem] {
        items.filter { $0.tag == "event" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(news) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "cross.case.fill")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                        .frame(width: 24)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.headline)
                            .font(.subheadline.weight(.semibold))
                        if !item.body.isEmpty {
                            Text(item.body)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !events.isEmpty {
                Divider()

                Text("Upcoming on campus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(events) { event in
                    EventRow(event: event)
                }
            }
        }
    }
}

struct EventRow: View {
    var event: StoryItem
    @State private var showingSafari = false

    var body: some View {
        Button {
            if event.sourceLinkURL != nil {
                showingSafari = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .foregroundStyle(.tint)
                    .frame(width: 34, height: 34)
                    .background(.tint.opacity(0.12), in: .circle)

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if !event.body.isEmpty {
                        Text(event.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                if event.sourceLinkURL != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(event.sourceLinkURL == nil)
        .accessibilityHint(event.sourceLinkURL == nil ? "" : "Opens the event details.")
        .sheet(isPresented: $showingSafari) {
            if let url = event.sourceLinkURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
}

/// Community observations with compact source chips.
struct CommunitySectionView: View {
    var items: [StoryItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(items) { item in
                BriefCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(item.headline)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        if let tag = item.tag, !tag.isEmpty {
                            Text(tag)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tint)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(.tint.opacity(0.12), in: .capsule)
                        }
                    }
                }
            }
        }
    }
}

/// Summary takeaways use the standard semantic confirmation symbol.
struct SummarySectionView: View {
    var items: [StoryItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                        .font(.body)
                    Text(item.headline)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}
