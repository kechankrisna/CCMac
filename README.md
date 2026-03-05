# CCMac — macOS System Cleaner

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2013%2B-blue?style=flat-square&logo=apple" />
  <img src="https://img.shields.io/badge/Swift-5.9%2B-orange?style=flat-square&logo=swift" />
  <img src="https://img.shields.io/badge/SwiftUI-5.0-blue?style=flat-square" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" />
  <img src="https://img.shields.io/badge/Xcode-15%2B-blue?style=flat-square&logo=xcode" />
</p>

A full-featured, native macOS system cleaner built entirely with **Swift & SwiftUI**. Inspired by CCMac, this open-source app delivers real system scanning, junk removal, performance monitoring, duplicate detection, storage visualization, and more — all in a polished dark-mode interface.

---

## Screenshots

> Dark mode · macOS 13+ · 1280×800 canvas

| Smart Care | Performance | Space Lens |
|---|---|---|
| *Health score ring + scan results* | *Live CPU/RAM sparklines + process table* | *Treemap storage visualizer* |

---

## Features

### 9 Full Modules
| Module | What it does |
|--------|-------------|
| **Smart Care** | One-click hub: runs all modules, shows health score ring (0–100) |
| **Cleanup** | Scans caches, logs, mail attachments, trash, Xcode DerivedData, language files |
| **Protection** | Quick / Normal / Deep malware scanner, app permissions manager, browser privacy tools |
| **Performance** | Live CPU, RAM, disk, battery, network monitors with sparklines; maintenance tasks |
| **Applications** | Lists all installed apps with sizes, finds leftover files, one-click uninstall |
| **My Clutter** | MD5-based duplicate finder, large & old file detector |
| **Space Lens** | Interactive treemap visualizing every folder on your disk |
| **Cloud Cleanup** | Connects iCloud, Google Drive, OneDrive, Dropbox — scan & delete cloud files |
| **AI Assistant** | Real-time Mac health report with prioritized recommendations |

### Menu Bar App
- Live metrics popover (CPU · RAM · Disk · Battery · Network Up/Down)
- Background protection status indicator
- Quick-launch Smart Care and Scan from any app

### Real macOS System APIs
| Capability | API Used |
|------------|----------|
| CPU usage | `host_processor_info` |
| RAM usage | `host_statistics64` / `vm_statistics64` |
| Disk usage | `FileManager.attributesOfFileSystem` |
| Battery level | `IOKit` / `IOPSCopyPowerSourcesInfo` |
| Network I/O | `getifaddrs` / `AF_LINK` |
| Process list | `proc_listpids` / `proc_pidinfo` |
| File scanning | `FileManager.enumerator` |
| Duplicate detection | `CryptoKit` MD5 hashing |
| App uninstall | `FileManager.trashItem` + leftover search |
| DNS flush | `/usr/bin/dscacheutil` |
| Spotlight re-index | `/usr/bin/mdutil` |
| Open in Finder | `NSWorkspace.activateFileViewerSelecting` |

---

## Requirements

| Tool | Version |
|------|---------|
| macOS | 13 Ventura or later |
| Xcode | 15 or later |
| Swift | 5.9+ |

---

## Installation

### Clone the repo

```bash
git clone https://github.com/kechankrisna/CCMac.git
cd CCMac
```

### Open in Xcode

```bash
open Package.swift
```

Or: **File → Open…** → select the `CCMac/` folder → Xcode resolves the Swift Package automatically.

### Build & Run

1. Select the **CCMac** scheme
2. Set destination to **My Mac**
3. Press **⌘R**

---

## Xcode Project Settings

After opening, set these in **Build Settings** for full functionality:

| Setting | Value |
|---------|-------|
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.ccmac.app` |
| `INFOPLIST_FILE` | `Sources/CCMac/Resources/Info.plist` |

---

## Entitlements

Add to your `.entitlements` file:

```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.temporary-exception.files.absolute-path.read-write</key>
<array>
    <string>/Library/</string>
    <string>/var/log/</string>
</array>
```

For **Full Disk Access** (caches, logs, mail):
Go to **System Settings → Privacy & Security → Full Disk Access** → add the built app.

---

## Project Structure

```
CCMac/
├── Package.swift
└── Sources/CCMac/
    ├── App/
    │   ├── CCMacApp.swift          # @main entry + NSStatusItem menu bar
    │   └── ContentView.swift            # Root layout: sidebar + module switcher
    ├── DesignSystem/
    │   ├── AppColors.swift              # Full color palette with hex init
    │   └── AppTypography.swift          # Font scale, spacing & border radius tokens
    ├── Models/
    │   └── AppModels.swift              # All data models (FileItem, ThreatItem, etc.)
    ├── Services/
    │   ├── SystemMonitorService.swift   # CPU / RAM / Disk / Battery / Network / Processes
    │   ├── CleanupService.swift         # Filesystem scanner + file deletion
    │   ├── AppManagerService.swift      # App listing, leftover finder, uninstaller
    │   ├── DuplicateFinderService.swift # MD5 duplicate + large file detection
    │   ├── StorageService.swift         # Recursive disk tree for Space Lens
    │   └── MaintenanceService.swift     # DNS flush, maintenance scripts, Spotlight
    ├── Components/
    │   ├── SidebarView.swift            # 220px animated sidebar navigation
    │   └── SharedComponents.swift       # Buttons, progress rings, cards, sparklines
    ├── Modules/
    │   ├── SmartCare/SmartCareView.swift
    │   ├── Cleanup/CleanupView.swift
    │   ├── Protection/ProtectionView.swift
    │   ├── Performance/PerformanceView.swift
    │   ├── Applications/ApplicationsView.swift
    │   ├── MyClutter/MyClutterView.swift
    │   ├── SpaceLens/SpaceLensView.swift
    │   ├── CloudCleanup/CloudCleanupView.swift
    │   └── Assistant/AssistantView.swift
    ├── MenuBar/
    │   └── MenuBarView.swift            # 340×420px popover with live metrics
    └── Resources/
        └── Info.plist                   # Bundle ID + privacy descriptions
```

---

## Design System

Based on a custom Figma design guide — dark mode primary, light mode secondary.

| Token | Dark | Light |
|-------|------|-------|
| Background | `#0F1B26` | `#F0F4F8` |
| Surface | `#1C2E3E` | `#FFFFFF` |
| Brand Blue | `#1A6B9A` | `#1A6B9A` |
| Brand Green (CTA) | `#2E9C6A` | `#2E9C6A` |
| Danger Red | `#E05252` | `#E05252` |
| Text Primary | `#FFFFFF` | `#1A2B38` |
| Text Secondary | `#8BA8BE` | `#4A6A80` |

Typography: SF Pro Display / SF Pro Text (macOS system font) · 8px base grid · 24px gutter

---

## Notes

- **Malware detection** scans the filesystem but does not ship with a threat database. Integrate [ClamAV](https://www.clamav.net/) or a similar engine for real detection.
- **Cloud cleanup** UI is complete; OAuth tokens for Google Drive / OneDrive / Dropbox require registering your own API credentials.
- **Full Disk Access** must be granted in System Settings for scanning protected directories.
- Targets **macOS 13 Ventura** and is ready for **macOS Tahoe (macOS 26)**.

---

## Contributing

Pull requests are welcome! Please open an issue first to discuss what you'd like to change.

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m 'Add your feature'`
4. Push to the branch: `git push origin feature/your-feature`
5. Open a Pull Request

---

## Author

**KE CHANKRISNA**
ke.chankrisna168@gmail.com

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.
