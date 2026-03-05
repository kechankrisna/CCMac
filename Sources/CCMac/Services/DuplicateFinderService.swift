import Foundation
import CryptoKit

// MARK: - Real Duplicate File Finder via MD5 hashing
class DuplicateFinderService: ObservableObject {

    // MARK: - Find Duplicates in directory
    func findDuplicates(in directory: URL, progress: @escaping (Double, String) -> Void) async -> [[FileItem]] {
        let fileURLs = collectFiles(in: directory)
        guard !fileURLs.isEmpty else { return [] }

        var hashMap: [String: [URL]] = [:]
        var processed = 0

        for url in fileURLs {
            await MainActor.run {
                progress(Double(processed) / Double(fileURLs.count), url.lastPathComponent)
            }

            if let hash = md5(url: url) {
                hashMap[hash, default: []].append(url)
            }
            processed += 1
        }

        // Filter to groups with more than one file
        let duplicateGroups = hashMap.values.filter { $0.count > 1 }

        var result: [[FileItem]] = []
        for group in duplicateGroups.sorted(by: { $0[0].path < $1[0].path }) {
            let items = group.map { url -> FileItem in
                let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                let mod  = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? Date()
                return FileItem(name: url.lastPathComponent, path: url.path, size: size, dateModified: mod)
            }
            result.append(items)
        }

        return result.sorted { $0.first!.size > $1.first!.size }
    }

    // MARK: - Collect all files recursively
    private func collectFiles(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var files: [URL] = []
        for case let url as URL in enumerator {
            guard let attrs = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
                  !(attrs.isDirectory ?? false),
                  let size = attrs.fileSize, size > 1024 // Skip tiny files
            else { continue }
            files.append(url)
        }
        return files
    }

    // MARK: - MD5 Hash using CryptoKit
    private func md5(url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Find Large & Old Files
    func findLargeFiles(in directory: URL, minSizeMB: Double = 50) -> [FileItem] {
        let minBytes = Int64(minSizeMB * 1024 * 1024)
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [FileItem] = []
        for case let url as URL in enumerator {
            guard let attrs = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]),
                  !(attrs.isDirectory ?? false),
                  let size = attrs.fileSize, Int64(size) >= minBytes
            else { continue }
            files.append(FileItem(
                name: url.lastPathComponent,
                path: url.path,
                size: Int64(size),
                dateModified: attrs.contentModificationDate ?? Date()
            ))
        }
        return files.sorted { $0.size > $1.size }
    }
}
