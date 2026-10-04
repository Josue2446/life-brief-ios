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
    @AppStorage("feedURLString") private var feedURLString = "https://example.com/life-brief/feed.json"

    @State private var updateStatus: String?
    @State private var isChecking = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Appearance")
            }

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

            Section("Feedback") {
                Toggle("Haptic Feedback", isOn: $hapticsEnabled)
            }

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

            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Designed for", value: "iOS 26 and later")
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
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
                BriefStore.importFeed(dtos, into: context)
                updateStatus = "Updated just now."
            } catch {
                updateStatus = error.localizedDescription
            }
            isChecking = false
        }
    }
}
