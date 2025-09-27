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
    private var audioBufferAccumulator: [[Float]] = []
    private let targetFrameSize: Int = 4096 // ~256ms at 16kHz

    weak var delegate: VADDelegate?

    // FluidAudio VAD manager
    private var fluidAudioManager: VadManager?
    private var vadState: VadStreamState?

    init(configuration: VADConfiguration = .default) {
        self.configuration = configuration
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
                    self?.delegate?.vadDidDetectEvent(.speechEnd(audioData: audioData))
                }
            }
        )

        frameProcessor = FrameProcessor(
            probabilityFunction: probabilityFunc,
            configuration: configuration,
            callbacks: callbacks,
            delegate: delegate
        )
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
        audioBufferAccumulator.removeAll()
        speechProbability = 0.0
        isSpeaking = false

        // Reset FluidAudio state
        fluidAudioManager = nil
        vadState = nil

        logger.info("VAD disabled")
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isVADEnabled else { return }

        guard let vadFormat = AudioFormatConverter.convertToVADFormat(buffer) else {
            logger.warning("Failed to convert audio buffer to VAD format")
            return
        }

        audioBufferAccumulator.append(vadFormat)

        let totalSamples = audioBufferAccumulator.reduce(0) { $0 + $1.count }

        if totalSamples >= targetFrameSize {
            let combinedFrame = audioBufferAccumulator.flatMap { $0 }
            let chunk = Array(combinedFrame.prefix(targetFrameSize))

            processVADChunk(chunk)

            audioBufferAccumulator.removeAll()

            if combinedFrame.count > targetFrameSize {
                let remaining = Array(combinedFrame.dropFirst(targetFrameSize))
                audioBufferAccumulator.append(remaining)
            }
        }
    }

    private func setupFluidAudio() async throws {
        fluidAudioManager = try await VadManager()
        vadState = await fluidAudioManager?.makeStreamState()
        logger.info("FluidAudio VAD manager initialized successfully")
    }

    private func processVADChunk(_ chunk: [Float]) {
        if let fluidAudioManager = fluidAudioManager,
           let vadState = vadState {
            // Use FluidAudio for VAD processing
            processWithFluidAudio(chunk: chunk, manager: fluidAudioManager, state: vadState)
        } else {
            // Fallback to energy-based processing
            processWithEnergyBased(chunk: chunk)
        }
    }

    private func processWithFluidAudio(chunk: [Float], manager: VadManager, state: VadStreamState) {
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

                    if let event = result.event {
                        switch event.kind {
                        case .speechStart:
                            logger.info("FluidAudio detected speech start at \(event.time ?? 0)s")
                            isSpeaking = true
                            delegate?.vadDidDetectEvent(.speechStart)

                        case .speechEnd:
                            logger.info("FluidAudio detected speech end at \(event.time ?? 0)s")
                            isSpeaking = false

                            // Create audio data from the accumulated frames
                            // Note: FluidAudio doesn't return the actual audio, so we need to
                            // use our accumulated frames for transcription
                            let audioData = createAudioDataFromAccumulator()
                            delegate?.vadDidDetectEvent(.speechEnd(audioData: audioData))
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    logger.error("FluidAudio processing failed: \(error)")
                    // Fall back to energy-based processing for this chunk
                    processWithEnergyBased(chunk: chunk)
                }
            }
        }
    }

    private func processWithEnergyBased(chunk: [Float]) {
        let frameSize = configuration.frameSamples
        var frameIndex = 0

        while frameIndex + frameSize <= chunk.count {
            let frame = Array(chunk[frameIndex..<frameIndex + frameSize])
            frameProcessor?.process(frame: frame)
            frameIndex += frameSize
        }
    }

    private func createAudioDataFromAccumulator() -> Data {
        // Convert accumulated audio buffers to audio data
        let flatArray = audioBufferAccumulator.flatMap { $0 }
        return AudioFormatConverter.vadFramesToAudioData([flatArray])
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
        audioBufferAccumulator.removeAll()
        speechProbability = 0.0
        isSpeaking = false

        // Reset FluidAudio state
        Task {
            vadState = await fluidAudioManager?.makeStreamState()
        }
    }
}