import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor
final class GuardianViewModel: ObservableObject {
    let persistence: PersistenceService
    let settings: SettingsService
    let notifications: NotificationService
    let monitor: ActivityMonitorService
    @Published private(set) var sessions: [ActivitySession] = []
    @Published var error: String?
    @Published var now = Date()
    private var subscriptions = Set<AnyCancellable>()

    init() throws {
        persistence = try PersistenceService()
        settings = try SettingsService()
        notifications = NotificationService()
        monitor = ActivityMonitorService(persistence: persistence, settings: settings, notifications: notifications)
        monitor.updated.sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        settings.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &subscriptions)
        monitor.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        notifications.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        refresh()
    }
    func refresh() {
        now = Date()
        do { sessions = try persistence.sessions() }
        catch { self.error = error.localizedDescription }
    }
    var records: [UsageRecord] {
        sessions.map { UsageRecord(applicationName: $0.applicationName, bundleIdentifier: $0.bundleIdentifier,
                                  start: $0.startTime, end: $0.endTime, category: $0.category,
                                  duringStudyHours: $0.duringStudyHours) }
    }
    var today: DateInterval { Calendar.current.dateInterval(of: .day, for: now)! }
    var todaySummary: UsageSummary { UsageMath.summarize(records, in: today) }
    var todaySessions: [ActivitySession] {
        sessions.filter { $0.endTime >= today.start && $0.startTime < today.end }
    }
    var studyActive: Bool { ScheduleService().isStudyTime(now, periods: settings.preferences.periods) }
    func editSettings(_ edit: (inout GuardianPreferences) -> Void) {
        do { try settings.update(edit) }
        catch { self.error = error.localizedDescription }
    }
    func exportAppCSV(date: Date) {
        do { try settings.requireUnlocked() }
        catch { self.error = error.localizedDescription; return }
        let panel = NSSavePanel()
        panel.title = "Export daily app usage"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "Study Guardian Apps \(date.formatted(.iso8601.year().month().day())).csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try settings.requireUnlocked()
            try ReportService().dailyAppCSV(date: date, records: records).write(to: url, atomically: true, encoding: .utf8)
        } catch { self.error = error.localizedDescription }
    }

    func exportReport(date: Date) {
        do { try settings.requireUnlocked() }
        catch { self.error = error.localizedDescription; return }
        let panel = NSSavePanel()
        panel.title = "Export local daily report"
        panel.nameFieldStringValue = "Study Guardian \(date.formatted(.iso8601.year().month().day())).txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // Re-check after the modal: authorization may have expired during Save.
        do {
            try settings.requireUnlocked()
            try ReportService().dailySummary(date: date, records: records).write(to: url, atomically: true, encoding: .utf8)
        } catch { self.error = error.localizedDescription }
    }
}
