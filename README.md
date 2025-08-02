
<img width="900" height="846" alt="github_export" src="https://github.com/user-attachments/assets/df798940-820c-46b6-b149-3a2771c7b5f3" />

---

# Recap

## Why I Built This

Ever been in a meeting where you wanted to focus on your work but still catch the important bits? That's exactly why I created Recap. 

I found myself constantly torn between paying attention to meetings and getting actual work done. Sometimes I'd miss crucial decisions while coding, or I'd lose my flow state trying to take notes. I needed something that could listen for me and give me the highlights afterward.

But here's the thing - I didn't want my private conversations floating around on some company's servers. When you're discussing sensitive business matters, product roadmaps, or personal topics, that data should stay on YOUR machine. That's why Recap processes everything locally on your Mac using Apple's own technologies.

Now, Recap is broken. But it is a project that I am always working on on my free time so it meets my needs. I hope it can help you too.

---

Recap is an open-source, privacy-focused, macOS-native project to help you summarize your meetings. You could summarize audio of any app, not just meetings.

## Tech Stack

#### Linter
Not using any linter right now, but I am planning to use SwiftLint/SwiftFormat in the future (PRs greatly welcomed).

Built using native macOS technologies - no drivers or kernel extensions required.

**Core Audio**: Native Core Audio taps, AVAudioEngine, driver-free system audio capture  
**ML**: WhisperKit (local transcription), Ollama/OpenRouter (summarization)  
**Platform**: Swift + SwiftUI, Apple Silicon optimized, sandboxed execution 

> [!IMPORTANT]
> Recap is not complete yet, it is broken, and not recommended for production usage. 


### Roadmap: 
> [!TIP]
> Recap is in an incomplete state and I suggest that it is not used for production and daily usage, but help in shaping it is greatly appreciated. 

Working on the following features now:
- [ ] Meeting Detection (Teams, Zoom, Google etc)
- [ ] Custom Prompt Via Settings
- [ ] Background Audio Processing 
- [ ] Auto Recording Stop
- [ ] Better Error Handling
- [ ] 85% or more test coverage

Right now, Recap is more of a POC of what I am trying to make. It records system audio (Core Audio Taps) + with an optional microphone recording (your audio) and feeds it to Whisper for transcription and then uses Ollama for summarizing. 

**LLM Provider Options:**
- **Ollama** (recommended): Complete privacy - everything stays on your device
- **OpenRouter**: Cloud-based option if you lack local compute capacity, but data leaves your device

## System Requirements

### For Ollama (Local Processing)

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **macOS** | 15.0 or later| 15.0 or later |
| **Processor** | Apple M1 | Apple M2 Pro or newer |
| **RAM** | 16 GB | 32 GB or more |
| **Storage** | 10 GB free space | 50 GB free space |

### For OpenRouter (Cloud Processing)

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **macOS** | 15.0 or later| 15.0 or later |
| **Processor** | Apple M1 | Apple M2 or newer |
| **RAM** | 8 GB | 16 GB or more |
| **Storage** | 2 GB free space | 5 GB free space |

> **Note**: Intel Macs are not supported. Apple Silicon required for WhisperKit transcription.

## How It Works

```
                                  DATA FLOW
                              ┌───────────────┐
                          ┌───┤ 1. App Start  │
                          │   └───────────────┘
                          ▼
                    ┌─────────────┐
                    │2. App Select│
                    └─────────────┘
                          │
                          ▼
               ┌────────────────────────┐
               │3. Start Recording      │
               │   • System Audio       │
               │   • Microphone (opt)   │
               └────────────────────────┘
                          │
                          ▼
               ┌────────────────────────┐
               │4. Stop Recording       │
               │   • Save Audio Files   │
               │   • Create DB Record   │
               └────────────────────────┘
                          │
                          ▼
               ┌────────────────────────┐
               │5. Background Process   │
               │   • Transcribe Audio   │
               │   • Generate Summary   │
               └────────────────────────┘
                          │
                          ▼
               ┌────────────────────────┐
               │6. Complete & Store     │
               │   • Update DB Record   │
               │   • Show Results       │
               └────────────────────────┘
```

## Installation

Currently, Recap is only available through compilation from source. Pre-built releases will be available once core features are stabilized.

### Compile from Source

1. **Prerequisites:**
   - Ensure your system meets the [requirements](#system-requirements) above
   - Install Xcode 15.0 or later from the Mac App Store

2. **Clone and Build:**
   ```bash
   git clone https://github.com/your-username/recap.git
   cd recap
   open Recap.xcodeproj
   ```

3. **Build in Xcode:**
   - Select your development team in project settings
   - Build and run (⌘+R)

> **Note**: Distribution via Mac App Store and direct download will be available in future releases once the app reaches production readiness.

## Usage

### Required Environment Variables

Before using Recap, you need to set up the following environment variables:

- **`HF_TOKEN`** (Required): Hugging Face token for downloading Whisper models
  ```bash
  export HF_TOKEN="your_huggingface_token_here"
  ```
  
- **`OPENROUTER_API_KEY`** (Optional): Only required if using OpenRouter for summarization
  ```bash
  export OPENROUTER_API_KEY="your_openrouter_api_key_here"
  ```

### First-Time Setup

1. **Download Whisper Model:**
   - Open Recap and go to **Settings → Whisper Models**
   - Download a Whisper model (recommended: **Large v3** for best accuracy)
   - Wait for the download to complete before proceeding

2. **Configure LLM Provider:**
   - Go to **Settings → LLM Models**
   - Choose your preferred provider (Ollama or OpenRouter)
   - If using Ollama, ensure it's installed and running locally

3. **Start Recording:**
   - Select an audio application from the dropdown
   - Click the record button to start capturing
   - Optionally enable microphone for dual-audio recording
   - Click stop when finished - processing will begin automatically

## Tech Stack

Recap is built using native macOS technologies, avoiding third-party drivers and kernel extensions for maximum system stability and security.

### Core Audio Implementation
- **Native Core Audio**: Direct integration with macOS audio subsystem
- **Audio Unit Taps**: System-level audio interception without drivers
- **AVAudioEngine**: Modern Swift audio processing pipeline
- **No Kernel Extensions**: Driver-free audio capture using Apple's official APIs
- **Process-Specific Capture**: Target individual applications without affecting system audio

### Technologies Used
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI + AppKit (menu bar integration)
- **Audio Processing**: Core Audio, AVAudioEngine, Audio Toolbox
- **Machine Learning**: 
  - WhisperKit (local speech-to-text)
  - MLX/CoreML optimization for Apple Silicon
- **LLM Integration**: 
  - Ollama (local inference)
  - OpenRouter (cloud API)
- **Data Storage**: Core Data + local file system
- **Concurrency**: Swift async/await, structured concurrency
- **Architecture**: MVVM, Coordinator pattern, Dependency injection

### Security & Privacy Benefits
- **Sandboxed Execution**: Runs within macOS security boundaries
- **No System Modifications**: Zero kernel-level changes required
- **Permission-Based**: Uses standard macOS audio permissions
- **Local Processing**: WhisperKit keeps transcription on-device
- **Secure Audio Taps**: Apple's blessed method for audio interception

## Contributing

I really need help finishing Recap! Any contribution is greatly welcomed.

### Priority Areas

**Critical needs:**
- **Permission Management**: Proper audio/microphone permission handling and user guidance
- **Alerts & Notifications**: User-friendly error messages and system notifications  
- **Error Handling**: Robust error recovery and user feedback throughout the app
- **UI/UX Polish**: Improve the interface and user experience
- **Testing**: Unit tests and integration tests for core functionality

**Also needed:**
- Meeting app detection improvements
- Custom prompt templates via settings
- Performance optimizations
- Documentation improvements
- Bug fixes and stability improvements

### How to Contribute

1. **Fork the repository** and create a feature branch
2. **Check existing issues** or create new ones for bugs/features
3. **Follow the coding patterns** established in the codebase
4. **Test your changes** thoroughly on Apple Silicon Macs
5. **Submit a pull request** with clear description of changes

All skill levels welcome - from fixing typos to architecting new features. Let's build something great together. I really mean it!

