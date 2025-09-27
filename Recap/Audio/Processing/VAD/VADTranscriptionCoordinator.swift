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

        let task = Task {
            await streamingTranscriptionService.transcribeAudioSegment(audioData, segmentID: segmentID)

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