@preconcurrency import AVFoundation
import Foundation

/// Captures live audio from the system microphone via AVAudioEngine.
/// Requires com.apple.security.device.audio-input entitlement.
public final class MicrophoneCaptureSource: AudioCaptureSource, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let bufferSize: AVAudioFrameCount
    private var continuation: AsyncThrowingStream<AVAudioPCMBuffer, Error>.Continuation?

    public init(bufferSize: AVAudioFrameCount = 4096) {
        self.bufferSize = bufferSize
    }

    public var format: AVAudioFormat {
        get async throws {
            engine.inputNode.outputFormat(forBus: 0)
        }
    }

    public func start() -> AsyncThrowingStream<AVAudioPCMBuffer, Error> {
        let eng = engine
        let bs = bufferSize

        return AsyncThrowingStream { continuation in
            self.continuation = continuation

            let inputNode = eng.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: bs, format: inputFormat) { buffer, _ in
                continuation.yield(buffer)
            }

            eng.prepare()
            do {
                try eng.start()
            } catch {
                continuation.finish(throwing: error)
            }

            continuation.onTermination = { _ in
                inputNode.removeTap(onBus: 0)
                if eng.isRunning {
                    eng.stop()
                }
            }
        }
    }

    public func stop() async {
        continuation?.finish()
        continuation = nil
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning {
            engine.stop()
        }
    }
}
