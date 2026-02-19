@preconcurrency import AVFoundation
import Foundation

/// Test double: yields pre-configured buffers, then completes.
public final class MockAudioSource: AudioCaptureSource, @unchecked Sendable {
    private let mockFormat: AVAudioFormat
    private let bufferCount: Int
    private let framesPerBuffer: AVAudioFrameCount
    private var stopped = false

    public init(
        format: AVAudioFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!,
        bufferCount: Int = 3,
        framesPerBuffer: AVAudioFrameCount = 1600
    ) {
        self.mockFormat = format
        self.bufferCount = bufferCount
        self.framesPerBuffer = framesPerBuffer
    }

    public var format: AVAudioFormat {
        get async throws { mockFormat }
    }

    public func start() -> AsyncThrowingStream<AVAudioPCMBuffer, Error> {
        let fmt = mockFormat
        let count = bufferCount
        let frames = framesPerBuffer

        return AsyncThrowingStream { continuation in
            // Generate buffers inside the closure to avoid Sendable issues
            for i in 0..<count {
                guard !self.stopped else { break }
                let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames)!
                buf.frameLength = frames
                if let data = buf.floatChannelData {
                    for j in 0..<Int(frames) {
                        data[0][j] = sinf(Float(i * Int(frames) + j) * 0.01)
                    }
                }
                continuation.yield(buf)
            }
            continuation.finish()
        }
    }

    public func stop() async {
        stopped = true
    }
}

/// A mock source that throws an error after yielding some buffers.
public final class FailingAudioSource: AudioCaptureSource, @unchecked Sendable {
    private let mockFormat: AVAudioFormat
    private let failAfter: Int
    private let error: any Error

    public init(
        format: AVAudioFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!,
        failAfter: Int = 1,
        error: any Error = TranscriberError.audioFormatInvalid
    ) {
        self.mockFormat = format
        self.failAfter = failAfter
        self.error = error
    }

    public var format: AVAudioFormat {
        get async throws { mockFormat }
    }

    public func start() -> AsyncThrowingStream<AVAudioPCMBuffer, Error> {
        let failAt = failAfter
        let err = error
        let fmt = mockFormat

        return AsyncThrowingStream { continuation in
            for i in 0..<failAt {
                let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 1600)!
                buf.frameLength = 1600
                if let data = buf.floatChannelData {
                    for j in 0..<1600 {
                        data[0][j] = Float(i) * 0.001 + Float(j) * 0.0001
                    }
                }
                continuation.yield(buf)
            }
            continuation.finish(throwing: err)
        }
    }

    public func stop() async {}
}
