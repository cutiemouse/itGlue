import AppKit
import Combine

@MainActor
final class ActivityMonitorService: NSObject, ObservableObject {
    @Published private(set) var currentApplication = "Starting…"
    @Published private(set) var isMonitoring = false
    @Published private(set) var warning: String?
    @Published private(set) var error: String?
    let updated = PassthroughSubject<Void, Never>()
    private let persistence: PersistenceService
    private let settings: SettingsService
    private let notifications: NotificationService
    private let classifier = AppClassificationService()
    private let schedule = ScheduleService()
    private var preferences: GuardianPreferences
    private var current: ActivitySession?
    private var application: NSRunningApplication?
    private var lastCheckpoint = Date()
    private var entertainmentPolicy = EntertainmentPolicy()
    private var timer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var subscriptions = Set<AnyCancellable>()
    private var sleeping = false
    private var screenLocked = false
    private var sessionInactive = false
    private var suspended: Bool { sleeping || screenLocked || sessionInactive }
    private var started = false
    private var lastPrunedDay: Date?

    init(persistence: PersistenceService, settings: SettingsService, notifications: NotificationService) {
        self.persistence = persistence
        self.settings = settings
        self.notifications = notifications
        preferences = settings.preferences
        super.init()
        settings.changed.sink { [weak self] _ in self?.settingsChanged() }.store(in: &subscriptions)
    }
    func start() {
        guard !started else { return }
        started = true
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.didActivateApplicationNotification) { [weak self] in self?.activateFrontmost() }
        observe(workspace, NSWorkspace.willSleepNotification) { [weak self] in self?.sleeping = true; self?.suspend() }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { [weak self] in self?.sessionInactive = true; self?.suspend() }
        observe(workspace, NSWorkspace.didWakeNotification) { [weak self] in self?.sleeping = false; self?.resumeIfActive() }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { [weak self] in self?.sessionInactive = false; self?.resumeIfActive() }
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(screenDidLock(_:)),
                                name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        distributed.addObserver(self, selector: #selector(screenDidUnlock(_:)),
                                name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)
        observe(NotificationCenter.default, NSApplication.willTerminateNotification) { [weak self] in self?.stop() }
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        activateFrontmost()
    }
    @objc private func screenDidLock(_ notification: Notification) {
        screenLocked = true
        suspend()
    }
    @objc private func screenDidUnlock(_ notification: Notification) {
        screenLocked = false
        resumeIfActive()
    }
    private func observe(_ center: NotificationCenter, _ name: Notification.Name, action: @escaping @MainActor () -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            // NSWorkspace and screen events are delivered on the main queue, in order.
            MainActor.assumeIsolated { action() }
        }
        observers.append((center, token))
    }
    func stop() {
        guard started else { return }
        checkpoint(at: Date())
        close(at: Date())
        timer?.invalidate()
        timer = nil
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
        DistributedNotificationCenter.default().removeObserver(self)
        started = false
        isMonitoring = false
    }
    private func suspend() {
        checkpoint(at: Date())
        close(at: Date())
        isMonitoring = false
        currentApplication = "Paused — screen locked, asleep, or user session inactive"
        settings.lock()
        resetEntertainment()
        updated.send()
    }
    private func resumeIfActive() {
        guard !suspended else { return }
        activateFrontmost()
    }
    private func activateFrontmost() {
        guard !suspended, error == nil else { return }
        let now = Date()
        checkpoint(at: now)
        guard let next = NSWorkspace.shared.frontmostApplication, !next.isTerminated else {
            close(at: now)
            isMonitoring = false
            currentApplication = "No foreground application"
            resetEntertainment()
            return
        }
        guard application?.processIdentifier != next.processIdentifier || current == nil else { return }
        close(at: now)
        resetEntertainment()
        application = next
        open(at: now)
        evaluateEntertainment(at: now)
        updated.send()
    }
    private func open(at date: Date) {
        guard let application, error == nil else { return }
        let bundleID = application.bundleIdentifier ?? "unidentified.pid.\(application.processIdentifier)"
        let session = ActivitySession(applicationName: application.localizedName ?? "Unnamed application",
                                      bundleIdentifier: bundleID, startTime: date,
                                      category: classifier.category(bundleIdentifier: bundleID, overrides: preferences.categoryOverrides),
                                      duringStudyHours: schedule.isStudyTime(date, periods: preferences.periods))
        do {
            try persistence.insert(session)
            current = session
            lastCheckpoint = date
            currentApplication = session.applicationName
            isMonitoring = true
        } catch { fail(error) }
    }
    private func close(at date: Date) {
        guard let current else { application = nil; return }
        current.endTime = max(current.startTime, date)
        current.isOpen = false
        do { try persistence.save() } catch { fail(error) }
        self.current = nil
        application = nil
    }
    private func checkpoint(at date: Date) {
        guard let current, date >= lastCheckpoint, error == nil else { return }
        let boundaries = schedule.boundaries(from: lastCheckpoint, to: date, periods: preferences.periods)
        for boundary in boundaries {
            let running = application
            close(at: boundary)
            application = running
            open(at: boundary)
            if !schedule.isStudyTime(boundary, periods: preferences.periods) { resetEntertainment() }
        }
        // Use the new session after splitting, not the previous segment.
        let active = self.current ?? current
        active.endTime = max(active.startTime, date)
        lastCheckpoint = date
        do { try persistence.save() } catch { fail(error) }
    }
    private func tick() {
        guard !suspended, error == nil else { return }
        let now = Date()
        if now < lastCheckpoint {
            // Do not fabricate negative/overlapping sessions after a backwards clock correction.
            close(at: lastCheckpoint)
            resetEntertainment()
            activateFrontmost()
        } else {
            activateFrontmost()
            evaluateEntertainment(at: now)
        }
        let day = Calendar.current.startOfDay(for: now)
        if lastPrunedDay != day {
            do {
                let cutoff = Calendar.current.date(byAdding: .day, value: -preferences.retainDays, to: day) ?? day
                try persistence.prune(olderThan: cutoff)
                lastPrunedDay = day
            } catch { fail(error) }
        }
        if !settings.isUnlocked { settings.lock() }
        updated.send()
    }
    private func settingsChanged() {
        let now = Date()
        checkpoint(at: now)
        let running = application
        close(at: now)
        preferences = settings.preferences
        lastPrunedDay = nil
        application = running
        resetEntertainment()
        if !suspended { open(at: now); evaluateEntertainment(at: now) }
        updated.send()
    }
    private func evaluateEntertainment(at now: Date) {
        guard let current, let application else { resetEntertainment(); return }
        let isStudy = schedule.isStudyTime(now, periods: preferences.periods)
        if current.category != .entertainment || !isStudy { resetEntertainment(); return }
        let actions = entertainmentPolicy.evaluate(applicationKey: "\(application.processIdentifier)",
            category: current.category, duringStudyHours: isStudy, strictMode: preferences.strictMode, at: now)
        for action in actions {
            switch action {
            case .warning:
                warning = "Study time is active. Please finish your schoolwork before using this app."
                if preferences.remindersEnabled { notifications.warn(applicationName: current.applicationName, reminder: false) }
            case .reminder:
                warning = "\(current.applicationName) has remained active for more than 5 minutes during study time."
                if preferences.remindersEnabled { notifications.warn(applicationName: current.applicationName, reminder: true) }
            case .requestNormalQuit:
                // A normal quit permits Save/Cancel or refusal. Never forceTerminate.
                let accepted = application.terminate()
                warning = accepted
                    ? "Strict Mode requested a normal quit of \(current.applicationName). Save or cancel any app prompts."
                    : "\(current.applicationName) declined a normal quit. Study Guardian will not force-quit it."
            }
        }
    }
    private func resetEntertainment() {
        entertainmentPolicy.reset()
        warning = nil
    }
    private func fail(_ failure: Error) {
        error = "Activity storage failed: \(failure.localizedDescription). Restart after resolving the problem."
        isMonitoring = false
    }
    func deleteHistory() throws {
        try settings.requireUnlocked()
        let running = application
        close(at: Date())
        try persistence.deleteAll()
        application = running
        if !suspended { open(at: Date()) }
        updated.send()
    }
}
