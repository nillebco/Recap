import Foundation
import CoreData

@MainActor
final class UserPreferencesRepository: UserPreferencesRepositoryType {
    private let coreDataManager: CoreDataManagerType
    private let defaultPreferencesId = "default-preferences"
    
    init(coreDataManager: CoreDataManagerType) {
        self.coreDataManager = coreDataManager
    }
    
    func getOrCreatePreferences() async throws -> UserPreferencesInfo {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", defaultPreferencesId)
        request.fetchLimit = 1

        do {
            let preferences = try context.fetch(request).first

            if let existingPreferences = preferences {
                // Sync to UserDefaults for synchronous access
                if let customPath = existingPreferences.customTmpDirectoryPath {
                    UserDefaults.standard.set(customPath, forKey: "customTmpDirectoryPath")
                }
                return UserPreferencesInfo(from: existingPreferences)
            } else {
                let newPreferences = UserPreferences(context: context)
                newPreferences.id = defaultPreferencesId
                newPreferences.createdAt = Date()
                newPreferences.modifiedAt = Date()
                newPreferences.autoSummarizeEnabled = true
                newPreferences.autoSummarizeDuringRecording = true
                newPreferences.autoSummarizeAfterRecording = true
                newPreferences.autoTranscribeEnabled = true
                newPreferences.selectedProvider = LLMProvider.default.rawValue
                newPreferences.autoDetectMeetings = false
                newPreferences.autoStopRecording = false

                try context.save()
                return UserPreferencesInfo(from: newPreferences)
            }
        } catch {
            throw LLMError.dataAccessError(error.localizedDescription)
        }
    }
    
    func updateSelectedLLMModel(id: String?) async throws {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", defaultPreferencesId)
        request.fetchLimit = 1
        
        do {
            guard let preferences = try context.fetch(request).first else {
                let newPreferences = UserPreferences(context: context)
                newPreferences.id = defaultPreferencesId
                newPreferences.selectedLLMModelID = id
                newPreferences.selectedProvider = LLMProvider.default.rawValue
                newPreferences.autoDetectMeetings = false
                newPreferences.autoStopRecording = false
                newPreferences.createdAt = Date()
                newPreferences.modifiedAt = Date()
                newPreferences.autoSummarizeEnabled = true
                try context.save()
                return
            }
            
            preferences.selectedLLMModelID = id
            preferences.modifiedAt = Date()
            try context.save()
        } catch {
            throw LLMError.dataAccessError(error.localizedDescription)
        }
    }
    
    func updateSelectedProvider(_ provider: LLMProvider) async throws {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", defaultPreferencesId)
        request.fetchLimit = 1
        
        do {
            guard let preferences = try context.fetch(request).first else {
                let newPreferences = UserPreferences(context: context)
                newPreferences.id = defaultPreferencesId
                newPreferences.selectedProvider = provider.rawValue
                newPreferences.autoDetectMeetings = false
                newPreferences.autoStopRecording = false
                newPreferences.createdAt = Date()
                newPreferences.modifiedAt = Date()
                newPreferences.autoSummarizeEnabled = true
                try context.save()
                return
            }
            
            preferences.selectedProvider = provider.rawValue
            preferences.modifiedAt = Date()
            try context.save()
        } catch {
            throw LLMError.dataAccessError(error.localizedDescription)
        }
    }
    
    func updateAutoDetectMeetings(_ enabled: Bool) async throws {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", defaultPreferencesId)
        request.fetchLimit = 1
        
        do {
            guard let preferences = try context.fetch(request).first else {
                let newPreferences = UserPreferences(context: context)
                newPreferences.id = defaultPreferencesId
                newPreferences.autoDetectMeetings = enabled
                newPreferences.autoStopRecording = false
                newPreferences.selectedProvider = LLMProvider.default.rawValue
                newPreferences.createdAt = Date()
                newPreferences.modifiedAt = Date()
                newPreferences.autoSummarizeEnabled = true
                try context.save()
                return
            }
            
            preferences.autoDetectMeetings = enabled
            preferences.modifiedAt = Date()
            try context.save()
        } catch {
            throw LLMError.dataAccessError(error.localizedDescription)
        }
    }
    
    func updateAutoStopRecording(_ enabled: Bool) async throws {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", defaultPreferencesId)
        request.fetchLimit = 1
        
        do {
            guard let preferences = try context.fetch(request).first else {
                let newPreferences = UserPreferences(context: context)
                newPreferences.id = defaultPreferencesId
                newPreferences.autoDetectMeetings = false
                newPreferences.autoStopRecording = enabled
                newPreferences.selectedProvider = LLMProvider.default.rawValue
                newPreferences.createdAt = Date()
                newPreferences.modifiedAt = Date()
                newPreferences.autoSummarizeEnabled = true
                try context.save()
                return
            }
            
            preferences.autoStopRecording = enabled
            preferences.modifiedAt = Date()
            try context.save()
        } catch {
            throw LLMError.dataAccessError(error.localizedDescription)
        }
    }
    
    func updateSummaryPromptTemplate(_ template: String?) async throws {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", defaultPreferencesId)
        request.fetchLimit = 1
        
        do {
            guard let preferences = try context.fetch(request).first else {
                let newPreferences = UserPreferences(context: context)
                newPreferences.id = defaultPreferencesId
                newPreferences.summaryPromptTemplate = template
                newPreferences.selectedProvider = LLMProvider.default.rawValue
                newPreferences.autoDetectMeetings = false
                newPreferences.autoStopRecording = false
                newPreferences.createdAt = Date()
                newPreferences.modifiedAt = Date()
                newPreferences.autoSummarizeEnabled = true
                try context.save()
                return
            }
            
            preferences.summaryPromptTemplate = template
            preferences.modifiedAt = Date()
            try context.save()
        } catch {
            throw LLMError.dataAccessError(error.localizedDescription)
        }
    }
    
    func updateAutoSummarize(_ enabled: Bool) async throws {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", defaultPreferencesId)
        request.fetchLimit = 1

        do {
            guard let preferences = try context.fetch(request).first else {
                let newPreferences = UserPreferences(context: context)
                newPreferences.id = defaultPreferencesId
                newPreferences.autoSummarizeEnabled = enabled
                newPreferences.selectedProvider = LLMProvider.default.rawValue
                newPreferences.autoDetectMeetings = false
                newPreferences.autoStopRecording = false
                newPreferences.createdAt = Date()
                newPreferences.modifiedAt = Date()
                try context.save()
                return
            }

            preferences.autoSummarizeEnabled = enabled
            preferences.modifiedAt = Date()
            try context.save()
        } catch {
            throw LLMError.dataAccessError(error.localizedDescription)
        }
    }

    func updateAutoTranscribe(_ enabled: Bool) async throws {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", defaultPreferencesId)
        request.fetchLimit = 1

        do {
            guard let preferences = try context.fetch(request).first else {
                let newPreferences = UserPreferences(context: context)
                newPreferences.id = defaultPreferencesId
                newPreferences.autoTranscribeEnabled = enabled
                newPreferences.selectedProvider = LLMProvider.default.rawValue
                newPreferences.autoDetectMeetings = false
                newPreferences.autoStopRecording = false
                newPreferences.createdAt = Date()
                newPreferences.modifiedAt = Date()
                try context.save()
                return
            }

            preferences.autoTranscribeEnabled = enabled
            preferences.modifiedAt = Date()
            try context.save()
        } catch {
            throw LLMError.dataAccessError(error.localizedDescription)
        }
    }
    
    func updateOnboardingStatus(_ completed: Bool) async throws {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", defaultPreferencesId)
        request.fetchLimit = 1
        
        do {
            guard let preferences = try context.fetch(request).first else {
                let newPreferences = UserPreferences(context: context)
                newPreferences.id = defaultPreferencesId
                newPreferences.onboarded = completed
                newPreferences.selectedProvider = LLMProvider.default.rawValue
                newPreferences.autoDetectMeetings = false
                newPreferences.autoStopRecording = false
                newPreferences.autoSummarizeEnabled = true
                newPreferences.createdAt = Date()
                newPreferences.modifiedAt = Date()
                try context.save()
                return
            }
            
            preferences.onboarded = completed
            preferences.modifiedAt = Date()
            try context.save()
        } catch {
            throw LLMError.dataAccessError(error.localizedDescription)
        }
    }

    func updateMicrophoneEnabled(_ enabled: Bool) async throws {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", defaultPreferencesId)
        request.fetchLimit = 1

        do {
            guard let preferences = try context.fetch(request).first else {
                let newPreferences = UserPreferences(context: context)
                newPreferences.id = defaultPreferencesId
                newPreferences.microphoneEnabled = enabled
                newPreferences.autoDetectMeetings = false
                newPreferences.autoStopRecording = false
                newPreferences.selectedProvider = LLMProvider.default.rawValue
                newPreferences.createdAt = Date()
                newPreferences.modifiedAt = Date()
                newPreferences.autoSummarizeEnabled = true
                newPreferences.onboarded = false
                try context.save()
                return
            }

            preferences.microphoneEnabled = enabled
            preferences.modifiedAt = Date()
            try context.save()
        } catch {
            throw LLMError.dataAccessError(error.localizedDescription)
        }
    }
    
    func updateGlobalShortcut(keyCode: Int32, modifiers: Int32) async throws {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", defaultPreferencesId)
        request.fetchLimit = 1
        
        do {
            guard let preferences = try context.fetch(request).first else {
                let newPreferences = UserPreferences(context: context)
                newPreferences.id = defaultPreferencesId
                newPreferences.globalShortcutKeyCode = keyCode
                newPreferences.globalShortcutModifiers = modifiers
                newPreferences.autoDetectMeetings = false
                newPreferences.autoStopRecording = false
                newPreferences.selectedProvider = LLMProvider.default.rawValue
                newPreferences.createdAt = Date()
                newPreferences.modifiedAt = Date()
                newPreferences.autoSummarizeEnabled = true
                newPreferences.onboarded = false
                try context.save()
                return
            }
            
            preferences.globalShortcutKeyCode = keyCode
            preferences.globalShortcutModifiers = modifiers
            preferences.modifiedAt = Date()
            try context.save()
        } catch {
            throw LLMError.dataAccessError(error.localizedDescription)
        }
    }
    
    func updateCustomTmpDirectory(path: String?, bookmark: Data?) async throws {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", defaultPreferencesId)
        request.fetchLimit = 1

        do {
            guard let preferences = try context.fetch(request).first else {
                let newPreferences = UserPreferences(context: context)
                newPreferences.id = defaultPreferencesId
                newPreferences.customTmpDirectoryPath = path
                newPreferences.customTmpDirectoryBookmark = bookmark
                newPreferences.autoDetectMeetings = false
                newPreferences.autoStopRecording = false
                newPreferences.selectedProvider = LLMProvider.default.rawValue
                newPreferences.createdAt = Date()
                newPreferences.modifiedAt = Date()
                newPreferences.autoSummarizeEnabled = true
                newPreferences.onboarded = false
                try context.save()

                // Also save to UserDefaults for synchronous access
                if let path = path {
                    UserDefaults.standard.set(path, forKey: "customTmpDirectoryPath")
                } else {
                    UserDefaults.standard.removeObject(forKey: "customTmpDirectoryPath")
                }

                return
            }

            preferences.customTmpDirectoryPath = path
            preferences.customTmpDirectoryBookmark = bookmark
            preferences.modifiedAt = Date()
            try context.save()

            // Also save to UserDefaults for synchronous access
            if let path = path {
                UserDefaults.standard.set(path, forKey: "customTmpDirectoryPath")
            } else {
                UserDefaults.standard.removeObject(forKey: "customTmpDirectoryPath")
            }
        } catch {
            throw LLMError.dataAccessError(error.localizedDescription)
        }
    }

}
