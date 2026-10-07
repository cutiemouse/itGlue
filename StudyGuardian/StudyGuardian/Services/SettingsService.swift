import Foundation
import Combine
import ServiceManagement

@MainActor
final class SettingsService: ObservableObject {
    @Published private(set) var preferences: GuardianPreferences
    @Published private(set) var unlockedUntil: Date?
    @Published private(set) var hasPIN = true
    @Published var error: String?
    private let pinService = ParentPINService()
    private let fileURL: URL
    let changed = PassthroughSubject<Void, Never>()
    var isUnlocked: Bool { unlockedUntil.map { $0 > Date() } ?? false }
    var loginEnabled: Bool { SMAppService.mainApp.status == .enabled }

    init() throws {
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                    appropriateFor: nil, create: true)
            .appendingPathComponent("StudyGuardian", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        fileURL = directory.appendingPathComponent("Preferences.json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            preferences = try JSONDecoder().decode(GuardianPreferences.self, from: Data(contentsOf: fileURL))
        } else { preferences = GuardianPreferences() }
        do { hasPIN = try pinService.exists() }
        catch { self.error = error.localizedDescription; hasPIN = true }
    }
    func unlock(pin: String, confirmation: String) {
        do {
            if hasPIN { try pinService.verify(pin) }
            else {
                guard pin == confirmation else { throw SettingsError.confirmation }
                try pinService.create(pin)
                hasPIN = true
            }
            unlockedUntil = Date().addingTimeInterval(300)
            error = nil
        } catch { self.error = error.localizedDescription }
    }
    func lock() { unlockedUntil = nil }
    func update(_ edit: (inout GuardianPreferences) -> Void) throws {
        try requireUnlocked()
        var next = preferences
        edit(&next)
        guard next.periods.allSatisfy(\.isValid), [7, 30, 90, 365].contains(next.retainDays) else {
            throw SettingsError.invalid
        }
        try JSONEncoder().encode(next).write(to: fileURL, options: .atomic)
        preferences = next
        changed.send()
    }
    func setLoginEnabled(_ enabled: Bool) throws {
        try requireUnlocked()
        if enabled { try SMAppService.mainApp.register() }
        else { try SMAppService.mainApp.unregister() }
        changed.send()
    }
    func requireUnlocked() throws {
        guard isUnlocked else { throw SettingsError.locked }
    }
}

enum SettingsError: LocalizedError {
    case locked, invalid, confirmation
    var errorDescription: String? {
        switch self {
        case .locked: return "Unlock parent settings first."
        case .invalid: return "Select at least one weekday, different start and end times, and a valid retention period."
        case .confirmation: return "The PIN and confirmation do not match."
        }
    }
}
