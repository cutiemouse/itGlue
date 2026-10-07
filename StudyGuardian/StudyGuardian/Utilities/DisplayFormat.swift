import Foundation

enum DisplayFormat {
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds) / 60)
        if minutes == 0 { return seconds > 0 ? "<1m" : "0m" }
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
    static func clock(_ minute: Int) -> String {
        let date = Calendar.current.startOfDay(for: Date())
        return (Calendar.current.date(byAdding: .minute, value: minute, to: date) ?? date)
            .formatted(date: .omitted, time: .shortened)
    }
}
