@preconcurrency import AVFoundation
import Foundation

/// Reads an audio file in chunks, yielding AVAudioPCMBuffer via AsyncThrowingStream.
public final class FileCaptureSource: AudioCaptureSource, @unchecked Sendable {
    private let fileURL: URL
    private let chunkFrames: AVAudioFrameCount
    private var stopped = false

    public init(url: URL, chunkFrames: AVAudioFrameCount = 4800) {
        self.fileURL = url
        self.chunkFrames = chunkFrames
    }

    public var format: AVAudioFormat {
        get async throws {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw TranscriberError.audioFileNotFound(fileURL.path)
            }
            let file = try AVAudioFile(forReading: fileURL)
            return file.processingFormat
        }
    }

    public func start() -> AsyncThrowingStream<AVAudioPCMBuffer, Error> {
        let url = fileURL
        let chunkSize = chunkFrames

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard FileManager.default.fileExists(atPath: url.path) else {
                        continuation.finish(throwing: TranscriberError.audioFileNotFound(url.path))
                        return
                    }

                    let file = try AVAudioFile(forReading: url)
                    let format = file.processingFormat
                    let totalFrames = AVAudioFrameCount(file.length)
                    var framesRead: AVAudioFrameCount = 0

                    while framesRead < totalFrames && !self.stopped {
                        let remaining = totalFrames - framesRead
                        let framesToRead = min(chunkSize, remaining)

                        guard let buffer = AVAudioPCMBuffer(
                            pcmFormat: format, frameCapacity: framesToRead
                        ) else {
                            continuation.finish(
                                throwing: TranscriberError.bufferConversionFailed(
                                    "Failed to create buffer"))
                            return
                        }

                        try file.read(into: buffer, frameCount: framesToRead)
                        framesRead += buffer.frameLength
                        continuation.yield(buffer)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func stop() async {
        stopped = true
    }
}
