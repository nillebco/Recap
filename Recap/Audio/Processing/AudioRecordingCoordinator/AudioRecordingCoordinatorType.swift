import Foundation

protocol AudioRecordingCoordinatorType {
    var currentMicrophoneLevel: Float { get }
    var currentSystemAudioLevel: Float { get }
    var hasDualAudio: Bool { get }
    var recordedFiles: RecordedFiles { get }

    // VAD properties
    var isVADEnabled: Bool { get }
    var currentSpeechProbability: Float { get }
    var isSpeaking: Bool { get }

    func start() async throws
    func stop()

    // VAD methods
    func enableVAD(configuration: VADConfiguration?, delegate: VADTranscriptionCoordinatorDelegate?, recordingID: String?) async
    func disableVAD() async
    func pauseVAD() async
    func resumeVAD() async
    
    // VAD transcription access
    func getVADTranscriptions() async -> [StreamingTranscriptionSegment]
    func getVADSegments(for recordingID: String) async -> [VADAudioSegment]
    func getVADTranscriptionCoordinator() -> VADTranscriptionCoordinator?
}