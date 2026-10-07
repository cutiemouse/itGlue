import Foundation

struct AppClassificationService {
    private static let defaults: [String: ActivityCategory] = [
        "com.apple.Safari": .browser,
        "com.google.Chrome": .browser,
        "org.mozilla.firefox": .browser,
        "com.microsoft.edgemac": .browser,
        "company.thebrowser.Browser": .browser,
        "com.brave.Browser": .browser,
        "com.microsoft.Word": .study,
        "com.microsoft.Powerpoint": .study,
        "com.microsoft.Excel": .study,
        "com.microsoft.onenote.mac": .study,
        "com.apple.Preview": .study,
        "com.adobe.Acrobat.Pro": .study,
        "com.adobe.Reader": .study,
        "com.microsoft.VSCode": .study,
        "com.apple.dt.Xcode": .study,
        "com.todesktop.230313mzl4w4u92": .study,
        "com.figma.Desktop": .study,
        "com.valvesoftware.steam": .entertainment,
        "com.epicgames.EpicGamesLauncher": .entertainment,
        "net.battle.BattleNet": .entertainment,
        "net.battle.net.app": .entertainment,
        "com.roblox.RobloxPlayer": .entertainment,
        "com.mojang.minecraftlauncher": .entertainment,
        "com.ea.app": .entertainment,
        "com.ea.EADesktop": .entertainment,
        "com.ea.origin": .entertainment,
        "com.hnc.Discord": .communication,
        "com.apple.MobileSMS": .communication,
        "com.apple.FaceTime": .communication,
        "net.whatsapp.WhatsApp": .communication,
        "com.tencent.xinWeChat": .communication
    ]

    func category(bundleIdentifier: String, overrides: [String: ActivityCategory]) -> ActivityCategory {
        overrides[bundleIdentifier] ?? Self.defaults[bundleIdentifier] ?? .unknown
    }

    var knownApplications: [String: ActivityCategory] { Self.defaults }
}
