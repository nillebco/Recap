import Foundation
import AVFoundation

enum VADAudioSource: Hashable {
    case microphone
    case system

    var transcriptionSource: TranscriptionSegment.AudioSource {
        switch self {
        case .microphone:
            return .microphone
        case .system:
            return .systemAudio
        }
    }
}

enum VADEvent {
    case speechStart(source: VADAudioSource)
    case speechRealStart(source: VADAudioSource)
    case speechEnd(audioData: Data, source: VADAudioSource)
    case vadMisfire(source: VADAudioSource)
}

struct VADCallbacks {
    let onFrameProcessed: ((Float, [Float]) -> Void)?
    let onVADMisfire: (() -> Void)?
    let onSpeechStart: (() -> Void)?
    let onSpeechRealStart: (() -> Void)?
    let onSpeechEnd: ((Data) -> Void)?

    static let empty = VADCallbacks(
        onFrameProcessed: nil,
        onVADMisfire: nil,
        onSpeechStart: nil,
        onSpeechRealStart: nil,
        onSpeechEnd: nil
    )
}

protocol VADDelegate: AnyObject {
    func vadDidDetectEvent(_ event: VADEvent)
    func vadDidProcessFrame(_ probability: Float, _ audioFrame: [Float], source: VADAudioSource)
}

typealias ProbabilityFunction = ([Float]) -> Float
