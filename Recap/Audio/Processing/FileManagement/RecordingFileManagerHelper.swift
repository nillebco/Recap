import Foundation

protocol RecordingFileManagerHelperType {
    func getBaseDirectory() -> URL
    func setBaseDirectory(_ url: URL, bookmark: Data?) throws
    func createRecordingDirectory(for recordingID: String) throws -> URL
}

final class RecordingFileManagerHelper: RecordingFileManagerHelperType {
    private let userPreferencesRepository: UserPreferencesRepositoryType

    init(userPreferencesRepository: UserPreferencesRepositoryType) {
        self.userPreferencesRepository = userPreferencesRepository
    }

    func getBaseDirectory() -> URL {
        // Try to get custom directory from preferences synchronously by checking UserDefaults
        // This is a simplified approach since we can't use async in a synchronous context
        let defaults = UserDefaults.standard
        if let customPath = defaults.string(forKey: "customTmpDirectoryPath") {
            let url = URL(fileURLWithPath: customPath)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // Default to temporary directory
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("Recap", isDirectory: true)
    }

    func setBaseDirectory(_ url: URL, bookmark: Data?) throws {
        // This will be handled by UserPreferencesRepository
        // Just validate the URL is accessible
        guard FileManager.default.isWritableFile(atPath: url.path) else {
            throw NSError(domain: "RecordingFileManagerHelper", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Directory is not writable"])
        }
    }

    func createRecordingDirectory(for recordingID: String) throws -> URL {
        let baseDir = getBaseDirectory()
        let recordingDir = baseDir.appendingPathComponent(recordingID, isDirectory: true)

        if !FileManager.default.fileExists(atPath: recordingDir.path) {
            try FileManager.default.createDirectory(
                at: recordingDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        return recordingDir
    }
}
