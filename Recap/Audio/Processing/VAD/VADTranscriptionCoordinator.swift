import Foundation
import OSLog

@MainActor
final class VADTranscriptionCoordinator: VADDelegate, StreamingTranscriptionDelegate, ObservableObject {
    private let logger = Logger(subsystem: AppConstants.Logging.subsystem, category: String(describing: VADTranscriptionCoordinator.self))

    @Published var isVADActive: Bool = false
    @Published var realtimeTranscriptions: [StreamingTranscriptionSegment] = []
    @Published var currentSpeechProbability: Float = 0.0

    private let streamingTranscriptionService: StreamingTranscriptionService
    private let segmentAccumulator: VADSegmentAccumulator
    private var pendingTranscriptionTasks: Set<Task<Void, Never>> = []
    private var speechProbabilities: [VADAudioSource: Float] = [:]
    private var currentRecordingID: String?

    weak var delegate: VADTranscriptionCoordinatorDelegate?

    init(streamingTranscriptionService: StreamingTranscriptionService) {
        self.streamingTranscriptionService = streamingTranscriptionService
        self.segmentAccumulator = VADSegmentAccumulator()
        self.streamingTranscriptionService.delegate = self
    }

    func startVADTranscription(for recordingID: String) {
        isVADActive = true
        currentRecordingID = recordingID
        logger.info("VAD transcription coordinator started for recording \(recordingID)")
    }
    
    func startVADTranscription() {
        isVADActive = true
        logger.info("VAD transcription coordinator started")
    }

    func stopVADTranscription() {
        isVADActive = false

        // Cancel all pending transcription tasks
        for task in pendingTranscriptionTasks {
            task.cancel()
        }
        pendingTranscriptionTasks.removeAll()
        speechProbabilities.removeAll()
        currentSpeechProbability = 0.0

        logger.info("VAD transcription coordinator stopped")
    }

    func clearTranscriptions() {
        realtimeTranscriptions.removeAll()
        streamingTranscriptionService.clearTranscriptions()
        speechProbabilities.removeAll()
        currentSpeechProbability = 0.0
    }

    // MARK: - VADDelegate

    func vadDidDetectEvent(_ event: VADEvent) {
        guard isVADActive else { return }

        switch event {
        case .speechStart(let source):
            logger.debug("VAD detected speech start for \(source.transcriptionSource.rawValue) source")
            delegate?.vadTranscriptionDidDetectSpeechStart()

        case .speechRealStart(let source):
            logger.debug("VAD confirmed real speech start for \(source.transcriptionSource.rawValue) source")
            delegate?.vadTranscriptionDidConfirmSpeechStart()

        case .speechEnd(let audioData, let source):
            let transcriptionSource = source.transcriptionSource
            logger.info("VAD detected speech end for \(transcriptionSource.rawValue) audio, processing: \(audioData.count) bytes")
            print("🔥 VAD: Speech end detected for \(transcriptionSource.rawValue) source! Audio data size: \(audioData.count) bytes")
            processAudioSegment(audioData, source: transcriptionSource)

        case .vadMisfire(let source):
            logger.debug("VAD misfire detected for \(source.transcriptionSource.rawValue) source")
            delegate?.vadTranscriptionDidDetectMisfire()
        }
    }

    func vadDidProcessFrame(_ probability: Float, _ audioFrame: [Float], source: VADAudioSource) {
        speechProbabilities[source] = probability
        currentSpeechProbability = speechProbabilities.values.max() ?? 0.0
    }

    // MARK: - StreamingTranscriptionDelegate

    nonisolated func streamingTranscriptionDidComplete(_ segment: StreamingTranscriptionSegment) {
        Task { @MainActor in
            streamingTranscriptionDidCompleteInternal(segment)
        }
    }

    private func streamingTranscriptionDidCompleteInternal(_ segment: StreamingTranscriptionSegment) {
        realtimeTranscriptions.append(segment)

        print("✅ VAD: Transcription result received: '\(segment.text)' (segment \(segment.id), source: \(segment.source.rawValue))")
        print("✅ VAD: Total transcriptions collected: \(realtimeTranscriptions.count)")

        // Keep only the last 50 transcriptions to avoid memory issues
        if realtimeTranscriptions.count > 50 {
            realtimeTranscriptions.removeFirst(realtimeTranscriptions.count - 50)
        }

        delegate?.vadTranscriptionDidComplete(segment)
        logger.info("Streaming transcription completed: '\(segment.text.prefix(50))...'")
    }

    nonisolated func streamingTranscriptionDidFail(segmentID: String, error: Error) {
        Task { @MainActor in
            streamingTranscriptionDidFailInternal(segmentID: segmentID, error: error)
        }
    }

    private func streamingTranscriptionDidFailInternal(segmentID: String, error: Error) {
        delegate?.vadTranscriptionDidFail(segmentID: segmentID, error: error)
        logger.error("Streaming transcription failed for segment \(segmentID): \(error)")
    }

    // MARK: - Private Methods

    private func processAudioSegment(_ audioData: Data, source: TranscriptionSegment.AudioSource) {
        // Always accumulate segments regardless of VAD state
        guard let recordingID = currentRecordingID else {
            logger.warning("No recording ID set, cannot accumulate VAD segment")
            return
        }
        
        let segmentID = UUID().uuidString
        logger.info("Accumulating VAD segment \(segmentID) for recording \(recordingID) [source: \(source.rawValue)], size: \(audioData.count) bytes")
        
        // Debug: Check if audio data looks like a valid WAV file
        if audioData.count >= 44 {
            let header = String(data: audioData.prefix(4), encoding: .ascii) ?? "unknown"
            print("🎙️ VAD: Audio data header: '\(header)' (should be 'RIFF')")
            
            let waveHeader = String(data: audioData.subdata(in: 8..<12), encoding: .ascii) ?? "unknown"
            print("🎙️ VAD: WAVE header: '\(waveHeader)' (should be 'WAVE')")
        } else {
            print("🎙️ VAD: Audio data too small to be valid WAV file")
        }

        // Accumulate the segment - this is independent of VAD/transcription state
        segmentAccumulator.accumulateSegment(audioData, source: source, recordingID: recordingID)
        
        // Notify delegate that a segment was accumulated
        delegate?.vadTranscriptionDidAccumulateSegment(segmentID: segmentID, source: source)
    }
    
    // MARK: - Public Methods for Accessing Accumulated Segments
    
    /// Get all accumulated VAD segments for the current recording
    func getAccumulatedSegments() -> [VADAudioSegment] {
        guard let recordingID = currentRecordingID else {
            logger.warning("No recording ID set, cannot get accumulated segments")
            return []
        }
        return segmentAccumulator.getAllAccumulatedSegments(for: recordingID)
    }
    
    /// Get all accumulated VAD segments for a specific recording
    func getAccumulatedSegments(for recordingID: String) -> [VADAudioSegment] {
        return segmentAccumulator.getAllAccumulatedSegments(for: recordingID)
    }
    
    /// Clear accumulated segments for the current recording
    func clearAccumulatedSegments() {
        guard let recordingID = currentRecordingID else {
            logger.warning("No recording ID set, cannot clear accumulated segments")
            return
        }
        segmentAccumulator.clearSegments(for: recordingID)
    }
    
    /// Clear accumulated segments for a specific recording
    func clearAccumulatedSegments(for recordingID: String) {
        segmentAccumulator.clearSegments(for: recordingID)
    }

}

protocol VADTranscriptionCoordinatorDelegate: AnyObject {
    func vadTranscriptionDidDetectSpeechStart()
    func vadTranscriptionDidConfirmSpeechStart()
    func vadTranscriptionDidDetectMisfire()
    func vadTranscriptionDidComplete(_ segment: StreamingTranscriptionSegment)
    func vadTranscriptionDidFail(segmentID: String, error: Error)
    func vadTranscriptionDidAccumulateSegment(segmentID: String, source: TranscriptionSegment.AudioSource)
}
