import Foundation
import Combine
import UserNotifications

@MainActor
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var status = "Not requested"
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
        Task { await refreshStatus() }
    }
    func requestAuthorization() async {
        do { _ = try await center.requestAuthorization(options: [.alert, .sound]) }
        catch { status = error.localizedDescription; return }
        await refreshStatus()
    }
    func refreshStatus() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized: status = "Allowed"
        case .denied: status = "Denied — enable in System Settings > Notifications"
        case .notDetermined: status = "Not requested"
        default: status = "Limited"
        }
    }
    func warn(applicationName: String, reminder: Bool) {
        let content = UNMutableNotificationContent()
        content.title = reminder ? "Study Guardian — reminder" : "Study Guardian"
        content.body = "Study time is active. Please finish your schoolwork before using this app."
        content.subtitle = applicationName
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        Task {
            do { try await center.add(request) }
            catch { status = "Notification failed: \(error.localizedDescription)" }
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
