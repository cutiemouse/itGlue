#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import StudyGuardian

final class PersistenceTests: XCTestCase {
    @MainActor func testSessionRoundTripAndDeletion() throws {
        let storage = try PersistenceService(inMemory: true)
        let start = Date(timeIntervalSince1970: 1000)
        let session = ActivitySession(applicationName: "Word", bundleIdentifier: "com.microsoft.Word", startTime: start,
                                      category: .study, duringStudyHours: true)
        try storage.insert(session)
        session.endTime = start.addingTimeInterval(120)
        session.isOpen = false
        try storage.save()
        let fetched = try XCTUnwrap(storage.sessions().first)
        XCTAssertEqual(fetched.bundleIdentifier, "com.microsoft.Word")
        XCTAssertEqual(fetched.totalDuration, 120)
        XCTAssertEqual(fetched.category, .study)
        try storage.deleteAll()
        XCTAssertTrue(try storage.sessions().isEmpty)
    }
    @MainActor func testRetentionPreservesCurrentSessions() throws {
        let storage = try PersistenceService(inMemory: true)
        let old = ActivitySession(applicationName: "Steam", bundleIdentifier: "steam", startTime: .distantPast,
                                  category: .entertainment, duringStudyHours: true)
        old.isOpen = false
        try storage.insert(old)
        let active = ActivitySession(applicationName: "Preview", bundleIdentifier: "preview", startTime: Date(),
                                     category: .study, duringStudyHours: true)
        try storage.insert(active)
        try storage.prune(olderThan: Date())
        XCTAssertEqual(try storage.sessions().map(\.id), [active.id])
    }
}
#endif
