import Foundation
import AppKit

// MARK: - Real App Manager Service
class AppManagerService: ObservableObject {
    @Published var installedApps: [AppInfo] = []
    @Published var isLoading = false

    private let cleanupService = CleanupService()

    // MARK: - Scan /Applications for installed apps
    func loadInstalledApps() async {
        await MainActor.run { isLoading = true }

        let searchPaths = [
            "/Applications",
            NSHomeDirectory() + "/Applications"
        ]

        var apps: [AppInfo] = []

        for basePath in searchPaths {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: basePath) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let appPath = (basePath as NSString).appendingPathComponent(item)
                if let appInfo = parseApp(at: appPath) {
                    apps.append(appInfo)
                }
            }
        }

        // Sort by size descending
        apps.sort { $0.size > $1.size }

        await MainActor.run {
            self.installedApps = apps
            self.isLoading = false
        }
    }

    private func parseApp(at path: String) -> AppInfo? {
        let infoPlistPath = (path as NSString).appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOfFile: infoPlistPath) else { return nil }

        let name      = plist["CFBundleDisplayName"] as? String
                     ?? plist["CFBundleName"] as? String
                     ?? (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        let bundleID  = plist["CFBundleIdentifier"] as? String ?? "unknown"
        let version   = plist["CFBundleShortVersionString"] as? String ?? "1.0"

        let icon = NSWorkspace.shared.icon(forFile: path)
        let size = cleanupService.directorySize(at: path)

        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let installDate = attrs?[.creationDate] as? Date ?? Date()

        return AppInfo(
            name: name,
            bundleID: bundleID,
            version: version,
            newVersion: nil,
            size: size,
            installDate: installDate,
            icon: icon,
            leftoverFiles: [],
            lastUsed: nil
        )
    }

    // MARK: - Uninstall App
    func uninstall(app: AppInfo, includeLeftovers: Bool = true) async throws {
        // Find the app bundle
        let appPath = "/Applications/\(app.name).app"
        let altPath  = NSHomeDirectory() + "/Applications/\(app.name).app"
        let target   = FileManager.default.fileExists(atPath: appPath) ? appPath : altPath

        // Move to trash
        try FileManager.default.trashItem(at: URL(fileURLWithPath: target), resultingItemURL: nil)

        // Remove leftover files
        if includeLeftovers {
            for file in app.leftoverFiles {
                try? FileManager.default.removeItem(atPath: file.path)
            }
        }

        // Refresh list
        await loadInstalledApps()
    }

    // MARK: - Load Leftovers for an App
    func loadLeftovers(for app: AppInfo) async -> AppInfo {
        let leftovers = await cleanupService.findLeftovers(for: app)
        var updated = app
        updated.leftoverFiles = leftovers
        return updated
    }

    // MARK: - Check for App Updates via Sparkle-style feeds (stub)
    // In a real app this would check each app's Sparkle feed or the Mac App Store API.
    // Here we return a plausible demo result.
    func checkForUpdates() async -> [AppInfo] {
        return installedApps.filter { _ in Bool.random() && Bool.random() }
            .map { app in
                var updated = app
                let parts = app.version.components(separatedBy: ".")
                if let last = parts.last, let n = Int(last) {
                    updated.newVersion = parts.dropLast().joined(separator: ".") + ".\(n + 1)"
                }
                return updated
            }
    }

    // MARK: - Force Quit Process
    func forceQuit(pid: Int32) {
        kill(pid, SIGKILL)
    }
}
