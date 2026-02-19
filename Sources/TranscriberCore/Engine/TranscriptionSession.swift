@preconcurrency import AVFoundation
import Foundation
import Speech

/// Wires an AudioCaptureSource through SpeechAnalyzer to produce TranscriptionEvents.
/// This is the core transcription pipeline, consumed by TranscriptionEngine.
public actor TranscriptionSession {
    private let source: AudioCaptureSource
    private let options: TranscriptionOptions
    private let converter = BufferConverter()

    private var analyzerTask: Task<Void, any Error>?
    private var feedTask: Task<Void, any Error>?

    public enum State: Sendable {
        case idle
        case running
        case stopping
        case finished
    }

    private(set) public var state: State = .idle

    public init(source: AudioCaptureSource, options: TranscriptionOptions) {
        self.source = source
        self.options = options
    }

    /// Start the session. Returns a stream of TranscriptionEvents.
    @available(macOS 26, *)
    public func start() -> AsyncStream<TranscriptionEvent> {
        guard state == .idle else {
            return AsyncStream { $0.finish() }
        }
        state = .running

        let (stream, continuation) = AsyncStream<TranscriptionEvent>.makeStream()
        let opts = options
        let src = source
        let conv = converter

        // Launch the pipeline
        analyzerTask = Task {
            do {
                let locale = opts.locale
                let transcriber = SpeechTranscriber(
                    locale: locale,
                    transcriptionOptions: [],
                    reportingOptions: opts.enableVolatileResults
                        ? [.volatileResults] : [],
                    attributeOptions: [.audioTimeRange]
                )

                let analyzer = SpeechAnalyzer(modules: [transcriber])
                let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
                    compatibleWith: [transcriber]
                )

                guard let analyzerFormat else {
                    continuation.yield(.ended(.error("No compatible audio format")))
                    continuation.finish()
                    return
                }

                // Feed audio from source to analyzer via AsyncStream
                let (inputStream, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()

                // Start feeding audio buffers
                let feedingTask = Task {
                    do {
                        for try await buffer in src.start() {
                            let converted = try conv.convertBuffer(buffer, to: analyzerFormat)
                            inputContinuation.yield(AnalyzerInput(buffer: converted))
                        }
                        inputContinuation.finish()
                    } catch {
                        inputContinuation.finish()
                        throw error
                    }
                }

                // Start receiving transcription results
                let resultsTask = Task {
                    for try await result in transcriber.results {
                        if result.isFinal {
                            continuation.yield(.final_(.init(
                                text: String(result.text.characters),
                                startTime: 0,
                                endTime: 0
                            )))
                        } else {
                            continuation.yield(.volatile(.init(
                                text: String(result.text.characters),
                                timestamp: 0
                            )))
                        }
                    }
                }

                // Start the analyzer
                try await analyzer.start(inputSequence: inputStream)

                // Wait for feed to complete
                try await feedingTask.value

                // Finalize
                try await analyzer.finalizeAndFinishThroughEndOfInput()
                resultsTask.cancel()

                continuation.yield(.ended(.completed))
                continuation.finish()

            } catch is CancellationError {
                continuation.yield(.ended(.cancelled))
                continuation.finish()
            } catch {
                continuation.yield(.ended(.error(error.localizedDescription)))
                continuation.finish()
            }
        }

        return stream
    }

    /// Stop the session.
    public func stop() async {
        guard state == .running else { return }
        state = .stopping
        await source.stop()
        analyzerTask?.cancel()
        feedTask?.cancel()
        state = .finished
    }
}

/// Lightweight session for testing without Speech framework.
/// Produces events from a MockAudioSource by simulating the pipeline.
public actor MockTranscriptionSession {
    private let source: AudioCaptureSource
    private let options: TranscriptionOptions
    private var state: TranscriptionSession.State = .idle

    public init(source: AudioCaptureSource, options: TranscriptionOptions = .init()) {
        self.source = source
        self.options = options
    }

    public func start() -> AsyncStream<TranscriptionEvent> {
        guard state == .idle else {
            return AsyncStream { $0.finish() }
        }
        state = .running

        let (stream, continuation) = AsyncStream<TranscriptionEvent>.makeStream()
        let src = source
        let opts = options

        Task {
            do {
                var segmentIndex = 0
                for try await _ in src.start() {
                    if opts.enableVolatileResults {
                        continuation.yield(.volatile(.init(
                            text: "partial \(segmentIndex)",
                            timestamp: Double(segmentIndex)
                        )))
                    }
                    continuation.yield(.final_(.init(
                        text: "segment \(segmentIndex)",
                        startTime: Double(segmentIndex),
                        endTime: Double(segmentIndex + 1)
                    )))
                    segmentIndex += 1
                }
                continuation.yield(.ended(.completed))
                continuation.finish()
            } catch {
                continuation.yield(.ended(.error(error.localizedDescription)))
                continuation.finish()
            }
        }

        return stream
    }

    public func stop() async {
        state = .stopping
        await source.stop()
        state = .finished
    }

    public func getState() -> TranscriptionSession.State { state }
}
