import SwiftUI
import AppKit

struct AppsView: View {
    @ObservedObject var model: GuardianViewModel
    @State private var search = ""
    @State private var manualID = ""
    @State private var manualCategory: ActivityCategory = .unknown
    private var identifiers: [String] {
        let keys = Set(AppClassificationService().knownApplications.keys)
            .union(model.sessions.map(\.bundleIdentifier)).union(model.settings.preferences.categoryOverrides.keys)
        return keys.sorted().filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) || name(for: $0).localizedCaseInsensitiveContains(search) }
    }
    private func name(for id: String) -> String {
        if let session = model.sessions.first(where: { $0.bundleIdentifier == id }) { return session.applicationName }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return id
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories describe applications, not what happens inside them. Browsers default to Browser Activity. Overrides apply to future activity.")
                .foregroundStyle(.secondary)
            TextField("Search applications or bundle IDs", text: $search)
            List(identifiers, id: \.self) { id in
                HStack {
                    VStack(alignment: .leading) {
                        Text(name(for: id))
                        Text(id).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("Category", selection: Binding(get: {
                        AppClassificationService().category(bundleIdentifier: id, overrides: model.settings.preferences.categoryOverrides)
                    }, set: { category in model.editSettings { $0.categoryOverrides[id] = category } })) {
                        ForEach(ActivityCategory.allCases) { Text($0.title).tag($0) }
                    }.labelsHidden().frame(width: 165).disabled(!model.settings.isUnlocked)
                    Button("Reset") { model.editSettings { $0.categoryOverrides.removeValue(forKey: id) } }
                        .disabled(!model.settings.isUnlocked || model.settings.preferences.categoryOverrides[id] == nil)
                }.padding(.vertical, 4)
            }
            HStack {
                TextField("Additional app bundle identifier", text: $manualID)
                Picker("Category", selection: $manualCategory) {
                    ForEach(ActivityCategory.allCases) { Text($0.title).tag($0) }
                }.frame(width: 200)
                Button("Add override") {
                    let id = manualID.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !id.isEmpty else { return }
                    model.editSettings { $0.categoryOverrides[id] = manualCategory }
                    manualID = ""
                }.disabled(!model.settings.isUnlocked || manualID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.disabled(!model.settings.isUnlocked)
        }.padding(24)
    }
}
