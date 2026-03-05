import SwiftUI

@MainActor
class ApplicationsViewModel: ObservableObject {
    @Published var apps: [AppInfo] = []
    @Published var updatableApps: [AppInfo] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var filter: Filter = .all
    @Published var selectedApp: AppInfo? = nil
    @Published var showUninstallModal = false
    @Published var tab: Tab = .installed

    enum Filter: String, CaseIterable { case all = "All", recentlyUsed = "Recently Used", unused = "Unused", large = "Large Apps" }
    enum Tab: String, CaseIterable { case installed = "Installed Apps", updater = "App Updater" }

    private let service = AppManagerService()

    var filteredApps: [AppInfo] {
        var result = apps
        if !searchText.isEmpty { result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }
        switch filter {
        case .all: break
        case .large: result = result.filter { $0.size > 100_000_000 }
        case .unused: result = result.filter { $0.lastUsed == nil }
        case .recentlyUsed: result = result.filter { $0.lastUsed != nil }
        }
        return result
    }

    func load() {
        isLoading = true
        Task {
            await service.loadInstalledApps()
            apps = service.installedApps
            isLoading = false
        }
    }

    func checkUpdates() {
        Task { updatableApps = await service.checkForUpdates() }
    }

    func selectForUninstall(_ app: AppInfo) {
        Task {
            let updated = await service.loadLeftovers(for: app)
            selectedApp = updated
            showUninstallModal = true
        }
    }

    func uninstall(_ app: AppInfo) {
        Task {
            try? await service.uninstall(app: app)
            apps = service.installedApps
            showUninstallModal = false
        }
    }
}

struct ApplicationsView: View {
    @StateObject private var vm = ApplicationsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderView(
                module: .applications,
                subtitle: "Uninstall apps and stay up to date",
                actionLabel: "Refresh",
                onAction: { vm.load() }
            )

            // Tab Selector
            HStack(spacing: 0) {
                ForEach(ApplicationsViewModel.Tab.allCases, id: \.self) { tab in
                    Button(action: { vm.tab = tab }) {
                        Text(tab.rawValue)
                            .font(AppFont.heading3)
                            .foregroundColor(vm.tab == tab ? .textPrimary : .textSecondary)
                            .padding(.vertical, AppSpacing.compact)
                            .padding(.horizontal, AppSpacing.section)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(vm.tab == tab ? Color.brandGreen : Color.clear).frame(height: 2)
                    }
                }
                Spacer()
            }
            .background(Color.bgDark2)
            .overlay(alignment: .bottom) { Divider().overlay(Color.white.opacity(0.06)) }

            if vm.tab == .installed {
                InstalledAppsView(vm: vm)
            } else {
                AppUpdaterView(vm: vm)
            }
        }
        .background(Color.bgDark)
        .onAppear { vm.load(); vm.checkUpdates() }
        .sheet(isPresented: $vm.showUninstallModal) {
            if let app = vm.selectedApp {
                UninstallModalView(app: app,
                    onUninstall: { vm.uninstall(app) },
                    onCancel: { vm.showUninstallModal = false }
                )
            }
        }
    }
}

struct InstalledAppsView: View {
    @ObservedObject var vm: ApplicationsViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Search + Filters
            HStack(spacing: AppSpacing.standard) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.textDisabled)
                    TextField("Search apps…", text: $vm.searchText)
                        .textFieldStyle(.plain).font(AppFont.bodyLarge).foregroundColor(.textPrimary)
                }
                .padding(AppSpacing.compact)
                .background(Color.surfaceDark)
                .cornerRadius(AppRadius.medium)

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.base) {
                        ForEach(ApplicationsViewModel.Filter.allCases, id: \.self) { f in
                            Button(action: { vm.filter = f }) {
                                Text(f.rawValue)
                                    .font(AppFont.labelBadge)
                                    .foregroundColor(vm.filter == f ? .white : .textSecondary)
                                    .padding(.horizontal, AppSpacing.compact)
                                    .padding(.vertical, 6)
                                    .background(vm.filter == f ? Color.brandBlue : Color.surfaceDark)
                                    .cornerRadius(AppRadius.small)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.section)
            .padding(.vertical, AppSpacing.compact)
            .background(Color.bgDark2)

            if vm.isLoading {
                Spacer()
                ProgressView("Loading apps…").foregroundColor(.textSecondary)
                Spacer()
            } else if vm.filteredApps.isEmpty {
                EmptyStateView(icon: "app.badge", title: "No Apps Found", subtitle: "Try a different search or filter")
            } else {
                List(vm.filteredApps) { app in
                    AppRow(app: app) { vm.selectForUninstall(app) }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

struct AppRow: View {
    let app: AppInfo
    var onUninstall: () -> Void
    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.standard) {
                if let icon = app.icon {
                    Image(nsImage: icon).resizable().frame(width: 32, height: 32).cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6).fill(Color.surfaceDark).frame(width: 32, height: 32)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(AppFont.bodyLarge).foregroundColor(.textPrimary)
                    Text("v\(app.version) · Installed \(app.installDate, style: .date)").font(AppFont.bodySmall).foregroundColor(.textSecondary)
                }
                Spacer()
                Text(app.sizeString).font(AppFont.bodyDefault).foregroundColor(.brandBlue).monospacedDigit()
                    .padding(.horizontal, AppSpacing.compact).padding(.vertical, 4)
                    .background(Color.brandBlue.opacity(0.12)).cornerRadius(AppRadius.small)
                CMButton("Uninstall", style: .secondary, isDestructive: false) { onUninstall() }
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down").foregroundColor(.textDisabled)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.standard)
            .frame(height: 56)
            .background(isHovered ? Color.surfaceDarkHover : Color.surfaceDark.opacity(0.4))
            .onHover { isHovered = $0 }

            if isExpanded {
                Text("No leftover files found").font(AppFont.bodySmall).foregroundColor(.textDisabled)
                    .padding(.horizontal, AppSpacing.section).padding(.vertical, AppSpacing.compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surfaceDark.opacity(0.3))
            }
        }
        .cornerRadius(AppRadius.small)
        .padding(.vertical, 2)
    }
}

struct AppUpdaterView: View {
    @ObservedObject var vm: ApplicationsViewModel

    var body: some View {
        VStack(spacing: 0) {
            if !vm.updatableApps.isEmpty {
                HStack {
                    Text("\(vm.updatableApps.count) apps have updates available")
                        .font(AppFont.heading3).foregroundColor(.textPrimary)
                    Spacer()
                    CMButton("Update All") {}
                }
                .padding(.horizontal, AppSpacing.section).padding(.vertical, AppSpacing.compact)
            }

            if vm.updatableApps.isEmpty {
                EmptyStateView(icon: "checkmark.circle.fill", title: "All Up to Date", subtitle: "Your apps are running the latest versions")
            } else {
                List(vm.updatableApps) { app in
                    HStack(spacing: AppSpacing.standard) {
                        if let icon = app.icon {
                            Image(nsImage: icon).resizable().frame(width: 32, height: 32).cornerRadius(6)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name).font(AppFont.bodyLarge).foregroundColor(.textPrimary)
                            HStack(spacing: 6) {
                                Text("v\(app.version)").font(AppFont.bodySmall).foregroundColor(.textSecondary)
                                Image(systemName: "arrow.right").font(.system(size: 10)).foregroundColor(.textDisabled)
                                Text("v\(app.newVersion ?? "—")").font(AppFont.bodySmall).foregroundColor(.brandGreen)
                            }
                        }
                        Spacer()
                        CMButton("Update") {}
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 4)
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
            }
        }
    }
}

struct UninstallModalView: View {
    let app: AppInfo
    var onUninstall: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.section) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 36)).foregroundColor(.warningOrange)
            Text("Uninstall \(app.name)?").font(AppFont.heading1).foregroundColor(.textPrimary)
            Text("This will remove the app and \(app.leftoverFiles.count) associated files.")
                .font(AppFont.bodyDefault).foregroundColor(.textSecondary).multilineTextAlignment(.center)

            if !app.leftoverFiles.isEmpty {
                ScrollView {
                    ForEach(app.leftoverFiles) { file in
                        FileListRow(file: file, isSelected: .constant(true))
                        Divider().overlay(Color.white.opacity(0.05))
                    }
                }
                .frame(maxHeight: 200)
                .background(Color.surfaceDark).cornerRadius(AppRadius.medium)
            }

            HStack(spacing: AppSpacing.compact) {
                CMButton("Cancel", style: .secondary) { onCancel() }
                CMButton("Uninstall + Clean \(app.leftoverSizeString)", isDestructive: true) { onUninstall() }
            }
        }
        .padding(AppSpacing.section)
        .frame(width: 480)
        .background(Color.bgDark)
    }
}
