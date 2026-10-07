import SwiftUI

struct ReportsView: View {
    @ObservedObject var model: GuardianViewModel
    @State private var date = Date()
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                DatePicker("Daily report", selection: $date, in: ...Date(), displayedComponents: .date)
                Spacer()
                Button("Export app CSV…") { model.exportAppCSV(date: date) }.disabled(!model.settings.isUnlocked)
                Button("Export text report…") { model.exportReport(date: date) }.disabled(!model.settings.isUnlocked)
            }
            ScrollView {
                Text(ReportService().dailySummary(date: date, records: model.records))
                    .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding()
            }.background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            Text("Reports are generated locally. Export is a parent-authorized, local file save; no data is uploaded.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24)
    }
}
