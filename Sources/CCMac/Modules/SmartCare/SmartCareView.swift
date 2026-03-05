import SwiftUI

// MARK: - Smart Care Module ViewModel
@MainActor
class SmartCareViewModel: ObservableObject {
    @Published var state: ScanState = .idle
    @Published var scanProgress: Double = 0
    @Published var scanMessage: String = ""
    @Published var scanCategories: [ScanCategory] = []
    @Published var healthScore: Int = 72
    @Published var lastScanDate: Date? = nil
    @Published var freedBytes: Int64 = 0

    enum ScanState { case idle, scanning, results, cleaning, complete }

    private let cleanupService = CleanupService()

    var totalFoundBytes: Int64 { scanCategories.reduce(0) { $0 + $1.totalSize } }
    var selectedBytes: Int64 { scanCategories.filter { $0.isSelected }.reduce(0) { $0 + $1.totalSize } }
    var totalFoundString: String { ByteCountFormatter.string(fromByteCount: totalFoundBytes, countStyle: .file) }
    var selectedString: String { ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file) }

    func startScan() {
        state = .scanning
        scanProgress = 0
        scanCategories = []

        Task {
            let results = await cleanupService.scanCategories { prog, msg in
                Task { @MainActor in
                    self.scanProgress = prog
                    self.scanMessage = msg
                }
            }
            scanCategories = results
            lastScanDate = Date()
            state = .results
        }
    }

    func clean() {
        state = .cleaning
        let selected = scanCategories.filter { $0.isSelected }.flatMap { $0.files }.filter { $0.isSelected }
        Task {
            let (_, freed) = await cleanupService.deleteFiles(selected) { prog, path in
                Task { @MainActor in
                    self.scanProgress = prog
                    self.scanMessage = path
                }
            }
            freedBytes = freed
            healthScore = min(100, healthScore + Int(Double(freed) / 1_000_000))
            state = .complete
        }
    }

    func reset() { state = .idle; scanCategories = []; scanProgress = 0; freedBytes = 0 }
}

// MARK: - Smart Care View (state machine)
struct SmartCareView: View {
    @StateObject private var vm = SmartCareViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderView(
                module: .smartCare,
                subtitle: "Scan and optimize your Mac in one click",
                actionLabel: "Run Smart Care",
                isScanning: vm.state == .scanning,
                onAction: { vm.startScan() }
            )

            Group {
                switch vm.state {
                case .idle:    SmartCareIdleView(vm: vm)
                case .scanning: SmartCareScanningView(vm: vm)
                case .results:  SmartCareResultsView(vm: vm)
                case .cleaning: SmartCareCleaningView(vm: vm)
                case .complete: SmartCareCompleteView(vm: vm)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.bgDark)
    }
}

// MARK: - Idle / Welcome State
struct SmartCareIdleView: View {
    @ObservedObject var vm: SmartCareViewModel

    var body: some View {
        VStack(spacing: AppSpacing.section) {
            Spacer()
            // Health Score Ring
            HealthScoreRing(score: vm.healthScore)
                .shadow(color: Color.brandGreen.opacity(0.25), radius: 30, x: 0, y: 0)

            if let date = vm.lastScanDate {
                Text("Last scan: \(date, style: .relative) ago")
                    .font(AppFont.bodySmall).foregroundColor(.textDisabled)
            } else {
                Text("No recent scan").font(AppFont.bodySmall).foregroundColor(.textDisabled)
            }

            CMButton("Run Smart Care", icon: "sparkles") { vm.startScan() }

            // Stats row
            HStack(spacing: AppSpacing.standard) {
                MiniStatCard(title: "Junk Found", value: vm.lastScanDate == nil ? "—" : vm.totalFoundString, icon: "trash.fill")
                MiniStatCard(title: "Threats", value: "0", icon: "shield.fill")
                MiniStatCard(title: "Health Score", value: "\(vm.healthScore)/100", icon: "heart.fill")
            }
            .padding(.horizontal, AppSpacing.section)

            Spacer()
        }
        .padding(AppSpacing.section)
    }
}

struct MiniStatCard: View {
    let title: String; let value: String; let icon: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(.brandBlue).font(.system(size: 18))
            Text(value).font(AppFont.heading2).foregroundColor(.textPrimary).monospacedDigit()
            Text(title).font(AppFont.bodySmall).foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.standard)
        .background(Color.surfaceDark)
        .cornerRadius(AppRadius.medium)
    }
}

// MARK: - Scanning State
struct SmartCareScanningView: View {
    @ObservedObject var vm: SmartCareViewModel

    var body: some View {
        VStack(spacing: AppSpacing.section) {
            Spacer()
            CMProgressBar(progress: vm.scanProgress).padding(.horizontal, 60)
            CircularProgressView(
                progress: vm.scanProgress,
                size: 140,
                centerContent: AnyView(
                    Text("\(Int(vm.scanProgress * 100))%")
                        .font(AppFont.heading1).foregroundColor(.textPrimary)
                )
            )
            Text(vm.scanMessage).font(AppFont.bodyDefault).foregroundColor(.textSecondary).lineLimit(1)
            CMButton("Cancel", style: .secondary) { vm.reset() }
            Spacer()
        }
        .padding(AppSpacing.section)
    }
}

// MARK: - Results State
struct SmartCareResultsView: View {
    @ObservedObject var vm: SmartCareViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Summary header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.totalFoundString)
                        .font(AppFont.numberHero).foregroundColor(.brandGreen).monospacedDigit()
                    Text("can be cleaned from your Mac").font(AppFont.bodyLarge).foregroundColor(.textSecondary)
                }
                Spacer()
                HStack(spacing: AppSpacing.compact) {
                    Button("Select All") { vm.scanCategories.indices.forEach { vm.scanCategories[$0].isSelected = true } }
                        .buttonStyle(.plain).font(AppFont.bodySmall).foregroundColor(.brandBlue)
                    Text("/").foregroundColor(.textDisabled)
                    Button("Deselect All") { vm.scanCategories.indices.forEach { vm.scanCategories[$0].isSelected = false } }
                        .buttonStyle(.plain).font(AppFont.bodySmall).foregroundColor(.textSecondary)
                }
            }
            .padding(.horizontal, AppSpacing.section)
            .padding(.vertical, AppSpacing.standard)

            // Result Cards Grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.standard) {
                    ForEach(Array(vm.scanCategories.enumerated()), id: \.element.id) { i, cat in
                        ScanResultCard(
                            category: cat,
                            isSelected: Binding(
                                get: { vm.scanCategories[i].isSelected },
                                set: { vm.scanCategories[i].isSelected = $0 }
                            )
                        )
                    }
                }
                .padding(AppSpacing.section)
            }

            // Bottom action bar
            HStack {
                Text("\(vm.selectedString) selected").font(AppFont.bodyLarge).foregroundColor(.textSecondary)
                Spacer()
                CMButton("Review Details", style: .secondary) {}
                CMButton("Clean \(vm.selectedString)", icon: "sparkles") { vm.clean() }
            }
            .padding(.horizontal, AppSpacing.section)
            .padding(.vertical, AppSpacing.standard)
            .background(Color.bgDark2.shadow(.inner(color: .black.opacity(0.3), radius: 4, y: -2)))
        }
    }
}

// MARK: - Cleaning State
struct SmartCareCleaningView: View {
    @ObservedObject var vm: SmartCareViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: AppSpacing.section) {
                CircularProgressView(
                    progress: vm.scanProgress,
                    size: 160,
                    centerContent: AnyView(
                        VStack(spacing: 4) {
                            Image(systemName: "sparkles").font(.system(size: 28)).foregroundColor(.brandGreen)
                            Text("Cleaning…").font(AppFont.bodySmall).foregroundColor(.textSecondary)
                        }
                    )
                )
                Text(vm.scanMessage)
                    .font(AppFont.mono).foregroundColor(.textDisabled).lineLimit(1).truncationMode(.middle)
                    .frame(maxWidth: 400)
                CMProgressBar(progress: vm.scanProgress).padding(.horizontal, 40)
            }
            .padding(AppSpacing.hero)
            .background(Color.surfaceDark)
            .cornerRadius(AppRadius.xLarge)
        }
    }
}

// MARK: - Complete State
struct SmartCareCompleteView: View {
    @ObservedObject var vm: SmartCareViewModel

    var body: some View {
        VStack(spacing: AppSpacing.section) {
            Spacer()
            // Celebration
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72)).foregroundColor(.brandGreen)
                .shadow(color: Color.brandGreen.opacity(0.4), radius: 20)
            Text(ByteCountFormatter.string(fromByteCount: vm.freedBytes, countStyle: .file))
                .font(AppFont.numberHero).foregroundColor(.brandGreen).monospacedDigit()
            Text("Freed from your Mac").font(AppFont.heading2).foregroundColor(.textSecondary)

            // Stats grid
            HStack(spacing: AppSpacing.standard) {
                MiniStatCard(title: "Junk Removed", value: ByteCountFormatter.string(fromByteCount: vm.freedBytes, countStyle: .file), icon: "trash.fill")
                MiniStatCard(title: "Health Score", value: "\(vm.healthScore)/100", icon: "heart.fill")
                MiniStatCard(title: "Items Removed", value: "\(vm.scanCategories.flatMap{$0.files}.filter{$0.isSelected}.count)", icon: "doc.fill")
            }
            .padding(.horizontal, AppSpacing.section)

            HStack(spacing: AppSpacing.compact) {
                CMButton("View Details", style: .secondary) {}
                CMButton("Done", icon: "checkmark") { vm.reset() }
            }
            Spacer()
        }
        .padding(AppSpacing.section)
    }
}
