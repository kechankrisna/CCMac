import SwiftUI
import AppKit

// MARK: - About Window Controller (singleton)

final class AboutWindowController {
    static let shared = AboutWindowController()
    private var window: NSWindow?

    private init() {}

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view    = AboutView()
        let hosting = NSHostingController(rootView: view)
        let win     = NSWindow(contentViewController: hosting)

        win.title               = "About CCMac"
        win.styleMask           = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.titlebarAppearsTransparent = true
        win.backgroundColor     = NSColor(Color.bgDark)
        win.setContentSize(NSSize(width: 420, height: 520))
        win.center()

        self.window = win
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
}

// MARK: - About View

struct AboutView: View {
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.bgDark2, Color.bgDark],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── App Icon + Name ──────────────────────────────────────
                VStack(spacing: AppSpacing.standard) {
                    // Icon
                    if let img = NSImage(named: "AppIcon") ??
                                 loadBundledIcon() {
                        Image(nsImage: img)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 96, height: 96)
                            .cornerRadius(22)
                            .shadow(color: Color.brandGreen.opacity(0.35),
                                    radius: 20, x: 0, y: 8)
                    } else {
                        // Fallback SF Symbol icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color.bgDark2)
                                .frame(width: 96, height: 96)
                            Image(systemName: "sparkles")
                                .font(.system(size: 44))
                                .foregroundColor(.brandGreen)
                        }
                        .shadow(color: Color.brandGreen.opacity(0.35),
                                radius: 20, x: 0, y: 8)
                    }

                    // Name & version
                    VStack(spacing: 4) {
                        Text("CCMac")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        Text("Version \(appVersion) (Build \(buildNumber))")
                            .font(AppFont.bodySmall)
                            .foregroundColor(Color.white.opacity(0.45))
                        Text("macOS System Cleaner")
                            .font(AppFont.bodyDefault)
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                }
                .padding(.top, AppSpacing.section + 4)
                .padding(.bottom, AppSpacing.section)

                Divider()
                    .overlay(Color.white.opacity(0.08))
                    .padding(.horizontal, AppSpacing.section)

                // ── Info rows ────────────────────────────────────────────
                VStack(spacing: 0) {
                    AboutRow(label: "Author",    value: "KE CHANKRISNA")
                    AboutRow(label: "Email",     value: "ke.chankrisna168@gmail.com", isLink: true,
                             url: "mailto:ke.chankrisna168@gmail.com")
                    AboutRow(label: "License",   value: "MIT Open Source License")
                    AboutRow(label: "Platform",  value: "macOS 13 Ventura or later")
                    AboutRow(label: "Framework", value: "Swift 5.9 · SwiftUI 5")
                    AboutRow(label: "GitHub",    value: "github.com/kechankrisna/CCMac", isLink: true,
                             url: "https://github.com/kechankrisna/CCMac")
                }
                .padding(.vertical, AppSpacing.compact)
                .padding(.horizontal, AppSpacing.section)

                Divider()
                    .overlay(Color.white.opacity(0.08))
                    .padding(.horizontal, AppSpacing.section)

                // ── Description ──────────────────────────────────────────
                Text("CCMac is a free, open-source native macOS system cleaner. It uses real macOS system APIs to scan junk files, monitor live performance, detect duplicate files, visualise disk usage, and provide AI-powered health recommendations — all in a polished dark-mode interface with zero telemetry.")
                    .font(AppFont.bodySmall)
                    .foregroundColor(Color.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, AppSpacing.section)
                    .padding(.vertical, AppSpacing.standard)

                Divider()
                    .overlay(Color.white.opacity(0.08))
                    .padding(.horizontal, AppSpacing.section)

                // ── Copyright + Close ─────────────────────────────────────
                VStack(spacing: AppSpacing.compact) {
                    Text("© 2025 KE CHANKRISNA. All rights reserved.")
                        .font(AppFont.labelBadge)
                        .foregroundColor(Color.white.opacity(0.3))

                    Button("Close") {
                        NSApp.keyWindow?.close()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.section)
                    .padding(.vertical, AppSpacing.compact)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(AppRadius.small)
                }
                .padding(.vertical, AppSpacing.standard)
            }
        }
        .frame(width: 420, height: 520)
        .preferredColorScheme(.dark)
    }

    // Try to load AppIcon.icns bundled inside the .app Resources folder
    private func loadBundledIcon() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") else { return nil }
        return NSImage(contentsOf: url)
    }
}

// MARK: - About Row

private struct AboutRow: View {
    let label: String
    let value: String
    var isLink: Bool = false
    var url: String  = ""

    @State private var hovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .font(AppFont.bodySmall)
                .foregroundColor(Color.white.opacity(0.45))
                .frame(width: 90, alignment: .leading)

            if isLink {
                Button(action: openLink) {
                    Text(value)
                        .font(AppFont.bodySmall)
                        .foregroundColor(hovered ? .white : .brandBlue)
                        .underline(hovered)
                }
                .buttonStyle(.plain)
                .onHover { hovered = $0 }
            } else {
                Text(value)
                    .font(AppFont.bodySmall)
                    .foregroundColor(Color.white.opacity(0.8))
            }

            Spacer()
        }
        .padding(.vertical, 7)
        .padding(.horizontal, AppSpacing.compact)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.small)
                .fill(hovered && !isLink ? Color.white.opacity(0.04) : Color.clear)
        )
    }

    private func openLink() {
        guard let u = URL(string: url) else { return }
        NSWorkspace.shared.open(u)
    }
}
