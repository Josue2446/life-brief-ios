import SwiftUI
import SwiftData

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
            return Color(red: 1.0, green: 0.176, blue: 0.333)
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

/// Settings, crafted using modern Apple Human Interface Guidelines:
/// - Compact menu pickers (`.pickerStyle(.menu)`) with SF Symbol icons instead of wide segmented rows.
/// - Native Apple Liquid Glass context menus for single-tap options.
/// - Clear iconography and grouped hierarchical sections.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage("accentColorTheme") private var accentColorTheme: AccentColorTheme = .pink
    @AppStorage("appearance") private var appearance: Appearance = .system
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("feedURLString") private var feedURLString = BriefStore.defaultFeedURLString

    @State private var syncService = FeedbackSyncService.shared
    @State private var tokenInput: String = ""
    @State private var isTokenConfigured: Bool = KeychainHelper.hasToken

    @State private var updateStatus: String?
    @State private var isChecking = false
    @State private var feedbackCount: Int = FeedbackStore.loadFeed().entriesCount
    @State private var showingClearFeedbackAlert = false

    var body: some View {
        Form {
            themeSection
            feedbackToggleSection
            contentUpdatesSection
            automaticSyncSection
            feedbackStorageSection
            aboutSection
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .alert("Clear Feedback?", isPresented: $showingClearFeedbackAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                FeedbackStore.clearAllFeedback()
                feedbackCount = 0
            }
        } message: {
            Text("This will remove all saved reactions and comments from feedback.json.")
        }
        .onAppear {
            feedbackCount = FeedbackStore.loadFeed().entriesCount
            isTokenConfigured = KeychainHelper.hasToken
        }
    }

    // MARK: - Theme Section

    @ViewBuilder
    private var themeSection: some View {
        Section("Theme") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Color")
                    .font(.body)
                    .foregroundStyle(.primary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AccentColorTheme.allCases) { theme in
                            colorSwatchButton(theme: theme)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
            }
            .padding(.vertical, 4)

            Picker(selection: $appearance) {
                ForEach(Appearance.allCases) { mode in
                    Label(mode.label, systemImage: icon(for: mode))
                        .tag(mode)
                }
            } label: {
                Label("Appearance", systemImage: "circle.lefthalf.filled")
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Appearance")
        }
    }

    @ViewBuilder
    private func colorSwatchButton(theme: AccentColorTheme) -> some View {
        let isSelected = accentColorTheme == theme

        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
                accentColorTheme = theme
            }
            if hapticsEnabled {
                UISelectionFeedbackGenerator().selectionChanged()
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if isSelected {
                        Circle()
                            .strokeBorder(
                                theme == .multicolor
                                    ? AnyShapeStyle(AngularGradient(gradient: Gradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .pink, .red]), center: .center))
                                    : AnyShapeStyle(theme.color),
                                lineWidth: 2.5
                            )
                            .frame(width: 36, height: 36)
                    }

                    if theme == .multicolor {
                        Circle()
                            .fill(
                                AngularGradient(
                                    gradient: Gradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .pink, .red]),
                                    center: .center
                                )
                            )
                            .frame(width: 26, height: 26)
                    } else {
                        Circle()
                            .fill(theme.color)
                            .frame(width: 26, height: 26)
                    }
                }
                .frame(width: 38, height: 38)

                if isSelected {
                    Text(theme.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.color)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text(" ")
                        .font(.system(size: 11))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.displayName)
    }

    // MARK: - Interaction Section

    @ViewBuilder
    private var feedbackToggleSection: some View {
        Section {
            Toggle(isOn: $hapticsEnabled) {
                Label("Haptic Feedback", systemImage: "hand.tap")
            }
        } header: {
            Text("Interaction")
        }
    }

    // MARK: - Content Updates Section

    @ViewBuilder
    private var contentUpdatesSection: some View {
        Section {
            HStack(spacing: 12) {
                Label("Feed URL", systemImage: "link")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)

                TextField("Feed URL", text: $feedURLString)
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
#endif
            }

            Button {
                checkForUpdates()
            } label: {
                HStack {
                    Label("Check for Updates", systemImage: "arrow.clockwise")
                    Spacer()
                    if isChecking {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(isChecking || feedURLString.isEmpty)

            if let status = updateStatus {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Content Updates")
        }
    }

    // MARK: - Automatic Sync Section

    @ViewBuilder
    private var automaticSyncSection: some View {
        Section {
            if !isTokenConfigured {
                SecureField("GitHub Personal Access Token", text: $tokenInput)
                    .textContentType(.password)
                    .autocorrectionDisabled()
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                Button("Save Token & Setup Gist") {
                    saveToken()
                }
                .disabled(tokenInput.trimmingCharacters(in: .whitespaces).isEmpty)
            } else {
                HStack {
                    Label("Token Active", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Text("Configured")
                        .foregroundStyle(.secondary)
                }
            }

            if let gistID = syncService.gistID {
                LabeledContent("Private Gist ID") {
                    Text(maskedGistID(gistID))
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            if let error = syncService.lastErrorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if let date = syncService.lastSyncDate {
                LabeledContent("Last Synced") {
                    Text(date, format: .relative(presentation: .named))
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                manualSync()
            } label: {
                HStack {
                    Label(syncService.isSyncing ? "Syncing to Private Gist..." : "Sync Feedback Now",
                          systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    if syncService.isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(syncService.isSyncing || !isTokenConfigured)

            if isTokenConfigured {
                Button(role: .destructive) {
                    clearTokenAndGist()
                } label: {
                    Text("Remove Token & Disconnect Gist")
                        .font(.footnote)
                }
            }
        } header: {
            Text("Automatic Feedback Sync")
        } footer: {
            Text("Automatically syncs feedback.json to a private GitHub Gist so the content agent learns your preferences. Your token is stored securely in the iOS Keychain.")
        }
    }

    // MARK: - Feedback Storage Section

    @ViewBuilder
    private var feedbackStorageSection: some View {
        Section {
            LabeledContent {
                Text("\(feedbackCount)")
                    .foregroundStyle(.secondary)
            } label: {
                Label("Saved Responses", systemImage: "tray.full")
            }

            if feedbackCount > 0 {
                Menu {
                    ShareLink(item: FeedbackStore.feedbackFileURL) {
                        Label("Export feedback.json", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showingClearFeedbackAlert = true
                    } label: {
                        Label("Clear Stored Feedback", systemImage: "trash")
                    }
                } label: {
                    HStack {
                        Label("Feedback Actions", systemImage: "ellipsis.circle")
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        } header: {
            Text("Feedback Storage")
        } footer: {
            Text("Post reactions and comments are stored locally in feedback.json.")
        }
    }

    // MARK: - About Section

    @ViewBuilder
    private var aboutSection: some View {
        Section("About") {
            LabeledContent {
                Text(appVersion)
                    .foregroundStyle(.secondary)
            } label: {
                Label("Version", systemImage: "info.circle")
            }

            LabeledContent {
                Text("iOS 26 and later")
                    .foregroundStyle(.secondary)
            } label: {
                Label("Platform", systemImage: "apple.logo")
            }
        }
    }

    // MARK: - Helpers

    private func icon(for appearance: Appearance) -> String {
        switch appearance {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func saveToken() {
        let trimmed = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        KeychainHelper.saveToken(trimmed)
        isTokenConfigured = true
        tokenInput = ""
        manualSync()
    }

    private func clearTokenAndGist() {
        KeychainHelper.deleteToken()
        syncService.resetSyncConfiguration()
        isTokenConfigured = false
        tokenInput = ""
    }

    private func manualSync() {
        Task {
            _ = try? await syncService.syncNow()
        }
    }

    private func maskedGistID(_ id: String) -> String {
        guard id.count > 6 else { return "••••••" }
        let suffix = id.suffix(6)
        return "••••\(suffix)"
    }

    private func checkForUpdates() {
        guard let url = URL(string: feedURLString.trimmingCharacters(in: .whitespaces)),
              url.scheme == "https" || url.scheme == "http" else {
            updateStatus = "Enter a valid http(s) feed URL."
            return
        }
        isChecking = true
        updateStatus = nil
        Task {
            do {
                let dtos = try await FeedService.fetchTopics(from: url)
                let imported = BriefStore.importFeed(dtos, into: context)
                if imported > 0 {
                    updateStatus = "Updated: \(imported) new \(imported == 1 ? "edition" : "editions") imported."
                } else {
                    updateStatus = "Up to date."
                }
            } catch {
                updateStatus = "Fetch failed: \(error.localizedDescription)"
            }
            isChecking = false
        }
    }
}
