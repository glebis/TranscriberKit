@preconcurrency import AVFoundation
import Foundation

/// Central actor coordinating transcription sessions.
/// Enforces single-session semantics and manages the full lifecycle.
/// On macOS 26+, uses the real SpeechAnalyzer pipeline. Falls back to mock otherwise.
public actor TranscriptionEngine {
    public enum State: Sendable, Equatable {
        case idle
        case recording
        case transcribing
        case processing
    }

    private(set) public var state: State = .idle

    // We store both session types since they're different actors.
    // Only one is active at a time.
    private var realSession: TranscriptionSession?
    private var mockSession: MockTranscriptionSession?

    private var diarizationProcessor: DiarizationProcessor?
    private var collectedEvents: [TranscriptionEvent] = []

    /// Called for each event as it arrives. Set via `setOnEvent`.
    private var onEvent: (@Sendable (TranscriptionEvent) async -> Void)?

    /// When true, always use MockTranscriptionSession (for unit tests).
    public var forceMock: Bool = false

    public init() {}

    /// Set forceMock from outside the actor (for tests).
    public func setForceMock(_ value: Bool) {
        forceMock = value
    }

    /// Set a callback invoked for each transcription event as it arrives.
    public func setOnEvent(_ handler: (@Sendable (TranscriptionEvent) async -> Void)?) {
        onEvent = handler
    }

    /// Start a live transcription from a mic source.
    public func startLive(options: TranscriptionOptions = .init()) throws
        -> AsyncStream<TranscriptionEvent>
    {
        guard state == .idle else {
            throw TranscriberError.sessionAlreadyActive
        }
        state = .recording

        let source = MicrophoneCaptureSource()
        return startSession(source: source, options: options)
    }

    /// Start a transcription from an audio file.
    public func startFile(url: URL, options: TranscriptionOptions = .init()) throws
        -> AsyncStream<TranscriptionEvent>
    {
        guard state == .idle else {
            throw TranscriberError.sessionAlreadyActive
        }
        state = .transcribing

        let source = FileCaptureSource(url: url)
        return startSession(source: source, options: options)
    }

    /// Start a transcription from any AudioCaptureSource (useful for testing).
    public func startWithSource(
        _ source: AudioCaptureSource,
        options: TranscriptionOptions = .init()
    ) throws -> AsyncStream<TranscriptionEvent> {
        guard state == .idle else {
            throw TranscriberError.sessionAlreadyActive
        }
        state = .recording
        return startSession(source: source, options: options)
    }

    /// Stop the active session.
    public func stop() async throws {
        guard state == .recording || state == .transcribing else {
            throw TranscriberError.noActiveSession
        }
        state = .processing
        if let realSession {
            await realSession.stop()
            self.realSession = nil
        }
        if let mockSession {
            await mockSession.stop()
            self.mockSession = nil
        }
        state = .idle
    }

    /// Get the current engine state.
    public func getStatus() -> State {
        state
    }

    /// Get all collected events from the current/last session.
    public func getCollectedEvents() -> [TranscriptionEvent] {
        collectedEvents
    }

    /// Build a TranscriptionResult from collected events.
    public func buildResult(locale: String = "en-US") -> TranscriptionResult {
        var text = ""
        var segments: [TranscriptionResult.Segment] = []
        var speakerSegments: [SpeakerSegment] = []
        var duration: TimeInterval = 0

        for event in collectedEvents {
            switch event {
            case .final_(let result):
                text += result.text
                segments.append(.init(
                    text: result.text,
                    startTime: result.startTime,
                    endTime: result.endTime
                ))
                duration = max(duration, result.endTime)
            case .diarization(let segs):
                speakerSegments = segs
            case .volatile, .ended:
                break
            }
        }

        return TranscriptionResult(
            text: text,
            segments: segments,
            speakerSegments: speakerSegments,
            duration: duration,
            locale: locale
        )
    }

    /// Reset the engine, clearing collected events.
    public func reset() {
        collectedEvents.removeAll()
        realSession = nil
        mockSession = nil
        state = .idle
    }

    // MARK: - Private

    private func startSession(
        source: AudioCaptureSource,
        options: TranscriptionOptions
    ) -> AsyncStream<TranscriptionEvent> {
        collectedEvents.removeAll()

        // Use real SpeechAnalyzer session on macOS 26+, mock otherwise
        if #available(macOS 26, *), !forceMock {
            return startRealSession(source: source, options: options)
        } else {
            return startMockSession(source: source, options: options)
        }
    }

    @available(macOS 26, *)
    private func startRealSession(
        source: AudioCaptureSource,
        options: TranscriptionOptions
    ) -> AsyncStream<TranscriptionEvent> {
        let session = TranscriptionSession(source: source, options: options)
        realSession = session

        let innerStream = AsyncStream<TranscriptionEvent> { continuation in
            Task { [weak self] in
                let events = await session.start()
                for await event in events {
                    await self?.collectEvent(event)
                    continuation.yield(event)
                }
                await self?.sessionDidEnd()
                continuation.finish()
            }
        }

        return innerStream
    }

    private func startMockSession(
        source: AudioCaptureSource,
        options: TranscriptionOptions
    ) -> AsyncStream<TranscriptionEvent> {
        let session = MockTranscriptionSession(source: source, options: options)
        mockSession = session

        let innerStream = AsyncStream<TranscriptionEvent> { continuation in
            Task { [weak self] in
                let events = await session.start()
                for await event in events {
                    await self?.collectEvent(event)
                    continuation.yield(event)
                }
                await self?.sessionDidEnd()
                continuation.finish()
            }
        }

        return innerStream
    }

    private func collectEvent(_ event: TranscriptionEvent) async {
        collectedEvents.append(event)
        await onEvent?(event)
    }

    private func sessionDidEnd() {
        if state != .idle {
            state = .idle
        }
        realSession = nil
        mockSession = nil
    }
}
