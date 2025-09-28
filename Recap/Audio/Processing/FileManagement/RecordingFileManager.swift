import Foundation

protocol RecordingFileManaging {
    func createRecordingURL() -> URL
    func createRecordingBaseURL(for recordingID: String) -> URL
    func ensureRecordingsDirectoryExists() throws
}

final class RecordingFileManager: RecordingFileManaging {
    private let recordingsDirectoryName = "Recordings"
    private let eventFileManager: EventFileManaging?
    
    init(eventFileManager: EventFileManaging? = nil) {
        self.eventFileManager = eventFileManager
    }
    
    func createRecordingURL() -> URL {
        let timestamp = Date().timeIntervalSince1970
        let filename = "recap_recording_\(Int(timestamp))"
        
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)
            .appendingPathExtension("wav")
    }
    
    func createRecordingBaseURL(for recordingID: String) -> URL {
        // If we have an event file manager, use it for organized storage
        if let eventFileManager = eventFileManager {
            do {
                let eventDirectory = try eventFileManager.createEventDirectory(for: recordingID)
                return eventDirectory
            } catch {
                // Fallback to old system if event file manager fails
                let timestamp = Date().timeIntervalSince1970
                let filename = "\(recordingID)_\(Int(timestamp))"
                return recordingsDirectory.appendingPathComponent(filename)
            }
        } else {
            // Use old system
            let timestamp = Date().timeIntervalSince1970
            let filename = "\(recordingID)_\(Int(timestamp))"
            return recordingsDirectory.appendingPathComponent(filename)
        }
    }
    
    func ensureRecordingsDirectoryExists() throws {
        if let eventFileManager = eventFileManager {
            // Event file manager handles directory creation
            return
        } else {
            try FileManager.default.createDirectory(
                at: recordingsDirectory,
                withIntermediateDirectories: true
            )
        }
    }
    
    private var recordingsDirectory: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(recordingsDirectoryName)
    }
}