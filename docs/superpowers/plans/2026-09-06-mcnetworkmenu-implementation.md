# McNetworkMenu Swift CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and package a native macOS 14+ menu-bar utility entirely with Swift Package Manager and Make, using mock-driven tests for all network behavior.

**Architecture:** A SwiftUI executable target provides `MenuBarExtra(.window)` while an importable `McNetworkMenuCore` target owns domain state, Apple-framework adapters, and the main-actor view model. Make wraps SwiftPM, assembles the standard `.app` directory, copies bundle metadata, signs it, and verifies the result without an Xcode project.

**Tech Stack:** Swift 5.9 package manifest, SwiftUI, Network, CoreWLAN, CoreLocation, ServiceManagement, AppKit, XCTest, Swift 6.2 CLI toolchain, GNU Make, macOS 14 deployment target.

**Spec:** `docs/superpowers/specs/2026-09-06-mcnetworkmenu-design.md`

## Global Constraints

- Product name: `McNetworkMenu`.
- Bundle identifier: `com.prakharpal.McNetworkMenu`.
- Deployment target: macOS 14 Sonoma or newer.
- Use Swift Package Manager and Make only; do not create or require an `.xcodeproj`.
- Use only Apple public APIs and no third-party runtime or build dependencies.
- Local bundles use ad-hoc signing by default; `SIGNING_IDENTITY` may select a local self-signed certificate.
- Keep the application menu-bar-only with `LSUIElement` set to `true`.
- Use `wifi` for Wi-Fi primary, `network` for Ethernet primary, and `network.slash` for offline.
- Keep the menu-bar item icon-only; do not add throughput text.
- Never persist or log Wi-Fi passwords.
- Request location permission only when named Wi-Fi scanning is first requested.
- Do not use private Continuity/Instant Hotspot APIs.
- Automated acceptance uses mock/fake network data only for this iteration.
- Document real-hardware checks, but do not execute or claim them.
- Run `make check` before declaring implementation complete.

---

## File Map

| Path | Responsibility |
|---|---|
| `Package.swift` | Executable, core library, test targets, platform floor, Apple-framework linking |
| `Makefile` | Build, test, bundle, sign, run, clean, release, and verify lifecycle |
| `Support/Info.plist` | Bundle identity, executable, menu-bar agent, version, and location usage text |
| `Sources/McNetworkMenu/App/McNetworkMenuApp.swift` | App entry point and live dependency composition |
| `Sources/McNetworkMenu/Views/*.swift` | SwiftUI adaptive panel components |
| `Sources/McNetworkMenuCore/Models/*.swift` | Framework-neutral route, Wi-Fi, and operation state |
| `Sources/McNetworkMenuCore/Services/ServiceProtocols.swift` | Narrow service contracts consumed by the view model |
| `Sources/McNetworkMenuCore/Services/AppleNetworkPathMonitor.swift` | `NWPathMonitor` and IPv4 adapter |
| `Sources/McNetworkMenuCore/Services/CoreWLANController.swift` | CoreWLAN power, scan, association, and disassociation adapter |
| `Sources/McNetworkMenuCore/Services/AppleLocationAuthorizer.swift` | Just-in-time CoreLocation authorization |
| `Sources/McNetworkMenuCore/Services/AppleLaunchAtLoginController.swift` | `SMAppService.mainApp` adapter |
| `Sources/McNetworkMenuCore/Services/AppleSystemActions.swift` | System Settings, About, and Quit actions |
| `Sources/McNetworkMenuCore/ViewModels/NetworkMenuModel.swift` | Main-actor application state machine |
| `Tests/McNetworkMenuCoreTests/**/*Tests.swift` | Mock-driven domain, mapping, and state tests |
| `Tests/McNetworkMenuCoreTests/TestSupport/Fakes.swift` | Deterministic protocol fakes |
| `docs/smoke-tests.md` | Deferred real-hardware verification checklist |
| `README.md` | Requirements, Make commands, permissions, signing, installation, and limits |

---

### Task 1: Create the Swift package, app shell, bundle metadata, and Make lifecycle

**Files:**
- Create: `Package.swift`
- Create: `Makefile`
- Create: `Support/Info.plist`
- Create: `Sources/McNetworkMenu/App/McNetworkMenuApp.swift`
- Create: `Sources/McNetworkMenu/Views/MenuPanelView.swift`
- Create: `Sources/McNetworkMenuCore/McNetworkMenuCore.swift`

**Interfaces:**
- Consumes: installed Swift CLI, Make, `plutil`, and `codesign`.
- Produces: executable product `McNetworkMenu`, importable library `McNetworkMenuCore`, and Make targets `build`, `test`, `clean`, `run`, `release`, `bundle`, `verify`, and `check`.

- [ ] **Step 1: Add the package manifest**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "McNetworkMenu",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "McNetworkMenu", targets: ["McNetworkMenu"])],
    targets: [
        .target(
            name: "McNetworkMenuCore",
            linkerSettings: [
                .linkedFramework("Network"), .linkedFramework("CoreWLAN"),
                .linkedFramework("CoreLocation"), .linkedFramework("ServiceManagement"),
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "McNetworkMenu", dependencies: ["McNetworkMenuCore"],
            linkerSettings: [.linkedFramework("SwiftUI"), .linkedFramework("AppKit")]
        ),
        .testTarget(name: "McNetworkMenuCoreTests", dependencies: ["McNetworkMenuCore"])
    ]
)
```

- [ ] **Step 2: Add the smallest compileable targets**

`McNetworkMenuCore.swift` contains `public enum McNetworkMenuCoreVersion { public static let current = 1 }`. The executable defines `McNetworkMenuApp` with a `MenuBarExtra("McNetworkMenu", systemImage: "network.slash")`, `.menuBarExtraStyle(.window)`, and `MenuPanelView`. The initial build-verification panel renders `Text("McNetworkMenu")` in a `340 x 160` frame and is replaced by Task 8.

- [ ] **Step 3: Add exact bundle metadata**

Create an XML plist containing:

```text
CFBundleExecutable = McNetworkMenu
CFBundleIdentifier = com.prakharpal.McNetworkMenu
CFBundleName = McNetworkMenu
CFBundleDisplayName = McNetworkMenu
CFBundlePackageType = APPL
CFBundleShortVersionString = 0.1.0
CFBundleVersion = 1
LSMinimumSystemVersion = 14.0
LSUIElement = true
NSLocationWhenInUseUsageDescription = "McNetworkMenu uses location permission only to display the names of nearby Wi-Fi networks."
NSHighResolutionCapable = true
```

- [ ] **Step 4: Add the Make lifecycle**

Use `.build/apps/$(CONFIGURATION)/McNetworkMenu.app` and `swift build --configuration $(CONFIGURATION) --show-bin-path` to locate the binary. Set `SIGNING_IDENTITY ?= -`. `build` invokes `bundle CONFIGURATION=debug`; `test` invokes `swift test`; `clean` invokes `swift package clean`; `run` opens the Debug bundle; `release` invokes `bundle CONFIGURATION=release`; `check` invokes `test` then `release`.

The `bundle` recipe must compile, recreate only its resolved `.app` directory, install the executable at `Contents/MacOS/McNetworkMenu`, install the plist at `Contents/Info.plist`, ad-hoc/self-sign the bundle, and call `verify`. `verify` runs `plutil -lint`, checks the executable bit, and runs `codesign --verify --deep --strict`.

- [ ] **Step 5: Verify package, bundle, and metadata**

Run: `make build`

Expected: exit 0, Swift build completes, Debug `.app` exists, `plutil` reports `OK`, and signature verification exits 0.

Run: `/usr/libexec/PlistBuddy -c 'Print :LSUIElement' .build/apps/debug/McNetworkMenu.app/Contents/Info.plist`

Expected: `true`.

Run: `/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' .build/apps/debug/McNetworkMenu.app/Contents/Info.plist`

Expected: `com.prakharpal.McNetworkMenu`.

- [ ] **Step 6: Commit the CLI build skeleton**

```bash
git add Package.swift Makefile Support Sources/McNetworkMenu Sources/McNetworkMenuCore/McNetworkMenuCore.swift
git commit -m "build: scaffold Swift CLI menu app"
```

---

### Task 2: Resolve Wi-Fi, Ethernet, and offline primary routes

**Files:**
- Delete: `Sources/McNetworkMenuCore/McNetworkMenuCore.swift`
- Create: `Sources/McNetworkMenuCore/Models/PrimaryInterface.swift`
- Create: `Sources/McNetworkMenuCore/Models/NetworkPathSnapshot.swift`
- Create: `Tests/McNetworkMenuCoreTests/Models/PrimaryInterfaceResolverTests.swift`

**Interfaces:**
- Produces: public `NetworkPathSnapshot`, `PathInterface`, `NetworkInterfaceKind`, `PrimaryInterface`, and `PrimaryInterfaceResolver.resolve(_:)`.

- [ ] **Step 1: Write tests that fail because route types do not exist**

Test: satisfied `[ethernet en7, wifi en0]` resolves to Ethernet `en7`; satisfied `[wifi en0, ethernet en7]` resolves to Wi-Fi `en0`; unsatisfied and unknown-only paths resolve offline; and the three states expose `network`, `wifi`, and `network.slash` plus explicit accessibility labels.

- [ ] **Step 2: Verify RED**

Run: `swift test --filter PrimaryInterfaceResolverTests`

Expected: compilation FAILS because `PrimaryInterfaceResolver` is unavailable.

- [ ] **Step 3: Implement minimal route values and ordered resolution**

`NetworkPathSnapshot` contains `isSatisfied` and ordered `[PathInterface]`. Each interface contains BSD name, kind (`wifi`, `ethernet`, or `other`), and optional IPv4 address. Resolution returns the first Wi-Fi or Ethernet entry only when satisfied.

```swift
public enum PrimaryInterface: Equatable, Sendable {
    case wifi(interfaceName: String, ssid: String?, ipv4Address: String?)
    case ethernet(name: String, ipv4Address: String?)
    case offline
}
```

- [ ] **Step 4: Verify GREEN and commit**

Run: `swift test --filter PrimaryInterfaceResolverTests`

Expected: focused tests PASS.

Run: `swift test`

Expected: complete suite PASS.

```bash
git add Sources/McNetworkMenuCore Tests/McNetworkMenuCoreTests/Models/PrimaryInterfaceResolverTests.swift
git commit -m "feat: resolve primary network interface"
```

---

### Task 3: Model, deduplicate, group, and sort Wi-Fi networks

**Files:**
- Create: `Sources/McNetworkMenuCore/Models/WiFiNetwork.swift`
- Create: `Sources/McNetworkMenuCore/Models/OperationState.swift`
- Create: `Tests/McNetworkMenuCoreTests/Models/WiFiNetworkPresentationTests.swift`

**Interfaces:**
- Produces: public Wi-Fi value types, presentation sections, scan/connection states, location permission, and sanitized `DisplayError`.

- [ ] **Step 1: Write failing presentation tests**

Cover: connected/known/nearby order; duplicate BSSID collapse to strongest while OR-ing known/connected flags; descending RSSI then localized SSID sorting; blank SSID removal; RSSI `-45/-60/-72/-90` to signal levels `4/3/2/1`; and preservation of security flags.

- [ ] **Step 2: Verify RED**

Run: `swift test --filter WiFiNetworkPresentationTests`

Expected: compilation FAILS because `WiFiNetwork` does not exist.

- [ ] **Step 3: Implement minimal presentation behavior**

Use BSSID as identity when present and SSID otherwise. Deduplicate before partitioning. Return only nonempty `.connected`, `.known`, and `.nearby` sections. `DisplayError` contains only sanitized user-facing text.

- [ ] **Step 4: Verify GREEN and commit**

Run: `swift test --filter WiFiNetworkPresentationTests`

Expected: focused tests PASS.

Run: `swift test`

Expected: complete suite PASS.

```bash
git add Sources/McNetworkMenuCore/Models Tests/McNetworkMenuCoreTests/Models/WiFiNetworkPresentationTests.swift
git commit -m "feat: model Wi-Fi network presentation"
```

---

### Task 4: Define service contracts and adapt the active Network path

**Files:**
- Create: `Sources/McNetworkMenuCore/Services/ServiceProtocols.swift`
- Create: `Sources/McNetworkMenuCore/Services/AppleNetworkPathMonitor.swift`
- Create: `Tests/McNetworkMenuCoreTests/Services/IPv4AddressLookupTests.swift`

**Interfaces:**
- Consumes: Tasks 2 and 3 domain values.
- Produces: network, Wi-Fi, location, login, and system-action protocols; `AppleNetworkPathMonitor`; pure IPv4 lookup.

- [ ] **Step 1: Write a failing IPv4 boundary test**

Given `en0` IPv6, `en7` IPv4 `192.168.1.24`, and `en0` IPv4 `10.0.0.8`, assert lookup for `en7` returns only `192.168.1.24`; missing interface returns nil.

- [ ] **Step 2: Verify RED**

Run: `swift test --filter IPv4AddressLookupTests`

Expected: compilation FAILS because `IPv4AddressLookup` does not exist.

- [ ] **Step 3: Add service contracts**

Define `NetworkPathMonitoring` with `AsyncStream<NetworkPathSnapshot>` and start/stop; async `WiFiControlling` status/scan/power/connect/disconnect; async `LocationAuthorizing`; `LaunchAtLoginStatus` and its controller; `SystemSettingsDestination`; and main-actor `SystemActions` for settings/About/Quit.

- [ ] **Step 4: Implement the Network adapter**

Wrap one `NWPathMonitor` and AsyncStream. Preserve available-interface order, map Wi-Fi/Ethernet explicitly, attach IPv4 from `getifaddrs`, start on a private serial queue, make start idempotent, and finish on stop/deinit. Keep record selection pure and covered by Step 1.

- [ ] **Step 5: Verify GREEN and commit**

Run: `swift test --filter IPv4AddressLookupTests`

Expected: focused tests PASS.

Run: `swift test`

Expected: full suite PASS and framework imports compile via SwiftPM.

```bash
git add Sources/McNetworkMenuCore/Services Tests/McNetworkMenuCoreTests/Services/IPv4AddressLookupTests.swift
git commit -m "feat: monitor active network path"
```

---

### Task 5: Implement the CoreWLAN Wi-Fi adapter

**Files:**
- Create: `Sources/McNetworkMenuCore/Services/CoreWLANController.swift`
- Create: `Tests/McNetworkMenuCoreTests/Services/CoreWLANMappingTests.swift`

**Interfaces:**
- Consumes: Wi-Fi service contract, models, and sanitized errors.
- Produces: actor-backed `CoreWLANController` and pure mapping helpers.

- [ ] **Step 1: Write failing mapping tests**

Verify a `Home` record with BSSID `AA:BB`, RSSI `-48`, non-open security, known set containing `Home`, and connected SSID `Home` maps secure/known/connected. Verify nil/blank SSIDs map nil and open security maps insecure.

- [ ] **Step 2: Verify RED**

Run: `swift test --filter CoreWLANMappingTests`

Expected: compilation FAILS because mapper types are missing.

- [ ] **Step 3: Implement the actor-backed public API adapter**

Own one `CWWiFiClient`, default `CWInterface`, and scan cache. Implement status from power/SSID/RSSI; scan through public CoreWLAN including known profiles; set power; connect only through cached networks; disconnect; and stable sanitized errors. Return raw domain networks for Task 3 to present. Never log passwords or underlying errors.

- [ ] **Step 4: Verify GREEN and commit**

Run: `swift test --filter CoreWLANMappingTests`

Expected: focused tests PASS.

Run: `swift test`

Expected: full suite PASS and CoreWLAN compiles through SwiftPM.

```bash
git add Sources/McNetworkMenuCore/Services/CoreWLANController.swift Tests/McNetworkMenuCoreTests/Services/CoreWLANMappingTests.swift
git commit -m "feat: add CoreWLAN Wi-Fi controller"
```

---

### Task 6: Implement permission, login-item, and application actions

**Files:**
- Create: `Sources/McNetworkMenuCore/Services/AppleLocationAuthorizer.swift`
- Create: `Sources/McNetworkMenuCore/Services/AppleLaunchAtLoginController.swift`
- Create: `Sources/McNetworkMenuCore/Services/AppleSystemActions.swift`
- Create: `Tests/McNetworkMenuCoreTests/Services/SystemIntegrationMappingTests.swift`

**Interfaces:**
- Consumes: service protocols and operation states.
- Produces: production CoreLocation, ServiceManagement, and AppKit adapters.

- [ ] **Step 1: Write failing mapping tests**

Verify CoreLocation authorized-always/when-in-use map authorized and other cases remain distinct. Verify ServiceManagement enabled/requires-approval/not-registered/not-found map to the matching domain cases.

- [ ] **Step 2: Verify RED**

Run: `swift test --filter SystemIntegrationMappingTests`

Expected: compilation FAILS because mapping functions are missing.

- [ ] **Step 3: Implement production adapters**

Location owns `CLLocationManager`, requests when-in-use only when not determined, and completes continuations once from its delegate. Login reads/registers/unregisters `SMAppService.mainApp` and sanitizes rejection. System actions run on the main actor, open System Settings through `NSWorkspace`, show the standard About panel, and terminate through `NSApplication`; do not use undocumented pane URLs.

- [ ] **Step 4: Verify GREEN and commit**

Run: `swift test --filter SystemIntegrationMappingTests`

Expected: focused tests PASS.

Run: `swift test`

Expected: complete suite PASS.

```bash
git add Sources/McNetworkMenuCore/Services/AppleLocationAuthorizer.swift Sources/McNetworkMenuCore/Services/AppleLaunchAtLoginController.swift Sources/McNetworkMenuCore/Services/AppleSystemActions.swift Tests/McNetworkMenuCoreTests/Services/SystemIntegrationMappingTests.swift
git commit -m "feat: add macOS system integrations"
```

---

### Task 7: Implement the mock-tested network menu state machine

**Files:**
- Create: `Sources/McNetworkMenuCore/ViewModels/NetworkMenuModel.swift`
- Create: `Tests/McNetworkMenuCoreTests/TestSupport/Fakes.swift`
- Create: `Tests/McNetworkMenuCoreTests/ViewModels/NetworkMenuModelTests.swift`

**Interfaces:**
- Consumes: all domain values and service protocols.
- Produces: model start/stop, panel-open/refresh, password prompt, Wi-Fi actions, login toggle, and footer actions.

- [ ] **Step 1: Build deterministic protocol fakes**

Path fake owns an AsyncStream continuation. Wi-Fi fake supports queued scan continuations, configured status/errors, and records only network ID plus whether a credential existed—never its value. Other fakes expose configured results and consumer-visible counters.

- [ ] **Step 2: Write failing state tests**

Using only fakes, test Wi-Fi route plus connected SSID; just-in-time permission then scan; denied permission/no scan; stale scan rejection; password clearing after failure; Ethernet primary with Wi-Fi data retained; power, disconnect, login toggle, settings, About, and Quit effects.

- [ ] **Step 3: Verify RED**

Run: `swift test --filter NetworkMenuModelTests`

Expected: compilation FAILS because the model is missing.

- [ ] **Step 4: Implement the main-actor observable model**

Publish route, Wi-Fi, section, operation, permission, login, and prompt state read-only. Inject services. Consume path once, merge SSID into Wi-Fi route, preserve data during refresh, reject stale generations, never publish credentials, and expose explicit methods for every UI action with progress and sanitized failure states.

- [ ] **Step 5: Verify GREEN and commit**

Run: `swift test --filter NetworkMenuModelTests`

Expected: all focused mock tests PASS.

Run: `swift test`

Expected: complete suite PASS.

```bash
git add Sources/McNetworkMenuCore/ViewModels Tests/McNetworkMenuCoreTests/TestSupport Tests/McNetworkMenuCoreTests/ViewModels
git commit -m "feat: coordinate network menu state"
```

---

### Task 8: Build the adaptive SwiftUI menu and dynamic icon

**Files:**
- Modify: `Sources/McNetworkMenu/App/McNetworkMenuApp.swift`
- Modify: `Sources/McNetworkMenu/Views/MenuPanelView.swift`
- Create: `Sources/McNetworkMenu/Views/PrimaryConnectionView.swift`
- Create: `Sources/McNetworkMenu/Views/WiFiSectionView.swift`
- Create: `Sources/McNetworkMenu/Views/NetworkRowView.swift`
- Create: `Sources/McNetworkMenu/Views/PasswordPromptView.swift`
- Create: `Sources/McNetworkMenu/Views/FooterView.swift`
- Create: `Tests/McNetworkMenuCoreTests/Models/PresentationCopyTests.swift`

**Interfaces:**
- Consumes: live adapters and the model.
- Produces: icon-only menu item and 360-point adaptive panel.

- [ ] **Step 1: Write failing presentation tests**

Test distinct nonempty accessibility labels with approved symbols, native compact section titles, and sanitized operation-error copy.

- [ ] **Step 2: Verify RED**

Run: `swift test --filter PresentationCopyTests`

Expected: FAIL for missing section titles.

- [ ] **Step 3: Compose live dependencies and label**

Create adapters once, inject a `@StateObject` model, render `Image(systemName: model.primaryInterface.symbolName)` with its accessibility label inside `MenuBarExtra`, and use `.window` style.

- [ ] **Step 4: Implement the approved panel**

At 360-point width, show primary Ethernet/Wi-Fi/offline first; Wi-Fi toggle, refresh, sections, progress/errors, signal/security indicators second; password `SecureField` and actions when needed; then first-level Network Settings, Launch at Login, About, and Quit. Route every action through the model and add accessibility labels to icon-only controls.

- [ ] **Step 5: Verify without real network operations**

Run: `swift test`

Expected: mock-driven suite PASS.

Run: `make build`

Expected: Debug app compiles, assembles, signs, and verifies without launch.

- [ ] **Step 6: Commit the UI**

```bash
git add Sources/McNetworkMenu Sources/McNetworkMenuCore/Models Tests/McNetworkMenuCoreTests/Models/PresentationCopyTests.swift
git commit -m "feat: build adaptive network menu interface"
```

---

### Task 9: Document deferred hardware checks and verify Release

**Files:**
- Create: `docs/smoke-tests.md`
- Create: `README.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: all completed Make targets and features.
- Produces: GitHub-ready usage, signing, limits, and deferred-check documentation.

- [ ] **Step 1: Write the deferred real-Mac checklist**

Document but do not execute or mark passed: Wi-Fi/Ethernet/offline primary routes, power, permission/denial, open/known/unknown-secure association, wrong password, administrator rejection, Settings, About, Launch at Login, Dock absence, and Quit.

- [ ] **Step 2: Write README**

Document macOS 14+, Swift 5.9+ CLI, Make commands, bundle locations, signing override, `/Applications` installation before login registration, location rationale, public-API limits, and that validation currently uses mock data.

- [ ] **Step 3: Confirm ignored outputs**

Ensure `.gitignore` covers `.build/`, `.DS_Store`, `.superpowers/`, and `.worktrees/`.

- [ ] **Step 4: Run fresh verification**

Run: `make clean`

Expected: only generated SwiftPM/app output is removed.

Run: `make check`

Expected: all mock tests PASS, Release builds, `.build/apps/release/McNetworkMenu.app` exists, plist is valid, and signature verification exits 0.

- [ ] **Step 5: Commit documentation**

```bash
git add README.md docs/smoke-tests.md .gitignore
git commit -m "docs: add CLI build and smoke-test guidance"
```

- [ ] **Step 6: Confirm clean history**

Run: `git status --short --branch`

Expected: clean `feature/mcnetworkmenu` branch.

Run: `git log --oneline --decorate -12`

Expected: focused commits for specification revision and Tasks 1–9.
