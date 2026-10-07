import XCTest
#if canImport(GuardianCore)
@testable import GuardianCore
#else
@testable import StudyGuardian
#endif

final class EntertainmentPolicyTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1000)
    func testInitialWarningThenSingleReminderAfterFiveMinutes() {
        var policy = EntertainmentPolicy()
        XCTAssertEqual(policy.evaluate(applicationKey: "steam", category: .entertainment,
                                       duringStudyHours: true, strictMode: false, at: start), [.warning])
        XCTAssertEqual(policy.evaluate(applicationKey: "steam", category: .entertainment,
                                       duringStudyHours: true, strictMode: false, at: start.addingTimeInterval(300)), [])
        XCTAssertEqual(policy.evaluate(applicationKey: "steam", category: .entertainment,
                                       duringStudyHours: true, strictMode: false, at: start.addingTimeInterval(301)), [.reminder])
        XCTAssertEqual(policy.evaluate(applicationKey: "steam", category: .entertainment,
                                       duringStudyHours: true, strictMode: false, at: start.addingTimeInterval(600)), [])
    }
    func testLeavingEntertainmentResetsContinuousTimer() {
        var policy = EntertainmentPolicy()
        _ = policy.evaluate(applicationKey: "steam", category: .entertainment, duringStudyHours: true, strictMode: false, at: start)
        XCTAssertEqual(policy.evaluate(applicationKey: "word", category: .study, duringStudyHours: true, strictMode: true, at: start.addingTimeInterval(30)), [])
        XCTAssertEqual(policy.evaluate(applicationKey: "steam", category: .entertainment, duringStudyHours: true, strictMode: false, at: start.addingTimeInterval(400)), [.warning])
    }
    func testStrictModeRequestsOnlyOneNormalQuitPerOccurrence() {
        var policy = EntertainmentPolicy()
        XCTAssertEqual(policy.evaluate(applicationKey: "steam", category: .entertainment, duringStudyHours: true, strictMode: true, at: start), [.warning, .requestNormalQuit])
        XCTAssertEqual(policy.evaluate(applicationKey: "steam", category: .entertainment, duringStudyHours: true, strictMode: true, at: start.addingTimeInterval(60)), [])
        XCTAssertEqual(policy.evaluate(applicationKey: "roblox", category: .entertainment, duringStudyHours: true, strictMode: true, at: start.addingTimeInterval(90)), [.warning, .requestNormalQuit])
    }
    func testUnknownBrowserAndOutsideScheduleNeverQuit() {
        var policy = EntertainmentPolicy()
        for category in [ActivityCategory.unknown, .browser, .communication, .study] {
            XCTAssertEqual(policy.evaluate(applicationKey: "app", category: category, duringStudyHours: true, strictMode: true, at: start), [])
        }
        XCTAssertEqual(policy.evaluate(applicationKey: "steam", category: .entertainment, duringStudyHours: false, strictMode: true, at: start), [])
    }
    func testEndingStudyPeriodResetsWarningState() {
        var policy = EntertainmentPolicy()
        _ = policy.evaluate(applicationKey: "steam", category: .entertainment, duringStudyHours: true, strictMode: false, at: start)
        _ = policy.evaluate(applicationKey: "steam", category: .entertainment, duringStudyHours: false, strictMode: false, at: start.addingTimeInterval(200))
        XCTAssertEqual(policy.evaluate(applicationKey: "steam", category: .entertainment, duringStudyHours: true, strictMode: false, at: start.addingTimeInterval(400)), [.warning])
    }
}
