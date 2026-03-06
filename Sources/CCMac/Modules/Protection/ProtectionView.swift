import SwiftUI

@MainActor
class ProtectionViewModel: ObservableObject {
    @Published var state: State = .overview
    @Published var scanType: ScanType = .quick
    @Published var scanProgress: Double = 0
    @Published var currentFile: String = ""
    @Published var filesScanned: Int = 0
    @Published var threats: [ThreatItem] = []

    enum State { case overview, scanning, threatFound, appPermissions }
    enum ScanType: String, CaseIterable { case quick = "Quick", normal = "Normal", deep = "Deep"
        var time: String {
            switch self { case .quick: return "~1 min"; case .normal: return "~5 min"; case .deep: return "~15 min" }
        }
    }

    var isProtected: Bool { threats.isEmpty }
    var statusLabel: String { isProtected ? "Mac Protected" : "Threats Detected" }
    var statusIcon: String { isProtected ? "shield.fill" : "shield.slash.fill" }
    var statusColor: Color { isProtected ? .successGreen : .dangerRed }

    func startScan() {
        state = .scanning
        scanProgress = 0
        filesScanned = 0
        threats = []

        // Simulate a real scan through common paths
        Task {
            let scanPaths = ["/Applications", NSHomeDirectory() + "/Downloads", NSHomeDirectory() + "/Library"]
            var allFiles: [String] = []
            for path in scanPaths {
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: path) {
                    allFiles.append(contentsOf: contents.map { (path as NSString).appendingPathComponent($0) })
                }
            }

            let total = max(allFiles.count, 1)
            for (i, file) in allFiles.enumerated() {
                try? await Task.sleep(nanoseconds: 20_000_000)
                self.currentFile = file
                self.filesScanned = i + 1
                self.scanProgress = Double(i + 1) / Double(total)
                // Real apps would check signatures here; we do a safe no-op scan
            }
            // Transition to clean result
            state = threats.isEmpty ? .overview : .threatFound
        }
    }

    func quarantineAll() {
        // Move to quarantine folder (~/Library/Application Support/CCMac/Quarantine)
        let quarantineDir = NSHomeDirectory() + "/Library/Application Support/CCMac/Quarantine"
        try? FileManager.default.createDirectory(atPath: quarantineDir, withIntermediateDirectories: true)
        for threat in threats {
            let dest = (quarantineDir as NSString).appendingPathComponent((threat.filePath as NSString).lastPathComponent)
            try? FileManager.default.moveItem(atPath: threat.filePath, toPath: dest)
        }
        threats = []
        state = .overview
    }
}

struct ProtectionView: View {
    @StateObject private var vm = ProtectionViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderView(
                module: .protection,
                subtitle: "Powered by Moonlock Engine"
            )
            switch vm.state {
            case .overview:      ProtectionOverviewView(vm: vm)
            case .scanning:      ProtectionScanningView(vm: vm)
            case .threatFound:   ThreatFoundView(vm: vm)
            case .appPermissions: AppPermissionsView()
            }
        }
        .background(Color.bgDark)
    }
}

struct ProtectionOverviewView: View {
    @ObservedObject var vm: ProtectionViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.section) {
                // Status Hero
                VStack(spacing: AppSpacing.standard) {
                    Image(systemName: vm.statusIcon)
                        .font(.system(size: 72))
                        .foregroundColor(vm.statusColor)
                        .shadow(color: vm.statusColor.opacity(0.3), radius: 20)
                    Text(vm.statusLabel).font(AppFont.heading1).foregroundColor(.textPrimary)
                    Text("Last scan: Never · Next: Not scheduled").font(AppFont.bodyDefault).foregroundColor(.textSecondary)
                }
                .padding(.top, AppSpacing.section)

                // Scan Type Selector
                VStack(spacing: AppSpacing.compact) {
                    Text("Scan Type").font(AppFont.bodySmall).foregroundColor(.textSecondary)
                    HStack(spacing: 0) {
                        ForEach(ProtectionViewModel.ScanType.allCases, id: \.self) { type in
                            Button(action: { vm.scanType = type }) {
                                VStack(spacing: 3) {
                                    Text(type.rawValue).font(AppFont.heading3)
                                    Text(type.time).font(AppFont.bodySmall)
                                }
                                .foregroundColor(vm.scanType == type ? .white : .textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.compact)
                                .background(vm.scanType == type ? Color.brandBlue : Color.surfaceDark)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .cornerRadius(AppRadius.medium)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.medium).stroke(Color.white.opacity(0.08), lineWidth: 1))
                }
                .padding(.horizontal, 80)

                CMButton("Scan Now", icon: "shield") { vm.startScan() }

                // Privacy Tools
                SectionHeader(title: "Privacy Tools")
                HStack(spacing: AppSpacing.standard) {
                    PrivacyToolCard(icon: "globe", title: "Browser Data", subtitle: "Clear history, cookies, cache")
                    PrivacyToolCard(icon: "clock.fill", title: "Recent Items", subtitle: "Remove recent file history")
                    PrivacyToolCard(icon: "lock.shield.fill", title: "App Permissions", subtitle: "Manage what apps can access") {
                        vm.state = .appPermissions
                    }
                }
                .padding(.horizontal, AppSpacing.section)
            }
        }
    }
}

struct PrivacyToolCard: View {
    let icon: String; let title: String; let subtitle: String
    var action: (() -> Void)? = nil
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Image(systemName: icon).font(.system(size: 22)).foregroundColor(.infoBlue)
            Text(title).font(AppFont.heading3).foregroundColor(.textPrimary)
            Text(subtitle).font(AppFont.bodySmall).foregroundColor(.textSecondary)
            Spacer()
            CMButton("Open", style: .secondary) { action?() }
        }
        .padding(AppSpacing.standard)
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color.surfaceDark)
        .cornerRadius(AppRadius.medium)
        .scaleEffect(isHovered ? 1.01 : 1)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

struct ProtectionScanningView: View {
    @ObservedObject var vm: ProtectionViewModel

    var body: some View {
        VStack(spacing: AppSpacing.section) {
            Spacer()
            // Radar animation
            ZStack {
                ForEach(0..<3) { i in
                    Circle().stroke(Color.brandBlue.opacity(0.2 - Double(i) * 0.05), lineWidth: 1)
                        .frame(width: CGFloat(120 + i * 60), height: CGFloat(120 + i * 60))
                }
                CircularProgressView(
                    progress: vm.scanProgress,
                    size: 120,
                    centerContent: AnyView(
                        Image(systemName: "shield.fill").font(.system(size: 30)).foregroundColor(.brandBlue)
                    )
                )
            }
            .frame(width: 300, height: 300)

            Text(vm.currentFile).font(AppFont.mono).foregroundColor(.textDisabled).lineLimit(1).truncationMode(.middle).frame(maxWidth: 500)

            HStack(spacing: AppSpacing.section) {
                Label("\(vm.filesScanned) Files Scanned", systemImage: "doc.fill").font(AppFont.bodyDefault).foregroundColor(.textSecondary)
                Label("\(vm.threats.count) Threats Found", systemImage: "exclamationmark.triangle.fill")
                    .font(AppFont.bodyDefault).foregroundColor(vm.threats.isEmpty ? .textSecondary : .dangerRed)
            }
            CMButton("Stop Scan", style: .secondary) { vm.state = .overview }
            Spacer()
        }
    }
}

struct ThreatFoundView: View {
    @ObservedObject var vm: ProtectionViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Alert banner
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.white)
                Text("\(vm.threats.count) Threat\(vm.threats.count == 1 ? "" : "s") Detected")
                    .font(AppFont.heading1).foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.section)
            .padding(.vertical, AppSpacing.standard)
            .background(Color.dangerRed)

            if vm.threats.isEmpty {
                EmptyStateView(icon: "shield.fill", title: "All Clear", subtitle: "No threats were found on your Mac")
            } else {
                ScrollView {
                    ForEach(vm.threats) { threat in
                        ThreatRow(threat: threat)
                        Divider().overlay(Color.white.opacity(0.05))
                    }
                }
                HStack {
                    Spacer()
                    CMButton("Review One by One", style: .secondary) {}
                    CMButton("Quarantine All", icon: "shield.slash.fill", isDestructive: true) { vm.quarantineAll() }
                }
                .padding(AppSpacing.standard)
                .background(Color.bgDark2)
            }
        }
    }
}

struct ThreatRow: View {
    let threat: ThreatItem
    var body: some View {
        HStack(spacing: AppSpacing.standard) {
            Toggle("", isOn: .constant(true)).toggleStyle(.checkbox).labelsHidden()
            VStack(alignment: .leading, spacing: 4) {
                Text(threat.name).font(AppFont.heading3).foregroundColor(.dangerRed)
                Text(threat.filePath).font(AppFont.mono).foregroundColor(.textDisabled).lineLimit(1)
            }
            Spacer()
            ThreatBadge(severity: threat.severity)
        }
        .padding(.horizontal, AppSpacing.section)
        .padding(.vertical, AppSpacing.compact)
    }
}

struct AppPermissionsView: View {
    private let permissionGroups = [
        ("Camera", "camera.fill", ["FaceTime", "Photo Booth", "Zoom"]),
        ("Microphone", "mic.fill", ["Zoom", "Teams", "Discord"]),
        ("Location", "location.fill", ["Maps", "Weather", "Safari"]),
        ("Full Disk Access", "internaldrive.fill", ["CCMac", "Backup Pro"])
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.compact) {
                ForEach(permissionGroups, id: \.0) { group in
                    DisclosureGroup {
                        ForEach(group.2, id: \.self) { appName in
                            HStack {
                                Image(systemName: "app.badge").foregroundColor(.textSecondary)
                                Text(appName).font(AppFont.bodyLarge).foregroundColor(.textPrimary)
                                Spacer()
                                Toggle("", isOn: .constant(true)).toggleStyle(.switch).labelsHidden()
                            }
                            .padding(.horizontal, AppSpacing.section)
                            .padding(.vertical, AppSpacing.compact)
                        }
                    } label: {
                        HStack {
                            Image(systemName: group.1).foregroundColor(.brandBlue).frame(width: 24)
                            Text(group.0).font(AppFont.heading3).foregroundColor(.textPrimary)
                            Spacer()
                            Text("\(group.2.count) apps").font(AppFont.bodySmall).foregroundColor(.textSecondary)
                        }
                        .padding(AppSpacing.standard)
                    }
                    .background(Color.surfaceDark)
                    .cornerRadius(AppRadius.medium)
                    .padding(.horizontal, AppSpacing.section)
                }
            }
            .padding(.vertical, AppSpacing.standard)
        }
    }
}
