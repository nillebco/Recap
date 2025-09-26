import Foundation
import AVFoundation

enum VADEvent {
    case speechStart
    case speechRealStart
    case speechEnd(audioData: Data)
    case vadMisfire
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
    func vadDidProcessFrame(_ probability: Float, _ audioFrame: [Float])
}

typealias ProbabilityFunction = ([Float]) -> Float