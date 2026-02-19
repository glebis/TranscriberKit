import AVFoundation
import Foundation
import Testing
@testable import TranscriberCore

@Suite("DiarizationProcessor")
struct DiarizationProcessorTests {

    private func makeBuffer(
        sampleRate: Double = 16000,
        channels: UInt32 = 1,
        frameCount: AVAudioFrameCount = 1600
    ) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        if let data = buffer.floatChannelData {
            for ch in 0..<Int(channels) {
                for i in 0..<Int(frameCount) {
                    data[ch][i] = sinf(Float(i) * 0.01)
                }
            }
        }
        return buffer
    }

    @Test func accumulatesAudioSamples() async throws {
        let processor = DiarizationProcessor()

        // Feed 1 second of 16kHz mono audio
        let buffer = makeBuffer(sampleRate: 16000, frameCount: 16000)
        await processor.processBuffer(buffer)

        let count = await processor.sampleCount
        #expect(count == 16000)

        let duration = await processor.accumulatedDuration
        #expect(abs(duration - 1.0) < 0.01)
    }

    @Test func downsamples48kTo16k() async throws {
        let processor = DiarizationProcessor()

        // Feed 1 second of 48kHz audio (48000 frames)
        let buffer = makeBuffer(sampleRate: 48000, frameCount: 48000)
        await processor.processBuffer(buffer)

        // Should be downsampled to ~16000 samples
        let count = await processor.sampleCount
        #expect(count == 16000)
    }

    @Test func mixesStereoToMono() async throws {
        let processor = DiarizationProcessor()

        // Feed stereo 16kHz
        let buffer = makeBuffer(sampleRate: 16000, channels: 2, frameCount: 1600)
        await processor.processBuffer(buffer)

        let count = await processor.sampleCount
        #expect(count == 1600)
    }

    @Test func emptyBufferProducesNoSamples() async throws {
        let processor = DiarizationProcessor()

        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 0)!
        buffer.frameLength = 0
        await processor.processBuffer(buffer)

        let count = await processor.sampleCount
        #expect(count == 0)
    }

    @Test func resetClearsBuffer() async throws {
        let processor = DiarizationProcessor()

        let buffer = makeBuffer(sampleRate: 16000, frameCount: 16000)
        await processor.processBuffer(buffer)

        let countBefore = await processor.sampleCount
        #expect(countBefore == 16000)

        await processor.reset()

        let countAfter = await processor.sampleCount
        #expect(countAfter == 0)
    }

    @Test func finalizeWithoutInitReturnsEmpty() async throws {
        let processor = DiarizationProcessor()

        let buffer = makeBuffer(sampleRate: 16000, frameCount: 16000)
        await processor.processBuffer(buffer)

        // Not initialized, should return empty
        let segments = try await processor.finalize()
        #expect(segments.isEmpty)
    }

    @Test func accumulatesMultipleBuffers() async throws {
        let processor = DiarizationProcessor()

        for _ in 0..<5 {
            let buffer = makeBuffer(sampleRate: 16000, frameCount: 1600)
            await processor.processBuffer(buffer)
        }

        let count = await processor.sampleCount
        #expect(count == 8000)  // 5 * 1600

        let duration = await processor.accumulatedDuration
        #expect(abs(duration - 0.5) < 0.01)  // 8000 / 16000 = 0.5s
    }
}
