import Foundation

struct ScheduleService {
    var calendar = Calendar.current

    func isStudyTime(_ date: Date, periods: [StudyPeriod]) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let previousWeekday = weekday == 1 ? 7 : weekday - 1
        return periods.contains { period in
            guard period.enabled && period.isValid else { return false }
            if period.startMinute < period.endMinute {
                return period.weekdays.contains(weekday) && minute >= period.startMinute && minute < period.endMinute
            }
            return (period.weekdays.contains(weekday) && minute >= period.startMinute)
                || (period.weekdays.contains(previousWeekday) && minute < period.endMinute)
        }
    }

    /// Finds the exact minute boundary, including midnight, even if the main loop was delayed.
    /// Session labels are historical snapshots; later schedule edits do not rewrite history.
    func boundaries(from start: Date, to end: Date, periods: [StudyPeriod]) -> [Date] {
        guard end > start else { return [] }
        var points: [Date] = []
        var cursor = calendar.dateInterval(of: .minute, for: start)?.end ?? start.addingTimeInterval(60)
        var previous = isStudyTime(start, periods: periods)
        while cursor <= end {
            let next = isStudyTime(cursor, periods: periods)
            if next != previous || calendar.component(.hour, from: cursor) == 0
                && calendar.component(.minute, from: cursor) == 0 {
                points.append(cursor)
            }
            previous = next
            guard let following = calendar.date(byAdding: .minute, value: 1, to: cursor), following > cursor else { break }
            cursor = following
        }
        return points
    }
}
