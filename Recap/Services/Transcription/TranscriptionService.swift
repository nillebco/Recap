import Foundation
import WhisperKit

@MainActor
final class TranscriptionService: TranscriptionServiceType {
    private let whisperModelRepository: WhisperModelRepositoryType
    private var whisperKit: WhisperKit?
    private var loadedModelName: String?
    
    init(whisperModelRepository: WhisperModelRepositoryType) {
        self.whisperModelRepository = whisperModelRepository
    }
    
    func transcribe(audioURL: URL, microphoneURL: URL?) async throws -> TranscriptionResult {
        let startTime = Date()
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.audioFileNotFound
        }
        
        try await ensureModelLoaded()
        
        guard let whisperKit = self.whisperKit,
              let modelName = self.loadedModelName else {
            throw TranscriptionError.modelNotAvailable
        }
        
        let systemAudioText = try await transcribeAudioFile(audioURL, with: whisperKit)
        
        var microphoneText: String?
        if let microphoneURL = microphoneURL,
           FileManager.default.fileExists(atPath: microphoneURL.path) {
            microphoneText = try await transcribeAudioFile(microphoneURL, with: whisperKit)
        }
        
        let combinedText = buildCombinedText(
            systemAudioText: systemAudioText,
            microphoneText: microphoneText
        )
        
        let duration = Date().timeIntervalSince(startTime)
        
        return TranscriptionResult(
            systemAudioText: systemAudioText,
            microphoneText: microphoneText,
            combinedText: combinedText,
            transcriptionDuration: duration,
            modelUsed: modelName
        )
    }
    
    func ensureModelLoaded() async throws {
        let selectedModel = try await whisperModelRepository.getSelectedModel()
        
        guard let model = selectedModel else {
            throw TranscriptionError.modelNotAvailable
        }
        
        if loadedModelName != model.name || whisperKit == nil {
            try await loadModel(model.name, isDownloaded: model.isDownloaded)
        }
    }
    
    func getCurrentModel() async -> String? {
        loadedModelName
    }
    
    private func loadModel(_ modelName: String, isDownloaded: Bool) async throws {
        do {
            let newWhisperKit = try await WhisperKit.createWithProgress(
                model: modelName,
                modelRepo: "argmaxinc/whisperkit-coreml",
                modelFolder: nil,
                download: true,
                progressCallback: { progress in
                    // todo: notify UI?
                    print("WhisperKit download progress: \(progress.fractionCompleted)")
                }
            )

            self.whisperKit = newWhisperKit
            self.loadedModelName = modelName
            
            if !isDownloaded {
                try await whisperModelRepository.markAsDownloaded(name: modelName, sizeInMB: nil)
            }
            
        } catch {
            throw TranscriptionError.modelLoadingFailed(error.localizedDescription)
        }
    }
    
    private func transcribeAudioFile(_ url: URL, with whisperKit: WhisperKit) async throws -> String {
        do {
            let transcriptionResults = try await whisperKit.transcribe(audioPath: url.path)
            
            let text = transcriptionResults
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            
            return text
            
        } catch {
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }
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
}
