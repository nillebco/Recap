import Foundation
import OSLog

@MainActor
final class DragDropViewModel: DragDropViewModelType {
  @Published var transcriptEnabled: Bool
  @Published var summarizeEnabled: Bool
  @Published var isProcessing = false
  @Published var errorMessage: String?
  @Published var successMessage: String?

  private let transcriptionService: TranscriptionServiceType
  private let llmService: LLMServiceType
  private let userPreferencesRepository: UserPreferencesRepositoryType
  private let recordingFileManagerHelper: RecordingFileManagerHelperType
  private let logger = Logger(
    subsystem: AppConstants.Logging.subsystem,
    category: String(describing: DragDropViewModel.self))

  init(
    transcriptionService: TranscriptionServiceType,
    llmService: LLMServiceType,
    userPreferencesRepository: UserPreferencesRepositoryType,
    recordingFileManagerHelper: RecordingFileManagerHelperType
  ) {
    self.transcriptionService = transcriptionService
    self.llmService = llmService
    self.userPreferencesRepository = userPreferencesRepository
    self.recordingFileManagerHelper = recordingFileManagerHelper

    // Initialize with defaults, will be loaded async
    self.transcriptEnabled = true
    self.summarizeEnabled = true

    // Load user preferences asynchronously
    Task {
      if let prefs = try? await userPreferencesRepository.getOrCreatePreferences() {
        await MainActor.run {
          self.transcriptEnabled = prefs.autoTranscribeEnabled
          self.summarizeEnabled = prefs.autoSummarizeEnabled
        }
      }
    }
  }

  func handleDroppedFile(url: URL) async {
    errorMessage = nil
    successMessage = nil
    isProcessing = true

    do {
      // Validate file format
      let fileExtension = url.pathExtension.lowercased()
      let supportedFormats = ["wav", "mp3", "m4a", "flac"]

      guard supportedFormats.contains(fileExtension) else {
        throw DragDropError.unsupportedFormat(fileExtension)
      }

      // Create unique identifier with timestamp
      let timestamp = ISO8601DateFormatter().string(from: Date())
        .replacingOccurrences(of: ":", with: "-")
        .replacingOccurrences(of: ".", with: "-")
      let recordingID = "drag_drop_\(timestamp)"

      // Get storage directory using helper
      let recordingDirectory = try recordingFileManagerHelper.createRecordingDirectory(
        for: recordingID)

      // Copy audio file to storage
      let destinationURL = recordingDirectory.appendingPathComponent("system_recording.wav")
      try FileManager.default.copyItem(at: url, to: destinationURL)

      logger.info("Copied audio file to: \(destinationURL.path, privacy: .public)")

      var transcriptionText: String?

      // Transcribe if enabled
      if transcriptEnabled {
        logger.info("Starting transcription for drag & drop file")
        let result = try await transcriptionService.transcribe(
          audioURL: destinationURL, microphoneURL: nil)
        transcriptionText = result.combinedText

        // Save transcript to markdown
        let transcriptURL = recordingDirectory.appendingPathComponent("transcript.md")
        try result.combinedText.write(to: transcriptURL, atomically: true, encoding: .utf8)
        logger.info("Saved transcript to: \(transcriptURL.path, privacy: .public)")
      }

      // Summarize if enabled and we have a transcript
      if summarizeEnabled, let text = transcriptionText {
        logger.info("Starting summarization for drag & drop file")

        let summary = try await llmService.generateSummarization(
          text: text,
          options: .defaultSummarization
        )

        // Save summary to markdown
        let summaryURL = recordingDirectory.appendingPathComponent("summary.md")
        try summary.write(to: summaryURL, atomically: true, encoding: String.Encoding.utf8)
        logger.info("Saved summary to: \(summaryURL.path, privacy: .public)")
      }

      successMessage = "File processed successfully! Saved to: \(recordingDirectory.path)"
      logger.info("✅ Drag & drop processing complete: \(recordingID, privacy: .public)")

    } catch let error as DragDropError {
      errorMessage = error.localizedDescription
      logger.error("❌ Drag & drop error: \(error.localizedDescription, privacy: .public)")
    } catch {
      errorMessage = "Failed to process file: \(error.localizedDescription)"
      logger.error(
        "❌ Unexpected error in drag & drop: \(error.localizedDescription, privacy: .public)")
    }

    isProcessing = false
  }
}

enum DragDropError: LocalizedError {
  case unsupportedFormat(String)

  var errorDescription: String? {
    switch self {
    case .unsupportedFormat(let format):
      return "Unsupported audio format: .\(format). Supported formats: wav, mp3, m4a, flac"
    }
  }
}
