import Foundation

protocol RecordingFileManaging {
    func createRecordingURL() -> URL
    func createRecordingBaseURL(for recordingID: String) -> URL
    func ensureRecordingsDirectoryExists() throws
}

final class RecordingFileManager: RecordingFileManaging {
    private let recordingsDirectoryName = "Recordings"
    
    func createRecordingURL() -> URL {
        let timestamp = Date().timeIntervalSince1970
        let filename = "recap_recording_\(Int(timestamp))"
        
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)
            .appendingPathExtension("wav")
    }
    
    func createRecordingBaseURL(for recordingID: String) -> URL {
        let timestamp = Date().timeIntervalSince1970
        let filename = "\(recordingID)_\(Int(timestamp))"
        
        return recordingsDirectory
            .appendingPathComponent(filename)
    }
    
    func ensureRecordingsDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: recordingsDirectory,
            withIntermediateDirectories: true
        )
    }
    
    private var recordingsDirectory: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(recordingsDirectoryName)
    }
}