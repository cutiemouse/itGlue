import SwiftUI

struct ScheduleView: View {
    @ObservedObject var model: GuardianViewModel
    @State private var weekdays = Set(2...6)
    @State private var start = Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: Date())!
    @State private var end = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date())!
    private var minuteStart: Int { minutes(start) }
    private var minuteEnd: Int { minutes(end) }
    private func minutes(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date) * 60 + Calendar.current.component(.minute, from: date)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Study periods use this Mac’s local time zone. Overnight periods end the following day. Overlapping periods are combined.")
                    .foregroundStyle(.secondary)
                ForEach(model.settings.preferences.periods) { period in
                    GroupBox {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(period.weekdays.sorted().map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", "))
                                Text("\(DisplayFormat.clock(period.startMinute)) – \(DisplayFormat.clock(period.endMinute))\(period.startMinute > period.endMinute ? " (next day)" : "")")
                            }
                            Spacer()
                            Toggle("Enabled", isOn: Binding(get: { period.enabled }, set: { value in
                                model.editSettings { preferences in
                                    if let index = preferences.periods.firstIndex(where: { $0.id == period.id }) { preferences.periods[index].enabled = value }
                                }
                            })).toggleStyle(.switch)
                            Button("Remove", role: .destructive) { model.editSettings { $0.periods.removeAll { $0.id == period.id } } }
                        }.padding(8).disabled(!model.settings.isUnlocked)
                    }
                }
                if model.settings.preferences.periods.isEmpty { Text("No study periods configured. Activity is logged without entertainment warnings.") }
                GroupBox("Add study period") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { weekday in
                                Toggle(Calendar.current.shortWeekdaySymbols[weekday - 1], isOn: Binding(get: { weekdays.contains(weekday) }, set: {
                                    if $0 { weekdays.insert(weekday) } else { weekdays.remove(weekday) }
                                })).toggleStyle(.button)
                            }
                        }
                        HStack {
                            DatePicker("Start", selection: $start, displayedComponents: .hourAndMinute)
                            DatePicker("End", selection: $end, displayedComponents: .hourAndMinute)
                            Button("Add") {
                                let period = StudyPeriod(weekdays: weekdays, startMinute: minuteStart, endMinute: minuteEnd)
                                model.editSettings { $0.periods.append(period) }
                            }.disabled(weekdays.isEmpty || minuteStart == minuteEnd)
                        }
                        if minuteStart == minuteEnd { Text("Start and end must differ.").foregroundStyle(.red) }
                    }.padding(8).disabled(!model.settings.isUnlocked)
                }
                Text("Unlock parent settings to change periods. Schedule edits apply prospectively; historical reports retain the schedule used when recorded.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }
    }
}
