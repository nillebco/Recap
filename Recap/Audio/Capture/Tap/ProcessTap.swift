import SwiftUI
import AudioToolbox
import OSLog
import AVFoundation

extension String: @retroactive LocalizedError {
    public var errorDescription: String? { self }
}

final class ProcessTap: ObservableObject, AudioTapType {
    typealias InvalidationHandler = (ProcessTap) -> Void
    
    let process: AudioProcess
    let muteWhenRunning: Bool
    private let logger: Logger
    
    private(set) var errorMessage: String?
    @Published private(set) var audioLevel: Float = 0.0
    
    fileprivate func setAudioLevel(_ level: Float) {
        audioLevel = level
    }
    
    init(process: AudioProcess, muteWhenRunning: Bool = false) {
        self.process = process
        self.muteWhenRunning = muteWhenRunning
        self.logger = Logger(subsystem: AppConstants.Logging.subsystem, category: "\(String(describing: ProcessTap.self))(\(process.name))")
    }
    
    @ObservationIgnored
    private var processTapID: AudioObjectID = .unknown
    @ObservationIgnored
    private var aggregateDeviceID = AudioObjectID.unknown
    @ObservationIgnored
    private var deviceProcID: AudioDeviceIOProcID?
    @ObservationIgnored
    private(set) var tapStreamDescription: AudioStreamBasicDescription?
    @ObservationIgnored
    private var invalidationHandler: InvalidationHandler?
    
    @ObservationIgnored
    private(set) var activated = false
    
    @MainActor
    func activate() {
        guard !activated else { return }
        activated = true
        
        logger.debug(#function)
        
        self.errorMessage = nil
        
        do {
            try prepare(for: process.objectID)
        } catch {
            logger.error("\(error, privacy: .public)")
            self.errorMessage = error.localizedDescription
        }
    }
    
    func invalidate() {
        guard activated else { return }
        defer { activated = false }
        
        logger.debug(#function)
        
        invalidationHandler?(self)
        self.invalidationHandler = nil
        
        if aggregateDeviceID.isValid {
            if let deviceProcID = deviceProcID {
                var stopErr = AudioDeviceStop(aggregateDeviceID, deviceProcID)
                if stopErr != noErr { logger.warning("Failed to stop aggregate device: \(stopErr, privacy: .public)") }
                
                stopErr = AudioDeviceDestroyIOProcID(aggregateDeviceID, deviceProcID)
                if stopErr != noErr { logger.warning("Failed to destroy device I/O proc: \(stopErr, privacy: .public)") }
                self.deviceProcID = nil
            }
            
            let destroyErr = AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            if destroyErr != noErr {
                logger.warning("Failed to destroy aggregate device: \(destroyErr, privacy: .public)")
            }
            aggregateDeviceID = .unknown
        }
        
        if processTapID.isValid {
            let err = AudioHardwareDestroyProcessTap(processTapID)
            if err != noErr {
                logger.warning("Failed to destroy audio tap: \(err, privacy: .public)")
            }
            self.processTapID = .unknown
        }
    }
    
    private func prepare(for objectID: AudioObjectID) throws {
        errorMessage = nil
        
        logger.info("Preparing process tap for objectID: \(objectID, privacy: .public)")
        
        let tapDescription = CATapDescription(stereoMixdownOfProcesses: [objectID])
        tapDescription.uuid = UUID()
        tapDescription.muteBehavior = muteWhenRunning ? .mutedWhenTapped : .unmuted
        
        var tapID: AUAudioObjectID = .unknown
        var err = AudioHardwareCreateProcessTap(tapDescription, &tapID)
        
        guard err == noErr else {
            let errorMsg = "Process tap creation failed with error \(err) (0x\(String(err, radix: 16, uppercase: true)))"
            logger.error("\(errorMsg, privacy: .public)")
            errorMessage = errorMsg
            return
        }
        
        logger.info("Created process tap #\(tapID, privacy: .public)")
        
        self.processTapID = tapID
        
        let systemOutputID = try AudioDeviceID.readDefaultSystemOutputDevice()
        let outputUID = try systemOutputID.readDeviceUID()
        let aggregateUID = UUID().uuidString
        
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Tap-\(process.id)",
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [
                [
                    kAudioSubDeviceUIDKey: outputUID
                ]
            ],
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapDriftCompensationKey: true,
                    kAudioSubTapUIDKey: tapDescription.uuid.uuidString
                ]
            ]
        ]
        
        self.tapStreamDescription = try tapID.readAudioTapStreamBasicDescription()
        logger.info("Tap stream description: \(self.tapStreamDescription?.mSampleRate ?? 0)Hz, \(self.tapStreamDescription?.mChannelsPerFrame ?? 0)ch")
        
        aggregateDeviceID = AudioObjectID.unknown
        err = AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateDeviceID)
        guard err == noErr else {
            let errorMsg = "Failed to create aggregate device: \(err) (0x\(String(err, radix: 16, uppercase: true)))"
            logger.error("\(errorMsg, privacy: .public)")
            throw errorMsg
        }
        
        logger.info("Created aggregate device #\(self.aggregateDeviceID, privacy: .public)")
    }
    
    func run(on queue: DispatchQueue, ioBlock: @escaping AudioDeviceIOBlock, invalidationHandler: @escaping InvalidationHandler) throws {
        assert(activated, "\(#function) called with inactive tap!")
        assert(self.invalidationHandler == nil, "\(#function) called with tap already active!")
        
        errorMessage = nil
        
        logger.info("Starting audio device I/O proc for aggregate device #\(self.aggregateDeviceID, privacy: .public)")
        
        self.invalidationHandler = invalidationHandler
        
        let createErr = AudioDeviceCreateIOProcIDWithBlock(&deviceProcID, aggregateDeviceID, queue, ioBlock)
        guard createErr == noErr else { 
            let errorMsg = "Failed to create device I/O proc: \(createErr) (0x\(String(createErr, radix: 16, uppercase: true)))"
            logger.error("\(errorMsg, privacy: .public)")
            throw errorMsg 
        }
        
        logger.info("Created device I/O proc ID successfully")
        
        guard let procID = deviceProcID else {
            throw "Device I/O proc ID is nil"
        }
        
        let startErr = AudioDeviceStart(aggregateDeviceID, procID)
        guard startErr == noErr else { 
            let errorMsg = "Failed to start audio device: \(startErr) (0x\(String(startErr, radix: 16, uppercase: true)))"
            logger.error("\(errorMsg, privacy: .public)")
            throw errorMsg 
        }
        
        logger.info("Audio device started successfully")
    }
    
    deinit { 
        invalidate() 
    }
}

final class ProcessTapRecorder: ObservableObject, AudioTapRecorderType {
    let fileURL: URL
    let process: AudioProcess
    private let queue = DispatchQueue(label: "ProcessTapRecorder", qos: .userInitiated)
    private let logger: Logger
    
    @ObservationIgnored
    private weak var _tap: ProcessTap?

    private(set) var isRecording = false
    @ObservationIgnored
    var vadBufferHandler: ((AVAudioPCMBuffer) -> Void)?
    
    init(fileURL: URL, tap: ProcessTap) {
        self.process = tap.process
        self.fileURL = fileURL
        self._tap = tap
        self.logger = Logger(subsystem: AppConstants.Logging.subsystem, category: "\(String(describing: ProcessTapRecorder.self))(\(fileURL.lastPathComponent))")
    }
    
    private var tap: ProcessTap {
        get throws {
            guard let _tap = _tap else { 
                throw AudioCaptureError.coreAudioError("Process tap unavailable") 
            }
            return _tap
        }
    }
    
    @ObservationIgnored
    private var currentFile: AVAudioFile?
    
    @MainActor
    func start() throws {
        logger.debug(#function)
        
        guard !isRecording else {
            logger.warning("\(#function, privacy: .public) while already recording")
            return
        }
        
        let tap = try tap
        
        if !tap.activated { 
            tap.activate() 
        }
        
        guard var streamDescription = tap.tapStreamDescription else {
            throw AudioCaptureError.coreAudioError("Tap stream description not available")
        }
        
        guard let format = AVAudioFormat(streamDescription: &streamDescription) else {
            throw AudioCaptureError.coreAudioError("Failed to create AVAudioFormat")
        }
        
        logger.info("Using audio format: \(format, privacy: .public)")
        
        let settings: [String: Any] = [
            AVFormatIDKey: streamDescription.mFormatID,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount, 
        ]
        
        let file = try AVAudioFile(forWriting: fileURL, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: format.isInterleaved)
        
        self.currentFile = file
        
        try tap.run(on: queue) { [weak self] inNow, inInputData, inInputTime, outOutputData, inOutputTime in
            guard let self, let currentFile = self.currentFile else { return }
            do {
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: inInputData, deallocator: nil) else {
                    throw "Failed to create PCM buffer"
                }
                
                // Log audio data reception for debugging
                if buffer.frameLength > 0 {
                    logger.debug("Received audio data: \(buffer.frameLength) frames, \(buffer.format.sampleRate)Hz")
                }
                
                try currentFile.write(from: buffer)

                self.updateAudioLevel(from: buffer)
                self.handleVAD(for: buffer)
            } catch {
                logger.error("Audio processing error: \(error, privacy: .public)")
            }
        } invalidationHandler: { [weak self] tap in
            guard let self else { return }
            logger.warning("Audio tap invalidated")
            handleInvalidation()
        }
        
        isRecording = true
    }
    
    func stop() {
        do {
            logger.debug(#function)
            
            guard isRecording else { return }
            
            currentFile = nil
            isRecording = false
            vadBufferHandler = nil

            try tap.invalidate()
        } catch {
            logger.error("Stop failed: \(error, privacy: .public)")
        }
    }
    
    private func handleInvalidation() {
        guard isRecording else { return }
        logger.debug(#function)
    }
    
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let floatData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        
        var maxLevel: Float = 0.0
        
        for channel in 0..<channelCount {
            let channelData = floatData[channel]
            
            var channelLevel: Float = 0.0
            for frame in 0..<frameLength {
                let sample = abs(channelData[frame])
                channelLevel = max(channelLevel, sample)
            }
            
            maxLevel = max(maxLevel, channelLevel)
        }
        
        let decibels = 20 * log10(max(maxLevel, 0.00001))
        let normalizedLevel = (decibels + 60) / 60
        
        Task { @MainActor in
            self._tap?.setAudioLevel(min(max(normalizedLevel, 0), 1))
        }
    }

    private func handleVAD(for buffer: AVAudioPCMBuffer) {
        guard let handler = vadBufferHandler,
              let bufferCopy = copyBuffer(buffer) else { return }

        handler(bufferCopy)
    }

    private func copyBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else {
            logger.warning("Failed to allocate buffer copy for VAD processing")
            return nil
        }

        copy.frameLength = buffer.frameLength

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        if let sourcePointer = buffer.floatChannelData,
           let destinationPointer = copy.floatChannelData {
            if buffer.format.isInterleaved {
                let sampleCount = frameLength * channelCount
                destinationPointer[0].assign(from: sourcePointer[0], count: sampleCount)
            } else {
                for channel in 0..<channelCount {
                    destinationPointer[channel].assign(from: sourcePointer[channel], count: frameLength)
                }
            }
        } else if let sourceInt16 = buffer.int16ChannelData,
                    let destinationInt16 = copy.int16ChannelData {
            if buffer.format.isInterleaved {
                let sampleCount = frameLength * channelCount
                destinationInt16[0].assign(from: sourceInt16[0], count: sampleCount)
            } else {
                for channel in 0..<channelCount {
                    destinationInt16[channel].assign(from: sourceInt16[channel], count: frameLength)
                }
            }
        } else {
            logger.warning("Unsupported audio format for buffer copy in VAD handler")
            return nil
        }

        return copy
    }
}
