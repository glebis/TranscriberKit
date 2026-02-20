import Foundation
import MCP
import TranscriberCore

/// Buffers transcription events between start and stop for MCP request/response model.
/// Supports progress notifications and resource subscriptions for real-time updates.
actor SessionManager {
    private let engine = TranscriptionEngine()
    private var eventCollector: Task<Void, Never>?

    /// Accumulated transcript text from the current/last session.
    private(set) var liveTranscript: String = ""

    /// URIs that clients have subscribed to.
    private var subscribedURIs: Set<String> = []

    /// Progress token from the current tool call (if client provided one).
    private var progressToken: ProgressToken?

    /// Reference to the MCP server for sending notifications.
    private weak var server: Server?

    func setServer(_ server: Server) {
        self.server = server
    }

    func setProgressToken(_ token: ProgressToken?) {
        self.progressToken = token
    }

    func subscribe(uri: String) {
        subscribedURIs.insert(uri)
    }

    func unsubscribe(uri: String) {
        subscribedURIs.remove(uri)
    }

    func isSubscribed(uri: String) -> Bool {
        subscribedURIs.contains(uri)
    }

    func startLive(options: TranscriptionOptions) async throws -> String {
        liveTranscript = ""

        // Set up the unified event observer
        await engine.setOnEvent { [weak self] event in
            await self?.handleEvent(event)
        }

        let stream = try await engine.startLive(options: options)

        // Collect events in background
        eventCollector = Task {
            for await event in stream {
                if case .final_(let r) = event {
                    self.liveTranscript += r.text
                }
            }
        }

        return "Recording started. Use stop_transcription to get the transcript."
    }

    func stop() async throws -> TranscriptionResult {
        try await engine.stop()
        await eventCollector?.value
        eventCollector = nil
        progressToken = nil
        await engine.setOnEvent(nil)
        return await engine.buildResult()
    }

    func transcribeFile(url: URL, options: TranscriptionOptions) async throws
        -> TranscriptionResult
    {
        liveTranscript = ""

        await engine.setOnEvent { [weak self] event in
            await self?.handleEvent(event)
        }

        let stream = try await engine.startFile(url: url, options: options)

        for await event in stream {
            if case .final_(let r) = event {
                liveTranscript += r.text
            }
        }

        await engine.setOnEvent(nil)
        return await engine.buildResult()
    }

    func getStatus() async -> String {
        let state = await engine.getStatus()
        switch state {
        case .idle: return "idle"
        case .recording: return "recording"
        case .transcribing: return "transcribing"
        case .processing: return "processing"
        }
    }

    // MARK: - Private

    /// Unified event handler: sends progress notifications and resource update notifications.
    private func handleEvent(_ event: TranscriptionEvent) async {
        guard let message = event.progressMessage else { return }

        // Send progress notification if token is set
        if let token = progressToken, let server {
            let notification = ProgressNotification.message(
                .init(progressToken: token, progress: 0, message: message)
            )
            try? await server.notify(notification)
        }

        // Send resource update notification if subscribed
        if subscribedURIs.contains("transcript://live"), let server {
            try? await server.notify(
                ResourceUpdatedNotification.message(.init(uri: "transcript://live"))
            )
        }
    }
}
