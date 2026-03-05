import Foundation

// MARK: - System Maintenance Tasks
class MaintenanceService {

    struct MaintenanceTask: Identifiable {
        let id = UUID()
        var name: String
        var description: String
        var icon: String
        var lastRun: Date?
        var estimatedTime: String
        var requiresAdmin: Bool
    }

    static let availableTasks: [MaintenanceTask] = [
        MaintenanceTask(name: "Run Maintenance Scripts",
                        description: "Periodic Unix maintenance scripts (daily, weekly, monthly)",
                        icon: "wrench.and.screwdriver.fill",
                        lastRun: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
                        estimatedTime: "1–2 min",
                        requiresAdmin: true),
        MaintenanceTask(name: "Flush DNS Cache",
                        description: "Clears cached DNS records to fix network resolution issues",
                        icon: "network",
                        lastRun: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
                        estimatedTime: "< 5 sec",
                        requiresAdmin: false),
        MaintenanceTask(name: "Rebuild Spotlight Index",
                        description: "Re-indexes your Mac for faster Spotlight searches",
                        icon: "magnifyingglass",
                        lastRun: nil,
                        estimatedTime: "5–15 min",
                        requiresAdmin: true),
        MaintenanceTask(name: "Rebuild Mail Index",
                        description: "Speeds up searching in the Mail app by rebuilding its index",
                        icon: "envelope.fill",
                        lastRun: Calendar.current.date(byAdding: .day, value: -30, to: Date()),
                        estimatedTime: "2–5 min",
                        requiresAdmin: false),
        MaintenanceTask(name: "Free Purgeable Space",
                        description: "Reclaims disk space marked as purgeable by macOS",
                        icon: "arrow.down.circle.fill",
                        lastRun: nil,
                        estimatedTime: "< 30 sec",
                        requiresAdmin: false)
    ]

    // MARK: - Flush DNS Cache
    func flushDNS() async throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
        task.arguments = ["-flushcache"]
        try task.run()
        task.waitUntilExit()

        // Also kill mDNSResponder
        let task2 = Process()
        task2.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task2.arguments = ["-HUP", "mDNSResponder"]
        try? task2.run()
        task2.waitUntilExit()
    }

    // MARK: - Run Daily/Weekly/Monthly Maintenance Scripts
    func runMaintenanceScripts() async throws {
        for script in ["daily", "weekly", "monthly"] {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/periodic")
            task.arguments = [script]
            try? task.run()
            task.waitUntilExit()
        }
    }

    // MARK: - Rebuild Spotlight Index
    func rebuildSpotlight() async throws {
        let homePath = NSHomeDirectory()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/mdutil")
        task.arguments = ["-E", homePath]
        try task.run()
        task.waitUntilExit()
    }

    // MARK: - Rebuild Mail Index
    func rebuildMailIndex() async throws {
        let mailPath = NSHomeDirectory() + "/Library/Mail"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        // Close and reopen the mail envelope index
        task.arguments = ["\(mailPath)/V10/MailData/Envelope\\ Index", "VACUUM;"]
        try? task.run()
        task.waitUntilExit()
    }
}
