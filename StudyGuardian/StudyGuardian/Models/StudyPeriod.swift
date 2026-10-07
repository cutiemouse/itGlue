import Foundation

struct StudyPeriod: Codable, Identifiable, Equatable {
    var id = UUID()
    /// Calendar weekdays: Sunday = 1, Monday = 2, Saturday = 7.
    var weekdays: Set<Int>
    var startMinute: Int
    var endMinute: Int
    var enabled = true

    var isValid: Bool {
        !weekdays.isEmpty && weekdays.allSatisfy { (1...7).contains($0) }
            && (0..<1440).contains(startMinute) && (0..<1440).contains(endMinute)
            && startMinute != endMinute
    }

    static let defaultPeriod = StudyPeriod(weekdays: Set(2...6), startMinute: 16 * 60, endMinute: 21 * 60)
}

struct GuardianPreferences: Codable {
    var periods = [StudyPeriod.defaultPeriod]
    var categoryOverrides: [String: ActivityCategory] = [:]
    var strictMode = false
    var remindersEnabled = true
    var retainDays = 30
}
