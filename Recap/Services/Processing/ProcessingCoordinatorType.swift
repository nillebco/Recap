import Foundation
#if MOCKING
import Mockable
#endif

@MainActor
#if MOCKING
@Mockable
#endif
protocol ProcessingCoordinatorType {
    var delegate: ProcessingCoordinatorDelegate? { get set }
    var currentProcessingState: ProcessingState { get }
    
    func startProcessing(recordingInfo: RecordingInfo) async
    func startProcessing(recordingInfo: RecordingInfo, vadTranscriptions: [StreamingTranscriptionSegment]?) async
    func cancelProcessing(recordingID: String) async
    func retryProcessing(recordingID: String) async
    
    // VAD segment access
    func getVADSegments(for recordingID: String) async -> [VADAudioSegment]
    func getStructuredTranscriptions(for recordingID: String) async -> [StructuredTranscription]
}

@MainActor
protocol ProcessingCoordinatorDelegate: AnyObject {
    func processingDidStart(recordingID: String)
    func processingDidComplete(recordingID: String, result: ProcessingResult)
    func processingDidFail(recordingID: String, error: ProcessingError)
    func processingStateDidChange(recordingID: String, newState: RecordingProcessingState)
}