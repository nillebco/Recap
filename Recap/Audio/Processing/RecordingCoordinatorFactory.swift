import Foundation

extension RecordingCoordinator {
    static func createDefault() -> RecordingCoordinator {
        let microphoneCapture = MicrophoneCapture()
        let coordinator = RecordingCoordinator(
            appDetectionService: MeetingAppDetectionService(processController: nil),
            sessionManager: RecordingSessionManager(microphoneCapture: microphoneCapture),
            fileManager: RecordingFileManager(),
            microphoneCapture: microphoneCapture
        )
        coordinator.setupProcessController()
        return coordinator
    }
}
