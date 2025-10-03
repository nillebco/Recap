import Foundation
import Combine
import SwiftUI

// MARK: - Meeting Detection Setup
extension RecapViewModel {
    func setupMeetingDetection() {
        Task {
            guard await shouldEnableMeetingDetection() else { return }

            setupMeetingStateObserver()
            await startMonitoringIfPermissionGranted()
        }
    }
}

// MARK: - Private Setup Helpers
private extension RecapViewModel {
    func shouldEnableMeetingDetection() async -> Bool {
        do {
            let preferences = try await userPreferencesRepository.getOrCreatePreferences()
            return preferences.autoDetectMeetings
        } catch {
            logger.error("Failed to load meeting detection preferences: \(error)")
            return false
        }
    }

    func setupMeetingStateObserver() {
        meetingDetectionService.meetingStatePublisher
            .sink { [weak self] meetingState in
                guard let self = self else { return }
                self.handleMeetingStateChange(meetingState)
            }
            .store(in: &cancellables)
    }

    func startMonitoringIfPermissionGranted() async {
        if await permissionsHelper.checkScreenCapturePermission() {
            meetingDetectionService.startMonitoring()
        } else {
            logger.warning("Meeting detection permission denied")
        }
    }
}

// MARK: - Meeting State Handling
private extension RecapViewModel {
    func handleMeetingStateChange(_ meetingState: MeetingState) {
        switch meetingState {
        case .active(let info, let detectedApp):
            handleMeetingDetected(info: info, detectedApp: detectedApp)
        case .inactive:
            handleMeetingEnded()
        }
    }

    func handleMeetingDetected(info: ActiveMeetingInfo, detectedApp: AudioProcess?) {
        autoSelectAppIfAvailable(detectedApp)

        let currentMeetingKey = "\(info.appName)-\(info.title)"
        if lastNotifiedMeetingKey != currentMeetingKey {
            lastNotifiedMeetingKey = currentMeetingKey
            sendMeetingStartedNotification(appName: info.appName, title: info.title)
        }
    }

    func handleMeetingEnded() {
        lastNotifiedMeetingKey = nil
        sendMeetingEndedNotification()
    }
}

// MARK: - App Auto-Selection
private extension RecapViewModel {
    func autoSelectAppIfAvailable(_ detectedApp: AudioProcess?) {
        guard let detectedApp else {
            return
        }

        appSelectionCoordinator.autoSelectApp(detectedApp)
    }
}

// MARK: - Notification Helpers
private extension RecapViewModel {
    func sendMeetingStartedNotification(appName: String, title: String) {
        Task {
            await notificationService.sendMeetingStartedNotification(appName: appName, title: title)
        }
    }

    func sendMeetingEndedNotification() {
        // TODO: Later we will analyze audio levels, and if silence is detected, send a notification here.
    }
}

// MARK: - Supporting Types
private enum MeetingDetectionConstants {
    static let autoSelectionAnimationDuration: Double = 0.3
}
