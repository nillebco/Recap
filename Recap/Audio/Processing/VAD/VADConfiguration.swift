import Foundation

struct VADConfiguration {
    let frameSamples: Int
    let positiveSpeechThreshold: Float
    let negativeSpeechThreshold: Float
    let redemptionFrames: Int
    let preSpeechPadFrames: Int
    let minSpeechFrames: Int
    let submitUserSpeechOnPause: Bool

    static let `default` = VADConfiguration(
        frameSamples: 512, // 30ms @ 16kHz (matches Silero v5)
        positiveSpeechThreshold: 0.6,
        negativeSpeechThreshold: 0.35,
        redemptionFrames: 8,
        preSpeechPadFrames: 4,
        minSpeechFrames: 20, // Increased from 5 to 20 (0.6 seconds at 16kHz)
        submitUserSpeechOnPause: true
    )

    static let responsive = VADConfiguration(
        frameSamples: 512,
        positiveSpeechThreshold: 0.5, // More sensitive
        negativeSpeechThreshold: 0.3,
        redemptionFrames: 6, // Less tolerance for gaps
        preSpeechPadFrames: 3,
        minSpeechFrames: 3, // Shorter minimum
        submitUserSpeechOnPause: true
    )
    
    static let conservative = VADConfiguration(
        frameSamples: 512,
        positiveSpeechThreshold: 0.7, // Higher threshold - less sensitive
        negativeSpeechThreshold: 0.4, // Higher threshold for ending
        redemptionFrames: 15, // More tolerance for gaps
        preSpeechPadFrames: 8, // More pre-speech padding
        minSpeechFrames: 30, // Much longer minimum (0.9 seconds at 16kHz)
        submitUserSpeechOnPause: true
    )
}