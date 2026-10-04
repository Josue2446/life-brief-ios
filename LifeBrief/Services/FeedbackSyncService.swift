import Foundation
import Observation

enum FeedbackSyncError: LocalizedError {
    case noToken
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case unauthorized
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "No GitHub personal access token configured."
        case .invalidResponse:
            return "Received an invalid response from GitHub."
        case .httpError(let code, let message):
            return "GitHub API error (\(code)): \(message)"
        case .unauthorized:
            return "Invalid or expired GitHub token with gist scope required."
        case .encodingFailed:
            return "Failed to encode feedback data."
        }
    }
}

@Observable
@MainActor
final class FeedbackSyncService {
    static let shared = FeedbackSyncService()

    private let userDefaultsKeyGistID = "feedbackGistID"
    private let userDefaultsKeyLastSync = "feedbackLastSyncTimestamp"

    var isSyncing: Bool = false
    var lastSyncDate: Date?
    var lastSyncStatus: String?
    var lastErrorMessage: String?

    private var debounceTask: Task<Void, Never>?

    var gistID: String? {
        get { UserDefaults.standard.string(forKey: userDefaultsKeyGistID) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: userDefaultsKeyGistID)
            } else {
                UserDefaults.standard.removeObject(forKey: userDefaultsKeyGistID)
            }
        }
    }

    var hasToken: Bool {
        KeychainHelper.hasToken
    }

    private init() {
        if let timestamp = UserDefaults.standard.object(forKey: userDefaultsKeyLastSync) as? Date {
            self.lastSyncDate = timestamp
            self.lastSyncStatus = "Synced"
        }
    }

    /// Schedules a debounced sync. Rapid successive calls reset the timer.
    func scheduleDebouncedSync(delaySeconds: Double = 2.0) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                try Task.checkCancellation()
                _ = try await self.syncNow()
            } catch is CancellationError {
                // Expected when debouncing
            } catch {
                // Error status is set inside syncNow
            }
        }
    }

    /// Performs immediate sync to the private GitHub Gist.
    @discardableResult
    func syncNow() async throws -> String {
        guard let token = KeychainHelper.loadToken(), !token.isEmpty else {
            let error = FeedbackSyncError.noToken
            self.lastErrorMessage = error.localizedDescription
            throw error
        }

        guard !isSyncing else {
            return gistID ?? ""
        }

        isSyncing = true
        lastErrorMessage = nil

        defer {
            isSyncing = false
        }

        // 1. Prepare feedback JSON content
        let feed = FeedbackStore.loadFeed()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(feed),
              let jsonString = String(data: data, encoding: .utf8) else {
            let error = FeedbackSyncError.encodingFailed
            self.lastErrorMessage = error.localizedDescription
            throw error
        }

        // 2. Either update existing Gist or create new private Gist
        if let currentGistID = gistID, !currentGistID.isEmpty {
            do {
                try await updateGist(gistID: currentGistID, token: token, content: jsonString)
                recordSuccessfulSync(message: "Synced to private gist")
                return currentGistID
            } catch FeedbackSyncError.httpError(let statusCode, _) where statusCode == 404 {
                // Gist was deleted on GitHub; clear stored ID and recreate below
                self.gistID = nil
            }
        }

        // 3. Create new private Gist (public: false)
        let newGistID = try await createPrivateGist(token: token, content: jsonString)
        self.gistID = newGistID
        recordSuccessfulSync(message: "Created private gist & synced")
        return newGistID
    }

    private func createPrivateGist(token: String, content: String) async throws -> String {
        guard let url = URL(string: "https://api.github.com/gists") else {
            throw FeedbackSyncError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyStandardHeaders(to: &request, token: token)

        let bodyPayload: [String: Any] = [
            "description": "Life Brief User Feedback (Private)",
            "public": false,
            "files": [
                "feedback.json": [
                    "content": content
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: bodyPayload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedbackSyncError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            let error = FeedbackSyncError.unauthorized
            self.lastErrorMessage = error.localizedDescription
            throw error
        }

        guard httpResponse.statusCode == 201 else {
            let message = parseErrorMessage(from: data)
            let error = FeedbackSyncError.httpError(statusCode: httpResponse.statusCode, message: message)
            self.lastErrorMessage = error.localizedDescription
            throw error
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String else {
            throw FeedbackSyncError.invalidResponse
        }

        return id
    }

    private func updateGist(gistID: String, token: String, content: String) async throws {
        guard let url = URL(string: "https://api.github.com/gists/\(gistID)") else {
            throw FeedbackSyncError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        applyStandardHeaders(to: &request, token: token)

        let bodyPayload: [String: Any] = [
            "description": "Life Brief User Feedback (Private)",
            "files": [
                "feedback.json": [
                    "content": content
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: bodyPayload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedbackSyncError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            let error = FeedbackSyncError.unauthorized
            self.lastErrorMessage = error.localizedDescription
            throw error
        }

        guard httpResponse.statusCode == 200 else {
            let message = parseErrorMessage(from: data)
            let error = FeedbackSyncError.httpError(statusCode: httpResponse.statusCode, message: message)
            self.lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    private func applyStandardHeaders(to request: inout URLRequest, token: String) {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("LifeBrief-iOS", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    private func parseErrorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? String {
            return message
        }
        return "Unknown error"
    }

    private func recordSuccessfulSync(message: String) {
        let now = Date()
        self.lastSyncDate = now
        self.lastSyncStatus = message
        self.lastErrorMessage = nil
        UserDefaults.standard.set(now, forKey: userDefaultsKeyLastSync)
    }

    func resetSyncConfiguration() {
        gistID = nil
        lastSyncDate = nil
        lastSyncStatus = nil
        lastErrorMessage = nil
        KeychainHelper.deleteToken()
        UserDefaults.standard.removeObject(forKey: userDefaultsKeyLastSync)
    }
}
