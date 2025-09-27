import Foundation
import OSLog

@MainActor
final class VADTranscriptionCoordinator: VADDelegate, StreamingTranscriptionDelegate, ObservableObject {
    private let logger = Logger(subsystem: AppConstants.Logging.subsystem, category: String(describing: VADTranscriptionCoordinator.self))

    @Published var isVADActive: Bool = false
    @Published var realtimeTranscriptions: [StreamingTranscriptionSegment] = []
    @Published var currentSpeechProbability: Float = 0.0

    private let streamingTranscriptionService: StreamingTranscriptionService
    private var pendingTranscriptionTasks: Set<Task<Void, Never>> = []

    weak var delegate: VADTranscriptionCoordinatorDelegate?

    init(streamingTranscriptionService: StreamingTranscriptionService) {
        self.streamingTranscriptionService = streamingTranscriptionService
        self.streamingTranscriptionService.delegate = self
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

        logger.info("VAD transcription coordinator stopped")
    }

    func clearTranscriptions() {
        realtimeTranscriptions.removeAll()
        streamingTranscriptionService.clearTranscriptions()
    }

    // MARK: - VADDelegate

    func vadDidDetectEvent(_ event: VADEvent) {
        guard isVADActive else { return }

        switch event {
        case .speechStart:
            logger.debug("VAD detected speech start")
            delegate?.vadTranscriptionDidDetectSpeechStart()

        case .speechRealStart:
            logger.debug("VAD confirmed real speech start")
            delegate?.vadTranscriptionDidConfirmSpeechStart()

        case .speechEnd(let audioData):
            logger.info("VAD detected speech end, processing audio data: \(audioData.count) bytes")
            print("🔥 VAD: Speech end detected! Audio data size: \(audioData.count) bytes")
            processAudioSegment(audioData)

        case .vadMisfire:
            logger.debug("VAD misfire detected")
            delegate?.vadTranscriptionDidDetectMisfire()
        }
    }

    func vadDidProcessFrame(_ probability: Float, _ audioFrame: [Float]) {
        currentSpeechProbability = probability
    }

    // MARK: - StreamingTranscriptionDelegate

    nonisolated func streamingTranscriptionDidComplete(_ segment: StreamingTranscriptionSegment) {
        Task { @MainActor in
            streamingTranscriptionDidCompleteInternal(segment)
        }
    }

    private func streamingTranscriptionDidCompleteInternal(_ segment: StreamingTranscriptionSegment) {
        realtimeTranscriptions.append(segment)

        print("✅ VAD: Transcription result received: '\(segment.text)' (segment \(segment.id))")
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

    private func processAudioSegment(_ audioData: Data) {
        let segmentID = UUID().uuidString

        print("🎙️ VAD: Processing audio segment \(segmentID), size: \(audioData.count) bytes")
        
        // Debug: Check if audio data looks like a valid WAV file
        if audioData.count >= 44 {
            let header = String(data: audioData.prefix(4), encoding: .ascii) ?? "unknown"
            print("🎙️ VAD: Audio data header: '\(header)' (should be 'RIFF')")
            
            let waveHeader = String(data: audioData.subdata(in: 8..<12), encoding: .ascii) ?? "unknown"
            print("🎙️ VAD: WAVE header: '\(waveHeader)' (should be 'WAVE')")
        } else {
            print("🎙️ VAD: Audio data too small to be valid WAV file")
        }

        let task = Task {
            print("🎙️ VAD: Starting transcription for segment \(segmentID)")
            await streamingTranscriptionService.transcribeAudioSegment(audioData, segmentID: segmentID)
            print("🎙️ VAD: Completed transcription for segment \(segmentID)")

            // Remove completed task from pending set
            await MainActor.run {
                self.pendingTranscriptionTasks = self.pendingTranscriptionTasks.filter { !$0.isCancelled }
            }
        }

        pendingTranscriptionTasks.insert(task)
    }

}

protocol VADTranscriptionCoordinatorDelegate: AnyObject {
    func vadTranscriptionDidDetectSpeechStart()
    func vadTranscriptionDidConfirmSpeechStart()
    func vadTranscriptionDidDetectMisfire()
    func vadTranscriptionDidComplete(_ segment: StreamingTranscriptionSegment)
    func vadTranscriptionDidFail(segmentID: String, error: Error)
}