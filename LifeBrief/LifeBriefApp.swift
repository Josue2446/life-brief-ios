import SwiftUI
import SwiftData

/// Life Brief — a native iOS briefing app.
///
/// Topics (Portland, AI & Tech, Politics, ...) each publish editions.
/// New topics can be added later without changing the app's structure.
@main
struct LifeBriefApp: App {
    @AppStorage("appearance") private var appearance: Appearance = .system

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Topic.self, Edition.self, BriefSection.self, StoryItem.self])
        
        // Ensure Application Support directory exists before initializing SQLite persistent store
        // to prevent sandbox errno 2 errors on first launch in simulator.
        if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        }
        
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}

/// User-chosen appearance, following the iOS Settings convention
/// (System / Light / Dark) rather than a custom theme switcher.
enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
