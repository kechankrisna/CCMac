import SwiftUI

struct PerformanceView: View {
    @StateObject private var monitor = SystemMonitorService()
    @State private var showRAMFreed = false
    @State private var ramFreedMB: Int = 0
    @State private var runningTask: String? = nil
    private let maintenance = MaintenanceService()

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderView(
                module: .performance,
                subtitle: "Real-time monitoring and maintenance tasks",
                actionLabel: "Free Up RAM",
                onAction: { freeRAM() }
            )

            ScrollView {
                VStack(spacing: AppSpacing.section) {
                    // Metric Widgets Row
                    HStack(spacing: AppSpacing.standard) {
                        MetricWidget(title: "CPU", value: monitor.metrics.cpuString,
                                     icon: "cpu.fill", accent: .warningOrange, history: monitor.cpuHistory)
                        MetricWidget(title: "RAM Used", value: monitor.metrics.ramUsedString,
                                     icon: "memorychip.fill", accent: .infoBlue, history: monitor.ramHistory)
                        MetricWidget(title: "Disk Free", value: monitor.metrics.diskFreeString,
                                     icon: "internaldrive.fill", accent: .brandGreen, history: [])
                        MetricWidget(title: "Battery", value: String(format: "%.0f%%", monitor.metrics.batteryLevel),
                                     icon: "battery.100", accent: .successGreen, history: [])
                    }
                    .padding(.horizontal, AppSpacing.section)

                    // Top Processes Table
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "Top Processes by Memory")
                        ProcessTableHeader()
                        ForEach(monitor.processes.prefix(10)) { proc in
                            ProcessRow(process: proc) { kill(proc.id, SIGKILL) }
                            Divider().overlay(Color.white.opacity(0.04)).padding(.leading, AppSpacing.section)
                        }
                    }
                    .background(Color.surfaceDark.opacity(0.5))
                    .cornerRadius(AppRadius.medium)
                    .padding(.horizontal, AppSpacing.section)

                    // Maintenance Tasks
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "Maintenance Tasks")
                        ForEach(MaintenanceService.availableTasks) { task in
                            MaintenanceTaskRow(task: task, isRunning: runningTask == task.name) {
                                runTask(task)
                            }
                            Divider().overlay(Color.white.opacity(0.04)).padding(.leading, AppSpacing.section)
                        }
                    }
                    .background(Color.surfaceDark.opacity(0.5))
                    .cornerRadius(AppRadius.medium)
                    .padding(.horizontal, AppSpacing.section)
                    .padding(.bottom, AppSpacing.section)
                }
                .padding(.top, AppSpacing.standard)
            }

            // RAM Freed Overlay
            if showRAMFreed {
                RAMFreedOverlay(freedMB: ramFreedMB) { showRAMFreed = false }
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .background(Color.bgDark)
        .onAppear { monitor.startMonitoring() }
        .onDisappear { monitor.stopMonitoring() }
        .animation(.spring(), value: showRAMFreed)
    }

    private func freeRAM() {
        let before = monitor.metrics.ramUsed
        monitor.freeRAM()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let after = monitor.metrics.ramUsed
            ramFreedMB = max(0, Int((before - after) / 1_000_000))
            showRAMFreed = true
        }
    }

    private func runTask(_ task: MaintenanceService.MaintenanceTask) {
        runningTask = task.name
        Task {
            switch task.name {
            case "Flush DNS Cache": try? await maintenance.flushDNS()
            case "Run Maintenance Scripts": try? await maintenance.runMaintenanceScripts()
            case "Rebuild Spotlight Index": try? await maintenance.rebuildSpotlight()
            case "Rebuild Mail Index": try? await maintenance.rebuildMailIndex()
            default: try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
            await MainActor.run { runningTask = nil }
        }
    }
}

struct ProcessTableHeader: View {
    var body: some View {
        HStack {
            Text("Process").font(AppFont.labelBadge).foregroundColor(.textDisabled).frame(maxWidth: .infinity, alignment: .leading)
            Text("CPU").font(AppFont.labelBadge).foregroundColor(.textDisabled).frame(width: 80, alignment: .trailing)
            Text("Memory").font(AppFont.labelBadge).foregroundColor(.textDisabled).frame(width: 100, alignment: .trailing)
            Text("Action").font(AppFont.labelBadge).foregroundColor(.textDisabled).frame(width: 90)
        }
        .padding(.horizontal, AppSpacing.section)
        .padding(.vertical, AppSpacing.compact)
        .background(Color.bgDark2)
    }
}

struct ProcessRow: View {
    let process: SystemMonitorService.ProcessInfo2
    var onForceQuit: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack {
            Text(process.name).font(AppFont.bodyLarge).foregroundColor(.textPrimary).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            Text(String(format: "%.1f%%", process.cpuUsage)).font(AppFont.mono).foregroundColor(.textSecondary).frame(width: 80, alignment: .trailing)
            Text(process.ramString).font(AppFont.mono).foregroundColor(.infoBlue).frame(width: 100, alignment: .trailing)
            Button("Force Quit") { onForceQuit() }
                .buttonStyle(.plain).font(AppFont.bodySmall).foregroundColor(.dangerRed)
                .padding(.horizontal, AppSpacing.compact).padding(.vertical, 4)
                .background(Color.dangerRed.opacity(0.12))
                .cornerRadius(AppRadius.small)
                .frame(width: 90)
        }
        .padding(.horizontal, AppSpacing.section)
        .frame(height: 40)
        .background(isHovered ? Color.white.opacity(0.04) : Color.clear)
        .onHover { isHovered = $0 }
    }
}

struct MaintenanceTaskRow: View {
    let task: MaintenanceService.MaintenanceTask
    let isRunning: Bool
    var onRun: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: AppSpacing.standard) {
            Image(systemName: task.icon).font(.system(size: 18)).foregroundColor(.warningOrange).frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(task.name).font(AppFont.heading3).foregroundColor(.textPrimary)
                Text(task.description).font(AppFont.bodySmall).foregroundColor(.textSecondary)
            }
            Spacer()
            if let date = task.lastRun {
                Text(date, style: .relative).font(AppFont.bodySmall).foregroundColor(.textDisabled)
            }
            Text(task.estimatedTime).font(AppFont.bodySmall).foregroundColor(.textDisabled).frame(width: 60)
            if isRunning {
                ProgressView().progressViewStyle(.circular).scaleEffect(0.7)
            } else {
                CMButton("Run", style: .secondary) { onRun() }
            }
        }
        .padding(.horizontal, AppSpacing.section)
        .frame(height: 60)
        .background(isHovered ? Color.white.opacity(0.03) : Color.clear)
        .onHover { isHovered = $0 }
    }
}

struct RAMFreedOverlay: View {
    let freedMB: Int
    var onDone: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: AppSpacing.standard) {
                Image(systemName: "memorychip.fill").font(.system(size: 48)).foregroundColor(.successGreen)
                Text("\(freedMB) MB Freed").font(AppFont.numberHero).foregroundColor(.successGreen).monospacedDigit()
                Text("RAM has been optimized").font(AppFont.heading3).foregroundColor(.textSecondary)
                CMButton("Done") { onDone() }
            }
            .padding(AppSpacing.hero)
            .background(Color.surfaceDark)
            .cornerRadius(AppRadius.xLarge)
        }
    }
}
