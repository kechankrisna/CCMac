import SwiftUI

// MARK: - Menu Bar Popover (340×420px)
struct MenuBarPopoverView: View {
    @StateObject private var monitor = SystemMonitorService()
    @State private var isProtected = true
    @State private var settingsHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: AppSpacing.compact) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 16)).foregroundColor(.brandGreen)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Mac Health: \(healthLabel)")
                        .font(AppFont.heading3).foregroundColor(.textPrimary)
                    Text(healthLabel).font(AppFont.labelBadge).foregroundColor(healthColor)
                }
                Spacer()

                // Gear drop-down menu
                Menu {
                    Button {
                        openSettings()
                    } label: {
                        Label("Settings…", systemImage: "gearshape.fill")
                    }

                    Divider()

                    Button {
                        AboutWindowController.shared.show()
                    } label: {
                        Label("About CCMac", systemImage: "info.circle")
                    }

                    Divider()

                    Button(role: .destructive) {
                        NSApp.terminate(nil)
                    } label: {
                        Label("Quit CCMac", systemImage: "power")
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15))
                        .foregroundColor(settingsHovered ? .white : Color.white.opacity(0.75))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.small)
                                .fill(settingsHovered
                                      ? Color.white.opacity(0.12)
                                      : Color.clear)
                        )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .colorScheme(.dark)
                .accentColor(.white)
                .onHover { settingsHovered = $0 }
                .help("Settings & More")
            }
            .padding(.horizontal, AppSpacing.standard)
            .padding(.vertical, AppSpacing.compact)
            .background(Color.bgDark2)

            Divider().overlay(Color.white.opacity(0.06))

            // 2×3 Metric Grid (Figma spec: icon+label → value H2 → sparkline 40px)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      spacing: AppSpacing.compact) {
                MenuBarMetricCell(icon: "cpu.fill", label: "CPU",
                                  value: monitor.metrics.cpuString,
                                  color: .warningOrange,
                                  history: monitor.cpuHistory)
                MenuBarMetricCell(icon: "memorychip.fill", label: "RAM",
                                  value: monitor.metrics.ramUsedString,
                                  color: .infoBlue,
                                  history: monitor.ramHistory)
                MenuBarMetricCell(icon: "internaldrive.fill", label: "Disk",
                                  value: monitor.metrics.diskFreeString,
                                  color: .brandGreen,
                                  history: monitor.diskHistory)
                MenuBarMetricCell(icon: "battery.100", label: "Battery",
                                  value: String(format: "%.0f%%", monitor.metrics.batteryLevel),
                                  color: .successGreen,
                                  history: monitor.batteryHistory)
                MenuBarMetricCell(icon: "arrow.down.circle.fill", label: "Down",
                                  value: formatBytes(monitor.metrics.networkDown) + "/s",
                                  color: .brandBlue,
                                  history: monitor.netDownHistory)
                MenuBarMetricCell(icon: "arrow.up.circle.fill", label: "Up",
                                  value: formatBytes(monitor.metrics.networkUp) + "/s",
                                  color: .assistantPurple,
                                  history: monitor.netUpHistory)
            }
            .padding(.horizontal, AppSpacing.standard)
            .padding(.vertical, AppSpacing.compact)

            Divider().overlay(Color.white.opacity(0.06))

            // Protection status
            HStack(spacing: AppSpacing.compact) {
                Image(systemName: isProtected ? "shield.fill" : "shield.slash.fill")
                    .foregroundColor(isProtected ? .successGreen : .dangerRed)
                Text(isProtected ? "Protected · Last scan: 2 days ago" : "Threats Detected!")
                    .font(AppFont.bodyDefault)
                    .foregroundColor(isProtected ? .textSecondary : .dangerRed)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.standard)
            .padding(.vertical, AppSpacing.compact)

            Divider().overlay(Color.white.opacity(0.06))

            // Quick action buttons
            HStack(spacing: AppSpacing.compact) {
                CMButton("Smart Care", style: .secondary) {
                    openMainWindow()
                    NotificationCenter.default.post(name: .navigateToSmartCare, object: nil)
                }
                CMButton("Scan Now") {
                    openMainWindow()
                    NotificationCenter.default.post(name: .startSmartCareScan, object: nil)
                }
            }
            .padding(.horizontal, AppSpacing.standard)
            .padding(.vertical, AppSpacing.compact)

            Divider().overlay(Color.white.opacity(0.06))

            // Open main app link
            Button("Open CCMac →") {
                openMainWindow()
            }
            .buttonStyle(.plain)
            .font(AppFont.bodyDefault)
            .foregroundColor(.brandBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.compact)
        }
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.bgDark)
        .onAppear { monitor.startMonitoring() }
        .onDisappear { monitor.stopMonitoring() }
    }

    private var healthLabel: String {
        let score = 72 // Would pull from real health calculation
        switch score {
        case 80...100: return "Excellent"
        case 60..<80:  return "Good"
        default:       return "Needs Attention"
        }
    }

    private var healthColor: Color {
        switch healthLabel {
        case "Excellent": return .successGreen
        case "Good":      return .brandGreen
        default:          return .warningOrange
        }
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        // macOS 13+ uses "showSettingsWindow:", macOS 12 used "showPreferencesWindow:"
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func formatBytes(_ bytes: Double) -> String {
        if bytes > 1_000_000 { return String(format: "%.1f MB", bytes / 1_000_000) }
        if bytes > 1_000     { return String(format: "%.0f KB", bytes / 1_000) }
        return String(format: "%.0f B", bytes)
    }
}

struct MenuBarMetricCell: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    var history: [Double] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Row 1: Icon + Label
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                Text(label)
                    .font(AppFont.labelBadge)
                    .foregroundColor(.textSecondary)
                Spacer()
            }

            // Row 2: Live value (Heading 2 / large)
            Text(value)
                .font(AppFont.heading2)
                .foregroundColor(.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Row 3: Sparkline (40px, brand color)
            SparklineView(data: history.isEmpty ? [0, 0] : history, color: color)
                .frame(height: 32)
        }
        .padding(.horizontal, AppSpacing.compact)
        .padding(.vertical, AppSpacing.compact)
        .frame(maxWidth: .infinity)
        .background(Color.surfaceDark)
        .cornerRadius(AppRadius.medium)
    }
}
