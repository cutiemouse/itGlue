import SwiftUI

struct DashboardView: View {
    @ObservedObject var model: GuardianViewModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Today").font(.largeTitle.bold())
                        Text(model.now.formatted(date: .complete, time: .omitted)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label(model.studyActive ? "Study hours active" : "Outside study hours", systemImage: "calendar.badge.clock")
                }
                HStack(spacing: 16) {
                    metric("Total Mac usage", DisplayFormat.duration(model.todaySummary.total), "desktopcomputer")
                    metric("Study Focus Score", model.todaySummary.focusScore.map { String(format: "%.0f%%", $0) } ?? "—", "target")
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                    ForEach(ActivityCategory.allCases) { category in
                        metric(category.title, DisplayFormat.duration(model.todaySummary.byCategory[category, default: 0]), "clock")
                    }
                }
                Text("Focus Score = confirmed study time ÷ all recorded foreground time during study hours. Browser time is separate unless a parent classifies that browser as Study.")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Text("Today’s app usage").font(.title2)
                    Spacer()
                    Button("Export app CSV…") { model.exportAppCSV(date: model.now) }
                        .disabled(!model.settings.isUnlocked)
                }
                let apps = UsageMath.dailyApps(model.records, in: model.today)
                if !apps.isEmpty {
                    DailyAppUsageTable(apps: apps)
                        .frame(height: min(360, CGFloat(apps.count) * 48 + 40))
                } else { Text("No app usage recorded today.").foregroundStyle(.secondary) }
                Text("Today’s timeline").font(.title2)
                if model.todaySessions.isEmpty { Text("No activity recorded today.").foregroundStyle(.secondary) }
                ForEach(Array(model.todaySessions.prefix(20).reversed())) { session in TimelineRow(session: session) }
                Text("Only application names, identifiers, and timing are recorded. No keystrokes, messages, documents, screenshots, camera, microphone, or website contents are collected. Awake foreground time can include idle time.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }
    }
    private func metric(_ title: String, _ value: String, _ icon: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: icon).foregroundStyle(.secondary)
                Text(value).font(.title.bold()).monospacedDigit()
            }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
        }
    }
}

struct TimelineRow: View {
    let session: ActivitySession
    var body: some View {
        HStack(spacing: 16) {
            Text("\(session.startTime.formatted(date: .omitted, time: .shortened))–\(session.endTime.formatted(date: .omitted, time: .shortened))")
                .monospacedDigit().frame(width: 175, alignment: .leading)
            VStack(alignment: .leading) {
                Text(session.applicationName).fontWeight(.medium)
                Text(session.bundleIdentifier).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(session.category.title).foregroundStyle(.secondary)
            if session.duringStudyHours { Image(systemName: "calendar.badge.clock").help("During study hours") }
            Text(DisplayFormat.duration(session.totalDuration)).monospacedDigit().frame(width: 80, alignment: .trailing)
            if session.isOpen { Text("Active").font(.caption).foregroundStyle(.green) }
        }.padding(.vertical, 6)
    }
}
