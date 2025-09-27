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
    
    // Debug flag to keep segments for inspection
    private let keepSegmentsForDebug = true

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
            print("📁 VAD: Created temporary directory: \(self.temporaryDirectory.path)")
            
            // Verify directory exists
            if fileManager.fileExists(atPath: temporaryDirectory.path) {
                print("📁 VAD: Directory exists and is accessible")
            } else {
                print("📁 VAD: ERROR - Directory was not created!")
            }
        } catch {
            logger.error("Failed to create temporary directory: \(error)")
            print("📁 VAD: ERROR - Failed to create directory: \(error)")
        }
    }

    func transcribeAudioSegment(
        _ audioData: Data,
        source: TranscriptionSegment.AudioSource,
        segmentID: String = UUID().uuidString
    ) async {
        guard !audioData.isEmpty else {
            logger.warning("Received empty audio data for transcription")
            return
        }

        isProcessing = true
        logger.info("Starting transcription for segment \(segmentID) [source: \(source.rawValue)], size: \(audioData.count) bytes")

        do {
            let temporaryFileURL = temporaryDirectory.appendingPathComponent("\(segmentID).wav")

            try audioData.write(to: temporaryFileURL)

            print("🎵 VAD: Wrote audio file to \(temporaryFileURL.path)")
            print("🎵 VAD: File size: \(audioData.count) bytes (source: \(source.rawValue))")

            defer {
                // Keep files for debugging if flag is set
                if !keepSegmentsForDebug {
                    try? fileManager.removeItem(at: temporaryFileURL)
                } else {
                    print("🔍 VAD: Keeping segment file for debugging: \(temporaryFileURL.path)")
                }
            }

            print("🎵 VAD: Starting WhisperKit transcription...")
            let result = try await transcriptionService.transcribe(audioURL: temporaryFileURL, microphoneURL: nil)
            print("🎵 VAD: WhisperKit transcription completed")
            print("🎵 VAD: Result text: '\(result.systemAudioText)'")
            print("🎵 VAD: Result duration: \(result.transcriptionDuration)s")

            let segment = StreamingTranscriptionSegment(
                id: segmentID,
                text: result.systemAudioText,
                timestamp: Date(),
                confidence: 1.0, // WhisperKit doesn't provide confidence scores
                duration: result.transcriptionDuration,
                source: source
            )

            realtimeTranscriptions.append(segment)

            delegate?.streamingTranscriptionDidComplete(segment)

            logger.info("Completed transcription for segment \(segmentID) [source: \(source.rawValue)]: '\(result.systemAudioText.prefix(50))...'")
            
            // Debug: List VAD segment files after each transcription
            listVADSegmentFiles()

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
    
    // Debug method to list VAD segment files
    func listVADSegmentFiles() {
        do {
            let files = try fileManager.contentsOfDirectory(at: temporaryDirectory, includingPropertiesForKeys: nil)
            print("🔍 VAD: Found \(files.count) files in VAD segments directory:")
            for file in files {
                let attributes = try fileManager.attributesOfItem(atPath: file.path)
                let size = attributes[.size] as? Int64 ?? 0
                print("🔍 VAD: - \(file.lastPathComponent) (\(size) bytes)")
            }
        } catch {
            print("🔍 VAD: Error listing VAD segment files: \(error)")
        }
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
    let source: TranscriptionSegment.AudioSource

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
