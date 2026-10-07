import XCTest
#if canImport(GuardianCore)
@testable import GuardianCore
#else
@testable import StudyGuardian
#endif

final class GuardianCoreTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Vancouver")!
        return value
    }
    private func date(_ day: Int = 5, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }
    func testDefaultWeekdayScheduleUsesExclusiveEnd() {
        let service = ScheduleService(calendar: calendar)
        XCTAssertFalse(service.isStudyTime(date(5, 15, 59), periods: [.defaultPeriod]))
        XCTAssertTrue(service.isStudyTime(date(5, 16), periods: [.defaultPeriod]))
        XCTAssertTrue(service.isStudyTime(date(5, 20, 59), periods: [.defaultPeriod]))
        XCTAssertFalse(service.isStudyTime(date(5, 21), periods: [.defaultPeriod]))
        XCTAssertFalse(service.isStudyTime(date(10, 17), periods: [.defaultPeriod]))
    }
    func testOvernightPeriodFollowsSelectedStartDay() {
        let period = StudyPeriod(weekdays: [2], startMinute: 22 * 60, endMinute: 2 * 60)
        let service = ScheduleService(calendar: calendar)
        XCTAssertTrue(service.isStudyTime(date(5, 23), periods: [period]))
        XCTAssertTrue(service.isStudyTime(date(6, 1), periods: [period]))
        XCTAssertFalse(service.isStudyTime(date(6, 2), periods: [period]))
        XCTAssertFalse(service.isStudyTime(date(6, 23), periods: [period]))
    }
    func testDisabledAndInvalidPeriodsDoNotApply() {
        var period = StudyPeriod.defaultPeriod
        period.enabled = false
        let service = ScheduleService(calendar: calendar)
        XCTAssertFalse(service.isStudyTime(date(5, 17), periods: [period]))
        XCTAssertFalse(StudyPeriod(weekdays: [], startMinute: 0, endMinute: 60).isValid)
        XCTAssertFalse(StudyPeriod(weekdays: [2], startMinute: 60, endMinute: 60).isValid)
    }
    func testOverlappingPeriodsAreCombined() {
        let periods = [StudyPeriod(weekdays: [2], startMinute: 960, endMinute: 1080),
                       StudyPeriod(weekdays: [2], startMinute: 1020, endMinute: 1140)]
        let service = ScheduleService(calendar: calendar)
        XCTAssertEqual(service.boundaries(from: date(5, 15), to: date(5, 20), periods: periods),
                       [date(5, 16), date(5, 19)])
    }
    func testDelayedCheckpointSplitsExactBoundaries() {
        let service = ScheduleService(calendar: calendar)
        XCTAssertEqual(service.boundaries(from: date(5, 15, 59), to: date(5, 21, 1), periods: [.defaultPeriod]),
                       [date(5, 16), date(5, 21)])
        XCTAssertEqual(service.boundaries(from: date(5, 23, 59), to: date(6, 0, 1), periods: []), [date(6, 0)])
    }
    func testDSTFallBackBoundaryUsesLocalClock() {
        let period = StudyPeriod(weekdays: [1], startMinute: 60, endMinute: 120)
        let service = ScheduleService(calendar: calendar)
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 0))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 3))!
        XCTAssertEqual(service.boundaries(from: start, to: end, periods: [period]).count, 2)
        XCTAssertEqual(end.timeIntervalSince(start), 4 * 3600)
    }
    func testBrowsersAreSeparateAndOverridesWin() {
        let service = AppClassificationService()
        XCTAssertEqual(service.category(bundleIdentifier: "com.apple.Safari", overrides: [:]), .browser)
        XCTAssertEqual(service.category(bundleIdentifier: "com.google.Chrome", overrides: [:]), .browser)
        XCTAssertEqual(service.category(bundleIdentifier: "com.apple.Safari", overrides: ["com.apple.Safari": .study]), .study)
        XCTAssertEqual(service.category(bundleIdentifier: "unrecognized.app", overrides: [:]), .unknown)
        XCTAssertEqual(service.category(bundleIdentifier: "com.valvesoftware.steam", overrides: [:]), .entertainment)
    }
    func testFocusScoreIncludesBrowserTimeInDenominatorOnly() {
        let records = [
            UsageRecord(applicationName: "Word", bundleIdentifier: "word", start: date(5, 16), end: date(5, 17), category: .study, duringStudyHours: true),
            UsageRecord(applicationName: "Chrome", bundleIdentifier: "chrome", start: date(5, 17), end: date(5, 18), category: .browser, duringStudyHours: true),
            UsageRecord(applicationName: "Word", bundleIdentifier: "word", start: date(5, 10), end: date(5, 11), category: .study, duringStudyHours: false)
        ]
        let summary = UsageMath.summarize(records, in: calendar.dateInterval(of: .day, for: date(5, 12))!)
        XCTAssertEqual(summary.total, 10800)
        XCTAssertEqual(summary.byCategory[.study], 7200)
        XCTAssertEqual(summary.byCategory[.browser], 3600)
        XCTAssertEqual(summary.focusScore, 50)
    }
    func testDailySummaryClipsMidnightAndInvalidIntervals() {
        let records = [UsageRecord(applicationName: "Steam", bundleIdentifier: "steam", start: date(5, 23, 30), end: date(6, 0, 30), category: .entertainment, duringStudyHours: true),
                       UsageRecord(applicationName: "Bad", bundleIdentifier: "bad", start: date(5, 12), end: date(5, 11), category: .unknown, duringStudyHours: true)]
        let summary = UsageMath.summarize(records, in: calendar.dateInterval(of: .day, for: date(6, 12))!)
        XCTAssertEqual(summary.total, 1800)
        XCTAssertEqual(summary.entertainmentDuringStudy["Steam"], 1800)
        XCTAssertEqual(summary.focusScore, 0)
    }
    func testNoUsageHasNoInventedFocusScore() {
        let summary = UsageMath.summarize([], in: calendar.dateInterval(of: .day, for: date(5, 12))!)
        XCTAssertEqual(summary.total, 0)
        XCTAssertNil(summary.focusScore)
    }
    func testReportMakesWebsiteLimitExplicit() {
        let report = ReportService().dailySummary(date: date(5, 12), records: [], calendar: calendar)
        XCTAssertTrue(report.contains("Total usage: 0m"))
        XCTAssertTrue(report.contains("N/A"))
        XCTAssertTrue(report.contains("YouTube"))
        XCTAssertTrue(report.contains("not classified"))
    }
}


extension GuardianCoreTests {
    func testDailyAppTotalsMergeCategoryAndScheduleSegmentsByBundleID() throws {
        let records = [
            UsageRecord(applicationName: "Chrome", bundleIdentifier: "chrome", start: date(5, 16), end: date(5, 17), category: .browser, duringStudyHours: true),
            UsageRecord(applicationName: "Google Chrome", bundleIdentifier: "chrome", start: date(5, 18), end: date(5, 18, 30), category: .study, duringStudyHours: false),
            UsageRecord(applicationName: "Word", bundleIdentifier: "word", start: date(5, 17), end: date(5, 18), category: .study, duringStudyHours: true)
        ]
        let day = calendar.dateInterval(of: .day, for: date(5, 12))!
        let apps = UsageMath.dailyApps(records, in: day)
        XCTAssertEqual(apps.count, 2)
        let chrome = try XCTUnwrap(apps.first)
        XCTAssertEqual(chrome.id, "chrome")
        XCTAssertEqual(chrome.applicationName, "Google Chrome")
        XCTAssertEqual(chrome.duration, 5400)
        XCTAssertEqual(chrome.duringStudyHours, 3600)
        XCTAssertEqual(chrome.shareOfTotal, 60, accuracy: 0.001)
        XCTAssertEqual(apps.reduce(0) { $0 + $1.duration }, UsageMath.summarize(records, in: day).total)
        XCTAssertEqual(UsageMath.dailyApps(records.reversed(), in: day).first?.applicationName, "Google Chrome")
    }
    func testDailyAppTotalsClipCrossMidnightAndIgnoreInvalidRecords() {
        let records = [
            UsageRecord(applicationName: "Steam", bundleIdentifier: "steam", start: date(5, 23, 30), end: date(6, 0, 30), category: .entertainment, duringStudyHours: true),
            UsageRecord(applicationName: "Invalid", bundleIdentifier: "invalid", start: date(6, 12), end: date(6, 11), category: .unknown, duringStudyHours: false),
            UsageRecord(applicationName: "Zero", bundleIdentifier: "zero", start: date(6, 12), end: date(6, 12), category: .unknown, duringStudyHours: false)
        ]
        let day = calendar.dateInterval(of: .day, for: date(6, 12))!
        let apps = UsageMath.dailyApps(records, in: day)
        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps.first?.duration, 1800)
        XCTAssertEqual(apps.first?.duringStudyHours, 1800)
        XCTAssertEqual(apps.first?.shareOfTotal, 100)
    }
    func testSameDisplayNameDoesNotMergeDifferentBundleIDs() {
        let records = ["second", "first"].map { id in
            UsageRecord(applicationName: "Editor", bundleIdentifier: id, start: date(5, 16), end: date(5, 17), category: .study, duringStudyHours: true)
        }
        let apps = UsageMath.dailyApps(records, in: calendar.dateInterval(of: .day, for: date(5, 12))!)
        XCTAssertEqual(apps.map(\.id), ["first", "second"])
        XCTAssertEqual(apps.map(\.shareOfTotal), [50, 50])
    }
    func testDailyCSVIncludesAccurateNumbersAndEscapesAppNames() {
        let records = [UsageRecord(applicationName: "Editor, \"Pro\"\nEdition", bundleIdentifier: "editor", start: date(5, 16), end: date(5, 16, 30), category: .study, duringStudyHours: true)]
        let csv = ReportService().dailyAppCSV(date: date(5, 12), records: records, calendar: calendar)
        XCTAssertTrue(csv.contains("\"2026-10-05\",\"Editor, \"\"Pro\"\"\nEdition\",\"editor\",1800,\"30m\",100.00,1800\r\n"))
        let report = ReportService().dailySummary(date: date(5, 12), records: records, calendar: calendar)
        XCTAssertTrue(report.contains("Usage by application:"))
        XCTAssertTrue(report.contains("[editor] — 30m"))
        let unsafe = [UsageRecord(applicationName: "=HYPERLINK(\"example\")", bundleIdentifier: "unsafe", start: date(5, 16), end: date(5, 17), category: .unknown, duringStudyHours: false)]
        XCTAssertTrue(ReportService().dailyAppCSV(date: date(5, 12), records: unsafe, calendar: calendar).contains("\"'=HYPERLINK"))
    }
    func testEmptyDailyTableAndCSVDoNotInventUsage() {
        let day = calendar.dateInterval(of: .day, for: date(5, 12))!
        XCTAssertTrue(UsageMath.dailyApps([], in: day).isEmpty)
        let csv = ReportService().dailyAppCSV(date: date(5, 12), records: [], calendar: calendar)
        XCTAssertEqual(csv, "Date,Application,Bundle identifier,Duration seconds,Duration,Usage percent,Study-hour seconds\r\n")
    }
}
