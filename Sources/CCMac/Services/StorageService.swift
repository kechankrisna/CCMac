import Foundation
import SwiftUI

// MARK: - Storage Visualization Service for Space Lens
class StorageService: ObservableObject {
    @Published var rootItem: DiskItem?
    @Published var isScanning = false
    @Published var scanProgress: Double = 0

    private let colorPalette: [Color] = [
        .brandBlue, .brandGreen, .infoBlue, .assistantPurple,
        .warningOrange, .dangerRed, .successGreen, Color(hex: "#E0C030")
    ]

    // MARK: - Build Disk Tree from real filesystem
    func scanDisk(at path: String = "/", progress: @escaping (Double, String) -> Void) async {
        await MainActor.run { isScanning = true; scanProgress = 0 }

        // Limit to home directory for safety — full disk needs Full Disk Access
        let scanPath = path == "/" ? NSHomeDirectory() : path
        let url = URL(fileURLWithPath: scanPath)

        let item = await buildTree(url: url, depth: 0, maxDepth: 3, progress: progress)

        await MainActor.run {
            self.rootItem = item
            self.isScanning = false
            self.scanProgress = 1.0
        }
    }

    private func buildTree(url: URL, depth: Int, maxDepth: Int, progress: @escaping (Double, String) -> Void) async -> DiskItem {
        var children: [DiskItem] = []

        if depth < maxDepth,
           let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
           ) {
            await MainActor.run { progress(0, url.lastPathComponent) }

            for (i, childURL) in contents.enumerated() {
                let attrs = try? childURL.resourceValues(forKeys: [.isDirectoryKey])
                let isDir = attrs?.isDirectory ?? false
                let child = await buildTree(url: childURL, depth: depth + 1, maxDepth: maxDepth, progress: progress)
                children.append(child)

                if depth == 0 {
                    await MainActor.run { progress(Double(i) / Double(max(contents.count, 1)), childURL.lastPathComponent) }
                }
            }
        }

        // Compute size
        var selfSize: Int64 = 0
        if children.isEmpty {
            selfSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0
        } else {
            selfSize = children.reduce(0) { $0 + $1.size }
        }

        let color = colorPalette[abs(url.lastPathComponent.hashValue) % colorPalette.count]
        let item = DiskItem(
            name: url.lastPathComponent,
            path: url.path,
            size: selfSize,
            isDirectory: !children.isEmpty,
            children: children.filter { $0.size > 1024 }.sorted { $0.size > $1.size },
            color: color
        )
        return item
    }
}
