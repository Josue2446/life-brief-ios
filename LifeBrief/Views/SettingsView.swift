import SwiftUI
import SwiftData

/// Settings, crafted using modern Apple Human Interface Guidelines:
/// - Compact menu pickers (`.pickerStyle(.menu)`) with SF Symbol icons instead of wide segmented rows.
/// - Native Apple Liquid Glass context menus for single-tap options.
/// - Clear iconography and grouped hierarchical sections.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage("appearance") private var appearance: Appearance = .system
    @AppStorage("textSizeOverride") private var textSizeOverride: TextSizeOverride = .system
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
            displayAndReadingSection
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

    // MARK: - Display & Reading (Menu Pickers)

    @ViewBuilder
    private var displayAndReadingSection: some View {
        Section {
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

            Picker(selection: $textSizeOverride) {
                ForEach(TextSizeOverride.allCases) { size in
                    Label(size.label, systemImage: icon(for: size))
                        .tag(size)
                }
            } label: {
                Label("Text Size", systemImage: "textformat.size")
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Text Size")
        } header: {
            Text("Display & Reading")
        } footer: {
            Text("System follows your iOS Settings text size.")
        }
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

            if let updateStatus {
                Text(updateStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Content Updates")
        } footer: {
            Text("New editions published to this feed appear in the app automatically.")
        }
    }

    // MARK: - Automatic Sync Section

    @ViewBuilder
    private var automaticSyncSection: some View {
        Section {
            if isTokenConfigured {
                HStack {
                    Label("GitHub Token Configured", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    Button("Change") {
                        isTokenConfigured = false
                        tokenInput = ""
                    }
                    .font(.footnote)
                }
            } else {
                HStack {
                    SecureField("GitHub Token (gist scope)", text: $tokenInput)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if !tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Save") {
                            saveToken()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        Button("Paste") {
                            if let string = UIPasteboard.general.string {
                                tokenInput = string
                                saveToken()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            if let gistID = syncService.gistID, !gistID.isEmpty {
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

    private func icon(for textSize: TextSizeOverride) -> String {
        switch textSize {
        case .system: return "textformat"
        case .large: return "textformat.size.larger"
        case .extraLarge: return "text.magnifyingglass"
        case .accessibility: return "accessibility"
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
