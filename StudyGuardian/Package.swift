// swift-tools-version: 5.9
import PackageDescription

// Portable logic tests; the native app is built with the Xcode project.
let package = Package(
    name: "GuardianCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "GuardianCore", targets: ["GuardianCore"])],
    targets: [
        .target(name: "GuardianCore", path: "StudyGuardian",
                exclude: ["StudyGuardianApp.swift", "Info.plist", "StudyGuardian.entitlements", "Views", "ViewModels", "Models/ActivitySession.swift", "Services/ActivityMonitorService.swift", "Services/PersistenceService.swift", "Services/SettingsService.swift", "Services/ParentPINService.swift", "Services/NotificationService.swift"],
                sources: ["Models/ActivityCategory.swift", "Models/StudyPeriod.swift", "Utilities/UsageMath.swift", "Utilities/EntertainmentPolicy.swift", "Utilities/DisplayFormat.swift", "Services/ScheduleService.swift", "Services/AppClassificationService.swift", "Services/ReportService.swift"]),
        .testTarget(name: "GuardianCoreTests", dependencies: ["GuardianCore"],
                    path: "StudyGuardianTests", exclude: ["PersistenceTests.swift"])
    ]
)
