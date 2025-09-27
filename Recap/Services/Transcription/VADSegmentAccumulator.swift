import Foundation
import OSLog

/// Accumulates VAD audio segments independently of VAD or transcription state
@MainActor
final class VADSegmentAccumulator: ObservableObject {
    private let logger = Logger(subsystem: AppConstants.Logging.subsystem, category: String(describing: VADSegmentAccumulator.self))
    
    /// Accumulated audio segments by recording ID
    private var accumulatedSegments: [String: [VADAudioSegment]] = [:]
    
    /// File manager for persistent storage
    private let fileManager = FileManager.default
    private let segmentsDirectory: URL
    
    init() {
        self.segmentsDirectory = fileManager.temporaryDirectory.appendingPathComponent("VADAccumulatedSegments")
        setupSegmentsDirectory()
    }
    
    private func setupSegmentsDirectory() {
        do {
            try fileManager.createDirectory(at: segmentsDirectory, withIntermediateDirectories: true)
            logger.info("Created VAD segments accumulator directory: \(self.segmentsDirectory.path)")
        } catch {
            logger.error("Failed to create VAD segments directory: \(error)")
        }
    }
    
    /// Accumulate a VAD audio segment for a specific recording
    func accumulateSegment(_ audioData: Data, source: TranscriptionSegment.AudioSource, recordingID: String) {
        let segment = VADAudioSegment(
            id: UUID().uuidString,
            audioData: audioData,
            source: source,
            timestamp: Date(),
            recordingID: recordingID
        )
        
        // Add to memory
        if accumulatedSegments[recordingID] == nil {
            accumulatedSegments[recordingID] = []
        }
        accumulatedSegments[recordingID]?.append(segment)
        
        // Save to disk for persistence
        saveSegmentToDisk(segment)
        
        logger.info("Accumulated VAD segment \(segment.id) for recording \(recordingID) [source: \(source.rawValue)], size: \(audioData.count) bytes")
    }
    
    /// Get all accumulated segments for a recording
    func getAccumulatedSegments(for recordingID: String) -> [VADAudioSegment] {
        return accumulatedSegments[recordingID] ?? []
    }
    
    /// Get all accumulated segments for a recording, loading from disk if needed
    func getAllAccumulatedSegments(for recordingID: String) -> [VADAudioSegment] {
        // First try memory
        if let segments = accumulatedSegments[recordingID], !segments.isEmpty {
            return segments
        }
        
        // Load from disk if not in memory
        return loadSegmentsFromDisk(for: recordingID)
    }
    
    /// Clear segments for a specific recording
    func clearSegments(for recordingID: String) {
        accumulatedSegments.removeValue(forKey: recordingID)
        clearSegmentsFromDisk(for: recordingID)
        logger.info("Cleared accumulated segments for recording \(recordingID)")
    }
    
    /// Clear all segments
    func clearAllSegments() {
        accumulatedSegments.removeAll()
        clearAllSegmentsFromDisk()
        logger.info("Cleared all accumulated segments")
    }
    
    // MARK: - Private Methods
    
    private func saveSegmentToDisk(_ segment: VADAudioSegment) {
        do {
            let segmentURL = segmentsDirectory
                .appendingPathComponent(segment.recordingID)
                .appendingPathComponent("\(segment.id).json")
            
            // Create recording directory if it doesn't exist
            try fileManager.createDirectory(
                at: segmentURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            
            let encoder = JSONEncoder()
            let data = try encoder.encode(segment)
            try data.write(to: segmentURL)
            
        } catch {
            logger.error("Failed to save segment to disk: \(error)")
        }
    }
    
    private func loadSegmentsFromDisk(for recordingID: String) -> [VADAudioSegment] {
        do {
            let recordingDirectory = segmentsDirectory.appendingPathComponent(recordingID)
            guard fileManager.fileExists(atPath: recordingDirectory.path) else {
                return []
            }
            
            let files = try fileManager.contentsOfDirectory(at: recordingDirectory, includingPropertiesForKeys: nil)
            let segmentFiles = files.filter { $0.pathExtension == "json" }
            
            var segments: [VADAudioSegment] = []
            let decoder = JSONDecoder()
            
            for file in segmentFiles {
                do {
                    let data = try Data(contentsOf: file)
                    let segment = try decoder.decode(VADAudioSegment.self, from: data)
                    segments.append(segment)
                } catch {
                    logger.error("Failed to decode segment from \(file.path): \(error)")
                }
            }
            
            // Sort by timestamp
            segments.sort { $0.timestamp < $1.timestamp }
            
            // Store in memory for future access
            accumulatedSegments[recordingID] = segments
            
            logger.info("Loaded \(segments.count) segments from disk for recording \(recordingID)")
            return segments
            
        } catch {
            logger.error("Failed to load segments from disk for recording \(recordingID): \(error)")
            return []
        }
    }
    
    private func clearSegmentsFromDisk(for recordingID: String) {
        do {
            let recordingDirectory = segmentsDirectory.appendingPathComponent(recordingID)
            if fileManager.fileExists(atPath: recordingDirectory.path) {
                try fileManager.removeItem(at: recordingDirectory)
            }
        } catch {
            logger.error("Failed to clear segments from disk for recording \(recordingID): \(error)")
        }
    }
    
    private func clearAllSegmentsFromDisk() {
        do {
            if fileManager.fileExists(atPath: segmentsDirectory.path) {
                try fileManager.removeItem(at: segmentsDirectory)
                setupSegmentsDirectory()
            }
        } catch {
            logger.error("Failed to clear all segments from disk: \(error)")
        }
    }
}

/// Represents a VAD audio segment that can be accumulated and processed later
struct VADAudioSegment: Codable, Identifiable {
    let id: String
    let audioData: Data
    let source: TranscriptionSegment.AudioSource
    let timestamp: Date
    let recordingID: String
    let creationTime: Date // When the segment was actually created/started
    
    var duration: TimeInterval {
        // Estimate duration based on audio data size (assuming 16kHz, 16-bit mono)
        let sampleRate = 16000.0
        let bytesPerSample = 2.0
        let samples = Double(audioData.count) / bytesPerSample
        return samples / sampleRate
    }
    
    init(id: String, audioData: Data, source: TranscriptionSegment.AudioSource, timestamp: Date, recordingID: String) {
        self.id = id
        self.audioData = audioData
        self.source = source
        self.timestamp = timestamp
        self.recordingID = recordingID
        self.creationTime = Date() // Set creation time to now
    }
}

/// Structured transcription data with absolute timestamps
struct StructuredTranscription: Codable, Equatable {
    let segmentID: String
    let source: TranscriptionSegment.AudioSource
    let language: String
    let text: String
    let relativeStartTime: TimeInterval
    let relativeEndTime: TimeInterval
    let absoluteCreationTime: Date
    let absoluteStartTime: Date
    let absoluteEndTime: Date
    
    /// Convert to the structured format you specified
    var structuredText: String {
        let startTimeStr = String(format: "%.2f", relativeStartTime)
        let endTimeStr = String(format: "%.2f", relativeEndTime)
        return "<|startoftranscript|><|\(language)|><|transcribe|><|\(startTimeStr)|> \(text) <|\(endTimeStr)|><|endoftext|>"
    }
    
    /// Convert to JSON format
    var jsonData: [String: Any] {
        return [
            "segmentID": segmentID,
            "source": source.rawValue,
            "language": language,
            "text": text,
            "relativeStartTime": relativeStartTime,
            "relativeEndTime": relativeEndTime,
            "absoluteCreationTime": ISO8601DateFormatter().string(from: absoluteCreationTime),
            "absoluteStartTime": ISO8601DateFormatter().string(from: absoluteStartTime),
            "absoluteEndTime": ISO8601DateFormatter().string(from: absoluteEndTime)
        ]
    }
}
