import Foundation
import SwiftData

@Model
final class ActivitySession {
    @Attribute(.unique) var id: UUID
    var applicationName: String
    var bundleIdentifier: String
    var startTime: Date
    /// Checkpointed every 15 seconds; a crash never extends usage through downtime.
    var endTime: Date
    var isOpen: Bool
    var categoryRawValue: String
    var duringStudyHours: Bool

    init(applicationName: String, bundleIdentifier: String, startTime: Date,
         category: ActivityCategory, duringStudyHours: Bool) {
        id = UUID()
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.startTime = startTime
        endTime = startTime
        isOpen = true
        categoryRawValue = category.rawValue
        self.duringStudyHours = duringStudyHours
    }

    var category: ActivityCategory { ActivityCategory(rawValue: categoryRawValue) ?? .unknown }
    var totalDuration: TimeInterval { max(0, endTime.timeIntervalSince(startTime)) }
    func duration(in interval: DateInterval) -> TimeInterval {
        max(0, min(endTime, interval.end).timeIntervalSince(max(startTime, interval.start)))
    }
}
