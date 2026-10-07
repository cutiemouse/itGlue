import Foundation

struct ReportService {
    func dailyAppCSV(date: Date, records: [UsageRecord], calendar: Calendar = .current) -> String {
        let header = "Date,Application,Bundle identifier,Duration seconds,Duration,Usage percent,Study-hour seconds"
        guard let day = calendar.dateInterval(of: .day, for: date) else { return header + "\r\n" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let dateText = formatter.string(from: date)
        let lines = UsageMath.dailyApps(records, in: day).map { app in
            [csvText(dateText), csvText(app.applicationName), csvText(app.bundleIdentifier),
             String(format: "%.0f", locale: Locale(identifier: "en_US_POSIX"), app.duration),
             csvText(DisplayFormat.duration(app.duration)),
             String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), app.shareOfTotal),
             String(format: "%.0f", locale: Locale(identifier: "en_US_POSIX"), app.duringStudyHours)]
                .joined(separator: ",")
        }
        return ([header] + lines).joined(separator: "\r\n") + "\r\n"
    }
    private func csvText(_ text: String) -> String {
        // Quoted fields handle commas/newlines. Neutralize spreadsheet formulas in app-supplied names.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = trimmed.first.map { "=+-@".contains($0) } == true ? "'" + text : text
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    func dailySummary(date: Date, records: [UsageRecord], calendar: Calendar = .current) -> String {
        guard let day = calendar.dateInterval(of: .day, for: date) else { return "Unable to resolve report date." }
        let summary = UsageMath.summarize(records, in: day)
        let score = summary.focusScore.map { String(format: "%.0f%%", $0) } ?? "N/A (no recorded study-hour usage)"
        var lines = [date.formatted(date: .complete, time: .omitted),
                     "Total usage: \(DisplayFormat.duration(summary.total))", ""]
        for category in ActivityCategory.allCases {
            lines.append("\(category.title): \(DisplayFormat.duration(summary.byCategory[category, default: 0]))")
        }
        lines += ["", "Usage by application:"]
        let apps = UsageMath.dailyApps(records, in: day)
        lines += apps.isEmpty ? ["No app usage recorded"] : apps.map {
            "\($0.applicationName) [\($0.bundleIdentifier)] — \(DisplayFormat.duration($0.duration))"
        }
        lines += ["", "Study Focus Score: \(score)", "", "Entertainment during study hours:"]
        let entertainment = summary.entertainmentDuringStudy.sorted { $0.key < $1.key }
        lines += entertainment.isEmpty ? ["None recorded"] : entertainment.map { "\($0.key) — \(DisplayFormat.duration($0.value))" }
        lines += ["", "Websites (including YouTube): not classified in version 1.",
                  "Browser Activity is separate and does not count as study unless a parent overrides the app category.",
                  "Usage counts foreground time while this user session is active and the Mac is awake; it may include idle time.",
                  "Categories and study-hour labels reflect settings when activity was recorded."]
        return lines.joined(separator: "\n")
    }
}
