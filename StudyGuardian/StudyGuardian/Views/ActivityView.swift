import SwiftUI

struct ActivityView: View {
    @ObservedObject var model: GuardianViewModel
    @State private var date = Date()
    @State private var showTimeline = false
    @State private var sortByName = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                DatePicker("Activity date", selection: $date, in: ...Date(), displayedComponents: .date)
                    .frame(width: 280)
                Button("Today") { date = model.now }
                Spacer()
                Button("Export app CSV…") { model.exportAppCSV(date: date) }
                    .disabled(!model.settings.isUnlocked)
            }
            Picker("View", selection: $showTimeline) {
                Text("Daily app totals").tag(false)
                Text("Timeline").tag(true)
            }.pickerStyle(.segmented)
            let day = Calendar.current.dateInterval(of: .day, for: date)!
            let apps = UsageMath.dailyApps(model.records, in: day)
            HStack {
                Text("Total: \(DisplayFormat.duration(apps.reduce(0) { $0 + $1.duration })) · \(apps.count) apps")
                    .font(.headline).monospacedDigit()
                Spacer()
                if !showTimeline {
                    Picker("Sort", selection: $sortByName) {
                        Text("Longest usage first").tag(false)
                        Text("App name").tag(true)
                    }.frame(width: 240)
                }
            }
            if showTimeline {
                let sessions = model.sessions.filter { $0.endTime > day.start && $0.startTime < day.end }
                if sessions.isEmpty { emptyState }
                else { List(sessions) { session in TimelineRow(session: session) } }
            } else if apps.isEmpty {
                emptyState
            } else {
                DailyAppUsageTable(apps: sortByName ? apps.sorted {
                    let order = $0.applicationName.localizedStandardCompare($1.applicationName)
                    return order == .orderedSame ? $0.bundleIdentifier < $1.bundleIdentifier : order == .orderedAscending
                } : apps)
            }
            Text("Counts foreground app time, not background processes. All sessions for the same app are combined. Totals update about every 15 seconds while monitoring; browser time does not identify websites or video content.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24)
    }
    private var emptyState: some View {
        ContentUnavailableView("No activity", systemImage: "clock", description: Text("No recorded usage for this day."))
    }
}

struct DailyAppUsageTable: View {
    let apps: [DailyAppUsage]
    var body: some View {
        Table(apps) {
            TableColumn("Application") { app in
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.applicationName).fontWeight(.medium)
                    Text(app.bundleIdentifier).font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 3)
            }.width(min: 200, ideal: 280)
            TableColumn("Total time") { app in
                Text(DisplayFormat.duration(app.duration)).monospacedDigit()
            }.width(min: 100, ideal: 120)
            TableColumn("Usage share") { app in
                Text(String(format: "%.1f%%", app.shareOfTotal)).monospacedDigit()
            }.width(min: 85, ideal: 100)
            TableColumn("During study hours") { app in
                Text(DisplayFormat.duration(app.duringStudyHours)).monospacedDigit()
            }.width(min: 130, ideal: 150)
        }
    }
}
