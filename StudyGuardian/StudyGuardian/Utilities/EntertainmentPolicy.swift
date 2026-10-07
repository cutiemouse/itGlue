import Foundation

/// Pure policy separated from macOS side effects, so warning/quit timing is testable.
struct EntertainmentPolicy {
    enum Action: Equatable { case warning, reminder, requestNormalQuit }
    private var activeKey: String?
    private var startedAt: Date?
    private var didRemind = false
    private var didRequestQuit = false

    mutating func reset() {
        activeKey = nil
        startedAt = nil
        didRemind = false
        didRequestQuit = false
    }
    mutating func evaluate(applicationKey: String, category: ActivityCategory,
                           duringStudyHours: Bool, strictMode: Bool, at date: Date) -> [Action] {
        guard category == .entertainment, duringStudyHours else { reset(); return [] }
        var actions: [Action] = []
        if activeKey != applicationKey || startedAt == nil {
            reset()
            activeKey = applicationKey
            startedAt = date
            actions.append(.warning)
        } else if let start = startedAt, date.timeIntervalSince(start) > 300, !didRemind {
            didRemind = true
            actions.append(.reminder)
        }
        if strictMode && !didRequestQuit {
            didRequestQuit = true
            actions.append(.requestNormalQuit)
        }
        return actions
    }
}
