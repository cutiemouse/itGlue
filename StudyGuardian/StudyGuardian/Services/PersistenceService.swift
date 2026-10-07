import Foundation
import SwiftData

@MainActor
final class PersistenceService {
    let container: ModelContainer
    private let context: ModelContext

    init(inMemory: Bool = false) throws {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                        appropriateFor: nil, create: true)
                .appendingPathComponent("StudyGuardian", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            configuration = ModelConfiguration(url: directory.appendingPathComponent("Activity.store"),
                                               cloudKitDatabase: .none)
        }
        container = try ModelContainer(for: ActivitySession.self, configurations: configuration)
        context = container.mainContext
        // Recover checkpoints without inventing activity between the crash and next launch.
        for session in try sessions() where session.isOpen { session.isOpen = false }
        try context.save()
    }

    func sessions() throws -> [ActivitySession] {
        try context.fetch(FetchDescriptor<ActivitySession>(sortBy: [SortDescriptor(\ActivitySession.startTime, order: .reverse)]))
    }
    func insert(_ session: ActivitySession) throws {
        context.insert(session)
        try context.save()
    }
    func save() throws { try context.save() }
    func prune(olderThan cutoff: Date) throws {
        for session in try sessions() where !session.isOpen && session.endTime < cutoff { context.delete(session) }
        try context.save()
    }
    func deleteAll() throws {
        for session in try sessions() { context.delete(session) }
        try context.save()
    }
}
