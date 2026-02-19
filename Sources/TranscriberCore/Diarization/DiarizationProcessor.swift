@preconcurrency import AVFoundation
import FluidAudio
import Foundation

/// Wraps FluidAudio's DiarizerManager for post-hoc speaker diarization.
/// Accumulates audio at 16kHz mono, processes once after recording stops.
public actor DiarizationProcessor {
    private var audioBuffer: [Float] = []
    private let targetSampleRate: Float = 16000.0
    private var diarizer: DiarizerManager?
    private var isInitialized = false
    private let converter = BufferConverter()

    public init() {}

    /// Initialize FluidAudio diarizer and download models.
    public func initialize() async throws {
        let config = DiarizerConfig()
        diarizer = DiarizerManager(config: config)

        let models = try await DiarizerModels.downloadIfNeeded()
        diarizer?.initialize(models: models)

        isInitialized = true
    }

    /// Accumulate audio from a PCM buffer (converts to 16kHz mono Float).
    public func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let samples = convertToMono16kHz(buffer) else { return }
        audioBuffer.append(contentsOf: samples)
    }

    /// Run diarization on accumulated audio. Returns speaker segments.
    public func finalize() throws -> [SpeakerSegment] {
        guard isInitialized, let diarizer, !audioBuffer.isEmpty else {
            return []
        }

        let result = try diarizer.performCompleteDiarization(
            audioBuffer,
            sampleRate: Int(targetSampleRate)
        )

        let segments = result.segments.map { segment in
            SpeakerSegment(
                speakerId: Int(segment.speakerId) ?? 0,
                startTime: TimeInterval(segment.startTimeSeconds),
                endTime: TimeInterval(segment.endTimeSeconds)
            )
        }

        audioBuffer.removeAll()
        return segments
    }

    /// Current accumulated audio duration in seconds.
    public var accumulatedDuration: TimeInterval {
        TimeInterval(audioBuffer.count) / TimeInterval(targetSampleRate)
    }

    /// Number of accumulated samples.
    public var sampleCount: Int {
        audioBuffer.count
    }

    /// Reset accumulated audio without processing.
    public func reset() {
        audioBuffer.removeAll()
    }

    // MARK: - Private

    private func convertToMono16kHz(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channelData = buffer.floatChannelData else { return nil }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameCount > 0 else { return nil }

        if buffer.format.sampleRate != Double(targetSampleRate) {
            // Downsample
            let ratio = buffer.format.sampleRate / Double(targetSampleRate)
            let targetFrameCount = Int(Double(frameCount) / ratio)
            var samples = [Float](repeating: 0, count: targetFrameCount)

            for frame in 0..<targetFrameCount {
                let sourceFrame = Int(Double(frame) * ratio)
                if sourceFrame < frameCount {
                    var sample: Float = 0
                    for ch in 0..<channelCount {
                        sample += channelData[ch][sourceFrame]
                    }
                    samples[frame] = sample / Float(channelCount)
                }
            }
            return samples
        } else {
            // Already 16kHz, just mix to mono
            var samples = [Float](repeating: 0, count: frameCount)
            for frame in 0..<frameCount {
                var sample: Float = 0
                for ch in 0..<channelCount {
                    sample += channelData[ch][frame]
                }
                samples[frame] = sample / Float(channelCount)
            }
            return samples
        }
    }
}
