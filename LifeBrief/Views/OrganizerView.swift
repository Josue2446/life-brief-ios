import SwiftUI
import SwiftData

/// Organizer: add topics, reorder them, show or hide them, and reorder
/// the sections inside a topic. All changes persist immediately.
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
                                .foregroundStyle(.tint)
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
                        HStack(spacing: 12) {
                            ForEach(symbolChoices, id: \.self) { symbol in
                                Button {
                                    newTopicSymbol = symbol
                                } label: {
                                    Image(systemName: symbol)
                                        .font(.body)
                                        .frame(width: 40, height: 40)
                                        .foregroundStyle(newTopicSymbol == symbol ? .white : .primary)
                                        .background(
                                            Circle()
                                                .fill(newTopicSymbol == symbol ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(symbol)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 4)

                Button("Add Topic") { addTopic() }
                    .disabled(newTopicName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Organize")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
#if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
#endif
        }
    }

    private func visibilityBinding(for topic: Topic) -> Binding<Bool> {
        Binding(
            get: { topic.isVisible },
            set: { topic.isVisible = $0; try? context.save() }
        )
    }

    private func moveTopics(from source: IndexSet, to destination: Int) {
        var ordered = topics
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, topic) in ordered.enumerated() {
            topic.sortOrder = index
        }
        try? context.save()
    }

    private func deleteTopics(at offsets: IndexSet) {
        for index in offsets {
            context.delete(topics[index])
        }
        try? context.save()
    }

    private func addTopic() {
        let name = newTopicName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let topic = Topic(
            name: name,
            systemImage: newTopicSymbol,
            sortOrder: topics.count
        )
        context.insert(topic)
        try? context.save()
        newTopicName = ""
        nameFieldFocused = false
    }
}

/// Reorder the sections inside one topic's editions.
struct SectionOrderView: View {
    @Bindable var topic: Topic
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            Section {
                if let edition = topic.latestEdition {
                    ForEach(edition.sortedSections) { section in
                        Label(section.title, systemImage: section.kind.systemImage)
                    }
                    .onMove { source, destination in
                        var ordered = edition.sortedSections
                        ordered.move(fromOffsets: source, toOffset: destination)
                        for (index, section) in ordered.enumerated() {
                            section.sortOrder = index
                        }
                        try? context.save()
                    }
                } else {
                    Text("No sections yet. They will appear with the first edition.")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Drag to reorder. For example, move OHSU above the overview.")
            }
        }
        .navigationTitle(topic.name)
        .toolbar {
#if os(iOS)
            EditButton()
#endif
        }
    }
}
