import SwiftUI

/// OHSU healthcare & campus events section with Apple Glass aesthetic.
struct OHSUSectionView: View {
    var items: [StoryItem]

    private var news: [StoryItem] {
        items.filter { $0.tag != "event" }
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
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.headline)
                            .font(.subheadline.weight(.semibold))
                        if !item.body.isEmpty {
                            ExpandableText(
                                text: item.body,
                                font: .subheadline,
                                foregroundStyle: .secondary,
                                lineSpacing: 3
                            )
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

/// Compact event presentation with date badge and calendar export.
struct EventRow: View {
    var event: StoryItem
    @State private var showingSafari = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.headline)
                    .font(.subheadline.weight(.medium))

                if !event.body.isEmpty {
                    ExpandableText(
                        text: event.body,
                        font: .caption,
                        foregroundStyle: .secondary,
                        lineSpacing: 2
                    )
                }

                if event.sourceLinkURL != nil {
                    Button {
                        showingSafari = true
                    } label: {
                        Text("Event details")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
        }
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

                        if !item.body.isEmpty {
                            ExpandableText(
                                text: item.body,
                                font: .subheadline,
                                foregroundStyle: .secondary,
                                lineSpacing: 3
                            )
                        }

                        if let tag = item.tag, !tag.isEmpty {
                            Text(tag)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Color(uiColor: .tertiarySystemFill), in: .capsule)
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
                        .foregroundStyle(.secondary)
                        .font(.body)
                    VStack(alignment: .leading, spacing: 4) {
                        if item.body.isEmpty {
                            ExpandableText(
                                text: item.headline,
                                font: .subheadline,
                                foregroundStyle: .primary,
                                lineSpacing: 3
                            )
                        } else {
                            Text(item.headline)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                            ExpandableText(
                                text: item.body,
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
