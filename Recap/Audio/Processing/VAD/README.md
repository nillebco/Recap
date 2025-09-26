# Voice Activity Detection (VAD) Integration

This implementation provides real-time voice activity detection with streaming transcription capabilities.

## Architecture

### Core Components

1. **VADManager** - Main VAD coordinator using energy-based detection (ready for FluidAudio upgrade)
2. **FrameProcessor** - State machine for speech segment detection (ported from Python)
3. **StreamingTranscriptionService** - Real-time transcription of speech segments
4. **VADTranscriptionCoordinator** - Bridges VAD events to transcription pipeline
5. **AudioFormatConverter** - Handles audio format conversion for VAD processing

### Integration Points

- **MicrophoneCapture** - Extended with VAD processing in audio buffer pipeline
- **AudioRecordingCoordinator** - Orchestrates VAD and transcription services

## Usage

### Basic Setup

```swift
// In your recording coordinator setup
let transcriptionService = TranscriptionService(...)
let streamingService = StreamingTranscriptionService(transcriptionService: transcriptionService)

await recordingCoordinator.setStreamingTranscriptionService(streamingService)

// Enable VAD with custom configuration
await recordingCoordinator.enableVAD(
    configuration: .responsive, // or .default
    delegate: yourVADDelegate
)
```

### VADTranscriptionCoordinatorDelegate

```swift
class YourVADHandler: VADTranscriptionCoordinatorDelegate {
    func vadTranscriptionDidDetectSpeechStart() {
        print("🎤 Speech started")
    }

    func vadTranscriptionDidConfirmSpeechStart() {
        print("✅ Real speech confirmed")
    }

    func vadTranscriptionDidComplete(_ segment: StreamingTranscriptionSegment) {
        print("📝 Transcribed: \(segment.text)")
        // Handle real-time transcription
    }

    func vadTranscriptionDidFail(segmentID: String, error: Error) {
        print("❌ Transcription failed: \(error)")
    }

    func vadTranscriptionDidDetectMisfire() {
        print("🔇 VAD misfire (too short)")
    }
}
```

### Configuration Options

```swift
// Default configuration (balanced)
VADConfiguration.default

// Responsive configuration (more sensitive)
VADConfiguration.responsive

// Custom configuration
VADConfiguration(
    frameSamples: 512,           // 30ms @ 16kHz
    positiveSpeechThreshold: 0.6, // Trigger threshold
    negativeSpeechThreshold: 0.35, // End threshold
    redemptionFrames: 8,         // Grace period frames
    preSpeechPadFrames: 4,       // Pre-speech buffer
    minSpeechFrames: 5,          // Minimum speech length
    submitUserSpeechOnPause: true // Auto-submit on pause
)
```

## FluidAudio Integration

To upgrade from energy-based VAD to FluidAudio:

1. **Add FluidAudio dependency** to Xcode project
2. **Update VADManager.swift**:

```swift
import FluidAudio

// Replace in VADManager
private var fluidAudioManager: FluidAudio.VadManager?

func setupFluidAudio() async throws {
    fluidAudioManager = try await VadManager()
    // Update processVADChunk to use FluidAudio
}

private func processVADChunk(_ chunk: [Float]) async throws {
    let result = try await fluidAudioManager?.processStreamingChunk(
        chunk,
        state: vadState,
        config: .default,
        returnSeconds: true,
        timeResolution: 2
    )
    // Handle FluidAudio results
}
```

## Performance Characteristics

- **Latency**: ~23ms per buffer (1024 frames @ 44.1kHz)
- **VAD Processing**: ~256ms chunks at 16kHz
- **Memory**: Ring buffers for pre-speech padding
- **CPU**: Minimal overhead with energy-based VAD

## Audio Pipeline

```
Microphone → AVAudioEngine (1024 frames)
           → Format Conversion (44.1kHz → 16kHz)
           → Buffer Accumulation (4x buffers → 4096 samples)
           → VAD Processing (512-sample frames)
           → Speech Detection State Machine
           → Audio Segment Collection
           → Temporary WAV File Creation
           → WhisperKit Transcription
           → Real-time Results
```

## Error Handling

- **Audio format conversion failures** - Falls back to original buffer
- **VAD processing errors** - Logged and skipped
- **Transcription failures** - Delegate notification with error details
- **Memory management** - Automatic cleanup of temporary files and buffers

## Debugging

Enable detailed logging:
```swift
// VAD events are logged at debug/info level
// Check Console app for "Recap" subsystem logs
```

## Future Enhancements

1. **FluidAudio Integration** - Replace energy-based VAD
2. **Confidence Scoring** - Add speech confidence metrics
3. **Background Processing** - Move VAD to background queue
4. **Multiple Models** - Support different VAD models
5. **Real-time UI** - Live transcription display components