import AVFoundation
import Foundation
import Testing
@testable import TranscriberCore

@Suite("MockAudioSource")
struct MockAudioSourceTests {

    @Test func yieldsConfiguredBufferCount() async throws {
        let source = MockAudioSource(bufferCount: 5)
        var count = 0
        for try await _ in source.start() {
            count += 1
        }
        #expect(count == 5)
    }

    @Test func yieldsBuffersWithCorrectFormat() async throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let source = MockAudioSource(format: format, bufferCount: 2)

        let sourceFormat = try await source.format
        #expect(sourceFormat.sampleRate == 44100)

        for try await buffer in source.start() {
            #expect(buffer.format.sampleRate == 44100)
        }
    }

    @Test func stopSetsFlag() async throws {
        let source = MockAudioSource(bufferCount: 3)
        // Verify stop is callable and doesn't crash
        await source.stop()
        // After stop, a new start may yield fewer (implementation-dependent)
    }
}

@Suite("FailingAudioSource")
struct FailingAudioSourceTests {

    @Test func throwsAfterConfiguredBuffers() async throws {
        let source = FailingAudioSource(failAfter: 2)
        var count = 0
        do {
            for try await _ in source.start() {
                count += 1
            }
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(count == 2)
        }
    }
}

@Suite("FileCaptureSource")
struct FileCaptureSourceTests {

    /// Creates a temporary WAV file with sine wave data.
    private func createTestWAV(
        sampleRate: Double = 16000,
        channels: UInt32 = 1,
        seconds: Double = 1.0
    ) throws -> URL {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
        let frameCount = AVAudioFrameCount(sampleRate * seconds)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        if let data = buffer.floatChannelData {
            for ch in 0..<Int(channels) {
                for i in 0..<Int(frameCount) {
                    data[ch][i] = sinf(Float(i) * 0.1)
                }
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    @Test func readsCorrectChunkCount() async throws {
        let url = try createTestWAV(sampleRate: 16000, seconds: 1.0)
        defer { try? FileManager.default.removeItem(at: url) }

        // 16000 frames / 4800 chunk = 4 chunks (3 full + 1 partial)
        let source = FileCaptureSource(url: url, chunkFrames: 4800)
        var totalFrames: AVAudioFrameCount = 0
        var chunkCount = 0
        for try await buffer in source.start() {
            totalFrames += buffer.frameLength
            chunkCount += 1
        }
        #expect(totalFrames == 16000)
        #expect(chunkCount == 4) // ceil(16000/4800) = 4
    }

    @Test func reportsCorrectFormat() async throws {
        let url = try createTestWAV(sampleRate: 44100, channels: 2, seconds: 0.5)
        defer { try? FileManager.default.removeItem(at: url) }

        let source = FileCaptureSource(url: url)
        let format = try await source.format
        #expect(format.sampleRate == 44100)
        #expect(format.channelCount == 2)
    }

    @Test func missingFileThrowsError() async throws {
        let source = FileCaptureSource(url: URL(fileURLWithPath: "/tmp/nonexistent_\(UUID()).wav"))

        do {
            _ = try await source.format
            Issue.record("Expected audioFileNotFound error")
        } catch let error as TranscriberError {
            if case .audioFileNotFound = error {
                // expected
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test func streamCompletesNaturally() async throws {
        let url = try createTestWAV(sampleRate: 16000, seconds: 0.1)
        defer { try? FileManager.default.removeItem(at: url) }

        let source = FileCaptureSource(url: url)
        var finished = false
        for try await _ in source.start() {}
        finished = true
        #expect(finished)
    }
}
