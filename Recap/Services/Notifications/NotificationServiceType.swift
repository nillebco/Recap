import Foundation

@MainActor
protocol NotificationServiceType {
    func requestPermission() async -> Bool
    func sendMeetingStartedNotification(appName: String, title: String) async
    func sendMeetingEndedNotification() async
}