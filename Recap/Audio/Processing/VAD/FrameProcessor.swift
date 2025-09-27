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
    private let source: VADAudioSource
    private var isPaused: Bool = false

    init(
        probabilityFunction: @escaping ProbabilityFunction,
        configuration: VADConfiguration = .default,
        callbacks: VADCallbacks = .empty,
        delegate: VADDelegate? = nil,
        source: VADAudioSource
    ) {
        self.probabilityFunction = probabilityFunction
        self.configuration = configuration
        self.callbacks = callbacks
        self.delegate = delegate
        self.preRingBuffer = []
        self.preRingBuffer.reserveCapacity(configuration.preSpeechPadFrames)
        self.source = source
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
        delegate?.vadDidProcessFrame(speechProbability, frame, source: source)

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

        if speechFrameCount % 20 == 0 { // Log every 20th frame to avoid spam
            print("🟢 VAD: Speech frame \(speechFrameCount), total active frames: \(activeFrames.count), frame size: \(frame.count)")
        }

        if !realStartFired && speechFrameCount >= configuration.minSpeechFrames {
            realStartFired = true
            callbacks.onSpeechRealStart?()
            delegate?.vadDidDetectEvent(.speechRealStart(source: source))
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
        delegate?.vadDidDetectEvent(.speechStart(source: source))
    }

    private func finalizeSegment() {
        let totalFrames = speechFrameCount
        let audioData = concatenateFramesToData(activeFrames)

        print("🎯 VAD FrameProcessor: Finalizing segment")
        print("🎯 Speech frame count: \(totalFrames)")
        print("🎯 Active frames collected: \(activeFrames.count)")
        print("🎯 Total samples in segment: \(activeFrames.flatMap { $0 }.count)")
        print("🎯 Audio data size: \(audioData.count) bytes")

        activeFrames.removeAll()
        inSpeech = false
        speechFrameCount = 0
        realStartFired = false
        lowProbabilityStreak = 0

        if totalFrames < configuration.minSpeechFrames {
            print("🎯 VAD misfire: \(totalFrames) < \(configuration.minSpeechFrames)")
            callbacks.onVADMisfire?()
            delegate?.vadDidDetectEvent(.vadMisfire(source: source))
            return
        }

        callbacks.onSpeechEnd?(audioData)
        delegate?.vadDidDetectEvent(.speechEnd(audioData: audioData, source: source))
    }

    private func concatenateFramesToData(_ frames: [[Float]]) -> Data {
        guard !frames.isEmpty else { return Data() }

        let flatArray = frames.flatMap { $0 }
        return Data(bytes: flatArray, count: flatArray.count * MemoryLayout<Float>.size)
    }
}
