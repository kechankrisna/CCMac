import SwiftUI

// MARK: - Menu Bar Popover (340×420px)
struct MenuBarPopoverView: View {
    @StateObject private var monitor = SystemMonitorService()
    @State private var isProtected = true

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
            }
            .padding(.horizontal, AppSpacing.standard)
            .padding(.vertical, AppSpacing.compact)
            .background(Color.bgDark2)

            Divider().overlay(Color.white.opacity(0.06))

            // 2×3 Metric Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      spacing: AppSpacing.base) {
                MenuBarMetricCell(icon: "cpu.fill", label: "CPU",
                                  value: monitor.metrics.cpuString, color: .warningOrange)
                MenuBarMetricCell(icon: "memorychip.fill", label: "RAM",
                                  value: monitor.metrics.ramUsedString, color: .infoBlue)
                MenuBarMetricCell(icon: "internaldrive.fill", label: "Disk",
                                  value: monitor.metrics.diskFreeString, color: .brandGreen)
                MenuBarMetricCell(icon: "battery.100", label: "Battery",
                                  value: String(format: "%.0f%%", monitor.metrics.batteryLevel), color: .successGreen)
                MenuBarMetricCell(icon: "arrow.down.circle.fill", label: "Down",
                                  value: formatBytes(monitor.metrics.networkDown) + "/s", color: .brandBlue)
                MenuBarMetricCell(icon: "arrow.up.circle.fill", label: "Up",
                                  value: formatBytes(monitor.metrics.networkUp) + "/s", color: .assistantPurple)
            }
            .padding(AppSpacing.standard)

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

    private func formatBytes(_ bytes: Double) -> String {
        if bytes > 1_000_000 { return String(format: "%.1f MB", bytes / 1_000_000) }
        if bytes > 1_000     { return String(format: "%.0f KB", bytes / 1_000) }
        return String(format: "%.0f B", bytes)
    }
}

struct MenuBarMetricCell: View {
    let icon: String; let label: String; let value: String; let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
            Text(value).font(AppFont.bodyDefault).foregroundColor(.textPrimary).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(AppFont.bodySmall).foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.compact)
        .background(Color.surfaceDark)
        .cornerRadius(AppRadius.small)
    }
}
