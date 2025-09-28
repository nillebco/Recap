import Foundation

extension DependencyContainer {
    
    func makeCoreDataManager() -> CoreDataManagerType {
        CoreDataManager(inMemory: inMemory)
    }
    
    func makeStatusBarManager() -> StatusBarManagerType {
        StatusBarManager()
    }
    
    func makeAudioProcessController() -> AudioProcessController {
        AudioProcessController()
    }
    
    func makeRecordingFileManager() -> RecordingFileManaging {
        RecordingFileManager(eventFileManager: eventFileManager)
    }
    
    func makeWarningManager() -> any WarningManagerType {
        WarningManager()
    }
}
