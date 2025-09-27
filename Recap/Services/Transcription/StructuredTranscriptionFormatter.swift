import Foundation

/// Utility class for formatting structured transcriptions
@MainActor
final class StructuredTranscriptionFormatter {
    
    /// Format multiple structured transcriptions into the combined format you specified
    static func formatCombinedTranscriptions(_ transcriptions: [StructuredTranscription]) -> String {
        // Sort by absolute creation time to maintain chronological order
        let sortedTranscriptions = transcriptions.sorted { $0.absoluteCreationTime < $1.absoluteCreationTime }
        
        return sortedTranscriptions.map { $0.structuredText }.joined(separator: " ")
    }
    
    /// Convert structured transcriptions to JSON format
    static func toJSON(_ transcriptions: [StructuredTranscription]) -> String? {
        let jsonData = transcriptions.map { $0.jsonData }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonData, options: [.prettyPrinted, .sortedKeys])
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Failed to convert structured transcriptions to JSON: \(error)")
            return nil
        }
    }
    
    /// Group transcriptions by source (microphone vs system audio)
    static func groupBySource(_ transcriptions: [StructuredTranscription]) -> [TranscriptionSegment.AudioSource: [StructuredTranscription]] {
        return Dictionary(grouping: transcriptions) { $0.source }
    }
    
    /// Get transcriptions for a specific source
    static func getTranscriptionsForSource(_ transcriptions: [StructuredTranscription], source: TranscriptionSegment.AudioSource) -> [StructuredTranscription] {
        return transcriptions.filter { $0.source == source }
    }
    
    /// Format transcriptions with source identification
    static func formatWithSourceIdentification(_ transcriptions: [StructuredTranscription]) -> String {
        let grouped = groupBySource(transcriptions)
        
        var result = ""
        
        // Add microphone transcriptions first
        if let microphoneTranscriptions = grouped[.microphone] {
            result += "=== MICROPHONE AUDIO ===\n"
            result += formatCombinedTranscriptions(microphoneTranscriptions)
            result += "\n\n"
        }
        
        // Add system audio transcriptions
        if let systemTranscriptions = grouped[.systemAudio] {
            result += "=== SYSTEM AUDIO ===\n"
            result += formatCombinedTranscriptions(systemTranscriptions)
        }
        
        return result
    }
    
    /// Create a summary of the transcription session
    static func createSessionSummary(_ transcriptions: [StructuredTranscription]) -> [String: Any] {
        let grouped = groupBySource(transcriptions)
        let totalDuration = transcriptions.map { $0.relativeEndTime }.max() ?? 0.0
        
        return [
            "totalSegments": transcriptions.count,
            "microphoneSegments": grouped[.microphone]?.count ?? 0,
            "systemAudioSegments": grouped[.systemAudio]?.count ?? 0,
            "totalDuration": totalDuration,
            "sessionStartTime": transcriptions.first?.absoluteCreationTime.timeIntervalSince1970 ?? 0,
            "sessionEndTime": transcriptions.last?.absoluteEndTime.timeIntervalSince1970 ?? 0,
            "sources": Array(grouped.keys.map { $0.rawValue })
        ]
    }
    
    /// Format transcriptions in a beautiful, readable format for copying
    static func formatForCopying(_ transcriptions: [StructuredTranscription]) -> String {
        // Sort by absolute creation time to maintain chronological order
        let sortedTranscriptions = transcriptions.sorted { $0.absoluteCreationTime < $1.absoluteCreationTime }
        
        var result = ""
        
        for transcription in sortedTranscriptions {
            let timestamp = formatTimestamp(transcription.absoluteStartTime)
            let source = formatSource(transcription.source)
            let language = transcription.language
            let text = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Format: 2025-09-27 19:56 [microphone] (en) hello world
            result += "\(timestamp) [\(source)] (\(language)) \(text)\n"
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Format timestamp in a readable format
    private static func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    /// Format source in a readable format
    private static func formatSource(_ source: TranscriptionSegment.AudioSource) -> String {
        switch source {
        case .microphone:
            return "microphone"
        case .systemAudio:
            return "system audio"
        }
    }
    
    /// Format transcriptions with enhanced visual separation
    static func formatForCopyingEnhanced(_ transcriptions: [StructuredTranscription]) -> String {
        // Sort by absolute creation time to maintain chronological order
        let sortedTranscriptions = transcriptions.sorted { $0.absoluteCreationTime < $1.absoluteCreationTime }
        
        var result = ""
        var currentDate: String = ""
        
        for transcription in sortedTranscriptions {
            let timestamp = formatTimestamp(transcription.absoluteStartTime)
            let date = String(timestamp.prefix(10)) // Extract date part
            let time = String(timestamp.suffix(8)) // Extract time part (HH:mm:ss)
            let source = formatSource(transcription.source)
            let language = transcription.language
            let text = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Add date separator if date changed
            if currentDate != date {
                if !result.isEmpty {
                    result += "\n"
                }
                result += "📅 \(date)\n"
                result += String(repeating: "─", count: 20) + "\n"
                currentDate = date
            }
            
            // Format: 19:56 [microphone] (en) hello world
            result += "\(time) [\(source)] (\(language)) \(text)\n"
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
