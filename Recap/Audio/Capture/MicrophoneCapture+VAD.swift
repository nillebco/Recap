import AVFoundation
import OSLog
import ObjectiveC

extension MicrophoneCapture {

    private static var vadManagerKey: UInt8 = 0
    private static var vadDelegateKey: UInt8 = 0

    var vadManager: VADManager? {
        get {
            return objc_getAssociatedObject(self, &Self.vadManagerKey) as? VADManager
        }
        set {
            objc_setAssociatedObject(self, &Self.vadManagerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    weak var vadDelegate: VADDelegate? {
        get {
            return objc_getAssociatedObject(self, &Self.vadDelegateKey) as? VADDelegate
        }
        set {
            objc_setAssociatedObject(self, &Self.vadDelegateKey, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }

    @MainActor
    func setupVAD(configuration: VADConfiguration = .default, delegate: VADDelegate? = nil) {
        let manager = VADManager(configuration: configuration)
        manager.delegate = delegate
        self.vadManager = manager
        self.vadDelegate = delegate

        logger.info("VAD setup completed with configuration: frameSamples=\(configuration.frameSamples)")
    }

    @MainActor
    func enableVAD() async {
        await vadManager?.enable()
        logger.info("VAD enabled for microphone capture")
    }

    @MainActor
    func disableVAD() {
        vadManager?.disable()
        logger.info("VAD disabled for microphone capture")
    }

    @MainActor
    func pauseVAD() {
        vadManager?.pause()
    }

    @MainActor
    func resumeVAD() {
        vadManager?.resume()
    }

    @MainActor
    func resetVAD() {
        vadManager?.reset()
    }

    var isVADEnabled: Bool {
        return vadManager?.isVADEnabled ?? false
    }

    var currentSpeechProbability: Float {
        return vadManager?.speechProbability ?? 0.0
    }

    var isSpeaking: Bool {
        return vadManager?.isSpeaking ?? false
    }
}