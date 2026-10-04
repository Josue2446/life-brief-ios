import SwiftUI
import SwiftData

enum OrganizerTab: String, CaseIterable, Identifiable {
    case sections = "Sections"
    case topics = "Topics"

    var id: String { rawValue }
}

/// Organize sections within briefings and reorder/toggle topics.
struct OrganizerView: View {
    var initialTab: OrganizerTab = .sections
    var selectedTopic: Topic?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    @Query(sort: \Topic.sortOrder) private var topics: [Topic]

    @State private var activeTab: OrganizerTab = .sections
    @State private var activeTopicID: UUID?
    @State private var sections: [BriefSection] = []

    @State private var newTopicName = ""
    @State private var newTopicSymbol = "newspaper"
    @FocusState private var nameFieldFocused: Bool

    private let symbolChoices = [
        "newspaper", "building.columns", "cross.case", "tree", "briefcase",
        "cpu", "globe.americas", "leaf", "sparkles", "chart.line.uptrend.xyaxis",
        "book", "film", "heart.text.square", "airplane", "gamecontroller"
    ]

    private var currentTopic: Topic? {
        if let id = activeTopicID, let match = topics.first(where: { $0.id == id }) {
            return match
        }
        return selectedTopic ?? topics.first
    }

    var body: some View {
        List {
            Section {
                Picker("Organizer Mode", selection: $activeTab) {
                    ForEach(OrganizerTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            if activeTab == .sections {
                sectionsContent
            } else {
                topicsContent
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(activeTab == .sections ? "Organize Sections" : "Organize Topics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .fontWeight(.semibold)
            }
        }
        .onAppear {
            activeTab = initialTab
            if let selected = selectedTopic {
                activeTopicID = selected.id
            } else if let first = topics.first {
                activeTopicID = first.id
            }
            loadSections()
        }
        .onChange(of: activeTopicID) {
            loadSections()
        }
    }

    // MARK: - Sections View

    @ViewBuilder
    private var sectionsContent: some View {
        if topics.count > 1 {
            Section("Topic") {
                Picker("Select Topic", selection: Binding(
                    get: { currentTopic?.id ?? topics.first?.id ?? UUID() },
                    set: { activeTopicID = $0 }
                )) {
                    ForEach(topics) { topic in
                        Label(topic.name, systemImage: topic.systemImage)
                            .tag(topic.id)
                    }
                }
                .pickerStyle(.menu)
            }
        }

        Section {
            if sections.isEmpty {
                Text("No sections available for this topic.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sections) { section in
                    HStack(spacing: 14) {
                        Image(systemName: section.kind.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(FloatingTabBar.appleMusicTint)
                            .frame(width: 32, height: 32)
                            .background(
                                FloatingTabBar.appleMusicTint.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(section.title)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text(storyCountLabel(for: section))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .onMove(perform: moveSections)
            }
        } header: {
            Text("Section Order")
        } footer: {
            Text("Drag sections to reorder how they appear in the briefing. For example, drag OHSU to the top, and Top Stories toward the bottom. Your order is saved across updates.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        if !sections.isEmpty {
            Section {
                Button(role: .destructive) {
                    resetSectionsToDefault()
                } label: {
                    HStack {
                        Spacer()
                        Text("Reset to Default Order")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                    }
                }
            }
        }
    }

    private func storyCountLabel(for section: BriefSection) -> String {
        let count = section.items.count
        if count == 0 {
            return "Overview notes"
        } else if count == 1 {
            return "1 story"
        } else {
            return "\(count) stories"
        }
    }

    private func loadSections() {
        if let edition = currentTopic?.latestEdition {
            sections = edition.sortedSections
        } else {
            sections = []
        }
    }

    private func moveSections(from source: IndexSet, to destination: Int) {
        sections.move(fromOffsets: source, toOffset: destination)
        for (index, section) in sections.enumerated() {
            section.sortOrder = index
        }
        try? context.save()

        if let topic = currentTopic {
            let titles = sections.map(\.title)
            UserDefaults.standard.set(titles, forKey: "sectionOrder_\(topic.id.uuidString)")
        }

        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func resetSectionsToDefault() {
        guard let topic = currentTopic, let edition = topic.latestEdition else { return }
        let defaultKindOrder: [SectionKind] = [.overview, .stories, .ohsu, .community, .summary, .custom]

        let sorted = edition.sections.sorted { a, b in
            let aIdx = defaultKindOrder.firstIndex(of: a.kind) ?? 99
            let bIdx = defaultKindOrder.firstIndex(of: b.kind) ?? 99
            return aIdx < bIdx
        }

        for (index, section) in sorted.enumerated() {
            section.sortOrder = index
        }
        try? context.save()
        UserDefaults.standard.removeObject(forKey: "sectionOrder_\(topic.id.uuidString)")

        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            sections = sorted
        }

        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: - Topics View

    @ViewBuilder
    private var topicsContent: some View {
        Section("Reorder Topics") {
            ForEach(topics) { topic in
                HStack(spacing: 12) {
                    Image(systemName: topic.systemImage)
                        .foregroundStyle(.tint)
                        .frame(width: 24)

                    Text(topic.name)
                        .font(.body)

                    Spacer()
                }
            }
            .onMove(perform: moveTopics)
        }

        Section("Visibility") {
            ForEach(topics) { topic in
                Toggle(isOn: visibilityBinding(for: topic)) {
                    Label(topic.name, systemImage: topic.systemImage)
                }
            }
        }

        Section("Add Topic") {
            TextField("Topic name", text: $newTopicName)
                .focused($nameFieldFocused)
                .submitLabel(.done)
                .onSubmit(addTopic)

            VStack(alignment: .leading, spacing: 8) {
                Text("Select Icon")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(symbolChoices, id: \.self) { symbol in
                            Button {
                                newTopicSymbol = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        newTopicSymbol == symbol
                                            ? Color(uiColor: .secondarySystemFill)
                                            : Color(uiColor: .tertiarySystemGroupedBackground),
                                        in: .rect(cornerRadius: 8, style: .continuous)
                                    )
                                    .overlay {
                                        if newTopicSymbol == symbol {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .strokeBorder(Color.primary, lineWidth: 1.5)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Button("Add Topic") {
                addTopic()
            }
            .disabled(newTopicName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func visibilityBinding(for topic: Topic) -> Binding<Bool> {
        Binding(
            get: { topic.isVisible },
            set: { topic.isVisible = $0 }
        )
    }

    private func moveTopics(from source: IndexSet, to destination: Int) {
        var reordered = topics
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, topic) in reordered.enumerated() {
            topic.sortOrder = index
        }
        try? context.save()
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func addTopic() {
        let trimmed = newTopicName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let nextOrder = (topics.map(\.sortOrder).max() ?? -1) + 1
        let topic = Topic(
            feedID: trimmed.lowercased().replacingOccurrences(of: " ", with: "-"),
            name: trimmed,
            systemImage: newTopicSymbol,
            sortOrder: nextOrder
        )
        context.insert(topic)

        newTopicName = ""
        nameFieldFocused = false
        try? context.save()
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
