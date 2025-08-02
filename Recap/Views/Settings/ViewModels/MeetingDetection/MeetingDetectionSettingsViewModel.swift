import Foundation
import SwiftUI

@MainActor
final class MeetingDetectionSettingsViewModel: MeetingDetectionSettingsViewModelType {
    @Published var hasScreenRecordingPermission = false
    @Published var autoDetectMeetings = false
    
    private let detectionService: any MeetingDetectionServiceType
    private let userPreferencesRepository: UserPreferencesRepositoryType
    
    init(detectionService: any MeetingDetectionServiceType,
         userPreferencesRepository: UserPreferencesRepositoryType) {
        self.detectionService = detectionService
        self.userPreferencesRepository = userPreferencesRepository
        
        Task {
            await loadCurrentSettings()
        }
    }
    
    private func loadCurrentSettings() async {
        do {
            let preferences = try await userPreferencesRepository.getOrCreatePreferences()
            withAnimation(.easeInOut(duration: 0.2)) {
                autoDetectMeetings = preferences.autoDetectMeetings
            }
        } catch {
            logger.error("Failed to load user preferences: \(String(describing: error))")
        }
    }
    
    func handleAutoDetectToggle(_ enabled: Bool) async {
        do {
            try await userPreferencesRepository.updateAutoDetectMeetings(enabled)
            
            withAnimation(.easeInOut(duration: 0.2)) {
                autoDetectMeetings = enabled
            }
            
            if enabled {
                let hasPermission = await detectionService.checkPermission()
                hasScreenRecordingPermission = hasPermission
                
                if hasPermission {
                    detectionService.startMonitoring()
                } else {
                    openScreenRecordingPreferences()
                }
            } else {
                detectionService.stopMonitoring()
            }
        } catch {
            print("Failed to update auto detect meetings setting: \(error)")
        }
    }
    
    func checkPermissionStatus() async {
        hasScreenRecordingPermission = await detectionService.checkPermission()
        
        if autoDetectMeetings && hasScreenRecordingPermission {
            detectionService.startMonitoring()
        }
    }
    
    func openScreenRecordingPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
