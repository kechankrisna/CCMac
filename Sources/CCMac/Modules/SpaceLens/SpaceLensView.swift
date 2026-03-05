import SwiftUI

struct SpaceLensView: View {
    @StateObject private var service = StorageService()
    @State private var selectedItem: DiskItem? = nil
    @State private var breadcrumb: [DiskItem] = []
    @State private var currentRoot: DiskItem? = nil
    @State private var sortBy: SortOption = .size

    enum SortOption: String, CaseIterable { case size = "Size", name = "Name", date = "Date" }

    var displayRoot: DiskItem? { currentRoot ?? service.rootItem }

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderView(
                module: .spaceLens,
                subtitle: "Visualize what's taking up your disk space",
                actionLabel: service.isScanning ? "Scanning…" : "Scan Disk",
                isScanning: service.isScanning,
                onAction: { scanDisk() }
            )

            if service.isScanning {
                SpaceLensScanningView(progress: service.scanProgress)
            } else if let root = displayRoot {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        // Toolbar
                        HStack {
                            // Breadcrumb
                            HStack(spacing: 4) {
                                Button("~") { resetToRoot() }.buttonStyle(.plain).font(AppFont.bodyDefault).foregroundColor(.brandBlue)
                                ForEach(breadcrumb.indices, id: \.self) { i in
                                    Text(">").foregroundColor(.textDisabled)
                                    Button(breadcrumb[i].name) { drillUp(to: i) }
                                        .buttonStyle(.plain).font(AppFont.bodyDefault).foregroundColor(.brandBlue)
                                }
                            }
                            Spacer()
                            HStack {
                                Text("Sort:").font(AppFont.bodySmall).foregroundColor(.textSecondary)
                                Picker("", selection: $sortBy) {
                                    ForEach(SortOption.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                                }
                                .pickerStyle(.segmented).frame(width: 160)
                            }
                            if !breadcrumb.isEmpty {
                                CMButton("↑ Go Up", style: .secondary) { goUp() }
                            }
                        }
                        .padding(.horizontal, AppSpacing.section)
                        .padding(.vertical, AppSpacing.compact)
                        .background(Color.bgDark2)
                        .overlay(alignment: .bottom) { Divider().overlay(Color.white.opacity(0.06)) }

                        // Treemap
                        TreemapView(item: root, sortBy: sortBy) { item in
                            withAnimation(.spring(response: 0.35)) {
                                if item.isDirectory {
                                    breadcrumb.append(item)
                                    currentRoot = item
                                }
                                selectedItem = item
                            }
                        }

                        // Bottom status bar
                        HStack {
                            CMProgressBar(progress: service.rootItem.map { Double($0.size - (displayRoot?.size ?? 0)) / Double(max($0.size, 1)) } ?? 0, showLabel: false)
                                .frame(height: 4)
                            Text("\(root.sizeString) in folder")
                                .font(AppFont.bodySmall).foregroundColor(.textSecondary)
                            Spacer()
                            Text("Disk: \(formatDiskInfo())")
                                .font(AppFont.bodySmall).foregroundColor(.textDisabled)
                        }
                        .padding(.horizontal, AppSpacing.section)
                        .padding(.vertical, AppSpacing.compact)
                        .background(Color.bgDark2)
                    }
                    .frame(maxWidth: .infinity)

                    // Right detail panel
                    if let sel = selectedItem {
                        Divider().overlay(Color.white.opacity(0.06))
                        SpaceLensDetailPanel(item: sel, onClose: { selectedItem = nil }, onDelete: {
                            try? FileManager.default.trashItem(at: URL(fileURLWithPath: sel.path), resultingItemURL: nil)
                            selectedItem = nil
                            scanDisk()
                        })
                    }
                }
            } else {
                EmptyStateView(icon: "circle.grid.3x3.fill", title: "Space Lens", subtitle: "Tap 'Scan Disk' to create a visual map of your storage usage")
            }
        }
        .background(Color.bgDark)
        .onAppear { if service.rootItem == nil { scanDisk() } }
    }

    private func scanDisk() {
        Task { await service.scanDisk { prog, msg in
            Task { @MainActor in service.scanProgress = prog }
        }}
        currentRoot = nil; breadcrumb = []; selectedItem = nil
    }

    private func resetToRoot() { breadcrumb = []; currentRoot = nil }
    private func goUp() {
        breadcrumb.removeLast()
        currentRoot = breadcrumb.last
    }
    private func drillUp(to index: Int) {
        breadcrumb = Array(breadcrumb.prefix(index + 1))
        currentRoot = breadcrumb.last
    }

    private func formatDiskInfo() -> String {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
           let total = attrs[.systemSize] as? Int64,
           let free  = attrs[.systemFreeSize] as? Int64 {
            let freeStr = ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
            let totalStr = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            return "\(freeStr) free of \(totalStr)"
        }
        return "—"
    }
}

// MARK: - Treemap Visualization
struct TreemapView: View {
    let item: DiskItem
    let sortBy: SpaceLensView.SortOption
    var onSelect: (DiskItem) -> Void

    var sortedChildren: [DiskItem] {
        switch sortBy {
        case .size: return item.children.sorted { $0.size > $1.size }
        case .name: return item.children.sorted { $0.name < $1.name }
        case .date: return item.children.sorted { $0.name < $1.name }
        }
    }

    var body: some View {
        GeometryReader { geo in
            if item.children.isEmpty {
                // Leaf node
                RoundedRectangle(cornerRadius: 4)
                    .fill(item.color.opacity(0.7))
                    .frame(width: geo.size.width, height: geo.size.height)
            } else {
                Canvas { ctx, size in
                    drawTreemap(in: ctx, size: size, items: sortedChildren, totalSize: item.size)
                }
                .overlay {
                    TreemapInteractionOverlay(items: sortedChildren, totalSize: item.size, size: geo.size, onSelect: onSelect)
                }
            }
        }
        .padding(AppSpacing.standard)
    }

    private func drawTreemap(in ctx: GraphicsContext, size: CGSize, items: [DiskItem], totalSize: Int64) {
        guard totalSize > 0, !items.isEmpty else { return }
        var remaining = CGRect(origin: .zero, size: size)

        for (i, child) in items.enumerated() {
            let ratio = CGFloat(child.size) / CGFloat(totalSize)
            let isLast = i == items.count - 1
            var rect: CGRect
            if remaining.width > remaining.height {
                let w = isLast ? remaining.width : remaining.width * ratio * CGFloat(items.count - i)
                rect = CGRect(x: remaining.minX, y: remaining.minY, width: min(w, remaining.width), height: remaining.height)
                remaining = CGRect(x: rect.maxX, y: remaining.minY, width: remaining.width - rect.width, height: remaining.height)
            } else {
                let h = isLast ? remaining.height : remaining.height * ratio * CGFloat(items.count - i)
                rect = CGRect(x: remaining.minX, y: remaining.minY, width: remaining.width, height: min(h, remaining.height))
                remaining = CGRect(x: remaining.minX, y: rect.maxY, width: remaining.width, height: remaining.height - rect.height)
            }
            let inset = rect.insetBy(dx: 2, dy: 2)
            ctx.fill(Path(roundedRect: inset, cornerRadius: 4), with: .color(child.color.opacity(0.75)))

            if inset.width > 60 && inset.height > 30 {
                ctx.draw(
                    Text(child.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white),
                    at: CGPoint(x: inset.midX, y: inset.midY - 8),
                    anchor: .center
                )
                ctx.draw(
                    Text(child.sizeString)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.65)),
                    at: CGPoint(x: inset.midX, y: inset.midY + 8),
                    anchor: .center
                )
            }
        }
    }
}

struct TreemapInteractionOverlay: View {
    let items: [DiskItem]; let totalSize: Int64; let size: CGSize
    var onSelect: (DiskItem) -> Void

    var body: some View {
        ZStack {
            ForEach(items) { _ in Color.clear }
        }
        .contentShape(Rectangle())
        .gesture(TapGesture().onEnded { _ in }) // Simplified — full hit testing would need custom NSView
    }
}

struct SpaceLensScanningView: View {
    let progress: Double
    var body: some View {
        VStack(spacing: AppSpacing.section) {
            Spacer()
            CMProgressBar(progress: progress).padding(.horizontal, 60)
            Text("Mapping your storage…").font(AppFont.heading3).foregroundColor(.textSecondary)
            Spacer()
        }
    }
}

struct SpaceLensDetailPanel: View {
    let item: DiskItem
    var onClose: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.standard) {
            HStack {
                Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                    .foregroundColor(item.color)
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark").foregroundColor(.textDisabled) }.buttonStyle(.plain)
            }
            Text(item.name).font(AppFont.heading2).foregroundColor(.textPrimary)
            Text(item.path).font(AppFont.mono).foregroundColor(.textDisabled).lineLimit(3)
            Divider().overlay(Color.white.opacity(0.06))
            DetailRow(label: "Size", value: item.sizeString)
            if item.isDirectory { DetailRow(label: "Items", value: "\(item.children.count)") }
            Spacer()
            CMButton("Open in Finder", style: .secondary) {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
            }
            CMButton("Delete", isDestructive: true) { onDelete() }
        }
        .padding(AppSpacing.standard)
        .frame(width: 260)
        .background(Color.bgDark2)
    }
}

struct DetailRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).font(AppFont.bodyDefault).foregroundColor(.textSecondary)
            Spacer()
            Text(value).font(AppFont.bodyDefault).foregroundColor(.textPrimary).monospacedDigit()
        }
    }
}
