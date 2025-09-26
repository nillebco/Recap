import Foundation
import OrderedCollections

final class FrameProcessor {
    private let probabilityFunction: ProbabilityFunction
    private let configuration: VADConfiguration
    private let callbacks: VADCallbacks
    weak var delegate: VADDelegate?

    private var preRingBuffer: [[Float]]
    private var activeFrames: [[Float]] = []
    private var inSpeech: Bool = false
    private var speechFrameCount: Int = 0
    private var realStartFired: Bool = false
    private var lowProbabilityStreak: Int = 0
    private var isPaused: Bool = false

    init(
        probabilityFunction: @escaping ProbabilityFunction,
        configuration: VADConfiguration = .default,
        callbacks: VADCallbacks = .empty,
        delegate: VADDelegate? = nil
    ) {
        self.probabilityFunction = probabilityFunction
        self.configuration = configuration
        self.callbacks = callbacks
        self.delegate = delegate
        self.preRingBuffer = []
        self.preRingBuffer.reserveCapacity(configuration.preSpeechPadFrames)
    }

    func pause() {
        guard !isPaused else { return }

        if configuration.submitUserSpeechOnPause && inSpeech {
            finalizeSegment()
        }
        isPaused = true
    }

    func resume() {
        isPaused = false
    }

    func reset() {
        preRingBuffer.removeAll()
        activeFrames.removeAll()
        inSpeech = false
        speechFrameCount = 0
        realStartFired = false
        lowProbabilityStreak = 0
        isPaused = false
    }

    func process(frame: [Float]) {
        guard !isPaused else { return }

        let speechProbability = probabilityFunction(frame)

        callbacks.onFrameProcessed?(speechProbability, frame)
        delegate?.vadDidProcessFrame(speechProbability, frame)

        if !inSpeech {
            handleIdleState(frame: frame, probability: speechProbability)
        } else {
            handleSpeakingState(frame: frame, probability: speechProbability)
        }
    }

    private func handleIdleState(frame: [Float], probability: Float) {
        if preRingBuffer.count >= configuration.preSpeechPadFrames {
            preRingBuffer.removeFirst()
        }
        preRingBuffer.append(frame)

        if probability >= configuration.positiveSpeechThreshold {
            enterSpeaking()
        }
    }

    private func handleSpeakingState(frame: [Float], probability: Float) {
        activeFrames.append(frame)
        speechFrameCount += 1

        if !realStartFired && speechFrameCount >= configuration.minSpeechFrames {
            realStartFired = true
            callbacks.onSpeechRealStart?()
            delegate?.vadDidDetectEvent(.speechRealStart)
        }

        if probability < configuration.negativeSpeechThreshold {
            lowProbabilityStreak += 1
            if lowProbabilityStreak > configuration.redemptionFrames {
                finalizeSegment()
            }
        } else {
            lowProbabilityStreak = 0
        }
    }

    private func enterSpeaking() {
        activeFrames = Array(preRingBuffer)
        preRingBuffer.removeAll()
        inSpeech = true
        speechFrameCount = activeFrames.count
        realStartFired = false
        lowProbabilityStreak = 0

        callbacks.onSpeechStart?()
        delegate?.vadDidDetectEvent(.speechStart)
    }

    private func finalizeSegment() {
        let totalFrames = speechFrameCount
        let audioData = concatenateFramesToData(activeFrames)

        activeFrames.removeAll()
        inSpeech = false
        speechFrameCount = 0
        realStartFired = false
        lowProbabilityStreak = 0

        if totalFrames < configuration.minSpeechFrames {
            callbacks.onVADMisfire?()
            delegate?.vadDidDetectEvent(.vadMisfire)
            return
        }

        callbacks.onSpeechEnd?(audioData)
        delegate?.vadDidDetectEvent(.speechEnd(audioData: audioData))
    }

    private func concatenateFramesToData(_ frames: [[Float]]) -> Data {
        guard !frames.isEmpty else { return Data() }

        let flatArray = frames.flatMap { $0 }
        return Data(bytes: flatArray, count: flatArray.count * MemoryLayout<Float>.size)
    }
}