import SwiftUI

struct CloudCleanupView: View {
    @State private var services: [CloudService] = [
        CloudService(name: "iCloud Drive", icon: "icloud.fill", color: .infoBlue,
                     isConnected: true, usedBytes: 28_000_000_000, totalBytes: 50_000_000_000),
        CloudService(name: "Google Drive", icon: "g.circle.fill", color: .successGreen,
                     usedBytes: 0, totalBytes: 15_000_000_000),
        CloudService(name: "OneDrive", icon: "cloud.fill", color: .brandBlue,
                     usedBytes: 0, totalBytes: 5_000_000_000),
        CloudService(name: "Dropbox", icon: "cube.fill", color: Color(hex: "#0061FE"),
                     usedBytes: 0, totalBytes: 2_000_000_000),
    ]
    @State private var selectedService: CloudService? = nil
    @State private var tab: Tab = .connect

    enum Tab { case connect, spaceLens, complete }

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderView(
                module: .cloudCleanup,
                subtitle: "Clean files from your cloud storage services",
                actionLabel: "Refresh",
                onAction: {}
            )

            switch tab {
            case .connect:
                CloudConnectView(services: $services, onScanCloud: { svc in
                    selectedService = svc
                    tab = .spaceLens
                })
            case .spaceLens:
                CloudSpaceLensView(service: selectedService) { tab = .complete }
            case .complete:
                CloudCompleteView { tab = .connect }
            }
        }
        .background(Color.bgDark)
    }
}

struct CloudConnectView: View {
    @Binding var services: [CloudService]
    var onScanCloud: (CloudService) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.section) {
                Text("Connect your cloud services to scan and clean them")
                    .font(AppFont.bodyLarge).foregroundColor(.textSecondary).padding(.top, AppSpacing.section)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.standard) {
                    ForEach(Array(services.enumerated()), id: \.element.id) { i, svc in
                        CloudServiceCard(service: svc,
                            onConnect: { services[i].isConnected = true },
                            onDisconnect: { services[i].isConnected = false },
                            onScan: { onScanCloud(svc) }
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.section)
                .padding(.bottom, AppSpacing.section)
            }
        }
    }
}

struct CloudServiceCard: View {
    let service: CloudService
    var onConnect: () -> Void
    var onDisconnect: () -> Void
    var onScan: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.standard) {
            HStack {
                Image(systemName: service.icon).font(.system(size: 40)).foregroundColor(service.color)
                Spacer()
                if service.isConnected {
                    HStack(spacing: 4) {
                        Circle().fill(Color.successGreen).frame(width: 8, height: 8)
                        Text("Connected").font(AppFont.bodySmall).foregroundColor(.successGreen)
                    }
                }
            }
            Text(service.name).font(AppFont.heading2).foregroundColor(.textPrimary)

            if service.isConnected {
                // Storage bar
                VStack(alignment: .leading, spacing: 4) {
                    CMProgressBar(progress: service.usagePercent, showLabel: false)
                    HStack {
                        Text(service.usedString).font(AppFont.bodySmall).foregroundColor(.textSecondary)
                        Text("of \(service.totalString)").font(AppFont.bodySmall).foregroundColor(.textDisabled)
                    }
                }
                CMButton("Scan Cloud") { onScan() }
                Button("Disconnect") { onDisconnect() }
                    .buttonStyle(.plain).font(AppFont.bodySmall).foregroundColor(.textDisabled)
            } else {
                Text(service.totalString + " available").font(AppFont.bodySmall).foregroundColor(.textDisabled)
                CMButton("Connect") { onConnect() }
            }
        }
        .padding(AppSpacing.standard)
        .frame(height: 200)
        .background(Color.surfaceDark)
        .cornerRadius(AppRadius.large)
        .shadow(color: .black.opacity(isHovered ? 0.4 : 0.2), radius: isHovered ? 20 : 10)
        .scaleEffect(isHovered ? 1.01 : 1)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

struct CloudSpaceLensView: View {
    let service: CloudService?
    var onClean: () -> Void
    @State private var selectedTab: String = "iCloud"

    var body: some View {
        VStack(spacing: 0) {
            // Service tabs
            HStack(spacing: 0) {
                ForEach(["iCloud", "Google Drive", "OneDrive", "Dropbox"], id: \.self) { tab in
                    Button(tab) { selectedTab = tab }
                        .buttonStyle(.plain)
                        .font(AppFont.bodyDefault)
                        .foregroundColor(selectedTab == tab ? .textPrimary : .textSecondary)
                        .padding(.vertical, AppSpacing.compact).padding(.horizontal, AppSpacing.standard)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(selectedTab == tab ? Color.brandGreen : Color.clear).frame(height: 2)
                        }
                }
                Spacer()
            }
            .background(Color.bgDark2)
            .overlay(alignment: .bottom) { Divider().overlay(Color.white.opacity(0.06)) }

            EmptyStateView(
                icon: "cloud.fill",
                title: "Cloud Space Lens",
                subtitle: "Connect your cloud account to visualize what's taking up space"
            )

            HStack {
                Spacer()
                CMButton("Delete from Cloud", isDestructive: true) { onClean() }
                CMButton("Remove Local Copy", style: .secondary) {}
                CMButton("Unsync", style: .secondary) {}
            }
            .padding(AppSpacing.standard)
            .background(Color.bgDark2)
        }
    }
}

struct CloudCompleteView: View {
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.section) {
            Spacer()
            Image(systemName: "cloud.fill").font(.system(size: 64)).foregroundColor(.brandGreen)
            Text("2.4 GB freed from cloud").font(AppFont.numberHero).foregroundColor(.brandGreen).monospacedDigit()
            // Service breakdown
            VStack(spacing: AppSpacing.compact) {
                CloudBreakdownRow(service: "iCloud Drive", freed: "1.8 GB")
                CloudBreakdownRow(service: "Google Drive", freed: "0.6 GB")
            }
            .padding(AppSpacing.standard)
            .background(Color.surfaceDark).cornerRadius(AppRadius.medium)
            .padding(.horizontal, 80)
            HStack(spacing: AppSpacing.compact) {
                CMButton("View Cloud", style: .secondary) {}
                CMButton("Done") { onDone() }
            }
            Spacer()
        }
    }
}

struct CloudBreakdownRow: View {
    let service: String; let freed: String
    var body: some View {
        HStack {
            Text(service).font(AppFont.bodyDefault).foregroundColor(.textSecondary)
            Spacer()
            Text(freed).font(AppFont.heading3).foregroundColor(.textPrimary).monospacedDigit()
        }
    }
}
