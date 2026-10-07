import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: GuardianViewModel
    @State private var confirmDelete = false
    var body: some View {
        Form {
            Section("Study-time reminders") {
                Toggle("Entertainment reminders", isOn: Binding(get: { model.settings.preferences.remindersEnabled }, set: { enabled in
                    model.editSettings { $0.remindersEnabled = enabled }
                }))
                LabeledContent("macOS notification permission", value: model.notifications.status)
                Button("Allow macOS notifications…") {
                    guard model.settings.isUnlocked else { return }
                    Task { await model.notifications.requestAuthorization() }
                }
                Text("An initial warning is followed by one reminder after more than five continuous foreground minutes. macOS Focus or denied permission can suppress banners; current warnings also appear in Study Guardian.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Strict Mode") {
                Toggle("Request normal quit of entertainment apps during study hours", isOn: Binding(get: {
                    model.settings.preferences.strictMode
                }, set: { enabled in model.editSettings { $0.strictMode = enabled } }))
                Text("Optional and off by default. Apps can refuse or show an unsaved-work prompt. Study Guardian never force-quits and does not guarantee blocking.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Login") {
                Toggle("Launch Study Guardian automatically when this user logs in", isOn: Binding(get: { model.settings.loginEnabled }, set: { enabled in
                    do { try model.settings.setLoginEnabled(enabled) }
                    catch { model.error = error.localizedDescription }
                }))
                Text("macOS may require approval in System Settings > General > Login Items. Launch from a stable installed location, such as Applications.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Reporting and local storage") {
                Picker("Keep activity for", selection: Binding(get: { model.settings.preferences.retainDays }, set: { days in
                    model.editSettings { $0.retainDays = days }
                })) {
                    ForEach([7, 30, 90, 365], id: \.self) { Text("\($0) days").tag($0) }
                }
                Text("Data stays in ~/Library/Application Support/StudyGuardian. PIN verification uses a salted, slow hash in Keychain. No account or network service is required.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Delete recorded activity…", role: .destructive) { confirmDelete = true }
            }
            Section("Transparency") {
                Text("The menu-bar shield shows Study Guardian is running. Closing its window keeps monitoring active; quitting ends monitoring. This app is a visible household agreement tool, not tamper-proof device management. Someone with this macOS account can quit the app or alter local files. Use a separate parent administrator account and standard child account for stronger OS-level controls.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .disabled(!model.settings.isUnlocked)
        .onAppear { Task { await model.notifications.refreshStatus() } }
        .confirmationDialog("Delete all recorded activity? This cannot be undone.", isPresented: $confirmDelete) {
            Button("Delete activity", role: .destructive) {
                do { try model.monitor.deleteHistory(); model.refresh() }
                catch { model.error = error.localizedDescription }
            }
        }
    }
}
