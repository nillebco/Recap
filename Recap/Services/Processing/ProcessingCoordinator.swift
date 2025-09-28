import Foundation
import Combine
import OSLog

@MainActor
final class ProcessingCoordinator: ProcessingCoordinatorType {
    private let logger = Logger(subsystem: AppConstants.Logging.subsystem, category: String(describing: ProcessingCoordinator.self))
    weak var delegate: ProcessingCoordinatorDelegate?
    
    @Published private(set) var currentProcessingState: ProcessingState = .idle
    
    private let recordingRepository: RecordingRepositoryType
    private let summarizationService: SummarizationServiceType
    private let transcriptionService: TranscriptionServiceType
    private let userPreferencesRepository: UserPreferencesRepositoryType
    private let eventFileManager: EventFileManaging
    private var systemLifecycleManager: SystemLifecycleManager?
    private var vadTranscriptionCoordinator: VADTranscriptionCoordinator?
    
    private var processingTask: Task<Void, Never>?
    private let processingQueue = AsyncStream<RecordingInfo>.makeStream()
    private var queueTask: Task<Void, Never>?
    private var vadTranscriptionsCache: [String: [StreamingTranscriptionSegment]] = [:]
    
    init(
        recordingRepository: RecordingRepositoryType,
        summarizationService: SummarizationServiceType,
        transcriptionService: TranscriptionServiceType,
        userPreferencesRepository: UserPreferencesRepositoryType,
        eventFileManager: EventFileManaging
    ) {
        self.recordingRepository = recordingRepository
        self.summarizationService = summarizationService
        self.transcriptionService = transcriptionService
        self.userPreferencesRepository = userPreferencesRepository
        self.eventFileManager = eventFileManager
        
        startQueueProcessing()
    }
    
    func setSystemLifecycleManager(_ manager: SystemLifecycleManager) {
        self.systemLifecycleManager = manager
        manager.delegate = self
    }
    
    func setVADTranscriptionCoordinator(_ coordinator: VADTranscriptionCoordinator) {
        self.vadTranscriptionCoordinator = coordinator
        // Set the event file manager on the VAD coordinator for real-time segment transcription
        coordinator.setEventFileManager(eventFileManager)
    }
    
    func startProcessing(recordingInfo: RecordingInfo) async {
        processingQueue.continuation.yield(recordingInfo)
    }
    
    func startProcessing(recordingInfo: RecordingInfo, vadTranscriptions: [StreamingTranscriptionSegment]?) async {
        // Store VAD transcriptions for this recording
        if let vadTranscriptions = vadTranscriptions {
            vadTranscriptionsCache[recordingInfo.id] = vadTranscriptions
        }
        processingQueue.continuation.yield(recordingInfo)
    }
    
    func cancelProcessing(recordingID: String) async {
        guard case .processing(let currentID) = currentProcessingState,
              currentID == recordingID else { return }
        
        processingTask?.cancel()
        currentProcessingState = .idle

        try? await recordingRepository.updateRecordingState(
            id: recordingID,
            state: .recorded,
            errorMessage: "Processing cancelled"
        )
        
        delegate?.processingDidFail(recordingID: recordingID, error: .cancelled)
    }
    
    func retryProcessing(recordingID: String) async {
        guard let recording = try? await recordingRepository.fetchRecording(id: recordingID),
              recording.canRetry else { return }
        
        await startProcessing(recordingInfo: recording)
    }
    
    private func startQueueProcessing() {
        queueTask = Task {
            for await recording in processingQueue.stream {
                guard !Task.isCancelled else { break }
                
                currentProcessingState = .processing(recordingID: recording.id)
                delegate?.processingDidStart(recordingID: recording.id)
                
                processingTask = Task {
                    await processRecording(recording)
                }
                
                await processingTask?.value
                currentProcessingState = .idle
            }
        }
    }
    
    private func processRecording(_ recording: RecordingInfo) async {
        let startTime = Date()

        do {
            // Files are already in the correct location, just copy VAD segments if they exist
            try await copyVADSegmentsToEventDirectory(recording)

            // Get VAD transcriptions for this recording if available
            let vadTranscriptions = vadTranscriptionsCache[recording.id]

            // Try to get VAD segments from the VAD system if available
            let vadSegments = await getVADSegmentsForRecording(recording.id)

            let transcriptionText = try await performTranscriptionPhase(recording, vadTranscriptions: vadTranscriptions, vadSegments: vadSegments)
            guard !Task.isCancelled else { throw ProcessingError.cancelled }
            
            // Clear VAD transcriptions from cache after processing
            vadTranscriptionsCache.removeValue(forKey: recording.id)
            
            let autoSummarizeEnabled = await checkAutoSummarizeEnabled()
            
            if autoSummarizeEnabled {
                let summaryText = try await performSummarizationPhase(recording, transcriptionText: transcriptionText)
                guard !Task.isCancelled else { throw ProcessingError.cancelled }
                
                await completeProcessing(
                    recording: recording,
                    transcriptionText: transcriptionText,
                    summaryText: summaryText,
                    startTime: startTime
                )
            } else {
                await completeProcessingWithoutSummary(
                    recording: recording,
                    transcriptionText: transcriptionText,
                    startTime: startTime
                )
            }
            
        } catch let error as ProcessingError {
            await handleProcessingError(error, for: recording)
        } catch {
            let processingError = ProcessingError.coreDataError(error.localizedDescription)
            await handleProcessingError(processingError, for: recording)
        }
    }
    
    private func performTranscriptionPhase(_ recording: RecordingInfo, vadTranscriptions: [StreamingTranscriptionSegment]? = nil, vadSegments: [VADAudioSegment]? = nil) async throws -> String {
        try await updateRecordingState(recording.id, state: .transcribing)
        
        let transcriptionResult = try await performTranscription(recording, vadTranscriptions: vadTranscriptions, vadSegments: vadSegments)
        
        try await recordingRepository.updateRecordingTranscription(
            id: recording.id,
            transcriptionText: transcriptionResult.combinedText
        )
        
        // Save timestamped transcription data if available
        if let timestampedTranscription = transcriptionResult.timestampedTranscription {
            try await recordingRepository.updateRecordingTimestampedTranscription(
                id: recording.id,
                timestampedTranscription: timestampedTranscription
            )
        }
        
        // Always save enhanced transcription to markdown file (no segment references)
        let sources: [AudioSource] = [.systemAudio] + (recording.hasMicrophoneAudio ? [.microphone] : [])
        try eventFileManager.writeTranscription(
            transcriptionResult.combinedText,
            for: recording.id,
            duration: recording.duration,
            model: transcriptionResult.modelUsed,
            sources: sources
        )
        
        try await updateRecordingState(recording.id, state: .transcribed)
        
        return transcriptionResult.combinedText
    }
    
    private func performSummarizationPhase(_ recording: RecordingInfo, transcriptionText: String) async throws -> String {
        try await updateRecordingState(recording.id, state: .summarizing)
        
        let summaryRequest = buildSummarizationRequest(
            recording: recording,
            transcriptionText: transcriptionText
        )
        
        let summaryResult = try await summarizationService.summarize(summaryRequest)
        
        try await recordingRepository.updateRecordingSummary(
            id: recording.id,
            summaryText: summaryResult.summary
        )
        
        try eventFileManager.writeSummary(summaryResult.summary, for: recording.id)
        
        return summaryResult.summary
    }
    
    private func buildSummarizationRequest(recording: RecordingInfo, transcriptionText: String) -> SummarizationRequest {
        let metadata = SummarizationRequest.TranscriptMetadata(
            duration: recording.duration ?? 0,
            participants: recording.hasMicrophoneAudio ? ["User", "System Audio"] : ["System Audio"],
            recordingDate: recording.startDate,
            applicationName: recording.applicationName
        )
        
        return SummarizationRequest(
            transcriptText: transcriptionText,
            metadata: metadata,
            options: .default
        )
    }
    
    private func updateRecordingState(_ recordingID: String, state: RecordingProcessingState) async throws {
        try await recordingRepository.updateRecordingState(
            id: recordingID,
            state: state,
            errorMessage: nil
        )
        delegate?.processingStateDidChange(recordingID: recordingID, newState: state)
    }
    
    private func completeProcessing(
        recording: RecordingInfo,
        transcriptionText: String,
        summaryText: String,
        startTime: Date
    ) async {
        do {
            try await updateRecordingState(recording.id, state: .completed)
            
            let result = ProcessingResult(
                recordingID: recording.id,
                transcriptionText: transcriptionText,
                summaryText: summaryText,
                processingDuration: Date().timeIntervalSince(startTime)
            )
            
            delegate?.processingDidComplete(recordingID: recording.id, result: result)
        } catch {
            await handleProcessingError(ProcessingError.coreDataError(error.localizedDescription), for: recording)
        }
    }
    
    private func completeProcessingWithoutSummary(
        recording: RecordingInfo,
        transcriptionText: String,
        startTime: Date
    ) async {
        do {
            try await updateRecordingState(recording.id, state: .completed)
            
            let result = ProcessingResult(
                recordingID: recording.id,
                transcriptionText: transcriptionText,
                summaryText: "",
                processingDuration: Date().timeIntervalSince(startTime)
            )
            
            delegate?.processingDidComplete(recordingID: recording.id, result: result)
        } catch {
            await handleProcessingError(ProcessingError.coreDataError(error.localizedDescription), for: recording)
        }
    }
    
    private func performTranscription(_ recording: RecordingInfo, vadTranscriptions: [StreamingTranscriptionSegment]? = nil, vadSegments: [VADAudioSegment]? = nil) async throws -> TranscriptionResult {
        // Always use the full audio file for end-of-event transcription for better quality
        // VAD segments are only used for real-time transcription
        do {
            let microphoneURL = recording.hasMicrophoneAudio ? recording.microphoneURL : nil
            return try await transcriptionService.transcribe(
                audioURL: recording.recordingURL,
                microphoneURL: microphoneURL
            )
        } catch let error as TranscriptionError {
            throw ProcessingError.transcriptionFailed(error.localizedDescription)
        } catch {
            throw ProcessingError.transcriptionFailed(error.localizedDescription)
        }
    }
    
    private func buildTranscriptionResultFromVAD(_ segments: [StreamingTranscriptionSegment]) -> TranscriptionResult {
        // Separate system audio and microphone transcriptions
        let systemAudioSegments = segments.filter { $0.source == .systemAudio }
        let microphoneSegments = segments.filter { $0.source == .microphone }
        
        let systemAudioText = systemAudioSegments.map { $0.text }.joined(separator: " ")
        let microphoneText = microphoneSegments.isEmpty ? nil : microphoneSegments.map { $0.text }.joined(separator: " ")
        
        let combinedText = buildCombinedText(
            systemAudioText: systemAudioText,
            microphoneText: microphoneText
        )
        
        // Create timestamped transcription
        let transcriptionSegments = segments.map { segment in
            TranscriptionSegment(
                text: segment.text,
                startTime: segment.timestamp.timeIntervalSince1970,
                endTime: segment.timestamp.timeIntervalSince1970 + segment.duration,
                source: segment.source
            )
        }
        let timestampedTranscription = TimestampedTranscription(segments: transcriptionSegments)
        
        return TranscriptionResult(
            systemAudioText: systemAudioText,
            microphoneText: microphoneText,
            combinedText: combinedText,
            transcriptionDuration: segments.reduce(0) { $0 + $1.duration },
            modelUsed: "VAD",
            timestampedTranscription: timestampedTranscription
        )
    }
    
    private func buildTranscriptionResultFromVADSegments(_ vadSegments: [VADAudioSegment]) async -> TranscriptionResult {
        // Transcribe the accumulated VAD segments
        let vadTranscriptionService = VADTranscriptionService(transcriptionService: transcriptionService)
        let transcriptionSegments = await vadTranscriptionService.transcribeAccumulatedSegments(vadSegments)
        
        // Use the existing method to build the result
        return buildTranscriptionResultFromVAD(transcriptionSegments)
    }
    
    private func buildStructuredTranscriptionFromVADSegments(_ vadSegments: [VADAudioSegment]) async -> [StructuredTranscription] {
        // Transcribe the accumulated VAD segments with structured output
        let vadTranscriptionService = VADTranscriptionService(transcriptionService: transcriptionService)
        return await vadTranscriptionService.transcribeAccumulatedSegmentsStructured(vadSegments)
    }
    
    private func handleProcessingError(_ error: ProcessingError, for recording: RecordingInfo) async {
        let failureState: RecordingProcessingState
        
        switch error {
        case .transcriptionFailed:
            failureState = .transcriptionFailed
        case .summarizationFailed:
            failureState = .summarizationFailed
        default:
            failureState = recording.state == .transcribing ? .transcriptionFailed : .summarizationFailed
        }
        
        do {
            try await recordingRepository.updateRecordingState(
                id: recording.id,
                state: failureState,
                errorMessage: error.localizedDescription
            )
            delegate?.processingStateDidChange(recordingID: recording.id, newState: failureState)
        } catch {
            print("Failed to update recording state after error: \(error)")
        }
        
        delegate?.processingDidFail(recordingID: recording.id, error: error)
    }
    
    private func checkAutoSummarizeEnabled() async -> Bool {
        do {
            let preferences = try await userPreferencesRepository.getOrCreatePreferences()
            return preferences.autoSummarizeEnabled
        } catch {
            return true
        }
    }
    
    func clearVADTranscriptionsCache() {
        vadTranscriptionsCache.removeAll()
    }
    
    func getVADSegments(for recordingID: String) async -> [VADAudioSegment] {
        return await vadTranscriptionCoordinator?.getAccumulatedSegments(for: recordingID) ?? []
    }
    
    func getStructuredTranscriptions(for recordingID: String) async -> [StructuredTranscription] {
        let vadSegments = await getVADSegments(for: recordingID)
        return await buildStructuredTranscriptionFromVADSegments(vadSegments)
    }
    
    private func getVADSegmentsForRecording(_ recordingID: String) async -> [VADAudioSegment] {
        // Try to get VAD segments from the VAD coordinator if available
        if let vadCoordinator = vadTranscriptionCoordinator {
            return await vadCoordinator.getAccumulatedSegments(for: recordingID)
        }
        
        // Fallback: return empty array if no VAD coordinator is available
        logger.warning("No VAD coordinator available, cannot get VAD segments for recording \(recordingID)")
        return []
    }
    
    private func buildCombinedText(systemAudioText: String, microphoneText: String?) -> String {
        var combinedText = systemAudioText
        
        if let microphoneText = microphoneText, !microphoneText.isEmpty {
            combinedText += "\n\n[User Audio Note: The following was spoken by the user during this recording. Please incorporate this context when creating the meeting summary:]\n\n"
            combinedText += microphoneText
            combinedText += "\n\n[End of User Audio Note. Please align the above user input with the meeting content for a comprehensive summary.]"
        }
        
        return combinedText
    }
    
    deinit {
        queueTask?.cancel()
        processingTask?.cancel()
    }
}

extension ProcessingCoordinator: SystemLifecycleDelegate {
    func systemWillSleep() {
        guard case .processing(let recordingID) = currentProcessingState else { return }
        currentProcessingState = .paused(recordingID: recordingID)
        processingTask?.cancel()
    }
    
    func systemDidWake() {
        guard case .paused(let recordingID) = currentProcessingState else { return }
        
        Task {
            if let recording = try? await recordingRepository.fetchRecording(id: recordingID) {
                await startProcessing(recordingInfo: recording)
            }
        }
    }
    
    // MARK: - File Organization

    private func copyVADSegmentsToEventDirectory(_ recording: RecordingInfo) async throws {
        // Copy VAD segments if they exist
        let vadSegments = await getVADSegmentsForRecording(recording.id)

        if !vadSegments.isEmpty {
            // Ensure event directory exists
            let eventDirectory = try eventFileManager.createEventDirectory(for: recording.id)

            for segment in vadSegments {
                try eventFileManager.writeAudioSegment(segment.audioData, for: recording.id, segmentID: segment.id)
            }

            logger.info("Copied \(vadSegments.count) VAD segments to event directory: \(eventDirectory.path)")
        }
    }
}
