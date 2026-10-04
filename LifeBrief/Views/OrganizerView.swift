import SwiftUI
import SwiftData

/// Organize topics: toggle visibility, reorder with native drag & drop,
/// and add custom topics with curated SF Symbols.
struct OrganizerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Topic.sortOrder) private var topics: [Topic]

    @State private var newTopicName = ""
    @State private var newTopicSymbol = "newspaper"
    @FocusState private var nameFieldFocused: Bool

    private let symbolChoices = [
        "newspaper", "building.columns", "cross.case", "tree", "briefcase",
        "cpu", "globe.americas", "leaf", "sparkles", "chart.line.uptrend.xyaxis",
        "book", "film", "heart.text.square", "airplane", "gamecontroller"
    ]

    var body: some View {
        List {
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
        .scrollEdgeEffectStyle(.soft, for: .top)
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
    }
}
