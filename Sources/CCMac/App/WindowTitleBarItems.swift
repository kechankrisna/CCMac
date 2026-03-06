import SwiftUI

// MARK: - Window Title Bar Tray Items
// Native Swift equivalent of the React AppShell's {/* ── Menu Bar Tray Items ── */}
// Placed into the macOS window toolbar via ContentView's .toolbar { } so they
// appear in the transparent hidden-title-bar area, just like the React mockup.
//
// Layout (left → right):
//   [• Shield Protected] [💿 Disk] [• Health NN]  |  [✦ CCMac ▾]
//                                                       └── opens MenuBarPopoverView

// MARK: - Container
struct TitleBarTrayView: View {
    @ObservedObject var monitor: SystemMonitorService

    var body: some View {
        HStack(spacing: 4) {
            ProtectionPill()
            DiskUsagePill(monitor: monitor)
            HealthScorePill(monitor: monitor)

            // Hair-line separator
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1, height: 12)

            // The main tray trigger button — mirrors the React <button ref={trayBtnRef}>
            TitleBarCCMacButton()
        }
    }
}

// MARK: - CCMac Tray Trigger Button  ─── ✦ "CCMac" ▾  →  opens MenuBarPopoverView
struct TitleBarCCMacButton: View {
    @State private var isOpen    = false
    @State private var isHovered = false

    var body: some View {
        Button(action: { isOpen.toggle() }) {
            HStack(spacing: 4) {

                // Gradient app icon (16×16) with sparkles — mirrors React's gradient box
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [.brandBlue, .brandGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 16, height: 16)
                        .shadow(
                            color: Color.brandGreen.opacity(isOpen ? 0.55 : 0.28),
                            radius: isOpen ? 4 : 2, x: 0, y: 0
                        )
                    Image(systemName: "sparkles")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Label
                Text("CCMac")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isOpen ? .brandGreen : Color(hex: "#C0D8E8"))
                    .tracking(0.1)

                // Chevron — rotates 180° when the popover is open
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(isOpen ? .brandGreen : .textDisabled)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
                    .animation(.easeOut(duration: 0.2), value: isOpen)
            }
            .padding(.leading, 5)
            .padding(.trailing, 8)
            .padding(.vertical, 3)
            // Button background
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isOpen
                            ? Color.brandGreen.opacity(0.18)
                            : Color.white.opacity(isHovered ? 0.09 : 0.05)
                    )
            )
            // Button border
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isOpen
                            ? Color.brandGreen.opacity(0.40)
                            : Color.white.opacity(isHovered ? 0.16 : 0.09),
                        lineWidth: 1
                    )
            )
            // Focus ring when popover is open (mirrors React's box-shadow ring)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.brandGreen.opacity(isOpen ? 0.15 : 0), lineWidth: 3)
                    .padding(-2)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.easeOut(duration: 0.15), value: isOpen)
        // ── The popover itself ────────────────────────────────────────────────
        // Mirrors: <MenuBarPopover isOpen={popoverOpen} onClose={...} anchorRef={trayBtnRef} />
        // SwiftUI's .popover() anchors automatically to this button and shows
        // a native NSPopover with arrowhead pointing up at the button.
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            MenuBarPopoverView()
                .preferredColorScheme(.dark)
        }
        .help("CCMac — Click to open system overview")
    }
}

// MARK: - Protection Status Pill  ─── • Shield "Protected"
struct ProtectionPill: View {
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            // Pulsing dot (mirrors React's glow-pulse circle)
            Circle()
                .fill(Color.successGreen)
                .frame(width: 5, height: 5)
                .shadow(color: Color.successGreen.opacity(0.85), radius: 3, x: 0, y: 0)

            Image(systemName: "shield.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.successGreen)

            Text("Protected")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.successGreen)
                .tracking(0.3)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Color.successGreen.opacity(isHovered ? 0.14 : 0.08))
        .cornerRadius(5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.successGreen.opacity(0.22), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Disk Usage Pill  ─── 💿 "347 GB / 512 GB"
struct DiskUsagePill: View {
    @ObservedObject var monitor: SystemMonitorService
    @State private var isHovered = false

    private var diskColor: Color {
        let pct = monitor.metrics.diskPercent
        if pct > 0.8 { return .dangerRed }
        if pct > 0.6 { return .warningOrange }
        return .textSecondary
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "internaldrive.fill")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(diskColor)

            Text("\(monitor.metrics.diskUsedString) / \(monitor.metrics.diskTotalString)")
                .font(.system(size: 9))
                .foregroundColor(diskColor)
                .monospacedDigit()
                .animation(.easeOut(duration: 0.3), value: monitor.metrics.diskUsedString)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Color.white.opacity(isHovered ? 0.07 : 0.04))
        .cornerRadius(5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.white.opacity(isHovered ? 0.12 : 0.07), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Health Score Pill  ─── • "Health 74"
struct HealthScorePill: View {
    @ObservedObject var monitor: SystemMonitorService

    /// Composite health score derived from CPU + RAM + Disk load average.
    private var score: Int {
        let cpu  = monitor.metrics.cpuUsage
        let ram  = monitor.metrics.ramPercent  * 100
        let disk = monitor.metrics.diskPercent * 100
        let avg  = (cpu + ram + disk) / 3.0
        return max(10, 100 - Int(avg * 0.75))
    }

    private var scoreColor: Color {
        switch score {
        case 80...100: return .successGreen
        case 60..<80:  return .brandGreen
        case 40..<60:  return .warningOrange
        default:       return .dangerRed
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(scoreColor)
                .frame(width: 5, height: 5)
                .shadow(color: scoreColor.opacity(0.75), radius: 2, x: 0, y: 0)

            Text("Health")
                .font(.system(size: 9))
                .foregroundColor(.textSecondary)

            Text("\(score)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(scoreColor)
                .monospacedDigit()
                .animation(.easeOut(duration: 0.4), value: score)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Color.white.opacity(0.04))
        .cornerRadius(5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}
