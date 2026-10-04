import SwiftUI

/// Section layout for OHSU News & Events with native Apple horizontal carousel snap scrolling.
struct OHSUSectionView: View {
    var items: [StoryItem]

    private var news: [StoryItem] {
        items.filter { $0.tag?.lowercased() != "event" }
    }

    private var events: [StoryItem] {
        items.filter { $0.tag?.lowercased() == "event" }
    }

    @State private var scrolledNewsID: UUID?
    @State private var scrolledEventID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Horizontal carousel for OHSU news stories
            if !news.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 14) {
                            ForEach(news) { item in
                                OHSUCard(item: item)
                            }
                        }
                        .padding(.horizontal, 20)
                        .scrollTargetLayout()
                    }
                    .padding(.horizontal, -20)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $scrolledNewsID)

                    // Discreet page dots
                    if news.count > 1 {
                        HStack(spacing: 6) {
                            ForEach(news) { item in
                                let isActive = item.id == (scrolledNewsID ?? news.first?.id)
                                Circle()
                                    .fill(isActive ? Color.primary : Color.secondary.opacity(0.28))
                                    .frame(width: isActive ? 6 : 5, height: isActive ? 6 : 5)
                                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: scrolledNewsID)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)
                    }
                }
            }

            // Horizontal carousel for upcoming campus events
            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Upcoming on campus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 14) {
                            ForEach(events) { event in
                                EventCard(event: event)
                            }
                        }
                        .padding(.horizontal, 20)
                        .scrollTargetLayout()
                    }
                    .padding(.horizontal, -20)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $scrolledEventID)

                    if events.count > 1 {
                        HStack(spacing: 6) {
                            ForEach(events) { event in
                                let isActive = event.id == (scrolledEventID ?? events.first?.id)
                                Circle()
                                    .fill(isActive ? Color.primary : Color.secondary.opacity(0.28))
                                    .frame(width: isActive ? 6 : 5, height: isActive ? 6 : 5)
                                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: scrolledEventID)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)
                    }
                }
            }
        }
        .onAppear {
            if scrolledNewsID == nil {
                scrolledNewsID = news.first?.id
            }
            if scrolledEventID == nil {
                scrolledEventID = events.first?.id
            }
        }
    }
}

/// Compact OHSU story card formatted for horizontal carousel reading with built-in app browser.
struct OHSUCard: View {
    @Bindable var item: StoryItem
    @State private var showingSafari = false

    var body: some View {
        BriefCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.secondary.opacity(0.12), in: Circle())

                    Text("OHSU News")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)

                    FavoriteHeartButton(item: item)
                }

                Text(item.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if item.sourceLinkURL != nil {
                            showingSafari = true
                        }
                    }

                if !item.body.isEmpty {
                    ExpandableText(
                        text: item.body,
                        font: .caption,
                        foregroundStyle: .secondary,
                        lineSpacing: 2
                    )
                }

                if let sourceName = item.sourceName {
                    Spacer(minLength: 4)

                    if item.sourceLinkURL != nil {
                        Button {
                            showingSafari = true
                        } label: {
                            Label(sourceName, systemImage: "arrow.up.right")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(sourceName)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 290)
        .sheet(isPresented: $showingSafari) {
            if let url = item.sourceLinkURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
}

/// Compact campus event card formatted for horizontal carousel reading.
struct EventCard: View {
    var event: StoryItem
    @AppStorage("accentColorTheme") private var accentColorTheme: AccentColorTheme = .pink
    @State private var showingSafari = false

    var body: some View {
        BriefCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.secondary.opacity(0.12), in: Circle())

                    Text("Campus Event")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)
                }

                Text(event.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if !event.body.isEmpty {
                    ExpandableText(
                        text: event.body,
                        font: .caption,
                        foregroundStyle: .secondary,
                        lineSpacing: 2
                    )
                }

                if event.sourceLinkURL != nil {
                    Spacer(minLength: 4)

                    Button("Event details") {
                        showingSafari = true
                    }
                    .buttonStyle(.bordered)
                    .tint(accentColorTheme.color)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 290)
        .sheet(isPresented: $showingSafari) {
            if let url = event.sourceLinkURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
}

/// Community observations presented with standard horizontal carousel snap scrolling.
struct CommunitySectionView: View {
    var items: [StoryItem]
    @State private var scrolledID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(items) { item in
                        CommunityCard(item: item)
                    }
                }
                .padding(.horizontal, 20)
                .scrollTargetLayout()
            }
            .padding(.horizontal, -20)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrolledID)

            // Discreet page dots
            if items.count > 1 {
                HStack(spacing: 6) {
                    ForEach(items) { item in
                        let isActive = item.id == (scrolledID ?? items.first?.id)
                        Circle()
                            .fill(isActive ? Color.primary : Color.secondary.opacity(0.28))
                            .frame(width: isActive ? 6 : 5, height: isActive ? 6 : 5)
                            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: scrolledID)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
            }
        }
        .onAppear {
            if scrolledID == nil {
                scrolledID = items.first?.id
            }
        }
    }
}

/// Compact community card formatted for horizontal carousel reading.
struct CommunityCard: View {
    @Bindable var item: StoryItem
    @State private var showingSafari = false

    var body: some View {
        BriefCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    if let tag = item.tag, !tag.isEmpty {
                        Text(tag)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color(uiColor: .secondarySystemFill), in: .capsule)
                    }

                    Spacer(minLength: 0)

                    FavoriteHeartButton(item: item)
                }

                Text(item.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if item.sourceLinkURL != nil {
                            showingSafari = true
                        }
                    }

                if !item.body.isEmpty {
                    ExpandableText(
                        text: item.body,
                        font: .caption,
                        foregroundStyle: .secondary,
                        lineSpacing: 2
                    )
                }

                if let sourceName = item.sourceName ?? (item.sourceLinkURL != nil ? "Source" : nil) {
                    Spacer(minLength: 4)

                    if item.sourceLinkURL != nil {
                        Button {
                            showingSafari = true
                        } label: {
                            Label(sourceName, systemImage: "arrow.up.right")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(sourceName)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 290)
        .sheet(isPresented: $showingSafari) {
            if let url = item.sourceLinkURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
}

/// Summary takeaways presented 2-at-a-time in a horizontal swipeable card carousel.
struct SummarySectionView: View {
    var items: [StoryItem]
    @State private var scrolledPairID: UUID?

    private struct SummaryPair: Identifiable {
        var id: UUID { items.first?.id ?? UUID() }
        var items: [StoryItem]
    }

    private var pairs: [SummaryPair] {
        stride(from: 0, to: items.count, by: 2).map { index in
            SummaryPair(items: Array(items[index..<min(index + 2, items.count)]))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(pairs) { pair in
                        SummaryCard(items: pair.items)
                    }
                }
                .padding(.horizontal, 20)
                .scrollTargetLayout()
            }
            .padding(.horizontal, -20)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrolledPairID)

            // Discreet page dots for summary pairs
            if pairs.count > 1 {
                HStack(spacing: 6) {
                    ForEach(pairs) { pair in
                        let isActive = pair.id == (scrolledPairID ?? pairs.first?.id)
                        Circle()
                            .fill(isActive ? Color.primary : Color.secondary.opacity(0.28))
                            .frame(width: isActive ? 6 : 5, height: isActive ? 6 : 5)
                            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: scrolledPairID)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
            }
        }
        .onAppear {
            if scrolledPairID == nil {
                scrolledPairID = pairs.first?.id
            }
        }
    }
}

/// A card holding 2 summary points stacked vertically.
struct SummaryCard: View {
    var items: [StoryItem]

    var body: some View {
        BriefCard {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    summaryRow(for: item)
                    if index < items.count - 1 {
                        Divider()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 300)
    }

    @ViewBuilder
    private func summaryRow(for item: StoryItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
                .font(.body)
                .frame(width: 24)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                if !item.body.isEmpty {
                    ExpandableText(
                        text: item.body,
                        font: .caption,
                        foregroundStyle: .secondary,
                        lineSpacing: 2
                    )
                }
            }
        }
    }
}
