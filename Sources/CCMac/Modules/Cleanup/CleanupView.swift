import SwiftUI

@MainActor
class CleanupViewModel: ObservableObject {
    @Published var state: State = .overview
    @Published var categories: [ScanCategory] = []
    @Published var selectedCategoryIndex: Int = 0
    @Published var scanProgress: Double = 0
    @Published var scanMessage: String = ""
    @Published var ignoreList: [FileItem] = []

    enum State { case overview, scanning, results, ignoreList }

    private let service = CleanupService()

    var selectedCategory: ScanCategory? {
        guard !categories.isEmpty, categories.indices.contains(selectedCategoryIndex) else { return nil }
        return categories[selectedCategoryIndex]
    }

    var totalSize: Int64 { categories.reduce(0) { $0 + $1.totalSize } }
    var selectedFilesSize: Int64 {
        guard let cat = selectedCategory else { return 0 }
        return cat.files.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }

    func scan() {
        state = .scanning
        Task {
            let results = await service.scanCategories { prog, msg in
                Task { @MainActor in self.scanProgress = prog; self.scanMessage = msg }
            }
            categories = results
            state = .results
        }
    }

    func clean() {
        guard let cat = selectedCategory else { return }
        let selected = cat.files.filter { $0.isSelected }
        Task {
            _ = await service.deleteFiles(selected) { _, _ in }
            await scan()
        }
    }
}

struct CleanupView: View {
    @StateObject private var vm = CleanupViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderView(
                module: .cleanup,
                subtitle: "Remove junk files and free up disk space",
                actionLabel: "Scan",
                isScanning: vm.state == .scanning,
                onAction: { vm.scan() }
            )
            switch vm.state {
            case .overview:    CleanupOverviewView(vm: vm)
            case .scanning:    CleanupScanningView(vm: vm)
            case .results:     CleanupResultsView(vm: vm)
            case .ignoreList:  CleanupIgnoreListView(vm: vm)
            }
        }
        .background(Color.bgDark)
    }
}

struct CleanupOverviewView: View {
    @ObservedObject var vm: CleanupViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Left: Category list
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(CleanupService.categories.enumerated()), id: \.offset) { i, cat in
                        HStack(spacing: AppSpacing.compact) {
                            Image(systemName: cat.icon).font(.system(size: 16)).foregroundColor(.infoBlue).frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(cat.name).font(AppFont.heading3).foregroundColor(.textPrimary)
                                Text("Tap Scan to see what's here").font(AppFont.bodySmall).foregroundColor(.textDisabled)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.standard)
                        .frame(height: 56)
                        .background(Color.surfaceDark.opacity(0.5))
                        .cornerRadius(AppRadius.small)
                        .padding(.horizontal, AppSpacing.standard)
                    }
                }
                .padding(.vertical, AppSpacing.base)
            }
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)

            Divider().overlay(Color.white.opacity(0.05))

            // Right: Info panel
            VStack(alignment: .leading, spacing: AppSpacing.standard) {
                Text("What Cleanup removes").font(AppFont.heading2).foregroundColor(.textPrimary)
                Text("Cleanup safely removes temporary files, caches, logs, and other system-generated junk that macOS leaves behind. It won't touch your documents or personal files.")
                    .font(AppFont.bodyDefault).foregroundColor(.textSecondary)
                Spacer()
                CMButton("Scan Now") { vm.scan() }
            }
            .padding(AppSpacing.section)
            .frame(width: 300)
        }
    }
}

struct CleanupScanningView: View {
    @ObservedObject var vm: CleanupViewModel
    var body: some View {
        VStack(spacing: AppSpacing.section) {
            Spacer()
            CMProgressBar(progress: vm.scanProgress).padding(.horizontal, 60)
            Text(vm.scanMessage).font(AppFont.bodyDefault).foregroundColor(.textSecondary)
            Spacer()
        }
    }
}

struct CleanupResultsView: View {
    @ObservedObject var vm: CleanupViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Left: category list with sizes
            VStack(spacing: 0) {
                HStack {
                    Text("Total Found:")
                        .font(AppFont.bodyDefault).foregroundColor(.textSecondary)
                    Text(ByteCountFormatter.string(fromByteCount: vm.totalSize, countStyle: .file))
                        .font(AppFont.heading3).foregroundColor(.brandGreen).monospacedDigit()
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.standard)
                .padding(.vertical, AppSpacing.compact)

                ScrollView {
                    ForEach(Array(vm.categories.enumerated()), id: \.element.id) { i, cat in
                        HStack {
                            Image(systemName: cat.icon).foregroundColor(cat.color).font(.system(size: 15)).frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cat.name).font(AppFont.heading3).foregroundColor(.textPrimary)
                                Text("\(cat.files.count) files").font(AppFont.bodySmall).foregroundColor(.textSecondary)
                            }
                            Spacer()
                            Text(cat.totalSizeString).font(AppFont.bodyDefault)
                                .foregroundColor(i == vm.selectedCategoryIndex ? .brandGreen : .textSecondary)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, AppSpacing.standard)
                        .frame(height: 52)
                        .background(i == vm.selectedCategoryIndex ? Color.brandBlue.opacity(0.12) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { vm.selectedCategoryIndex = i }
                    }
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .background(Color.bgDark2)

            Divider().overlay(Color.white.opacity(0.05))

            // Right: File list for selected category
            VStack(spacing: 0) {
                if let cat = vm.selectedCategory {
                    HStack {
                        Text(cat.name).font(AppFont.heading3).foregroundColor(.textPrimary)
                        Spacer()
                        Text(cat.totalSizeString).font(AppFont.heading3).foregroundColor(.brandGreen).monospacedDigit()
                    }
                    .padding(.horizontal, AppSpacing.standard)
                    .padding(.vertical, AppSpacing.compact)
                    .overlay(alignment: .bottom) { Divider().overlay(Color.white.opacity(0.05)) }

                    ScrollView {
                        ForEach(Array(cat.files.enumerated()), id: \.element.id) { i, file in
                            FileListRow(file: file, isSelected: Binding(
                                get: { vm.categories[vm.selectedCategoryIndex].files[i].isSelected },
                                set: { vm.categories[vm.selectedCategoryIndex].files[i].isSelected = $0 }
                            ))
                            Divider().overlay(Color.white.opacity(0.03)).padding(.leading, 48)
                        }
                    }
                } else {
                    EmptyStateView(icon: "doc.text.magnifyingglass", title: "Select a category", subtitle: "Choose a category on the left to review files")
                }

                // Bottom action bar
                HStack {
                    let selectedCount = vm.selectedCategory?.files.filter { $0.isSelected }.count ?? 0
                    Text("\(selectedCount) items selected · \(ByteCountFormatter.string(fromByteCount: vm.selectedFilesSize, countStyle: .file))")
                        .font(AppFont.bodyDefault).foregroundColor(.textSecondary)
                    Spacer()
                    Button("Ignore Selected") {}
                        .buttonStyle(.plain).font(AppFont.bodySmall).foregroundColor(.textDisabled)
                    CMButton("Clean") { vm.clean() }
                }
                .padding(.horizontal, AppSpacing.standard)
                .padding(.vertical, AppSpacing.compact)
                .background(Color.bgDark2)
            }
            .frame(minWidth: 0, maxWidth: .infinity)
        }
    }
}

struct CleanupIgnoreListView: View {
    @ObservedObject var vm: CleanupViewModel
    var body: some View {
        if vm.ignoreList.isEmpty {
            EmptyStateView(icon: "eye.slash", title: "No Ignored Items", subtitle: "Files you choose to ignore will appear here")
        } else {
            ScrollView { ForEach(vm.ignoreList) { file in FileListRow(file: file, isSelected: .constant(true)) } }
        }
    }
}
