import SwiftUI
import SwiftData

/// Settings, built only from standard iOS controls per the
/// Human Interface Guidelines: segmented pickers, toggles, text fields.
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
            appearanceSection
            readingSection
            feedbackToggleSection
            contentUpdatesSection
            automaticSyncSection
            feedbackStorageSection
            aboutSection
        }
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

    @ViewBuilder
    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Appearance", selection: $appearance) {
                ForEach(Appearance.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Appearance")
        }
    }

    @ViewBuilder
    private var readingSection: some View {
        Section {
            Picker("Text Size", selection: $textSizeOverride) {
                ForEach(TextSizeOverride.allCases) { size in
                    Text(size.label).tag(size)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Reading")
        } footer: {
            Text("System follows your iOS Settings text size.")
        }
    }

    @ViewBuilder
    private var feedbackToggleSection: some View {
        Section("Feedback") {
            Toggle("Haptic Feedback", isOn: $hapticsEnabled)
        }
    }

    @ViewBuilder
    private var contentUpdatesSection: some View {
        Section {
            TextField("Feed URL", text: $feedURLString)
#if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
#endif
            Button {
                checkForUpdates()
            } label: {
                if isChecking {
                    ProgressView()
                } else {
                    Text("Check for Updates")
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

    @ViewBuilder
    private var automaticSyncSection: some View {
        Section {
            if isTokenConfigured {
                HStack {
                    Label("GitHub Token Configured", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.tint)
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
                    if syncService.isSyncing {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                    }
                    Text(syncService.isSyncing ? "Syncing to Private Gist..." : "Sync Feedback Now")
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

    @ViewBuilder
    private var feedbackStorageSection: some View {
        Section {
            LabeledContent("Saved Responses", value: "\(feedbackCount)")

            if feedbackCount > 0 {
                ShareLink(item: FeedbackStore.feedbackFileURL) {
                    Label("Export feedback.json", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    showingClearFeedbackAlert = true
                } label: {
                    Label("Clear Stored Feedback", systemImage: "trash")
                }
            }
        } header: {
            Text("Feedback Storage")
        } footer: {
            Text("Post reactions and comments are stored locally in feedback.json.")
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Designed for", value: "iOS 26 and later")
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
