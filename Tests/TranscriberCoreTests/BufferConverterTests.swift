import AVFoundation
import Foundation
import Testing
@testable import TranscriberCore

@Suite("BufferConverter")
struct BufferConverterTests {

    @Test func sameFormatReturnsOriginalBuffer() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1600)!
        buffer.frameLength = 1600
        // Fill with test data
        if let data = buffer.floatChannelData {
            for i in 0..<1600 { data[0][i] = Float(i) / 1600.0 }
        }

        let converter = BufferConverter()
        let result = try converter.convertBuffer(buffer, to: format)
        // Same format should return the same buffer instance
        #expect(result === buffer)
    }

    @Test func convertsMonoSampleRate() throws {
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 4800)!
        buffer.frameLength = 4800
        if let data = buffer.floatChannelData {
            for i in 0..<4800 { data[0][i] = sinf(Float(i) * 0.1) }
        }

        let converter = BufferConverter()
        let result = try converter.convertBuffer(buffer, to: outputFormat)
        // 48kHz -> 16kHz = 1/3 samples
        #expect(result.frameLength == 1600)
        #expect(result.format.sampleRate == 16000)
    }

    @Test func emptyBufferWithSameFormatReturnsIdentity() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 0)!
        buffer.frameLength = 0

        let converter = BufferConverter()
        let result = try converter.convertBuffer(buffer, to: format)
        #expect(result === buffer)
    }

    @Test func emptyBufferWithDifferentFormatThrows() throws {
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 0)!
        buffer.frameLength = 0

        let converter = BufferConverter()
        #expect(throws: BufferConverter.Error.self) {
            _ = try converter.convertBuffer(buffer, to: outputFormat)
        }
    }

    @Test func reusesConverterForSameFormat() throws {
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!

        let converter = BufferConverter()

        for _ in 0..<3 {
            let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 4800)!
            buffer.frameLength = 4800
            if let data = buffer.floatChannelData {
                for i in 0..<4800 { data[0][i] = Float.random(in: -1...1) }
            }
            let result = try converter.convertBuffer(buffer, to: outputFormat)
            #expect(result.format.sampleRate == 16000)
        }
    }
}
