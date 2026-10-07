import SwiftUI

enum GuardianScreen: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard", activity = "Activity", apps = "Apps"
    case schedule = "Schedule", reports = "Reports", settings = "Settings"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dashboard: return "chart.pie"
        case .activity: return "clock"
        case .apps: return "app.badge"
        case .schedule: return "calendar"
        case .reports: return "doc.text"
        case .settings: return "gearshape"
        }
    }
}

struct RootView: View {
    @ObservedObject var model: GuardianViewModel
    @State private var selection: GuardianScreen? = .dashboard
    @State private var showingUnlock = false
    var body: some View {
        NavigationSplitView {
            List(GuardianScreen.allCases, selection: $selection) { screen in
                Label(screen.rawValue, systemImage: screen.icon).tag(screen)
            }
            .navigationTitle("Study Guardian")
            .navigationSplitViewColumnWidth(min: 175, ideal: 190)
        } detail: {
            VStack(spacing: 0) {
                HStack {
                    Label(model.monitor.isMonitoring ? "Recording app usage locally" : "Recording paused",
                          systemImage: model.monitor.isMonitoring ? "circle.fill" : "pause.circle")
                        .foregroundStyle(model.monitor.isMonitoring ? .green : .secondary)
                    Spacer()
                    Button(model.settings.isUnlocked ? "Lock settings" : (model.settings.hasPIN ? "Unlock parent settings" : "Create parent PIN")) {
                        if model.settings.isUnlocked { model.settings.lock() }
                        else { showingUnlock = true }
                    }
                }.padding()
                Divider()
                if let error = model.monitor.error {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red).padding()
                }
                if let warning = model.monitor.warning {
                    Label(warning, systemImage: "exclamationmark.shield").foregroundStyle(.orange).padding()
                }
                Group {
                    switch selection ?? .dashboard {
                    case .dashboard: DashboardView(model: model)
                    case .activity: ActivityView(model: model)
                    case .apps: AppsView(model: model)
                    case .schedule: ScheduleView(model: model)
                    case .reports: ReportsView(model: model)
                    case .settings: SettingsView(model: model)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle((selection ?? .dashboard).rawValue)
        }
        .sheet(isPresented: $showingUnlock) { ParentUnlockView(settings: model.settings) }
        .alert("Study Guardian", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
}

struct ParentUnlockView: View {
    @ObservedObject var settings: SettingsService
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var confirmation = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(settings.hasPIN ? "Parent settings" : "Create a parent PIN", systemImage: "lock.shield").font(.title2)
            Text(settings.hasPIN ? "Settings unlock for five minutes, or until you lock the screen." : "Choose 6–12 digits. Your PIN is secured in this Mac’s Keychain.")
            SecureField("Parent PIN", text: $pin)
            if !settings.hasPIN { SecureField("Confirm PIN", text: $confirmation) }
            if let error = settings.error { Text(error).foregroundStyle(.red) }
            HStack {
                Button("Cancel") { pin = ""; confirmation = ""; dismiss() }
                Spacer()
                Button(settings.hasPIN ? "Unlock" : "Create PIN") {
                    settings.unlock(pin: pin, confirmation: confirmation)
                    pin = ""; confirmation = ""
                    if settings.isUnlocked { dismiss() }
                }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 400)
    }
}
