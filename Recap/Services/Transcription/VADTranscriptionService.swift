import Foundation
import OSLog

/// Service for transcribing accumulated VAD segments
@MainActor
final class VADTranscriptionService: ObservableObject {
    private let logger = Logger(subsystem: AppConstants.Logging.subsystem, category: String(describing: VADTranscriptionService.self))
    
    private let transcriptionService: TranscriptionServiceType
    private let fileManager = FileManager.default
    private let temporaryDirectory: URL
    
    init(transcriptionService: TranscriptionServiceType) {
        self.transcriptionService = transcriptionService
        self.temporaryDirectory = fileManager.temporaryDirectory.appendingPathComponent("VADTranscriptionSegments")
        setupTemporaryDirectory()
    }
    
    private func setupTemporaryDirectory() {
        do {
            try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
            logger.info("Created VAD transcription temporary directory: \(self.temporaryDirectory.path)")
        } catch {
            logger.error("Failed to create VAD transcription directory: \(error)")
        }
    }
    
    /// Transcribe accumulated VAD segments and return StreamingTranscriptionSegments
    func transcribeAccumulatedSegments(_ segments: [VADAudioSegment]) async -> [StreamingTranscriptionSegment] {
        logger.info("Starting transcription of \(segments.count) accumulated VAD segments")
        
        var transcriptionSegments: [StreamingTranscriptionSegment] = []
        
        // Process segments in batches to avoid overwhelming the system
        let batchSize = 5
        for i in stride(from: 0, to: segments.count, by: batchSize) {
            let batch = Array(segments[i..<min(i + batchSize, segments.count)])
            let batchResults = await transcribeBatch(batch)
            transcriptionSegments.append(contentsOf: batchResults)
        }
        
        logger.info("Completed transcription of \(segments.count) segments, got \(transcriptionSegments.count) results")
        return transcriptionSegments
    }
    
    /// Transcribe accumulated VAD segments and return structured transcriptions
    func transcribeAccumulatedSegmentsStructured(_ segments: [VADAudioSegment]) async -> [StructuredTranscription] {
        logger.info("Starting structured transcription of \(segments.count) accumulated VAD segments")
        
        var structuredTranscriptions: [StructuredTranscription] = []
        
        // Process segments in batches to avoid overwhelming the system
        let batchSize = 5
        for i in stride(from: 0, to: segments.count, by: batchSize) {
            let batch = Array(segments[i..<min(i + batchSize, segments.count)])
            let batchResults = await transcribeBatchStructured(batch)
            structuredTranscriptions.append(contentsOf: batchResults)
        }
        
        logger.info("Completed structured transcription of \(segments.count) segments, got \(structuredTranscriptions.count) results")
        return structuredTranscriptions
    }
    
    private func transcribeBatch(_ segments: [VADAudioSegment]) async -> [StreamingTranscriptionSegment] {
        var results: [StreamingTranscriptionSegment] = []
        
        // Process segments concurrently within the batch
        await withTaskGroup(of: StreamingTranscriptionSegment?.self) { [weak self] group in
            guard let self = self else { return }
            
            for segment in segments {
                group.addTask {
                    await self.transcribeSegment(segment)
                }
            }
            
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
        }
        
        // Sort by timestamp to maintain chronological order
        results.sort { $0.timestamp < $1.timestamp }
        
        return results
    }
    
    private func transcribeBatchStructured(_ segments: [VADAudioSegment]) async -> [StructuredTranscription] {
        var results: [StructuredTranscription] = []
        
        // Process segments concurrently within the batch
        await withTaskGroup(of: StructuredTranscription?.self) { [weak self] group in
            guard let self = self else { return }
            
            for segment in segments {
                group.addTask {
                    await self.transcribeSegmentStructured(segment)
                }
            }
            
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
        }
        
        // Sort by creation time to maintain chronological order
        results.sort { $0.absoluteCreationTime < $1.absoluteCreationTime }
        
        return results
    }
    
    private func transcribeSegment(_ segment: VADAudioSegment) async -> StreamingTranscriptionSegment? {
        do {
            // Write audio data to temporary file
            let temporaryFileURL = temporaryDirectory.appendingPathComponent("\(segment.id).wav")
            try segment.audioData.write(to: temporaryFileURL)
            
            defer {
                // Clean up temporary file
                try? fileManager.removeItem(at: temporaryFileURL)
            }
            
            // Transcribe the segment
            let result = try await transcriptionService.transcribe(audioURL: temporaryFileURL, microphoneURL: nil)
            
            // Create StreamingTranscriptionSegment
            // Clean the text by removing WhisperKit tags
            let cleanedText = TranscriptionTextCleaner.cleanWhisperKitText(result.systemAudioText)
            
            let transcriptionSegment = StreamingTranscriptionSegment(
                id: segment.id,
                text: cleanedText,
                timestamp: segment.timestamp,
                confidence: 1.0, // WhisperKit doesn't provide confidence scores
                duration: result.transcriptionDuration,
                source: segment.source
            )
            
            logger.debug("Transcribed segment \(segment.id): '\(result.systemAudioText.prefix(50))...'")
            return transcriptionSegment
            
        } catch {
            logger.error("Failed to transcribe segment \(segment.id): \(error)")
            return nil
        }
    }
    
    private func transcribeSegmentStructured(_ segment: VADAudioSegment) async -> StructuredTranscription? {
        do {
            // Write audio data to temporary file
            let temporaryFileURL = temporaryDirectory.appendingPathComponent("\(segment.id).wav")
            try segment.audioData.write(to: temporaryFileURL)
            
            defer {
                // Clean up temporary file
                try? fileManager.removeItem(at: temporaryFileURL)
            }
            
            // Transcribe the segment
            let result = try await transcriptionService.transcribe(audioURL: temporaryFileURL, microphoneURL: nil)
            
            // Create structured transcription with absolute timestamps
            let relativeStartTime: TimeInterval = 0.0
            let relativeEndTime: TimeInterval = result.transcriptionDuration
            
            // Calculate absolute times based on segment creation time
            let absoluteStartTime = segment.creationTime.addingTimeInterval(relativeStartTime)
            let absoluteEndTime = segment.creationTime.addingTimeInterval(relativeEndTime)
            
            // Clean the text by removing WhisperKit tags
            let cleanedText = TranscriptionTextCleaner.cleanWhisperKitText(result.systemAudioText)
            
            let structuredTranscription = StructuredTranscription(
                segmentID: segment.id,
                source: segment.source,
                language: "en", // Default to English, could be detected from audio
                text: cleanedText,
                relativeStartTime: relativeStartTime,
                relativeEndTime: relativeEndTime,
                absoluteCreationTime: segment.creationTime,
                absoluteStartTime: absoluteStartTime,
                absoluteEndTime: absoluteEndTime
            )
            
            logger.debug("Transcribed structured segment \(segment.id): '\(result.systemAudioText.prefix(50))...'")
            return structuredTranscription
            
        } catch {
            logger.error("Failed to transcribe structured segment \(segment.id): \(error)")
            return nil
        }
    }
    
    
    /// Clear temporary files
    func cleanup() {
        do {
            if fileManager.fileExists(atPath: temporaryDirectory.path) {
                try fileManager.removeItem(at: temporaryDirectory)
                setupTemporaryDirectory()
            }
        } catch {
            logger.error("Failed to cleanup VAD transcription directory: \(error)")
        }
    }
}
