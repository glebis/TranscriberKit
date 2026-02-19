import Foundation
import TranscriberCore

/// Buffers transcription events between start and stop for MCP request/response model.
actor SessionManager {
    private let engine = TranscriptionEngine()
    private var eventCollector: Task<Void, Never>?

    func startLive(options: TranscriptionOptions) async throws -> String {
        let stream = try await engine.startLive(options: options)

        // Collect events in background
        eventCollector = Task {
            for await _ in stream {}
        }

        return "Recording started. Use stop_transcription to get the transcript."
    }

    func stop() async throws -> TranscriptionResult {
        try await engine.stop()
        // Wait for event collection to finish
        await eventCollector?.value
        eventCollector = nil
        return await engine.buildResult()
    }

    func transcribeFile(url: URL, options: TranscriptionOptions) async throws
        -> TranscriptionResult
    {
        let stream = try await engine.startFile(url: url, options: options)

        // Consume all events
        for await _ in stream {}

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
}
