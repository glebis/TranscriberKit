# TranscriberKit

Swift library, CLI tool, and MCP server for on-device speech transcription on macOS. Uses Apple's Speech framework (`SpeechTranscriber` / `SpeechAnalyzer`) for transcription and [FluidAudio](https://github.com/FluidInference/FluidAudio) for speaker diarization. Everything runs locally -- no cloud APIs.

## Architecture

```
TranscriberKit/
  Sources/
    TranscriberCore/     # Library (zero UI dependencies)
      Audio/             # AudioCaptureSource protocol, mic/file/mock sources, BufferConverter
      Engine/            # TranscriptionEngine (actor), TranscriptionSession
      Diarization/       # FluidAudio wrapper, SpeakerSegment
      Model/             # ModelManager, locale/download management
      Formatters/        # JSONL and plain text formatters
      Types/             # TranscriptionEvent, TranscriptionResult, TranscriptionOptions, errors

    TranscriberCLI/      # CLI executable (`transcriber`)
    TranscriberMCP/      # MCP server executable (`transcriber-mcp`)

  Tests/
    TranscriberCoreTests/  # 65 unit tests across 15 suites
```

**Key design decisions:**
- Actor-based concurrency (`TranscriptionEngine`, `TranscriptionSession`, `DiarizationProcessor`, `ModelManager`)
- `AsyncStream<TranscriptionEvent>` as the universal interface between engine and consumers
- Protocol-based audio sources (`AudioCaptureSource`) with `MockAudioSource` for testing
- Post-hoc diarization (accumulate audio, run FluidAudio once after stop)
- MCP disables volatile results (request/response model); CLI enables them for real-time feedback

## Requirements

- macOS 15+ (macOS 26+ for Speech framework features)
- Swift 6.0+
- Xcode 16+

## Build

```bash
swift build
swift test    # 65 tests
```

Release build with entitlements (required for microphone access):

```bash
swift build -c release
codesign --force --sign - --entitlements Speech.entitlements .build/release/transcriber
codesign --force --sign - --entitlements Speech.entitlements .build/release/transcriber-mcp
```

## CLI Usage

```bash
# List installed speech models
transcriber models

# Download a model
transcriber models --download en-US

# Transcribe from microphone (Ctrl+C to stop)
transcriber live --locale en-US --format text
transcriber live --locale en-US --format jsonl

# Transcribe an audio file
transcriber file recording.wav --locale en-US --format jsonl

# Disable diarization
transcriber live --no-diarization
transcriber file recording.wav --no-diarization
```

### Output Formats

**Text** (default) -- human-readable, volatile results overwrite the current line:
```
... partial transcri
... partial transcript of wha
Hello, this is a complete sentence.
[Transcription complete]
```

**JSONL** -- one JSON object per line, suitable for piping:
```json
{"payload":{"text":"partial transcri","timestamp":0.5},"type":"volatile"}
{"payload":{"endTime":3.2,"startTime":0,"text":"Hello, this is a complete sentence."},"type":"final_"}
{"type":"ended","payload":"completed"}
```

## MCP Server

The MCP server exposes four tools for use with Claude Code or any MCP client.

### Tools

| Tool | Description |
|------|-------------|
| `start_transcription` | Begin live mic recording. Params: `locale`, `enable_diarization`, `max_speakers` |
| `stop_transcription` | Stop recording, return full transcript + diarization |
| `transcribe_file` | Transcribe audio file. Params: `path`, `locale`, `enable_diarization` |
| `get_status` | Current engine state: `idle` / `recording` / `transcribing` / `processing` |

### Setup

Add to your `.mcp.json`:

```json
{
  "mcpServers": {
    "transcriber": {
      "command": "/path/to/TranscriberKit/.build/release/transcriber-mcp"
    }
  }
}
```

### Example session

```
Claude> start_transcription with locale en-US
→ "Recording started. Use stop_transcription to get the transcript."

(speak into microphone)

Claude> stop_transcription
→ {"text":"Hello world, this is a test recording.","segments":[...],"speakerSegments":[...],"duration":5.2,"locale":"en-US"}
```

## Library Usage

`TranscriberCore` can be used as a dependency in other Swift packages:

```swift
import TranscriberCore

let engine = TranscriptionEngine()
let options = TranscriptionOptions(
    locale: Locale(identifier: "en-US"),
    enableDiarization: true,
    enableVolatileResults: true
)

// From microphone
let stream = try await engine.startLive(options: options)
for await event in stream {
    switch event {
    case .volatile(let r): print("... \(r.text)")
    case .final_(let r):   print(r.text)
    case .diarization(let segments): // speaker labels
    case .ended(let reason): break
    }
}

// From file
let fileStream = try await engine.startFile(
    url: URL(fileURLWithPath: "recording.wav"),
    options: options
)
```

## Dependencies

- [FluidAudio](https://github.com/FluidInference/FluidAudio) 0.12.1+ -- speaker diarization
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) 1.3.0+ -- CLI
- [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) 0.11.0+ -- MCP server

## License

MIT
