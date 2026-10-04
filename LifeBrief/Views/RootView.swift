import SwiftUI
import SwiftData

/// App root: shows the selected topic and anchors the floating tab bar
/// using safeAreaInset, ensuring proper content scroll insets without
/// competing system bar chrome.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var systemDynamicTypeSize
    @Query(sort: \Topic.sortOrder) private var topics: [Topic]
    @AppStorage("textSizeOverride") private var textSizeOverride: TextSizeOverride = .system

    @State private var selection: UUID?
    @State private var showingOrganizer = false
    @State private var organizerTab: OrganizerTab = .sections
    @State private var showingSettings = false

    private var visibleTopics: [Topic] {
        topics.filter { $0.isVisible }
    }

    private var selectedTopic: Topic? {
        visibleTopics.first { $0.id == selection } ?? visibleTopics.first
    }

    private var selectionBinding: Binding<UUID> {
        Binding(
            get: { selection ?? visibleTopics.first?.id ?? UUID() },
            set: { selection = $0 }
        )
    }

    var body: some View {
        Group {
            if let topic = selectedTopic {
                TopicHomeView(
                    topic: topic,
                    showingOrganizer: $showingOrganizer,
                    organizerTab: $organizerTab,
                    showingSettings: $showingSettings
                )
                .id(topic.id)
            } else {
                ContentUnavailableView(
                    "No topics",
                    systemImage: "newspaper",
                    description: Text("Add a topic in the organizer to get started.")
                )
            }
        }
        .dynamicTypeSize(textSizeOverride.dynamicTypeSize ?? systemDynamicTypeSize)
        .safeAreaInset(edge: .bottom) {
            if visibleTopics.count > 1 {
                FloatingTabBar(topics: visibleTopics, selection: selectionBinding)
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showingOrganizer) {
            NavigationStack {
                OrganizerView(
                    initialTab: organizerTab,
                    selectedTopic: selectedTopic
                )
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack { SettingsView() }
        }
        .task {
            BriefStore.seedIfNeeded(context)
        }
        .onChange(of: visibleTopics.map(\.id)) { _, ids in
            // Keep selection valid when topics are hidden or deleted.
            if let selection, !ids.contains(selection) {
                self.selection = ids.first
            } else if selection == nil {
                selection = ids.first
            }
        }
    }
}

/// App-level text size, expressed through Dynamic Type the way
/// iOS Settings does, so type scales the Apple-blessed way.
enum TextSizeOverride: String, CaseIterable, Identifiable {
    case system
    case large
    case extraLarge
    case accessibility

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        case .accessibility: return "Largest"
        }
    }

    /// `nil` defers to the system setting, exactly like iOS does.
    var dynamicTypeSize: DynamicTypeSize? {
        switch self {
        case .system: return nil
        case .large: return .xxLarge
        case .extraLarge: return .xxxLarge
        case .accessibility: return .accessibility1
        }
    }
}
