# CCMac — Technical Reference

> **AI Developer Primer:** Read this document before making any code changes to CCMac. It covers the full architecture, every file's role, all patterns used, resolved bugs, design tokens, and a step-by-step guide to extending the app.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Tech Stack & Constraints](#2-tech-stack--constraints)
3. [Architecture](#3-architecture)
4. [File-by-File Reference](#4-file-by-file-reference)
5. [Service Layer API](#5-service-layer-api)
6. [Design System Tokens](#6-design-system-tokens)
7. [State Management Patterns](#7-state-management-patterns)
8. [Inter-Component Communication](#8-inter-component-communication)
9. [Build Pipeline](#9-build-pipeline)
10. [Resolved Bugs & Important Fixes](#10-resolved-bugs--important-fixes)
11. [Known Limitations](#11-known-limitations)
12. [How to Add a New Module](#12-how-to-add-a-new-module)
13. [How to Add a New Service](#13-how-to-add-a-new-service)
14. [Coding Conventions](#14-coding-conventions)

---

## 1. Project Overview

CCMac is a native macOS system cleaner app built with **Swift 5.9 / SwiftUI 5 / macOS 13+**. It is distributed as a Swift Package Manager (SPM) project (`Package.swift`). The app has a main window (sidebar + 9 module views) and a menu bar popover (live system metrics).

**Package name:** `CCMac`
**Bundle ID:** `com.ccmac.app`
**Minimum deployment:** macOS 13 Ventura
**Entry point:** `Sources/CCMac/App/CCMacApp.swift`
**Source root:** `Sources/CCMac/`

---

## 2. Tech Stack & Constraints

| Layer | Technology |
|-------|-----------|
| UI framework | SwiftUI 5 (`@StateObject`, `@ObservedObject`, `@Published`) |
| App lifecycle | `@main` struct conforming to `App`, `@NSApplicationDelegateAdaptor` |
| Concurrency | Swift `async/await`, `Task`, `@MainActor` |
| System APIs | `host_processor_info`, `host_statistics64`, `vm_statistics64`, IOKit, `getifaddrs`, `proc_listpids`, `proc_pidinfo` |
| File system | `FileManager.enumerator`, `FileManager.trashItem` |
| Crypto | `CryptoKit` (`Insecure.MD5`) for duplicate detection |
| Shell commands | `Foundation.Process` for maintenance tasks |
| Menu bar | `NSStatusItem` + `NSPopover` + `NSHostingController` |
| Build | Swift Package Manager (SPM) — **no Xcode project file** |
| Distribution | `build_dmg.sh` → `.app` bundle → `.icns` icon → DMG via `hdiutil` |

### SPM Package.swift notes

```swift
// Current Package.swift (simplified)
.executableTarget(
    name: "CCMac",
    path: "Sources/CCMac",
    exclude: ["Resources/Info.plist"],   // Info.plist excluded from resource processing
    resources: [.process("Resources")]   // Other resources bundled normally
)
```

- `Info.plist` is **excluded** from `.process("Resources")` because SPM forbids it as a top-level resource. It is copied into `CCMac.app/Contents/Info.plist` by `build_dmg.sh` instead.
- **No linker flags** for `-sectcreate` — removed because SPM passed it to `swiftc` directly, causing `error: unknown argument: '-sectcreate'`.

---

## 3. Architecture

### Layer Diagram

```
┌──────────────────────────────────────────────────────────┐
│  CCMacApp  (@main, App protocol)                         │
│  ├── AppDelegate (NSApplicationDelegate)                 │
│  │   ├── NSStatusItem → sparkles icon in menu bar        │
│  │   └── NSPopover → MenuBarPopoverView                  │
│  └── WindowGroup → ContentView                           │
│      └── HStack                                          │
│          ├── SidebarView (220 px)                        │
│          └── Module content (ZStack, switches on AppModule)│
└──────────────────────────────────────────────────────────┘

Module Views (9 total)
  Each module has its own ViewModel (@StateObject) which owns
  one or more Services (@StateObject / plain class)

Service Layer (6 services)
  All services are ObservableObject classes with @Published state.
  They call real macOS APIs on background threads and publish
  results back on MainActor.

NotificationCenter
  MenuBarView → ContentView: navigation (.navigateToSmartCare)
  MenuBarView → SmartCareView: trigger scan (.startSmartCareScan)
```

### Navigation Model

Navigation is a single `@State var selectedModule: AppModule` in `ContentView`. Switching modules destroys and re-creates the module view (due to `.id(selectedModule)` modifier), which resets local state cleanly.

```swift
// ContentView.swift
@State private var selectedModule: AppModule = .smartCare

ZStack {
    moduleView(for: selectedModule)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
        .id(selectedModule)   // force re-mount on switch
}
```

---

## 4. File-by-File Reference

### `App/CCMacApp.swift`

- `@main struct CCMacApp: App` — app entry point.
- `init()` — sets `NSWindow.allowsAutomaticWindowTabbing = false` **here**, not in `applicationDidFinishLaunching`. This must be the earliest possible call; if moved later, macOS logs `Cannot index window tabs due to missing main bundle identifier` when creating the first window.
- `AppDelegate.applicationDidFinishLaunching` — calls `setupMenuBarItem()` and `requestDiskAccess()`.
- `setupMenuBarItem()` — creates `NSStatusItem` with `sparkles` SF Symbol, sets up `NSPopover` hosting `MenuBarPopoverView`.
- `SettingsView` — tabbed settings window (General, Protection, Privacy tabs).

### `App/ContentView.swift`

- Root layout: `HStack { SidebarView | ZStack(moduleView) }`.
- `minWidth: 1060, minHeight: 700`.
- Listens for `NotificationCenter` notifications:
  - `.navigateToSmartCare` → sets `selectedModule = .smartCare`
  - `.startSmartCareScan` → sets `selectedModule = .smartCare` (SmartCareView picks up the scan trigger separately)

### `DesignSystem/AppColors.swift`

Defines `Color` extensions with hex initialiser and named semantic colours. Also defines `LinearGradient` static presets (`brandGradient`, `bgGradient`, `greenGlow`).

Key colours (hex):
- `bgDark`: `#0F1B26` — main background
- `bgDark2`: `#0A1520` — deeper background
- `surfaceDark`: `#1C2E3E` — card/panel surface
- `brandGreen`: `#2E9C6A` — primary CTA
- `brandBlue`: `#1A6B9A` — links, info
- `successGreen`: `#27AE60`
- `warningOrange`: `#E67E22`
- `dangerRed`: `#E05252`
- `infoBlue`: `#3498DB`
- `assistantPurple`: `#8E44AD`
- `textPrimary`: `#FFFFFF`
- `textSecondary`: `#8BA8BE`
- `textDisabled`: `#4A6A80`

### `DesignSystem/AppTypography.swift`

- `AppFont` struct — static `Font` values using SF Pro: `hero` (40 pt), `heading1` (28 pt), `heading2` (22 pt), `heading3` (18 pt), `bodyLarge` (16 pt), `bodyDefault` (14 pt), `bodySmall` (12 pt), `labelBadge` (11 pt), `mono` (13 pt monospaced), `numberHero` (48 pt bold).
- `AppSpacing` struct — spacing tokens: `micro` (2), `tiny` (4), `base` (8), `compact` (12), `standard` (16), `relaxed` (20), `section` (24), `large` (32), `hero` (48).
- `AppRadius` struct — corner radius tokens: `tiny` (4), `small` (6), `medium` (10), `large` (14), `xLarge` (20), `full` (9999).

### `Models/AppModels.swift`

Contains all shared data models:

| Type | Description |
|------|-------------|
| `AppModule` | Enum (9 cases): `.smartCare`, `.cleanup`, `.protection`, `.performance`, `.applications`, `.myClutter`, `.spaceLens`, `.cloudCleanup`, `.assistant`. Each case has `.icon` (SF Symbol) and `.accentColor`. |
| `ScanCategory` | Represents one cleanup category (name, icon, files, totalSize, isSelected). |
| `FileItem` | A scannable file (path, name, size, isSelected, date). |
| `ThreatItem` | A detected threat (name, path, severity: `ThreatSeverity`). |
| `ThreatSeverity` | Enum: `.critical`, `.high`, `.medium`, `.low`. Has `.color` property. |
| `AppInfo` | Installed app info (name, path, size, bundleID, version, icon). |
| `SystemMetrics` | Current system snapshot (cpuUsage, ramUsed, ramTotal, diskFree, diskTotal, batteryLevel, networkDown, networkUp, processes). Has computed string properties. |
| `DiskItem` | Observable class for treemap nodes (name, path, size, children, color). |
| `CloudService` | Cloud service model (name, icon, isConnected, storageUsed, storageTotal). |
| `HealthReport` | AI health report (score, categories: [HealthRecommendation]). |
| `HealthRecommendation` | Individual recommendation (title, description, priority, actionLabel). |
| `Notification.Name` extensions | `.navigateToSmartCare`, `.startSmartCareScan` — used for menu bar → main window communication. |

### `Services/SystemMonitorService.swift`

`@MainActor` `ObservableObject`. Publishes `@Published var metrics: SystemMetrics`.

**Timer:** 2-second `Timer.publish` loop calls `updateMetrics()`.

**APIs used:**

| Metric | Implementation |
|--------|---------------|
| CPU | `host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, ...)` — computes usage from tick deltas |
| RAM | `host_statistics64(mach_host_self(), HOST_VM_INFO64, ...)` → `vm_statistics64` |
| Disk | `FileManager.default.attributesOfFileSystem(forPath: "/")` |
| Battery | `IOPSCopyPowerSourcesInfo()` + `IOPSGetPowerSourceDescription()` |
| Network | `getifaddrs()` iterating `AF_LINK` interfaces, reading `if_data.ifi_ibytes/ifi_obytes` deltas |
| Processes | `proc_listpids(PROC_ALL_PIDS, 0, ...)` + `proc_pidinfo(..., PROC_PIDPATHINFO, ...)` with `pathBufSize = 4096` (literal, replaces unavailable `PROC_PIDPATHINFO_MAXSIZE`) |

**Important:** `PROC_PIDPATHINFO_MAXSIZE` is not available in Swift SPM targets — use literal `4096`.

### `Services/CleanupService.swift`

Scans 7 categories using `FileManager.default.enumerator(at:)`:

| Category | Path |
|----------|------|
| System Caches | `~/Library/Caches` |
| System Logs | `~/Library/Logs` |
| Mail Downloads | `~/Library/Mail Downloads` |
| Language Files | `.lproj` bundles in `/Library/` |
| Trash | `~/.Trash` |
| Xcode DerivedData | `~/Library/Developer/Xcode/DerivedData` |
| iOS Device Backups | `~/Library/Application Support/MobileSync/Backup` |

`deleteFiles(_ files: [FileItem]) async -> (count: Int, freed: Int64)` — uses `FileManager.trashItem` (moves to Trash, recoverable).

`findLeftovers(for app: AppInfo) async -> [FileItem]` — searches `~/Library/Application Support`, `~/Library/Preferences`, `~/Library/Caches` for files matching the app's bundle ID or name.

### `Services/AppManagerService.swift`

Scans `/Applications` and `~/Applications`. For each app:
- Reads `Info.plist` for bundleID and version.
- Measures app size recursively.
- Loads icon via `NSWorkspace.shared.icon(forFile:)`.

`uninstall(_ app: AppInfo) async` — calls `FileManager.trashItem` + `findLeftovers`.
`forceQuit(pid: Int32)` — calls `kill(pid, SIGKILL)`.

### `Services/DuplicateFinderService.swift`

`findDuplicates(in path: String) async -> [[FileItem]]` — uses `CryptoKit.Insecure.MD5` to hash file contents and groups matches.

`findLargeFiles(in path: String, minSize: Int64 = 50_000_000) async -> [FileItem]` — finds files larger than `minSize` bytes (default 50 MB).

### `Services/StorageService.swift`

`buildTree(path: String) async -> DiskItem` — recursively traverses directory up to `maxDepth: 3`, creating a tree of `DiskItem` nodes. Colors are assigned by hashing the path.

Used by `SpaceLensView` for the treemap visualization.

### `Services/MaintenanceService.swift`

Five tasks, each runs via `Foundation.Process`:

| Task | Command |
|------|---------|
| Flush DNS | `/usr/bin/dscacheutil -flushcache` + `/usr/bin/killall -HUP mDNSResponder` |
| Run maintenance scripts | `/usr/sbin/periodic daily weekly monthly` |
| Rebuild Spotlight | `/usr/bin/mdutil -E /` |
| Rebuild Mail index | removes `~/Library/Mail/V9/MailData/Envelope Index` |

### `Components/SidebarView.swift`

220 px fixed-width sidebar. Each `SidebarItem` shows module icon + label. Active item has a 3 px left border in the module's `accentColor` and a highlighted background. Hover state uses `onHover`. Bottom bar shows user info.

### `Components/SharedComponents.swift`

Reusable primitives used across all modules:

| Component | Description |
|-----------|-------------|
| `ModuleHeaderView` | Top bar with module icon, title, subtitle, optional action button |
| `CMButton` | Styled button: `.primary`, `.secondary`, `.destructive` styles |
| `CircularProgressView` | Animated ring progress indicator with center content slot |
| `CMProgressBar` | Linear progress bar. Uses `AnyShapeStyle` to resolve ternary between `Color` and `LinearGradient` (critical — see §10) |
| `ThreatBadge` | Coloured severity pill |
| `MetricWidget` | Icon + value + label card |
| `SparklineView` | Canvas-based line chart. Uses `maxVal` + `Swift.max()` to avoid shadowing `max()` builtin (critical — see §10) |
| `FileListRow` | File item row with size badge and checkbox |
| `ScanResultCard` | Category scan result card with toggle |
| `HealthScoreRing` | Animated score ring (0–100) |
| `EmptyStateView` | Icon + title + subtitle placeholder |
| `SectionHeader` | Bold section title with optional action |

### `Modules/SmartCare/SmartCareView.swift`

State machine: `ScanState { idle, scanning, results, cleaning, complete }`.

- `idle` → `SmartCareIdleView` (health ring + Run Smart Care button)
- `scanning` → `SmartCareScanningView` (circular progress + cancel)
- `results` → `SmartCareResultsView` (grid of `ScanResultCard` + clean button)
- `cleaning` → `SmartCareCleaningView` (overlay progress)
- `complete` → `SmartCareCompleteView` (celebration + stats)

Listens for `.startSmartCareScan` notification → calls `vm.startScan()` if currently idle.

### `Modules/Cleanup/CleanupView.swift`

Split panel: category list (left) + file list (right). Separate scan and results state from Smart Care — operates independently on the same `CleanupService`.

### `Modules/Protection/ProtectionView.swift`

Scan type picker (Quick / Normal / Deep). Quarantine moves files to `~/Library/Application Support/CCMac/Quarantine`. App permissions shown in `DisclosureGroup` per app. Browser privacy section clears cookies/history paths.

### `Modules/Performance/PerformanceView.swift`

Live metric widgets update via `SystemMonitorService` timer. Process table shows `proc_listpids` results. Force quit calls `kill(proc.id, SIGKILL)` — **directly on the service's process list**, not via `AppManagerService.forceQuit` (historical bug fix — see §10). Maintenance task rows call `MaintenanceService`. `RAMFreedOverlay` sheet shown after freeing RAM.

### `Modules/Applications/ApplicationsView.swift`

Tab view: Installed / Updater. Search bar + filter chips. `AppRow` expands to show leftover files. `UninstallModalView` sheet confirms before trashing.

### `Modules/MyClutter/MyClutterView.swift`

`ClutterCard` overview. `DuplicatesListView` groups files by hash — select all but one in each group. `LargeFilesView` shows files sorted by size.

### `Modules/SpaceLens/SpaceLensView.swift`

Breadcrumb navigation + `TreemapView` using `Canvas`/`GraphicsContext`. `drawTreemap()` calculates proportional rectangles recursively. Text drawing in Canvas uses plain `Text(string).font(...).foregroundColor(...)` — **no `AttributedString`, no `.lineLimit()`** (historical bug fix — see §10). `SpaceLensDetailPanel` slides in from trailing edge.

### `Modules/CloudCleanup/CloudCleanupView.swift`

`CloudServiceCard` for each provider (iCloud, Google Drive, OneDrive, Dropbox). 3-state per card: disconnected / connected / scanning. Requires OAuth tokens from developer for live cloud access.

### `Modules/Assistant/AssistantView.swift`

Reads real disk and RAM data to generate a `HealthReport`. `HealthCategoryCard` and `RecommendationCard` display findings. `SmartInsightsPanel` slides in with Apple Intelligence–style badge.

### `MenuBar/MenuBarView.swift`

`MenuBarPopoverView` (340×420 px):
- Header: Mac Health label + status
- 2×3 `LazyVGrid`: CPU, RAM, Disk, Battery, Down, Up metric cells
- Protection status row
- **Smart Care button** → `openMainWindow()` + posts `.navigateToSmartCare`
- **Scan Now button** → `openMainWindow()` + posts `.startSmartCareScan`
- **Open CCMac button** → `openMainWindow()`

`openMainWindow()` helper:
```swift
NSApp.activate(ignoringOtherApps: true)
NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
```

### `Resources/Info.plist`

| Key | Value |
|-----|-------|
| `CFBundleIdentifier` | `com.ccmac.app` |
| `CFBundleName` | `CCMac` |
| `CFBundleExecutable` | `CCMac` |
| `LSMinimumSystemVersion` | `13.0` |
| `NSDesktopFolderUsageDescription` | Scan and clean Desktop files |
| `NSDocumentsFolderUsageDescription` | Scan Documents folder |
| `NSDownloadsFolderUsageDescription` | Find duplicates and large files in Downloads |

### `Resources/AppIcon.png`

1024×1024 source icon. Dark navy background, green 4-point sparkle star, accent sparkles, "CCMac" and "Mac System Cleaner" text. `build_dmg.sh` converts this to `AppIcon.icns` using `sips` + `iconutil`. **Replace this PNG to customise the app icon.**

---

## 5. Service Layer API

### SystemMonitorService

```swift
class SystemMonitorService: ObservableObject {
    @Published var metrics: SystemMetrics
    @Published var processes: [ProcessInfo]

    func startMonitoring()   // starts 2s Timer
    func stopMonitoring()    // invalidates Timer
}
```

### CleanupService

```swift
class CleanupService {
    func scanCategories(
        progress: @escaping (Double, String) -> Void
    ) async -> [ScanCategory]

    func deleteFiles(
        _ files: [FileItem],
        progress: @escaping (Double, String) -> Void
    ) async -> (count: Int, freed: Int64)

    func findLeftovers(for app: AppInfo) async -> [FileItem]
}
```

### AppManagerService

```swift
class AppManagerService: ObservableObject {
    @Published var apps: [AppInfo]

    func loadApps() async
    func uninstall(_ app: AppInfo) async
    func forceQuit(pid: Int32)
}
```

### DuplicateFinderService

```swift
class DuplicateFinderService: ObservableObject {
    @Published var duplicateGroups: [[FileItem]]
    @Published var largeFiles: [FileItem]

    func findDuplicates(in path: String) async
    func findLargeFiles(in path: String, minSize: Int64 = 50_000_000) async
}
```

### StorageService

```swift
class StorageService: ObservableObject {
    @Published var rootItem: DiskItem?
    @Published var isScanning: Bool

    func buildTree(path: String) async
}
```

### MaintenanceService

```swift
class MaintenanceService: ObservableObject {
    @Published var tasks: [MaintenanceTask]

    func runTask(_ task: MaintenanceTask) async
}
```

---

## 6. Design System Tokens

### Colors (`AppColors.swift`)

```swift
Color.bgDark          // #0F1B26  Main window bg
Color.bgDark2         // #0A1520  Deeper bg
Color.surfaceDark     // #1C2E3E  Card/panel surface
Color.brandGreen      // #2E9C6A  Primary CTA
Color.brandBlue       // #1A6B9A  Links, info
Color.successGreen    // #27AE60  Success states
Color.warningOrange   // #E67E22  Warnings
Color.dangerRed       // #E05252  Errors, threats
Color.infoBlue        // #3498DB  Info accents
Color.assistantPurple // #8E44AD  AI assistant
Color.textPrimary     // #FFFFFF
Color.textSecondary   // #8BA8BE
Color.textDisabled    // #4A6A80
```

### Gradients

```swift
LinearGradient.brandGradient   // brandGreen → brandBlue (135°)
LinearGradient.bgGradient      // bgDark2 → bgDark (180°)
LinearGradient.greenGlow       // brandGreen.opacity(0.3) → clear (90°)
```

### Typography (`AppTypography.swift`)

```swift
AppFont.hero          // 40 pt bold
AppFont.heading1      // 28 pt bold
AppFont.heading2      // 22 pt semibold
AppFont.heading3      // 18 pt semibold
AppFont.bodyLarge     // 16 pt regular
AppFont.bodyDefault   // 14 pt regular
AppFont.bodySmall     // 12 pt regular
AppFont.labelBadge    // 11 pt medium
AppFont.mono          // 13 pt monospaced
AppFont.numberHero    // 48 pt bold
```

### Spacing (`AppTypography.swift`)

```swift
AppSpacing.micro      // 2
AppSpacing.tiny       // 4
AppSpacing.base       // 8
AppSpacing.compact    // 12
AppSpacing.standard   // 16
AppSpacing.relaxed    // 20
AppSpacing.section    // 24
AppSpacing.large      // 32
AppSpacing.hero       // 48
```

### Corner Radius (`AppTypography.swift`)

```swift
AppRadius.tiny        // 4
AppRadius.small       // 6
AppRadius.medium      // 10
AppRadius.large       // 14
AppRadius.xLarge      // 20
AppRadius.full        // 9999 (pill)
```

---

## 7. State Management Patterns

### Module ViewModel Pattern

Each module uses a `@MainActor` `ObservableObject` ViewModel owned by the module view as `@StateObject`:

```swift
@MainActor
class SmartCareViewModel: ObservableObject {
    @Published var state: ScanState = .idle
    @Published var scanProgress: Double = 0

    func startScan() {
        state = .scanning
        Task {
            let results = await cleanupService.scanCategories { prog, msg in
                Task { @MainActor in
                    self.scanProgress = prog
                    self.scanMessage = msg
                }
            }
            scanCategories = results
            state = .results
        }
    }
}
```

### Async/Await Pattern

Services perform work off the main thread and publish results via `@MainActor`:

```swift
// In service:
func scanCategories(...) async -> [ScanCategory] {
    // heavy work here (background thread)
    return results
}

// In ViewModel:
Task {
    let results = await service.scanCategories(...)
    // Task body runs on @MainActor (ViewModel is @MainActor)
    self.scanCategories = results
    self.state = .results
}
```

### Timer-Based Monitoring

`SystemMonitorService` uses a Combine `Timer.publish` to poll every 2 seconds:

```swift
Timer.publish(every: 2, on: .main, in: .common)
    .autoconnect()
    .sink { [weak self] _ in self?.updateMetrics() }
    .store(in: &cancellables)
```

---

## 8. Inter-Component Communication

### NotificationCenter (Menu Bar → Main Window)

Defined in `Models/AppModels.swift`:

```swift
extension Notification.Name {
    static let navigateToSmartCare = Notification.Name("com.ccmac.navigateToSmartCare")
    static let startSmartCareScan  = Notification.Name("com.ccmac.startSmartCareScan")
}
```

**Flow:**
1. User taps **Smart Care** or **Scan Now** in `MenuBarPopoverView`
2. `MenuBarView` calls `openMainWindow()` and posts notification
3. `ContentView` receives `.navigateToSmartCare` / `.startSmartCareScan` → sets `selectedModule = .smartCare`
4. `SmartCareView` receives `.startSmartCareScan` → calls `vm.startScan()` if state is `.idle`

Add new notifications by extending `Notification.Name` in `AppModels.swift`.

---

## 9. Build Pipeline

### Development (debug)

```bash
swift build
.build/debug/CCMac
```

### Release DMG

```bash
bash build_dmg.sh
```

Script steps:
1. `swift build -c release`
2. Creates `AppIcon.iconset/` with all 10 sizes using `sips -z`
3. `iconutil --convert icns` → `AppIcon.icns`
4. Assembles `CCMac.app/Contents/` structure:
   - `MacOS/CCMac` — binary
   - `Info.plist` — with `CFBundleIconFile = AppIcon` injected via `PlistBuddy`
   - `Resources/AppIcon.icns` — icon
5. `codesign --force --deep --sign - --identifier com.ccmac.app --options runtime CCMac.app`
6. `codesign --verify --verbose`
7. Creates DMG: staging folder + `/Applications` symlink → `hdiutil create -format UDZO`

### To customise the app icon

Replace `Sources/CCMac/Resources/AppIcon.png` with any 1024×1024 PNG, then re-run `bash build_dmg.sh`.

---

## 10. Resolved Bugs & Important Fixes

These bugs were encountered and resolved during development. **Do not revert these fixes.**

### Bug 1 — `SharedComponents.swift`: Type mismatch in ternary

**Error:** `Result values in '? :' expression have mismatching types 'Color' and 'LinearGradient'`

**Location:** `CMProgressBar` fill modifier.

**Fix:** Wrap both sides in `AnyShapeStyle(...)`:
```swift
.fill(isError
    ? AnyShapeStyle(Color.dangerRed)
    : AnyShapeStyle(LinearGradient.brandGradient))
```

**Why:** SwiftUI's `ShapeStyle` ternary requires both branches to have identical concrete types. `AnyShapeStyle` is the correct type-erasure wrapper.

---

### Bug 2 — `SharedComponents.swift`: Local variable shadows `max()` builtin

**Error:** `Cannot call value of non-function type 'Double'`

**Location:** `SparklineView`, `let max = data.max() ?? 1`.

**Fix:**
```swift
let maxVal = data.max() ?? 1          // renamed to maxVal
let count = Swift.max(data.count - 1, 1)  // qualified name
```

**Why:** `let max` shadowed the global `max()` function. Use a distinct name or `Swift.max()`.

---

### Bug 3 — `SystemMonitorService.swift`: `PROC_PIDPATHINFO_MAXSIZE` unavailable

**Error:** `Cannot find 'PROC_PIDPATHINFO_MAXSIZE' in scope`

**Fix:** Replace with literal `let pathBufSize = 4096`.

**Why:** The constant is defined in a C header not imported by Swift in SPM context.

---

### Bug 4 — `SpaceLensView.swift`: `GraphicsContext.draw` type mismatch

**Error:** `No exact matches in call to instance method 'draw'`

**Location:** Canvas text drawing in `TreemapView`.

**Fix:** Use plain `Text(string)` with view modifiers. Do **not** use `AttributedString` in `GraphicsContext.draw`. Do **not** apply `.lineLimit()` before passing to Canvas (returns `some View`, not `Text`):
```swift
// WRONG
context.draw(Text(AttributedString(...)).lineLimit(1), at: ...)
// CORRECT
context.draw(Text(string).font(.caption).foregroundColor(.white), at: ...)
```

---

### Bug 5 — `PerformanceView.swift`: `forceQuit` on wrong service

**Error:** `Value of type 'SystemMonitorService' has no dynamic member 'forceQuit'`

**Fix:** Call `kill(proc.id, SIGKILL)` directly — `forceQuit(pid:)` lives on `AppManagerService`, not `SystemMonitorService`:
```swift
// WRONG
monitor.forceQuit(pid: proc.id)
// CORRECT
kill(proc.id, SIGKILL)
```

---

### Bug 6 — Runtime: `No symbol named 'battery.100.fill'`

**Fix:** Change to `battery.100` (no `.fill` variant on macOS 13).

**Locations:** `PerformanceView.swift`, `MenuBarView.swift`.

---

### Bug 7 — Runtime crash: `UnsafeRawBufferPointer.load out of bounds`

**Location:** `getNetworkUsage()` in `SystemMonitorService.swift`.

**Root cause:** Original implementation used `sysctl` + `if_msghdr`/`if_msghdr2` raw pointer arithmetic without bounds checking.

**Fix:** Rewrote using `getifaddrs()`:
```swift
var ifaddrPtr: UnsafeMutablePointer<ifaddrs>? = nil
guard getifaddrs(&ifaddrPtr) == 0 else { return (0, 0) }
defer { freeifaddrs(ifaddrPtr) }
// Iterate AF_LINK interfaces, read if_data.ifi_ibytes/ifi_obytes
```

---

### Bug 8 — Runtime: `Cannot index window tabs due to missing main bundle identifier`

**Root cause:** `NSWindow.allowsAutomaticWindowTabbing` must be disabled before SwiftUI creates the first window. Setting it in `applicationDidFinishLaunching` or `AppDelegate.init()` is too late.

**Fix:** Set in `CCMacApp.init()`:
```swift
@main struct CCMacApp: App {
    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
}
```

---

### Bug 9 — SPM build: `error: unknown argument: '-sectcreate'`

**Root cause:** `linkerSettings: [.unsafeFlags(["-sectcreate", ...])]` passes flags directly to `swiftc`, which doesn't understand `ld` flags.

**Fix:** Remove the `linkerSettings` block entirely from `Package.swift`. `Info.plist` is handled by `build_dmg.sh` copying it into the `.app` bundle, not by embedding in the binary.

---

### Bug 10 — SPM build: `resource 'Resources/Info.plist' is forbidden`

**Root cause:** SPM forbids `Info.plist` as a top-level bundled resource.

**Fix:** Add `exclude: ["Resources/Info.plist"]` to the target in `Package.swift`.

---

## 11. Known Limitations

| Feature | Current State | Path to Production |
|---------|--------------|-------------------|
| Malware detection | Scans filesystem, no threat DB | Integrate ClamAV or VirusTotal API |
| Cloud cleanup | UI complete, no real OAuth | Register Google/Microsoft/Dropbox API credentials |
| Full Disk Access | User must grant manually | Cannot be automated — guide user to System Settings |
| Code signing | Ad-hoc (`--sign -`) | Enroll in Apple Developer Program for notarisation |
| Start at Login | UI toggle exists, not wired | Use `ServiceManagement.framework` |
| Scheduled scans | Not implemented | Use `LaunchAgent` plist in `~/Library/LaunchAgents` |
| Light mode | `preferredColorScheme(.dark)` forced | Remove the modifier to enable adaptive mode |
| Localization | English only | Add `.lproj` folders and `NSLocalizedString` |

---

## 12. How to Add a New Module

### Step 1 — Add the case to `AppModule`

In `Models/AppModels.swift`:
```swift
enum AppModule: String, CaseIterable, Identifiable {
    // existing cases...
    case myNewModule
}

extension AppModule {
    var icon: String {
        switch self {
        case .myNewModule: return "star.fill"  // SF Symbol
        // ...
        }
    }
    var accentColor: Color {
        switch self {
        case .myNewModule: return .brandBlue
        // ...
        }
    }
}
```

### Step 2 — Create the module view

Create `Sources/CCMac/Modules/MyNewModule/MyNewModuleView.swift`:
```swift
import SwiftUI

@MainActor
class MyNewModuleViewModel: ObservableObject {
    @Published var isLoading = false
    // Add your state here

    func load() {
        Task {
            isLoading = true
            // do work
            isLoading = false
        }
    }
}

struct MyNewModuleView: View {
    @StateObject private var vm = MyNewModuleViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ModuleHeaderView(
                module: .myNewModule,
                subtitle: "Description of this module",
                actionLabel: "Run",
                isScanning: vm.isLoading,
                onAction: { vm.load() }
            )
            // Module content here
        }
        .background(Color.bgDark)
    }
}
```

### Step 3 — Wire into `ContentView`

In `App/ContentView.swift`, add a case to `moduleView(for:)`:
```swift
case .myNewModule: MyNewModuleView()
```

That's it — the sidebar entry is generated automatically from `AppModule.allCases`.

---

## 13. How to Add a New Service

```swift
// Sources/CCMac/Services/MyNewService.swift
import Foundation

class MyNewService: ObservableObject {
    @Published var results: [SomeModel] = []

    func doWork() async {
        // heavy work (runs off main thread if called with Task from @MainActor VM)
        let data = await fetchData()
        await MainActor.run {
            self.results = data
        }
    }

    private func fetchData() async -> [SomeModel] {
        // implementation
        return []
    }
}
```

Inject it into the ViewModel that needs it:
```swift
class MyModuleViewModel: ObservableObject {
    private let myService = MyNewService()
    // use myService.doWork()
}
```

---

## 14. Coding Conventions

- **All ViewModels** are `@MainActor class ... : ObservableObject`
- **Services** are plain classes with `@Published` state; update on `MainActor` when publishing
- **Async work** always uses Swift `async/await` inside `Task {}`; never use `DispatchQueue` directly
- **Colors** always use `Color.tokenName` (never literal hex in views)
- **Fonts** always use `AppFont.scale` (never `.font(.system(size: N))` in views)
- **Spacing** always use `AppSpacing.token` or `AppRadius.token`
- **Destructive actions** use `CMButton(..., style: .destructive)` and confirm with a sheet
- **SF Symbols** — check availability for macOS 13 before use (e.g. `battery.100.fill` does not exist, use `battery.100`)
- **No force unwrap** (`!`) in production code — use `guard let` or `if let`
- **Notification names** are defined in `AppModels.swift` extension, prefixed with `com.ccmac.`
- **File headers** use `// MARK: - SectionName` for major sections within a file
