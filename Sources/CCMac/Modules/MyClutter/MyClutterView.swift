import SwiftUI

@MainActor
class MyClutterViewModel: ObservableObject {
    @Published var state: State = .overview
    @Published var duplicateGroups: [[FileItem]] = []
    @Published var largeFiles: [FileItem] = []
    @Published var scanProgress: Double = 0
    @Published var scanMessage: String = ""
    @Published var activeView: ActiveView = .duplicates

    enum State { case overview, scanning, results }
    enum ActiveView { case duplicates, largeFiles }

    private let finder = DuplicateFinderService()
    private let cleanup = CleanupService()

    var totalDuplicateSize: Int64 { duplicateGroups.flatMap { $0.dropFirst() }.reduce(0) { $0 + $1.size } }
    var totalLargeFilesSize: Int64 { largeFiles.reduce(0) { $0 + $1.size } }

    func scan(type: ActiveView) {
        activeView = type
        state = .scanning
        scanProgress = 0

        Task {
            let homeURL = URL(fileURLWithPath: NSHomeDirectory())
            if type == .duplicates {
                duplicateGroups = await finder.findDuplicates(in: homeURL) { prog, file in
                    Task { @MainActor in self.scanProgress = prog; self.scanMessage = file }
                }
            } else {
                await MainActor.run { scanMessage = "Scanning for large files…" }
                largeFiles = finder.findLargeFiles(in: homeURL, minSizeMB: 50)
                await MainActor.run { scanProgress = 1.0 }
            }
            state = .results
        }
    }

    func deleteSelected(in group: Int, indices: [Int]) {
        let toDelete = indices.compactMap { duplicateGroups[group].indices.contains($0) ? duplicateGroups[group][$0] : nil }
        Task {
            _ = await cleanup.deleteFiles(toDelete) { _, _ in }
            await scan(type: .duplicates)
        }
    }
}

struct MyClutterView: View {
    @StateObject private var vm = MyClutterViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderView(
                module: .myClutter,
                subtitle: "Find duplicates, similar photos, and large files",
                actionLabel: "Scan",
                isScanning: vm.state == .scanning,
                onAction: {}
            )
            switch vm.state {
            case .overview:  MyClutterOverview(vm: vm)
            case .scanning:  MyClutterScanning(vm: vm)
            case .results:   MyClutterResults(vm: vm)
            }
        }
        .background(Color.bgDark)
    }
}

struct MyClutterOverview: View {
    @ObservedObject var vm: MyClutterViewModel

    let cards: [(String, String, String, String, MyClutterViewModel.ActiveView)] = [
        ("Duplicates", "Find identical files eating up space", "doc.on.doc.fill", "#E0C030", .duplicates),
        ("Large & Old Files", "Surface forgotten files on disk", "archivebox.fill", "#7B52C8", .largeFiles),
    ]

    var body: some View {
        VStack(spacing: AppSpacing.section) {
            Spacer()
            HStack(spacing: AppSpacing.section) {
                ForEach(cards, id: \.0) { card in
                    ClutterCard(
                        title: card.0,
                        description: card.1,
                        icon: card.2,
                        colorHex: card.3
                    ) { vm.scan(type: card.4) }
                }
            }
            .padding(.horizontal, AppSpacing.section)
            Spacer()
        }
    }
}

struct ClutterCard: View {
    let title: String; let description: String; let icon: String; let colorHex: String
    var onScan: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.standard) {
            Image(systemName: icon).font(.system(size: 36)).foregroundColor(Color(hex: colorHex))
            Text(title).font(AppFont.heading2).foregroundColor(.textPrimary)
            Text(description).font(AppFont.bodyDefault).foregroundColor(.textSecondary)
            Spacer()
            CMButton("Scan") { onScan() }
        }
        .padding(AppSpacing.section)
        .frame(width: 280, height: 200)
        .background(Color.surfaceDark)
        .cornerRadius(AppRadius.large)
        .scaleEffect(isHovered ? 1.02 : 1)
        .shadow(color: .black.opacity(isHovered ? 0.4 : 0.2), radius: isHovered ? 20 : 10, x: 0, y: 6)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

struct MyClutterScanning: View {
    @ObservedObject var vm: MyClutterViewModel
    var body: some View {
        VStack(spacing: AppSpacing.section) {
            Spacer()
            CMProgressBar(progress: vm.scanProgress).padding(.horizontal, 60)
            Text(vm.scanMessage).font(AppFont.mono).foregroundColor(.textDisabled).lineLimit(1)
            Spacer()
        }
    }
}

struct MyClutterResults: View {
    @ObservedObject var vm: MyClutterViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Summary
            HStack {
                let total = vm.activeView == .duplicates
                    ? ByteCountFormatter.string(fromByteCount: vm.totalDuplicateSize, countStyle: .file)
                    : ByteCountFormatter.string(fromByteCount: vm.totalLargeFilesSize, countStyle: .file)
                VStack(alignment: .leading) {
                    Text(total).font(AppFont.numberHero).foregroundColor(.brandGreen).monospacedDigit()
                    Text("could be freed").font(AppFont.bodyDefault).foregroundColor(.textSecondary)
                }
                Spacer()
                CMButton("Scan Again", style: .secondary) { vm.state = .overview }
            }
            .padding(.horizontal, AppSpacing.section).padding(.vertical, AppSpacing.standard)
            .overlay(alignment: .bottom) { Divider().overlay(Color.white.opacity(0.06)) }

            if vm.activeView == .duplicates {
                DuplicatesListView(groups: vm.duplicateGroups)
            } else {
                LargeFilesView(files: vm.largeFiles)
            }
        }
    }
}

struct DuplicatesListView: View {
    let groups: [[FileItem]]

    var body: some View {
        if groups.isEmpty {
            EmptyStateView(icon: "doc.on.doc", title: "No Duplicates Found", subtitle: "Your files are already organized efficiently")
        } else {
            ScrollView {
                VStack(spacing: AppSpacing.compact) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { gi, group in
                        DuplicateGroupView(group: group, groupIndex: gi)
                    }
                }
                .padding(AppSpacing.section)
            }
        }
    }
}

struct DuplicateGroupView: View {
    let group: [FileItem]
    let groupIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Master file (keep)
            HStack(spacing: AppSpacing.compact) {
                Image(systemName: "doc.fill").foregroundColor(.brandGreen).frame(width: 20)
                VStack(alignment: .leading) {
                    Text(group[0].name).font(AppFont.bodyLarge).bold().foregroundColor(.textPrimary)
                    Text(group[0].path).font(AppFont.mono).foregroundColor(.textDisabled).lineLimit(1)
                }
                Spacer()
                Text("KEEP").font(AppFont.labelBadge).foregroundColor(.brandGreen)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.brandGreen.opacity(0.12)).cornerRadius(AppRadius.small)
            }
            .padding(AppSpacing.standard)
            .background(Color.surfaceDark)

            // Duplicates (delete)
            ForEach(Array(group.dropFirst().enumerated()), id: \.offset) { i, dup in
                HStack(spacing: AppSpacing.compact) {
                    Image(systemName: "doc.fill").foregroundColor(.dangerRed).frame(width: 20).padding(.leading, AppSpacing.standard)
                    VStack(alignment: .leading) {
                        Text(dup.name).font(AppFont.bodyDefault).foregroundColor(.textSecondary)
                        Text(dup.path).font(AppFont.mono).foregroundColor(.textDisabled).lineLimit(1)
                    }
                    Spacer()
                    Text("DELETE").font(AppFont.labelBadge).foregroundColor(.dangerRed)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.dangerRed.opacity(0.12)).cornerRadius(AppRadius.small)
                    Text(dup.sizeString).font(AppFont.bodySmall).foregroundColor(.textDisabled).monospacedDigit()
                }
                .padding(.vertical, AppSpacing.compact)
                .background(Color.surfaceDark.opacity(0.5))
                Divider().overlay(Color.white.opacity(0.04)).padding(.leading, 52)
            }
        }
        .cornerRadius(AppRadius.medium)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.medium).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

struct LargeFilesView: View {
    let files: [FileItem]
    var body: some View {
        if files.isEmpty {
            EmptyStateView(icon: "archivebox", title: "No Large Files Found", subtitle: "No files larger than 50MB were found in your home folder")
        } else {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(files) { f in
                        FileListRow(file: f, isSelected: .constant(true))
                        Divider().overlay(Color.white.opacity(0.04))
                    }
                }
                .padding(.horizontal, AppSpacing.section)
            }
        }
    }
}
