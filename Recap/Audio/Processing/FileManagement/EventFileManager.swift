import Foundation
import OSLog

/// Manages file organization for recording events with structured folder hierarchy
protocol EventFileManaging {
    func createEventDirectory(for eventID: String) throws -> URL
    func createRecordingFileURL(for eventID: String, source: AudioSource) -> URL
    func createTranscriptionFileURL(for eventID: String) -> URL
    func createSummaryFileURL(for eventID: String) -> URL
    func createSegmentsDirectoryURL(for eventID: String) -> URL
    func createSegmentFileURL(for eventID: String, segmentID: String) -> URL
    func getEventDirectory(for eventID: String) -> URL
    func cleanupEventDirectory(for eventID: String) throws
    func getBaseDirectory() -> URL
    func setBaseDirectory(_ url: URL, bookmark: Data?) throws

    // File writing methods
    func writeTranscription(_ transcription: String, for eventID: String) throws
    func writeStructuredTranscription(_ structuredTranscriptions: [StructuredTranscription], for eventID: String) throws
    func writeSummary(_ summary: String, for eventID: String) throws
    func writeAudioSegment(_ audioData: Data, for eventID: String, segmentID: String) throws
    func writeRecordingAudio(_ audioData: Data, for eventID: String, source: AudioSource) throws
}

enum AudioSource: String, CaseIterable {
    case systemAudio = "system"
    case microphone = "microphone"
    
    var fileExtension: String {
        return "wav"
    }
    
    var displayName: String {
        switch self {
        case .systemAudio:
            return "System Audio"
        case .microphone:
            return "Microphone"
        }
    }
}

final class EventFileManager: EventFileManaging {
    private let logger = Logger(subsystem: AppConstants.Logging.subsystem, category: String(describing: EventFileManager.self))
    private let fileManager = FileManager.default
    private let userPreferencesRepository: UserPreferencesRepositoryType
    
    // Default to the current tmp directory if no custom path is set
    private var _baseDirectory: URL?
#if os(macOS)
    private var baseDirectoryBookmark: Data?
    private var securityScopedURL: URL?
    private var securityScopeActive = false
#endif
    
    init(userPreferencesRepository: UserPreferencesRepositoryType) {
        self.userPreferencesRepository = userPreferencesRepository
        loadBaseDirectory()
    }

    deinit {
#if os(macOS)
        if securityScopeActive, let activeURL = securityScopedURL {
            activeURL.stopAccessingSecurityScopedResource()
        }
#endif
    }

    private func loadBaseDirectory() {
        Task { @MainActor in
            do {
                let preferences = try await userPreferencesRepository.getOrCreatePreferences()
#if os(macOS)
                if let customBookmark = preferences.customTmpDirectoryBookmark,
                   let resolvedURL = try? activateSecurityScope(for: nil, bookmark: customBookmark) {
                    _baseDirectory = resolvedURL
                    return
                }

                if let customPath = preferences.customTmpDirectoryPath {
                    let candidateURL = URL(fileURLWithPath: customPath, isDirectory: true)
                    if let resolvedURL = try? activateSecurityScope(for: candidateURL, bookmark: preferences.customTmpDirectoryBookmark) {
                        _baseDirectory = resolvedURL
                    } else {
                        _baseDirectory = candidateURL
                    }
                } else {
                    _baseDirectory = fileManager.temporaryDirectory.appendingPathComponent("RecapEvents")
                }
#else
                if let customPath = preferences.customTmpDirectoryPath {
                    _baseDirectory = URL(fileURLWithPath: customPath)
                } else {
                    _baseDirectory = fileManager.temporaryDirectory.appendingPathComponent("RecapEvents")
                }
#endif
            } catch {
                logger.error("Failed to load base directory from preferences: \(error)")
                _baseDirectory = fileManager.temporaryDirectory.appendingPathComponent("RecapEvents")
            }
        }
    }
    
    func getBaseDirectory() -> URL {
        return _baseDirectory ?? fileManager.temporaryDirectory.appendingPathComponent("RecapEvents")
    }
    
    func setBaseDirectory(_ url: URL, bookmark: Data?) throws {
#if os(macOS)
        let scopedURL = try activateSecurityScope(for: url, bookmark: bookmark)
        try fileManager.createDirectory(at: scopedURL, withIntermediateDirectories: true)
        _baseDirectory = scopedURL
        baseDirectoryBookmark = bookmark
#else
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        _baseDirectory = url
#endif
    }
    
    func createEventDirectory(for eventID: String) throws -> URL {
        let eventDirectory = getEventDirectory(for: eventID)
        try fileManager.createDirectory(at: eventDirectory, withIntermediateDirectories: true)
        
        // Create subdirectories
        let segmentsDirectory = createSegmentsDirectoryURL(for: eventID)
        try fileManager.createDirectory(at: segmentsDirectory, withIntermediateDirectories: true)
        
        logger.info("Created event directory: \(eventDirectory.path)")
        return eventDirectory
    }
    
    func createRecordingFileURL(for eventID: String, source: AudioSource) -> URL {
        let eventDirectory = getEventDirectory(for: eventID)
        let filename = "\(source.rawValue)_recording.\(source.fileExtension)"
        return eventDirectory.appendingPathComponent(filename)
    }
    
    func createTranscriptionFileURL(for eventID: String) -> URL {
        let eventDirectory = getEventDirectory(for: eventID)
        return eventDirectory.appendingPathComponent("transcription.md")
    }

    func createSummaryFileURL(for eventID: String) -> URL {
        let eventDirectory = getEventDirectory(for: eventID)
        return eventDirectory.appendingPathComponent("summary.md")
    }

    func createSegmentsDirectoryURL(for eventID: String) -> URL {
        let eventDirectory = getEventDirectory(for: eventID)
        return eventDirectory.appendingPathComponent("segments")
    }
    
    func createSegmentFileURL(for eventID: String, segmentID: String) -> URL {
        let segmentsDirectory = createSegmentsDirectoryURL(for: eventID)
        return segmentsDirectory.appendingPathComponent("\(segmentID).wav")
    }
    
    func getEventDirectory(for eventID: String) -> URL {
        return getBaseDirectory().appendingPathComponent(eventID)
    }
    
    func cleanupEventDirectory(for eventID: String) throws {
        let eventDirectory = getEventDirectory(for: eventID)
        if fileManager.fileExists(atPath: eventDirectory.path) {
            try fileManager.removeItem(at: eventDirectory)
            logger.info("Cleaned up event directory: \(eventDirectory.path)")
        }
    }
}

#if os(macOS)
private extension EventFileManager {
    @discardableResult
    func activateSecurityScope(for directURL: URL?, bookmark: Data?) throws -> URL {
        var resolvedURL = directURL ?? getBaseDirectory()
        var bookmarkToStore = bookmark
        
        if let bookmark = bookmark {
            var isStale = false
            resolvedURL = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                let refreshedBookmark = try resolvedURL.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                bookmarkToStore = refreshedBookmark
        Task { @MainActor [userPreferencesRepository] in
                    try await userPreferencesRepository.updateCustomTmpDirectory(
                        path: resolvedURL.path,
                        bookmark: refreshedBookmark
                    )
                }
            }
        }
        
        if securityScopeActive, let activeURL = securityScopedURL {
            activeURL.stopAccessingSecurityScopedResource()
            securityScopeActive = false
        }
        
        securityScopedURL = resolvedURL
        if let bookmarkToStore {
            securityScopeActive = resolvedURL.startAccessingSecurityScopedResource()
            baseDirectoryBookmark = bookmarkToStore
        } else {
            baseDirectoryBookmark = nil
        }
        
        return resolvedURL
    }
}

#endif

// MARK: - File Writing Helpers

extension EventFileManager {
    /// Write transcription data to markdown file
    func writeTranscription(_ transcription: String, for eventID: String) throws {
        let transcriptionURL = createTranscriptionFileURL(for: eventID)
        let markdownContent = formatTranscriptionAsMarkdown(transcription, eventID: eventID)
        try markdownContent.write(to: transcriptionURL, atomically: true, encoding: .utf8)
        logger.info("Written transcription to: \(transcriptionURL.path)")
    }
    
    /// Write structured transcription data to markdown file
    func writeStructuredTranscription(_ structuredTranscriptions: [StructuredTranscription], for eventID: String) throws {
        let transcriptionURL = createTranscriptionFileURL(for: eventID)
        let markdownContent = formatStructuredTranscriptionAsMarkdown(structuredTranscriptions, eventID: eventID)
        try markdownContent.write(to: transcriptionURL, atomically: true, encoding: .utf8)
        logger.info("Written structured transcription to: \(transcriptionURL.path)")
    }

    func writeSummary(_ summary: String, for eventID: String) throws {
        let summaryURL = createSummaryFileURL(for: eventID)
        let summaryContent = formatSummaryAsMarkdown(summary, eventID: eventID)
        try summaryContent.write(to: summaryURL, atomically: true, encoding: .utf8)
        logger.info("Written summary to: \(summaryURL.path)")
    }
    
    /// Write audio segment to file
    func writeAudioSegment(_ audioData: Data, for eventID: String, segmentID: String) throws {
        let segmentURL = createSegmentFileURL(for: eventID, segmentID: segmentID)
        try audioData.write(to: segmentURL)
        logger.info("Written audio segment to: \(segmentURL.path)")
    }
    
    /// Write recording audio to file
    func writeRecordingAudio(_ audioData: Data, for eventID: String, source: AudioSource) throws {
        let recordingURL = createRecordingFileURL(for: eventID, source: source)
        try audioData.write(to: recordingURL)
        logger.info("Written recording audio to: \(recordingURL.path)")
    }
    
    private func formatTranscriptionAsMarkdown(_ transcription: String, eventID: String) -> String {
        let timestamp = DateFormatter.iso8601.string(from: Date())
        return """
        # Transcription - Event \(eventID)
        
        **Generated:** \(timestamp)
        
        ## Transcript
        
        \(transcription)
        
        ---
        *Generated by Recap*
        """
    }
    
    private func formatStructuredTranscriptionAsMarkdown(_ structuredTranscriptions: [StructuredTranscription], eventID: String) -> String {
        let timestamp = DateFormatter.iso8601.string(from: Date())
        var content = """
        # Transcription - Event \(eventID)

        **Generated:** \(timestamp)
        
        ## Transcript Segments
        
        """
        
        for (index, transcription) in structuredTranscriptions.enumerated() {
            let startTime = formatTime(transcription.relativeStartTime)
            let endTime = formatTime(transcription.relativeEndTime)
            let source = transcription.source.rawValue.capitalized
            
            content += """
            ### Segment \(index + 1) - \(source) Audio
            **Time:** \(startTime) - \(endTime)
            
            \(transcription.text)
            
            ---
            
            """
        }
        
        content += "\n*Generated by Recap*"
        return content
    }

    private func formatSummaryAsMarkdown(_ summary: String, eventID: String) -> String {
        let timestamp = DateFormatter.iso8601.string(from: Date())
        return """
        # Summary - Event \(eventID)

        **Generated:** \(timestamp)

        ## Summary

        \(summary)

        ---
        *Generated by Recap*
        """
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        let milliseconds = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
}
