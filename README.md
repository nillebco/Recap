
<img width="900" height="846" alt="github_export" src="https://github.com/user-attachments/assets/df798940-820c-46b6-b149-3a2771c7b5f3" />

---

# Recap

Recap is an open-source, privacy-focused, macOS-native project to help you summarize your meetings. You could summarize audio of any app, not just meetings. 

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

