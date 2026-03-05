import SwiftUI
import Foundation

// MARK: - Navigation Modules
enum AppModule: String, CaseIterable, Identifiable {
    case smartCare    = "Smart Care"
    case cleanup      = "Cleanup"
    case protection   = "Protection"
    case performance  = "Performance"
    case applications = "Applications"
    case myClutter    = "My Clutter"
    case spaceLens    = "Space Lens"
    case cloudCleanup = "Cloud Cleanup"
    case assistant    = "Assistant"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .smartCare:    return "sparkles"
        case .cleanup:      return "trash"
        case .protection:   return "shield.fill"
        case .performance:  return "bolt.fill"
        case .applications: return "square.stack.3d.up.fill"
        case .myClutter:    return "tray.2.fill"
        case .spaceLens:    return "circle.grid.3x3.fill"
        case .cloudCleanup: return "cloud.fill"
        case .assistant:    return "brain"
        }
    }

    var accentColor: Color {
        switch self {
        case .smartCare:    return .brandBlue
        case .cleanup:      return .infoBlue
        case .protection:   return .dangerRed
        case .performance:  return .warningOrange
        case .applications: return .successGreen
        case .myClutter:    return Color(hex: "#E0C030")
        case .spaceLens:    return .assistantPurple
        case .cloudCleanup: return .infoBlue
        case .assistant:    return .assistantPurple
        }
    }
}

// MARK: - Scan Result
struct ScanCategory: Identifiable {
    let id = UUID()
    var name: String
    var icon: String
    var color: Color
    var files: [FileItem]
    var isSelected: Bool = true

    var totalSize: Int64 { files.reduce(0) { $0 + $1.size } }
    var totalSizeString: String { ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file) }
}

struct FileItem: Identifiable {
    let id = UUID()
    var name: String
    var path: String
    var size: Int64
    var dateModified: Date
    var isSelected: Bool = true

    var sizeString: String { ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }
}

// MARK: - Threat
struct ThreatItem: Identifiable {
    let id = UUID()
    var name: String
    var filePath: String
    var threatType: ThreatType
    var severity: ThreatSeverity
    var description: String
    var isSelected: Bool = true

    enum ThreatType: String {
        case malware = "Malware"
        case adware = "Adware"
        case spyware = "Spyware"
        case miner = "Miner"
        case pup = "PUP"
    }

    enum ThreatSeverity: String, CaseIterable {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        case clean = "Clean"

        var color: Color {
            switch self {
            case .critical: return .dangerRed
            case .high:     return .dangerRed
            case .medium:   return .warningOrange
            case .low:      return .infoBlue
            case .clean:    return .successGreen
            }
        }

        var bgColor: Color { color.opacity(0.12) }
        var borderColor: Color { color.opacity(0.25) }
    }
}

// MARK: - App Info
struct AppInfo: Identifiable {
    let id = UUID()
    var name: String
    var bundleID: String
    var version: String
    var newVersion: String?
    var size: Int64
    var installDate: Date
    var icon: NSImage?
    var leftoverFiles: [FileItem]
    var lastUsed: Date?

    var sizeString: String { ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }
    var hasUpdate: Bool { newVersion != nil }
    var leftoverSize: Int64 { leftoverFiles.reduce(0) { $0 + $1.size } }
    var leftoverSizeString: String { ByteCountFormatter.string(fromByteCount: leftoverSize, countStyle: .file) }
}

// MARK: - System Metrics
struct SystemMetrics {
    var cpuUsage: Double       // 0-100
    var ramUsed: Int64         // bytes
    var ramTotal: Int64        // bytes
    var diskUsed: Int64        // bytes
    var diskTotal: Int64       // bytes
    var batteryLevel: Double   // 0-100
    var networkDown: Double    // bytes/s
    var networkUp: Double      // bytes/s

    var ramUsedString: String  { ByteCountFormatter.string(fromByteCount: ramUsed, countStyle: .memory) }
    var ramTotalString: String { ByteCountFormatter.string(fromByteCount: ramTotal, countStyle: .memory) }
    var diskUsedString: String { ByteCountFormatter.string(fromByteCount: diskUsed, countStyle: .file) }
    var diskTotalString: String { ByteCountFormatter.string(fromByteCount: diskTotal, countStyle: .file) }
    var diskFreeString: String { ByteCountFormatter.string(fromByteCount: diskTotal - diskUsed, countStyle: .file) }
    var cpuString: String      { String(format: "%.1f%%", cpuUsage) }
    var ramPercent: Double     { ramTotal > 0 ? Double(ramUsed) / Double(ramTotal) : 0 }
    var diskPercent: Double    { diskTotal > 0 ? Double(diskUsed) / Double(diskTotal) : 0 }
}

// MARK: - Disk Item (Space Lens)
class DiskItem: Identifiable, ObservableObject {
    let id = UUID()
    var name: String
    var path: String
    var size: Int64
    var isDirectory: Bool
    var children: [DiskItem]
    var color: Color

    init(name: String, path: String, size: Int64, isDirectory: Bool, children: [DiskItem] = [], color: Color = .brandBlue) {
        self.name = name
        self.path = path
        self.size = size
        self.isDirectory = isDirectory
        self.children = children
        self.color = color
    }

    var sizeString: String { ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }
}

// MARK: - Cloud Service
struct CloudService: Identifiable {
    let id = UUID()
    var name: String
    var icon: String
    var color: Color
    var isConnected: Bool = false
    var usedBytes: Int64 = 0
    var totalBytes: Int64 = 0

    var usedString: String  { ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file) }
    var totalString: String { ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file) }
    var usagePercent: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0 }
}

// MARK: - Health Score
struct HealthReport {
    var overallScore: Int          // 0-100
    var diskHealth: Int
    var securityScore: Int
    var performanceScore: Int
    var updatesScore: Int
    var recommendations: [HealthRecommendation]

    var label: String {
        switch overallScore {
        case 80...100: return "Excellent"
        case 60..<80:  return "Good"
        case 40..<60:  return "Needs Attention"
        default:       return "Critical"
        }
    }

    var labelColor: Color {
        switch overallScore {
        case 80...100: return .successGreen
        case 60..<80:  return .brandGreen
        case 40..<60:  return .warningOrange
        default:       return .dangerRed
        }
    }
}

struct HealthRecommendation: Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var priority: Priority
    var icon: String
    var actionLabel: String

    enum Priority: String, CaseIterable {
        case high = "High"
        case medium = "Medium"
        case low = "Low"

        var color: Color {
            switch self {
            case .high:   return .dangerRed
            case .medium: return .warningOrange
            case .low:    return .infoBlue
            }
        }
    }
}

// MARK: - App-wide Notification Names
extension Notification.Name {
    static let navigateToSmartCare = Notification.Name("com.ccmac.navigateToSmartCare")
    static let startSmartCareScan  = Notification.Name("com.ccmac.startSmartCareScan")
}
