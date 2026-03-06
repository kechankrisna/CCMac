import SwiftUI

// MARK: - Main App Content View (Sidebar + Module Area)
struct ContentView: View {
    @State private var selectedModule: AppModule = .smartCare

    // Shared monitor instance — drives the title bar tray pills (live disk / health).
    // Lightweight: 2-second polling loop, stops when the window disappears.
    @StateObject private var monitor = SystemMonitorService()

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selectedModule: $selectedModule)

            // Module content area
            ZStack {
                Color.bgDark.ignoresSafeArea()
                moduleView(for: selectedModule)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    .id(selectedModule) // Force re-mount on tab switch
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1060, minHeight: 700)
        .preferredColorScheme(.dark)
        .onAppear  { monitor.startMonitoring() }
        .onDisappear { monitor.stopMonitoring() }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSmartCare)) { _ in
            selectedModule = .smartCare
        }
        .onReceive(NotificationCenter.default.publisher(for: .startSmartCareScan)) { _ in
            selectedModule = .smartCare
        }
        // ── Title Bar Tray (overlay, not toolbar) ────────────────────────────
        // Using .overlay avoids the macOS toolbar API entirely, which means
        // no system-drawn control border or group pill around the items.
        // With .windowStyle(.hiddenTitleBar) the content fills the full window,
        // so padding(.top, 7) centres the pills in the 28px transparent title bar.
        .overlay(alignment: .topTrailing) {
            TitleBarTrayView(monitor: monitor)
                .padding(.trailing, 12)
                .padding(.top, 7)
        }
    }

    @ViewBuilder
    private func moduleView(for module: AppModule) -> some View {
        switch module {
        case .smartCare:    SmartCareView()
        case .cleanup:      CleanupView()
        case .protection:   ProtectionView()
        case .performance:  PerformanceView()
        case .applications: ApplicationsView()
        case .myClutter:    MyClutterView()
        case .spaceLens:    SpaceLensView()
        case .cloudCleanup: CloudCleanupView()
        case .assistant:    AssistantView()
        }
    }
}

#Preview {
    ContentView()
}
