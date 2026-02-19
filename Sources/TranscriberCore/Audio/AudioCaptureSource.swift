@preconcurrency import AVFoundation
import Foundation

/// Protocol for audio sources that produce PCM buffers.
/// Implementations: MicrophoneCaptureSource (live), FileCaptureSource (file), MockAudioSource (test)
public protocol AudioCaptureSource: Sendable {
    /// The native audio format of this source.
    var format: AVAudioFormat { get async throws }

    /// Start producing audio buffers.
    func start() -> AsyncThrowingStream<AVAudioPCMBuffer, Error>

    /// Stop producing audio.
    func stop() async
}
