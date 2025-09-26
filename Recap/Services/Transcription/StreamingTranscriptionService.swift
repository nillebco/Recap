import Foundation
import WhisperKit
import OSLog

@MainActor
final class StreamingTranscriptionService: ObservableObject {
    private let logger = Logger(subsystem: AppConstants.Logging.subsystem, category: String(describing: StreamingTranscriptionService.self))

    @Published var realtimeTranscriptions: [StreamingTranscriptionSegment] = []
    @Published var isProcessing: Bool = false

    private let transcriptionService: TranscriptionServiceType
    private let fileManager = FileManager.default
    private var temporaryDirectory: URL

    weak var delegate: StreamingTranscriptionDelegate?

    init(transcriptionService: TranscriptionServiceType) {
        self.transcriptionService = transcriptionService
        self.temporaryDirectory = fileManager.temporaryDirectory.appendingPathComponent("VADSegments")

        setupTemporaryDirectory()
    }

    private func setupTemporaryDirectory() {
        do {
            try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
            logger.info("Created temporary directory for VAD segments: \(self.temporaryDirectory.path)")
        } catch {
            logger.error("Failed to create temporary directory: \(error)")
        }
    }

    func transcribeAudioSegment(_ audioData: Data, segmentID: String = UUID().uuidString) async {
        guard !audioData.isEmpty else {
            logger.warning("Received empty audio data for transcription")
            return
        }

        isProcessing = true
        logger.info("Starting transcription for segment \(segmentID), size: \(audioData.count) bytes")

        do {
            let temporaryFileURL = temporaryDirectory.appendingPathComponent("\(segmentID).wav")

            try audioData.write(to: temporaryFileURL)

            defer {
                try? fileManager.removeItem(at: temporaryFileURL)
            }

            let result = try await transcriptionService.transcribe(audioURL: temporaryFileURL, microphoneURL: nil)

            let segment = StreamingTranscriptionSegment(
                id: segmentID,
                text: result.systemAudioText,
                timestamp: Date(),
                confidence: 1.0, // WhisperKit doesn't provide confidence scores
                duration: result.transcriptionDuration
            )

            realtimeTranscriptions.append(segment)

            delegate?.streamingTranscriptionDidComplete(segment)

            logger.info("Completed transcription for segment \(segmentID): '\(result.systemAudioText.prefix(50))...'")

        } catch {
            logger.error("Failed to transcribe audio segment \(segmentID): \(error)")
            delegate?.streamingTranscriptionDidFail(segmentID: segmentID, error: error)
        }

        isProcessing = false
    }

    func clearTranscriptions() {
        realtimeTranscriptions.removeAll()
        logger.info("Cleared all realtime transcriptions")
    }

    func getRecentTranscriptions(limit: Int = 10) -> [StreamingTranscriptionSegment] {
        return Array(realtimeTranscriptions.suffix(limit))
    }

    deinit {
        try? fileManager.removeItem(at: temporaryDirectory)
    }
}

struct StreamingTranscriptionSegment: Identifiable {
    let id: String
    let text: String
    let timestamp: Date
    let confidence: Float
    let duration: TimeInterval

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

protocol StreamingTranscriptionDelegate: AnyObject {
    func streamingTranscriptionDidComplete(_ segment: StreamingTranscriptionSegment)
    func streamingTranscriptionDidFail(segmentID: String, error: Error)
}