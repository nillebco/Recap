import Foundation
import AVFoundation
import Accelerate

final class AudioFormatConverter {
    static let vadTargetSampleRate: Double = 16000.0
    static let vadTargetChannels: UInt32 = 1

    static func convertToVADFormat(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channelData = buffer.floatChannelData else { return nil }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let sourceSampleRate = buffer.format.sampleRate

        var audioData: [Float] = []

        if channelCount == 1 {
            audioData = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        } else {
            audioData = mixToMono(channelData: channelData, frameCount: frameCount, channelCount: channelCount)
        }

        if sourceSampleRate != vadTargetSampleRate {
            audioData = resample(audioData, from: sourceSampleRate, to: vadTargetSampleRate)
        }

        return audioData
    }

    private static func mixToMono(channelData: UnsafePointer<UnsafeMutablePointer<Float>>, frameCount: Int, channelCount: Int) -> [Float] {
        var monoData = [Float](repeating: 0.0, count: frameCount)

        for frame in 0..<frameCount {
            var sum: Float = 0.0
            for channel in 0..<channelCount {
                sum += channelData[channel][frame]
            }
            monoData[frame] = sum / Float(channelCount)
        }

        return monoData
    }

    private static func resample(_ inputData: [Float], from sourceSampleRate: Double, to targetSampleRate: Double) -> [Float] {
        guard sourceSampleRate != targetSampleRate else { return inputData }

        let ratio = targetSampleRate / sourceSampleRate
        let outputCount = Int(Double(inputData.count) * ratio)
        var outputData = [Float](repeating: 0.0, count: outputCount)

        for i in 0..<outputCount {
            let sourceIndex = Double(i) / ratio
            let lowerIndex = Int(sourceIndex)
            let upperIndex = min(lowerIndex + 1, inputData.count - 1)
            let fraction = Float(sourceIndex - Double(lowerIndex))

            if lowerIndex < inputData.count {
                outputData[i] = inputData[lowerIndex] * (1.0 - fraction) + inputData[upperIndex] * fraction
            }
        }

        return outputData
    }

    static func vadFramesToAudioData(_ frames: [[Float]], sampleRate: Double = vadTargetSampleRate) -> Data {
        let flatArray = frames.flatMap { $0 }
        return createWAVData(from: flatArray, sampleRate: sampleRate)
    }

    private static func createWAVData(from samples: [Float], sampleRate: Double) -> Data {
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16  // Use 16-bit PCM for better WhisperKit compatibility
        let bytesPerSample = bitsPerSample / 8
        let bytesPerFrame = numChannels * bytesPerSample
        
        // Convert float samples to 16-bit PCM
        let pcmSamples = samples.map { sample -> Int16 in
            // Clamp to [-1.0, 1.0] range and convert to 16-bit PCM
            let clampedSample = max(-1.0, min(1.0, sample))
            return Int16(clampedSample * Float(Int16.max))
        }
        
        let dataSize = UInt32(pcmSamples.count * Int(bytesPerSample))
        let fileSize = 36 + dataSize

        var data = Data()

        data.append("RIFF".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        data.append("WAVE".data(using: .ascii)!)

        data.append("fmt ".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // PCM format (not IEEE float)
        data.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: UInt32(sampleRate * Double(bytesPerFrame)).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: bytesPerFrame.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })

        data.append("data".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })

        for sample in pcmSamples {
            var littleEndianSample = sample.littleEndian
            data.append(withUnsafeBytes(of: &littleEndianSample) { Data($0) })
        }

        print("🎵 Created 16-bit PCM WAV: \(samples.count) float samples → \(pcmSamples.count) PCM samples → \(data.count) bytes")

        return data
    }
}