import Foundation
import AVFoundation
import OSLog
import FluidAudio

@MainActor
final class VADManager: ObservableObject {
    private let logger = Logger(subsystem: AppConstants.Logging.subsystem, category: String(describing: VADManager.self))

    @Published var isVADEnabled: Bool = false
    @Published var speechProbability: Float = 0.0
    @Published var isSpeaking: Bool = false

    private var frameProcessor: FrameProcessor?
    private var configuration: VADConfiguration
    private let source: VADAudioSource
    private var detectionBuffer: [Float] = []
    private var recentSamplesBuffer: [Float] = []
    private var currentSpeechSamples: [Float] = []
    private let targetFrameSize: Int = 4096 // ~256ms at 16kHz
    private let contextDurationSeconds: Double = 2.0

    private var maxRecentSampleCount: Int {
        let desiredSampleCount = Int(AudioFormatConverter.vadTargetSampleRate * contextDurationSeconds)
        return max(desiredSampleCount, targetFrameSize)
    }

    weak var delegate: VADDelegate? {
        didSet {
            frameProcessor?.delegate = delegate
        }
    }

    // FluidAudio VAD manager
    private var fluidAudioManager: VadManager?
    private var vadState: VadStreamState?

    init(configuration: VADConfiguration = .conservative, source: VADAudioSource) {
        self.configuration = configuration
        self.source = source
        setupFrameProcessor()
    }

    private func setupFrameProcessor() {
        let probabilityFunc: ProbabilityFunction = { [weak self] audioFrame in
            return self?.calculateEnergyBasedProbability(audioFrame) ?? 0.0
        }

        let callbacks = VADCallbacks(
            onFrameProcessed: { [weak self] probability, frame in
                Task { @MainActor in
                    self?.speechProbability = probability
                }
            },
            onVADMisfire: { [weak self] in
                self?.logger.debug("VAD misfire detected")
            },
            onSpeechStart: { [weak self] in
                Task { @MainActor in
                    self?.isSpeaking = true
                    self?.logger.info("Speech started")
                }
            },
            onSpeechRealStart: { [weak self] in
                self?.logger.info("Real speech confirmed")
            },
            onSpeechEnd: { [weak self] audioData in
                Task { @MainActor in
                    self?.isSpeaking = false
                    self?.logger.info("Speech ended, audio data: \(audioData.count) bytes")
                    guard let source = self?.source else { return }
                    self?.delegate?.vadDidDetectEvent(.speechEnd(audioData: audioData, source: source))
                }
            }
        )

        frameProcessor = FrameProcessor(
            probabilityFunction: probabilityFunc,
            configuration: configuration,
            callbacks: callbacks,
            delegate: delegate,
            source: source
        )

        frameProcessor?.delegate = delegate
    }

    func enable() async {
        isVADEnabled = true

        do {
            try await setupFluidAudio()
            logger.info("VAD enabled with FluidAudio")
        } catch {
            logger.error("Failed to setup FluidAudio, falling back to energy-based VAD: \(error)")
            // Continue with energy-based VAD fallback
        }
    }

    func disable() {
        isVADEnabled = false
        frameProcessor?.reset()
        detectionBuffer.removeAll()
        recentSamplesBuffer.removeAll()
        currentSpeechSamples.removeAll()
        speechProbability = 0.0
        isSpeaking = false

        // Reset FluidAudio state
        fluidAudioManager = nil
        vadState = nil

        logger.info("VAD disabled")
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        print("🎤 VADManager.processAudioBuffer called with \(buffer.frameLength) frames")
        guard isVADEnabled else {
            print("🎤 VADManager: VAD is disabled, isVADEnabled = \(isVADEnabled)")
            return
        }

        guard let vadFormat = AudioFormatConverter.convertToVADFormat(buffer) else {
            logger.warning("Failed to convert audio buffer to VAD format")
            print("🎤 VADManager: AudioFormatConverter.convertToVADFormat failed")
            return
        }

        print("🎤 VADManager: Converted buffer to VAD format, \(vadFormat.count) samples")
        let isUsingFluidAudioBuffers = fluidAudioManager != nil

        if isUsingFluidAudioBuffers {
            appendToRecentSamplesBuffer(vadFormat)
            print("🎤 VADManager: Recent samples buffer size: \(recentSamplesBuffer.count) (limit: \(maxRecentSampleCount))")

            if isSpeaking {
                currentSpeechSamples.append(contentsOf: vadFormat)
                print("🎤 VADManager: Capturing speech audio, total samples collected: \(currentSpeechSamples.count)")
            }
        }

        detectionBuffer.append(contentsOf: vadFormat)
        print("🎤 VADManager: Detection buffer size: \(detectionBuffer.count) samples (target frame: \(targetFrameSize))")

        if detectionBuffer.count >= targetFrameSize {
            print("🎤 VADManager: Detection buffer ready for chunk processing")

            while detectionBuffer.count >= targetFrameSize {
                let chunk = Array(detectionBuffer.prefix(targetFrameSize))
                detectionBuffer.removeFirst(targetFrameSize)

                print("🎤 VADManager: Processing VAD chunk with \(chunk.count) samples (remaining detection buffer: \(detectionBuffer.count))")
                processVADChunk(chunk)
            }
        } else {
            // Process the incoming samples to keep VAD probabilities updated
            print("🎤 VADManager: Processing \(vadFormat.count) samples for interim VAD detection")
            processVADChunk(vadFormat)
        }
    }

    private func setupFluidAudio() async throws {
        fluidAudioManager = try await VadManager()
        vadState = await fluidAudioManager?.makeStreamState()
        logger.info("FluidAudio VAD manager initialized successfully")
        print("🎤 VAD: FluidAudio manager initialized: \(fluidAudioManager != nil), state: \(vadState != nil)")
    }

    private func processVADChunk(_ chunk: [Float]) {
        print("🎤 VADManager: processVADChunk called with \(chunk.count) samples")
        print("🎤 VADManager: FluidAudio available: \(fluidAudioManager != nil), VAD state: \(vadState != nil)")

        if let fluidAudioManager = fluidAudioManager,
           let vadState = vadState {
            // Use FluidAudio for VAD processing
            print("🎤 VADManager: Using FluidAudio for processing")
            processWithFluidAudio(chunk: chunk, manager: fluidAudioManager, state: vadState)
        } else {
            // Fallback to energy-based processing
            print("🎤 VADManager: Using energy-based processing (fallback)")
            processWithEnergyBased(chunk: chunk)
        }
    }

    private func processWithFluidAudio(chunk: [Float], manager: VadManager, state: VadStreamState) {
        print("🎤 VADManager: FluidAudio processing chunk with \(chunk.count) samples")
        Task {
            do {
                let result = try await manager.processStreamingChunk(
                    chunk,
                    state: state,
                    config: .default,
                    returnSeconds: true,
                    timeResolution: 2
                )

                await MainActor.run {
                    self.vadState = result.state
                    print("🎤 VADManager: FluidAudio result - event: \(result.event != nil ? String(describing: result.event!.kind) : "none")")

                    if let event = result.event {
                        switch event.kind {
                        case .speechStart:
                            logger.info("FluidAudio detected speech start at \(event.time ?? 0)s")
                            isSpeaking = true
                            beginSpeechCapture()
                            delegate?.vadDidDetectEvent(.speechStart(source: source))

                        case .speechEnd:
                            logger.info("FluidAudio detected speech end at \(event.time ?? 0)s")
                            isSpeaking = false

                            let audioData = finalizeSpeechCapture()
                            print("🎤 VAD: Speech end - created audio data: \(audioData.count) bytes")

                            delegate?.vadDidDetectEvent(.speechEnd(audioData: audioData, source: source))
                        }
                    } else {
                        print("🎤 VADManager: FluidAudio - no event detected")
                    }
                }
            } catch {
                await MainActor.run {
                    logger.error("FluidAudio processing failed: \(error)")
                    print("🎤 VADManager: FluidAudio error: \(error)")
                    // Fall back to energy-based processing for this chunk
                    processWithEnergyBased(chunk: chunk)
                }
            }
        }
    }

    private func processWithEnergyBased(chunk: [Float]) {
        let frameSize = configuration.frameSamples
        var frameIndex = 0

        print("🎤 VAD: Using energy-based processing with \(chunk.count) samples, frame size: \(frameSize)")

        while frameIndex + frameSize <= chunk.count {
            let frame = Array(chunk[frameIndex..<frameIndex + frameSize])
            frameProcessor?.process(frame: frame)
            frameIndex += frameSize
        }
        
        print("🎤 VAD: Processed \(frameIndex / frameSize) frames with energy-based VAD")
    }

    private func appendToRecentSamplesBuffer(_ samples: [Float]) {
        guard !samples.isEmpty else { return }

        recentSamplesBuffer.append(contentsOf: samples)

        let overflow = recentSamplesBuffer.count - maxRecentSampleCount
        if overflow > 0 {
            recentSamplesBuffer.removeFirst(overflow)
            print("🎤 VADManager: Trimmed recent samples buffer by \(overflow) samples (current size: \(recentSamplesBuffer.count))")
        }
    }

    private func beginSpeechCapture() {
        currentSpeechSamples = recentSamplesBuffer
        print("🎤 VAD: Speech capture initialized with \(currentSpeechSamples.count) context samples")
    }

    private func finalizeSpeechCapture() -> Data {
        var samples = currentSpeechSamples

        if samples.isEmpty {
            print("🎤 VAD: WARNING - No speech samples captured, falling back to recent buffer (\(recentSamplesBuffer.count) samples)")
            samples = recentSamplesBuffer
        }

        let audioData = createAudioData(from: samples)

        currentSpeechSamples.removeAll()
        recentSamplesBuffer.removeAll()

        return audioData
    }

    private func createAudioData(from samples: [Float]) -> Data {
        print("🎤 VAD: Preparing audio data export with \(samples.count) samples")

        if samples.isEmpty {
            print("🎤 VAD: WARNING - Attempting to export empty speech buffer")
            return Data()
        }

        if samples.count < 1000 {
            print("🎤 VAD: WARNING - Very little audio data captured: \(samples.count) samples")
        }

        let audioData = AudioFormatConverter.vadFramesToAudioData([samples])

        print("🎤 VAD: Created audio data: \(audioData.count) bytes from \(samples.count) samples")

        if audioData.count < 1000 {
            print("🎤 VAD: WARNING - Exported audio data is very small: \(audioData.count) bytes")
        }

        return audioData
    }

    // Temporary energy-based VAD until FluidAudio is integrated
    private func calculateEnergyBasedProbability(_ frame: [Float]) -> Float {
        guard !frame.isEmpty else { return 0.0 }

        let energy = frame.reduce(0.0) { $0 + $1 * $1 } / Float(frame.count)
        let logEnergy = log10(max(energy, 1e-10))

        // Simple energy-based thresholding
        let normalizedEnergy = max(0.0, min(1.0, (logEnergy + 5.0) / 3.0))

        return normalizedEnergy
    }

    func pause() {
        frameProcessor?.pause()
    }

    func resume() {
        frameProcessor?.resume()
    }

    func reset() {
        frameProcessor?.reset()
        detectionBuffer.removeAll()
        recentSamplesBuffer.removeAll()
        currentSpeechSamples.removeAll()
        speechProbability = 0.0
        isSpeaking = false

        // Reset FluidAudio state
        Task {
            vadState = await fluidAudioManager?.makeStreamState()
        }
    }
}
