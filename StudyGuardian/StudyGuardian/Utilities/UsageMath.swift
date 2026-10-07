import Foundation

struct UsageRecord {
    var applicationName: String
    var bundleIdentifier: String
    var start: Date
    var end: Date
    var category: ActivityCategory
    var duringStudyHours: Bool
}

struct UsageSummary {
    var total: TimeInterval = 0
    var byCategory: [ActivityCategory: TimeInterval] = [:]
    var totalDuringStudy: TimeInterval = 0
    var studyDuringStudy: TimeInterval = 0
    var entertainmentDuringStudy: [String: TimeInterval] = [:]
    var focusScore: Double? {
        totalDuringStudy > 0 ? min(100, max(0, studyDuringStudy / totalDuringStudy * 100)) : nil
    }
}

struct DailyAppUsage: Identifiable {
    var id: String { bundleIdentifier }
    var applicationName: String
    var bundleIdentifier: String
    var duration: TimeInterval
    var duringStudyHours: TimeInterval
    var shareOfTotal: Double = 0
}

enum UsageMath {
    /// Combine all foreground segments by bundle ID, clipping each to the selected day.
    /// Category changes and schedule boundaries do not create duplicate app rows.
    static func dailyApps(_ records: [UsageRecord], in interval: DateInterval) -> [DailyAppUsage] {
        var apps: [String: DailyAppUsage] = [:]
        var latestNames: [String: Date] = [:]
        for record in records {
            let duration = max(0, min(record.end, interval.end).timeIntervalSince(max(record.start, interval.start)))
            guard duration > 0 else { continue }
            var app = apps[record.bundleIdentifier] ?? DailyAppUsage(
                applicationName: record.applicationName, bundleIdentifier: record.bundleIdentifier,
                duration: 0, duringStudyHours: 0)
            app.duration += duration
            if record.duringStudyHours { app.duringStudyHours += duration }
            if record.end >= (latestNames[record.bundleIdentifier] ?? .distantPast) {
                app.applicationName = record.applicationName
                latestNames[record.bundleIdentifier] = record.end
            }
            apps[record.bundleIdentifier] = app
        }
        let total = apps.values.reduce(0) { $0 + $1.duration }
        return apps.values.map { app in
            var result = app
            result.shareOfTotal = total > 0 ? app.duration / total * 100 : 0
            return result
        }.sorted {
            if $0.duration != $1.duration { return $0.duration > $1.duration }
            return $0.bundleIdentifier < $1.bundleIdentifier
        }
    }

    static func summarize(_ records: [UsageRecord], in interval: DateInterval) -> UsageSummary {
        var result = UsageSummary()
        for record in records {
            let duration = max(0, min(record.end, interval.end).timeIntervalSince(max(record.start, interval.start)))
            guard duration > 0 else { continue }
            result.total += duration
            result.byCategory[record.category, default: 0] += duration
            if record.duringStudyHours {
                result.totalDuringStudy += duration
                if record.category == .study { result.studyDuringStudy += duration }
                if record.category == .entertainment {
                    result.entertainmentDuringStudy[record.applicationName, default: 0] += duration
                }
            }
        }
        return result
    }
}
