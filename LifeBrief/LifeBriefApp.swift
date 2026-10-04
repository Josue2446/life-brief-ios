import SwiftUI
import SwiftData

/// Life Brief — a native iOS briefing app.
///
/// Topics (Portland, AI & Tech, Politics, ...) each publish editions.
/// New topics can be added later without changing the app's structure.
@main
struct LifeBriefApp: App {
    @AppStorage("appearance") private var appearance: Appearance = .system

    init() {
        // Completely remove default UIKit navigation bar background & hairline separators
        // so content can seamlessly fade under floating titles and controls without hard cutoffs.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = .clear
        appearance.backgroundColor = .clear
        appearance.backgroundEffect = nil
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

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

/// Curated accent colors matching Apple HIG and user theme preferences.
enum AccentColorTheme: String, CaseIterable, Identifiable {
    case multicolor
    case blue
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case graphite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .multicolor: return "Rainbow"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .pink: return "Pink"
        case .red: return "Coral"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .graphite: return "Graphite"
        }
    }

    var color: Color {
        switch self {
        case .multicolor:
            return Color(red: 1.0, green: 0.176, blue: 0.333)
        case .blue:
            return Color(red: 0.0, green: 0.478, blue: 1.0)
        case .purple:
            return Color(red: 0.686, green: 0.322, blue: 0.871)
        case .pink:
            return Color(red: 0.99, green: 0.18, blue: 0.33) // Apple Music Pink
        case .red:
            return Color(red: 1.0, green: 0.231, blue: 0.188)
        case .orange:
            return Color(red: 1.0, green: 0.584, blue: 0.0)
        case .yellow:
            return Color(red: 1.0, green: 0.8, blue: 0.0)
        case .green:
            return Color(red: 0.204, green: 0.780, blue: 0.349)
        case .graphite:
            return Color(red: 0.557, green: 0.557, blue: 0.576)
        }
    }
}
