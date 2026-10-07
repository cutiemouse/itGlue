import SwiftUI
import AppKit

@main
@MainActor
struct StudyGuardianApp: App {
    private let model: GuardianViewModel?
    private let startupError: String?

    init() {
        do { model = try GuardianViewModel(); startupError = nil }
        catch { model = nil; startupError = error.localizedDescription }
    }
    var body: some Scene {
        WindowGroup("Study Guardian", id: "main") {
            if let model {
                RootView(model: model)
                    .task { model.monitor.start() }
                    .frame(minWidth: 900, minHeight: 620)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.shield").font(.largeTitle)
                    Text("Study Guardian could not start").font(.title2)
                    Text(startupError ?? "Unknown startup error").textSelection(.enabled)
                    Text("No activity is being recorded. Check access to local Application Support storage, then restart.")
                }.padding(40)
            }
        }
        .defaultSize(width: 1060, height: 740)
        MenuBarExtra("Study Guardian", systemImage: "shield.lefthalf.filled") {
            if let model { GuardianMenu(model: model) }
            else { Text("Not recording — startup failed") }
        }
    }
}

struct GuardianMenu: View {
    @ObservedObject var model: GuardianViewModel
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Text(model.monitor.isMonitoring ? "Recording foreground app usage" : "Recording paused")
        Text(model.monitor.currentApplication)
        Text(model.studyActive ? "Study hours active" : "Outside study hours")
        if let warning = model.monitor.warning { Text(warning) }
        Divider()
        Button("Open Study Guardian") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Lock parent settings") { model.settings.lock() }
        Divider()
        Button("Quit Study Guardian") {
            model.monitor.stop()
            NSApp.terminate(nil)
        }
    }
}
