import Foundation

enum ActivityCategory: String, CaseIterable, Codable, Identifiable {
    case study = "STUDY"
    case entertainment = "ENTERTAINMENT"
    case communication = "COMMUNICATION"
    case unknown = "UNKNOWN"
    case browser = "BROWSER_ACTIVITY"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .study: return "Study"
        case .entertainment: return "Entertainment"
        case .communication: return "Communication"
        case .unknown: return "Unknown"
        case .browser: return "Browser Activity"
        }
    }
}

/// A permission-gated extension point. Version 1 never reads URLs, tabs, or page content.
protocol BrowserDomainClassifying {
    func category(forExplicitlySharedDomain domain: String) -> ActivityCategory?
}
