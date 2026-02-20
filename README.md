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
    TranscriberCoreTests/  # 73 unit tests across 16 suites
```

**Key design decisions:**
- Actor-based concurrency (`TranscriptionEngine`, `TranscriptionSession`, `DiarizationProcessor`, `ModelManager`)
- `AsyncStream<TranscriptionEvent>` as the universal interface between engine and consumers
- Protocol-based audio sources (`AudioCaptureSource`) with `MockAudioSource` for testing
- Post-hoc diarization (accumulate audio, run FluidAudio once after stop)
- Event observation callback (`onEvent`) for real-time streaming to MCP clients
- MCP supports progress notifications and resource subscriptions for streaming-capable clients

## Install

### Homebrew

```bash
brew install glebis/tap/transcriber-kit
```

After install, codesign for microphone access:

```bash
codesign --force --sign - --entitlements $(brew --prefix)/share/transcriber-kit/Speech.entitlements $(brew --prefix)/bin/transcriber
codesign --force --sign - --entitlements $(brew --prefix)/share/transcriber-kit/Speech.entitlements $(brew --prefix)/bin/transcriber-mcp
```

File-based transcription works without codesigning.

### Build from source

**Requirements:** macOS 15+, Swift 6.0+, Xcode 16+ (macOS 26+ for Speech framework features)

## Build

```bash
swift build
swift test    # 73 tests
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

The MCP server exposes tools and resources for use with Claude Code or any MCP client.

### Tools

| Tool | Description |
|------|-------------|
| `start_transcription` | Begin live mic recording. Params: `locale`, `enable_diarization`, `max_speakers` |
| `stop_transcription` | Stop recording, return full transcript + diarization |
| `transcribe_file` | Transcribe audio file. Params: `path`, `locale`, `enable_diarization` |
| `get_status` | Current engine state: `idle` / `recording` / `transcribing` / `processing` |

### Resources

| Resource | URI | Description |
|----------|-----|-------------|
| Live Transcript | `transcript://live` | Current accumulated transcript text (updated in real-time during recording) |

### Real-time Streaming

The MCP server supports two streaming mechanisms for clients that implement them:

**Progress notifications** -- When a client sends a `progressToken` in `_meta` with `start_transcription`, the server pushes `notifications/progress` messages containing partial transcript text as speech is recognized.

**Resource subscriptions** -- Clients can subscribe to `transcript://live` via `resources/subscribe`. The server sends `notifications/resources/updated` for each new transcript segment. The client reads the resource to get the current accumulated text.

Note: Claude Code does not currently surface MCP progress notifications or resource subscriptions. These features work with MCP Inspector and custom MCP clients.

### Setup

Add to your `.mcp.json`:

```json
{
  "mcpServers": {
    "transcriber": {
      "command": "transcriber-mcp"
    }
  }
}
```

If installed from source, use the full path: `.build/release/transcriber-mcp`

### Example session

```
Claude> start_transcription with locale en-US
-> "Recording started. Use stop_transcription to get the transcript."

(speak into microphone)

Claude> stop_transcription
-> {"text":"Hello world, this is a test recording.","segments":[...],"speakerSegments":[...],"duration":5.2,"locale":"en-US"}
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

// Real-time event observation
await engine.setOnEvent { event in
    if let text = event.progressMessage {
        print("Live: \(text)")
    }
}
```

## Dependencies

- [FluidAudio](https://github.com/FluidInference/FluidAudio) 0.12.1+ -- speaker diarization
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) 1.3.0+ -- CLI
- [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) 0.11.0+ -- MCP server

## License

MIT
