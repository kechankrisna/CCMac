import Foundation
import SwiftUI
import Combine

// MARK: - Real Cleanup Service using FileManager
class CleanupService: ObservableObject {

    // MARK: - Scan Categories Definition
    struct CleanupCategory {
        var name: String
        var icon: String
        var paths: [String]
        var extensions: [String]
    }

    static let categories: [CleanupCategory] = [
        CleanupCategory(
            name: "System Cache",
            icon: "internaldrive",
            paths: ["/Library/Caches", "~/Library/Caches"],
            extensions: ["cache", "db", "sqlite"]
        ),
        CleanupCategory(
            name: "User Logs",
            icon: "doc.text.fill",
            paths: ["~/Library/Logs", "/Library/Logs", "/var/log"],
            extensions: ["log", "crash", "diag"]
        ),
        CleanupCategory(
            name: "Mail Attachments",
            icon: "envelope.fill",
            paths: ["~/Library/Mail"],
            extensions: ["emlx", "mbox"]
        ),
        CleanupCategory(
            name: "Language Files",
            icon: "globe",
            paths: ["/Applications"],
            extensions: ["lproj"]
        ),
        CleanupCategory(
            name: "Trash",
            icon: "trash.fill",
            paths: ["~/.Trash"],
            extensions: []
        ),
        CleanupCategory(
            name: "Xcode DerivedData",
            icon: "hammer.fill",
            paths: ["~/Library/Developer/Xcode/DerivedData",
                    "~/Library/Developer/CoreSimulator/Caches"],
            extensions: []
        ),
        CleanupCategory(
            name: "iOS Device Backups",
            icon: "iphone",
            paths: ["~/Library/Application Support/MobileSync/Backup"],
            extensions: []
        )
    ]

    // MARK: - Real Disk Scanner
    func scanCategories(progress: @escaping (Double, String) -> Void) async -> [ScanCategory] {
        var results: [ScanCategory] = []
        let colors: [Color] = [.infoBlue, .warningOrange, .assistantPurple, .successGreen, .dangerRed, .brandBlue, .brandGreen]

        for (index, cat) in Self.categories.enumerated() {
            await MainActor.run {
                progress(Double(index) / Double(Self.categories.count), "Scanning \(cat.name)…")
            }

            var files: [FileItem] = []
            for rawPath in cat.paths {
                let expanded = NSString(string: rawPath).expandingTildeInPath
                let url = URL(fileURLWithPath: expanded)
                let found = scanDirectory(url: url, extensions: cat.extensions, maxFiles: 200)
                files.append(contentsOf: found)
            }

            if !files.isEmpty {
                results.append(ScanCategory(
                    name: cat.name,
                    icon: cat.icon,
                    color: colors[index % colors.count],
                    files: files
                ))
            }
        }

        await MainActor.run { progress(1.0, "Scan complete") }
        return results
    }

    // MARK: - Directory Scanner
    private func scanDirectory(url: URL, extensions: [String], maxFiles: Int) -> [FileItem] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }

        let opts: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: opts
        ) else { return [] }

        var items: [FileItem] = []
        var count = 0

        for case let fileURL as URL in enumerator {
            guard count < maxFiles else { break }
            guard let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]),
                  !(attrs.isDirectory ?? false),
                  let size = attrs.fileSize, size > 0
            else { continue }

            if !extensions.isEmpty {
                let ext = fileURL.pathExtension.lowercased()
                guard extensions.contains(ext) else { continue }
            }

            items.append(FileItem(
                name: fileURL.lastPathComponent,
                path: fileURL.path,
                size: Int64(size),
                dateModified: attrs.contentModificationDate ?? Date()
            ))
            count += 1
        }
        return items
    }

    // MARK: - Delete Selected Files
    func deleteFiles(_ files: [FileItem], progress: @escaping (Double, String) -> Void) async -> (deleted: Int, freedBytes: Int64) {
        var deleted = 0
        var freed: Int64 = 0
        let total = files.count

        for (i, file) in files.enumerated() {
            await MainActor.run {
                progress(Double(i) / Double(max(total, 1)), file.path)
            }
            do {
                try FileManager.default.removeItem(atPath: file.path)
                deleted += 1
                freed += file.size
            } catch {
                // File may already be gone or inaccessible — continue
            }
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms UI update gap
        }
        return (deleted, freed)
    }

    // MARK: - Find App Leftover Files
    func findLeftovers(for app: AppInfo) async -> [FileItem] {
        let searchPaths = [
            "~/Library/Application Support",
            "~/Library/Preferences",
            "~/Library/Caches",
            "~/Library/Logs",
            "~/Library/LaunchAgents",
            "/Library/LaunchDaemons"
        ]

        let bundleComponents = app.bundleID.components(separatedBy: ".")
        let searchTerms = bundleComponents.filter { $0.count > 3 } + [app.name.lowercased()]
        var results: [FileItem] = []

        for rawPath in searchPaths {
            let expanded = NSString(string: rawPath).expandingTildeInPath
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: expanded) else { continue }
            for item in contents {
                let lower = item.lowercased()
                if searchTerms.contains(where: { lower.contains($0.lowercased()) }) {
                    let fullPath = (expanded as NSString).appendingPathComponent(item)
                    let size = directorySize(at: fullPath)
                    results.append(FileItem(
                        name: item,
                        path: fullPath,
                        size: size,
                        dateModified: Date()
                    ))
                }
            }
        }
        return results
    }

    // MARK: - Helper: Directory Size
    func directorySize(at path: String) -> Int64 {
        var size: Int64 = 0
        let url = URL(fileURLWithPath: path)
        if let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                if let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fs = attrs.fileSize { size += Int64(fs) }
            }
        }
        return size
    }
}
