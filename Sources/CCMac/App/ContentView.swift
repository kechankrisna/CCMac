import SwiftUI

// MARK: - Main App Content View (Sidebar + Module Area)
struct ContentView: View {
    @State private var selectedModule: AppModule = .smartCare

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selectedModule: $selectedModule)

            // Module content
            ZStack {
                Color.bgDark.ignoresSafeArea()
                moduleView(for: selectedModule)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    .id(selectedModule) // Force re-mount on switch
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1060, minHeight: 700)
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSmartCare)) { _ in
            selectedModule = .smartCare
        }
        .onReceive(NotificationCenter.default.publisher(for: .startSmartCareScan)) { _ in
            selectedModule = .smartCare
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
