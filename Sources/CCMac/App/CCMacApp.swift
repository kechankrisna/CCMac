import SwiftUI
import AppKit

// MARK: - App Entry Point with Menu Bar Support
@main
struct CCMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var showMenuBarPopover = false

    init() {
        // Must be here — this is the earliest point before SwiftUI creates any window.
        // AppDelegate.init() and applicationDidFinishLaunching are both too late.
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Run Smart Care") {}
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Divider()
                Button("Check for Threats") {}
                    .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }

        // Settings window
        Settings {
            SettingsView()
        }
    }
}

// MARK: - App Delegate for Menu Bar Item
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarItem()
        // Request Full Disk Access if not already granted
        requestDiskAccess()
    }

    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "CCMac")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 340, height: 420)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarPopoverView())
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func requestDiskAccess() {
        // Trigger file access to prompt for Full Disk Access if not already granted
        _ = try? FileManager.default.contentsOfDirectory(atPath: NSHomeDirectory() + "/Library/Caches")
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @State private var darkMode = true
    @State private var startAtLogin = false
    @State private var showMenuBarIcon = true
    @State private var autoScanInterval = 0

    var body: some View {
        TabView {
            Form {
                Toggle("Dark Mode", isOn: $darkMode)
                Toggle("Start at Login", isOn: $startAtLogin)
                Toggle("Show Menu Bar Icon", isOn: $showMenuBarIcon)
                Picker("Auto-scan interval", selection: $autoScanInterval) {
                    Text("Manual only").tag(0)
                    Text("Daily").tag(1)
                    Text("Weekly").tag(7)
                }
            }
            .tabItem { Label("General", systemImage: "gearshape.fill") }
            .padding()

            Form {
                Text("Protection settings coming soon").foregroundColor(.secondary)
            }
            .tabItem { Label("Protection", systemImage: "shield.fill") }
            .padding()

            Form {
                Text("Privacy policy: MacPaw follows GDPR compliance.\nNo personal data is shared for advertising.\nData deleted within 30 days upon request.")
                    .foregroundColor(.secondary)
            }
            .tabItem { Label("Privacy", systemImage: "lock.fill") }
            .padding()
        }
        .frame(width: 420, height: 320)
        .preferredColorScheme(.dark)
    }
}
