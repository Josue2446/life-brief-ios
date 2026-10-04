import SwiftUI
import SwiftData

/// Organize topics: add new ones with native SF Symbols, reorder the
/// tabs, and toggle visibility. Section order within each topic is also editable.
struct OrganizerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Topic.sortOrder) private var topics: [Topic]

    @State private var newTopicName = ""
    @State private var newTopicSymbol = "newspaper"
    @FocusState private var nameFieldFocused: Bool

    private let symbolChoices = [
        "newspaper", "building.2", "cpu", "building.columns", "cross.case",
        "chart.line.uptrend.xyaxis", "globe", "flask", "music.note", "trophy",
        "book", "film", "gamecontroller", "leaf", "star"
    ]

    var body: some View {
        List {
            Section {
                ForEach(topics) { topic in
                    NavigationLink {
                        SectionOrderView(topic: topic)
                    } label: {
                        Label {
                            Text(topic.name)
                        } icon: {
                            Image(systemName: topic.systemImage)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .onMove(perform: moveTopics)
                .onDelete(perform: deleteTopics)
            } header: {
                Text("Topics")
            } footer: {
                Text("Drag to reorder topics. This order is reflected in the bottom bar.")
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
        .navigationTitle("Organize Topics")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
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
    }

    private func deleteTopics(at offsets: IndexSet) {
        for index in offsets {
            context.delete(topics[index])
        }
    }

    private func addTopic() {
        let trimmed = newTopicName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let newTopic = Topic(
            feedID: trimmed.lowercased().replacingOccurrences(of: " ", with: "-"),
            name: trimmed,
            systemImage: newTopicSymbol,
            sortOrder: topics.count
        )
        context.insert(newTopic)
        newTopicName = ""
        nameFieldFocused = false
    }
}

/// Allows dragging sections within a single topic to customize reading order.
struct SectionOrderView: View {
    @Bindable var topic: Topic

    private var sortedSections: [BriefSection] {
        topic.editions.first?.sections.sorted { $0.sortOrder < $1.sortOrder } ?? []
    }

    var body: some View {
        List {
            ForEach(sortedSections) { section in
                Label(section.title, systemImage: section.kind.systemImage)
            }
            .onMove(perform: moveSections)
        }
        .navigationTitle(topic.name)
        .toolbar {
            EditButton()
        }
    }

    private func moveSections(from source: IndexSet, to destination: Int) {
        guard let edition = topic.editions.first else { return }
        var sections = edition.sections.sorted { $0.sortOrder < $1.sortOrder }
        sections.move(fromOffsets: source, toOffset: destination)
        for (index, section) in sections.enumerated() {
            section.sortOrder = index
        }
    }
}
