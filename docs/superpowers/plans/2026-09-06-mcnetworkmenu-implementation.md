# McNetworkMenu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS 14+ menu-bar utility that identifies the active Wi-Fi, Ethernet, or offline route and exposes supported Wi-Fi controls through Apple's public APIs.

**Architecture:** A SwiftUI `MenuBarExtra(.window)` reads immutable state from a main-actor `NetworkMenuModel`. Narrow protocols isolate Network, CoreWLAN, CoreLocation, ServiceManagement, and AppKit adapters so route selection, network presentation, and UI state transitions can be tested without network hardware.

**Tech Stack:** Swift 5.9+, SwiftUI, Network, CoreWLAN, CoreLocation, ServiceManagement, AppKit, XCTest, Xcode 16+, GNU Make, macOS 14 deployment target.

**Spec:** `docs/superpowers/specs/2026-09-06-mcnetworkmenu-design.md`

## Global Constraints

- Product name: `McNetworkMenu`.
- Bundle identifier: `com.prakharpal.McNetworkMenu`.
- Deployment target: macOS 14 Sonoma or newer.
- Distribution: direct GitHub source distribution; local builds use ad-hoc signing unless `SIGNING_IDENTITY` is supplied.
- Use only Apple public APIs and no third-party runtime or build dependencies.
- Run all build lifecycle operations through the root `Makefile`.
- Keep the application menu-bar-only by setting `LSUIElement` to `true`.
- Use `wifi` for a Wi-Fi primary route, `network` for an Ethernet primary route, and `network.slash` for offline.
- Keep the menu-bar display icon-only; do not add throughput text.
- Never persist or log Wi-Fi passwords.
- Request location permission only when a named Wi-Fi scan is first requested.
- Do not attempt private Continuity/Instant Hotspot integration.
- Run `make check` before declaring implementation complete.

---

## File Map

| Path | Responsibility |
|---|---|
| `McNetworkMenu.xcodeproj/project.pbxproj` | macOS app and XCTest target definitions, build settings, linked Apple frameworks |
| `McNetworkMenu.xcodeproj/xcshareddata/xcschemes/McNetworkMenu.xcscheme` | Shared build-and-test scheme used by Make |
| `Makefile` | Stable build, test, clean, run, release, and check commands |
| `McNetworkMenu/App/McNetworkMenuApp.swift` | App entry point, dependency construction, dynamic menu-bar label |
| `McNetworkMenu/Models/PrimaryInterface.swift` | Primary-interface cases and SF Symbol/accessibility mapping |
| `McNetworkMenu/Models/NetworkPathSnapshot.swift` | Framework-neutral route snapshot and deterministic primary-route selection |
| `McNetworkMenu/Models/WiFiNetwork.swift` | Framework-neutral Wi-Fi status, network identity, signal, and grouping logic |
| `McNetworkMenu/Models/OperationState.swift` | Scan, connection, permission, and display-error states |
| `McNetworkMenu/Services/ServiceProtocols.swift` | Interfaces consumed by the view model |
| `McNetworkMenu/Services/AppleNetworkPathMonitor.swift` | `NWPathMonitor` adapter and interface IPv4 lookup |
| `McNetworkMenu/Services/CoreWLANController.swift` | CoreWLAN power, scan, association, disassociation, and mapping |
| `McNetworkMenu/Services/AppleLocationAuthorizer.swift` | Just-in-time CoreLocation authorization |
| `McNetworkMenu/Services/AppleLaunchAtLoginController.swift` | `SMAppService.mainApp` adapter |
| `McNetworkMenu/Services/AppleSystemActions.swift` | System Settings, About, and Quit actions |
| `McNetworkMenu/ViewModels/NetworkMenuModel.swift` | Main-actor orchestration and user-action state machine |
| `McNetworkMenu/Views/MenuPanelView.swift` | Adaptive popover composition and panel lifecycle |
| `McNetworkMenu/Views/PrimaryConnectionView.swift` | Ethernet, Wi-Fi, and offline summary |
| `McNetworkMenu/Views/WiFiSectionView.swift` | Wi-Fi toggle, refresh state, and section composition |
| `McNetworkMenu/Views/NetworkRowView.swift` | Individual network state and action |
| `McNetworkMenu/Views/PasswordPromptView.swift` | Ephemeral secured-network password entry |
| `McNetworkMenu/Views/FooterView.swift` | Settings, Launch at Login, About, and visible Quit actions |
| `McNetworkMenuTests/Models/*Tests.swift` | Pure route and Wi-Fi presentation tests |
| `McNetworkMenuTests/ViewModels/NetworkMenuModelTests.swift` | Orchestration tests using deterministic fakes |
| `McNetworkMenuTests/TestSupport/Fakes.swift` | Protocol-conforming test services |
| `docs/smoke-tests.md` | Repeatable hardware and macOS-integration checks |
| `README.md` | Build, permission, signing, usage, and known-limit documentation |

---

### Task 1: Create the buildable menu-bar project and Make workflow

**Files:**
- Create: `McNetworkMenu.xcodeproj/project.pbxproj`
- Create: `McNetworkMenu.xcodeproj/xcshareddata/xcschemes/McNetworkMenu.xcscheme`
- Create: `Makefile`
- Create: `McNetworkMenu/App/McNetworkMenuApp.swift`
- Create: `McNetworkMenu/Views/MenuPanelView.swift`

**Interfaces:**
- Consumes: none.
- Produces: Xcode scheme `McNetworkMenu`; app module `McNetworkMenu`; Make targets `build`, `test`, `clean`, `run`, `release`, and `check`.

- [ ] **Step 1: Create the Xcode project definition**

Create one macOS application target named `McNetworkMenu` and one unit-test target named `McNetworkMenuTests`. Use file-system-synchronized root groups for `McNetworkMenu/` and `McNetworkMenuTests/` so later Swift files are discovered without hand-editing the project.

Use these exact app build settings in both Debug and Release:

```text
PRODUCT_BUNDLE_IDENTIFIER = com.prakharpal.McNetworkMenu;
PRODUCT_NAME = McNetworkMenu;
MACOSX_DEPLOYMENT_TARGET = 14.0;
SWIFT_VERSION = 5.0;
GENERATE_INFOPLIST_FILE = YES;
INFOPLIST_KEY_LSUIElement = YES;
INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "McNetworkMenu uses location permission only to display the names of nearby Wi-Fi networks.";
CODE_SIGN_STYLE = Manual;
CODE_SIGN_IDENTITY = "-";
ENABLE_HARDENED_RUNTIME = YES;
```

Link `SwiftUI.framework`, `Network.framework`, `CoreWLAN.framework`, `CoreLocation.framework`, `ServiceManagement.framework`, and `AppKit.framework`. Configure the test target with `TEST_HOST = $(BUILT_PRODUCTS_DIR)/McNetworkMenu.app/Contents/MacOS/McNetworkMenu` and `BUNDLE_LOADER = $(TEST_HOST)`.

- [ ] **Step 2: Create the shared scheme**

The scheme must build the app for all actions and include `McNetworkMenuTests.xctest` in its `TestAction`. Set Debug for Run/Test and Release for Archive. Verify discovery before adding source:

Run: `xcodebuild -project McNetworkMenu.xcodeproj -list`

Expected: output lists targets `McNetworkMenu` and `McNetworkMenuTests`, and scheme `McNetworkMenu`.

- [ ] **Step 3: Add the smallest menu-bar-only app shell**

```swift
// McNetworkMenu/App/McNetworkMenuApp.swift
import SwiftUI

@main
struct McNetworkMenuApp: App {
    var body: some Scene {
        MenuBarExtra("McNetworkMenu", systemImage: "network.slash") {
            MenuPanelView()
        }
        .menuBarExtraStyle(.window)
    }
}
```

```swift
// McNetworkMenu/Views/MenuPanelView.swift
import SwiftUI

struct MenuPanelView: View {
    var body: some View {
        Text("McNetworkMenu")
            .frame(width: 340, height: 160)
    }
}
```

- [ ] **Step 4: Add the Makefile contract**

```make
SHELL := /bin/zsh
PROJECT := McNetworkMenu.xcodeproj
SCHEME := McNetworkMenu
DERIVED_DATA := $(CURDIR)/.build/DerivedData
APP := $(DERIVED_DATA)/Build/Products/Debug/McNetworkMenu.app
SIGNING_IDENTITY ?= -
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED_DATA)
SIGNING := CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$(SIGNING_IDENTITY)"

.PHONY: build test clean run release check

build:
	$(XCODEBUILD) -configuration Debug $(SIGNING) build

test:
	$(XCODEBUILD) -configuration Debug -destination 'platform=macOS' $(SIGNING) test

clean:
	$(XCODEBUILD) $(SIGNING) clean

run: build
	open "$(APP)"

release:
	$(XCODEBUILD) -configuration Release $(SIGNING) build

check: test clean release
```

- [ ] **Step 5: Verify the build artifact and menu-bar agent setting**

Run: `make build`

Expected: `** BUILD SUCCEEDED **` and `.build/DerivedData/Build/Products/Debug/McNetworkMenu.app` exists.

Run: `/usr/libexec/PlistBuddy -c 'Print :LSUIElement' .build/DerivedData/Build/Products/Debug/McNetworkMenu.app/Contents/Info.plist`

Expected: `true`.

Run: `/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' .build/DerivedData/Build/Products/Debug/McNetworkMenu.app/Contents/Info.plist`

Expected: `com.prakharpal.McNetworkMenu`.

- [ ] **Step 6: Commit the buildable skeleton**

```bash
git add McNetworkMenu.xcodeproj Makefile McNetworkMenu/App/McNetworkMenuApp.swift McNetworkMenu/Views/MenuPanelView.swift
git commit -m "build: scaffold McNetworkMenu macOS app"
```

---

### Task 2: Model route snapshots and resolve the primary interface

**Files:**
- Create: `McNetworkMenu/Models/PrimaryInterface.swift`
- Create: `McNetworkMenu/Models/NetworkPathSnapshot.swift`
- Create: `McNetworkMenuTests/Models/PrimaryInterfaceResolverTests.swift`

**Interfaces:**
- Consumes: app/test targets from Task 1.
- Produces: `NetworkPathSnapshot`, `PathInterface`, `NetworkInterfaceKind`, `PrimaryInterface`, and `PrimaryInterfaceResolver.resolve(_:)`.

- [ ] **Step 1: Write failing route-selection tests**

```swift
import XCTest
@testable import McNetworkMenu

final class PrimaryInterfaceResolverTests: XCTestCase {
    func testEthernetWinsWhenFirstOnSatisfiedPath() {
        let snapshot = NetworkPathSnapshot(
            isSatisfied: true,
            interfaces: [
                PathInterface(name: "en7", kind: .ethernet, ipv4Address: "192.168.1.24"),
                PathInterface(name: "en0", kind: .wifi, ipv4Address: "192.168.1.25")
            ]
        )

        XCTAssertEqual(
            PrimaryInterfaceResolver.resolve(snapshot),
            .ethernet(name: "en7", ipv4Address: "192.168.1.24")
        )
    }

    func testWiFiWinsWhenFirstOnSatisfiedPath() {
        let snapshot = NetworkPathSnapshot(
            isSatisfied: true,
            interfaces: [
                PathInterface(name: "en0", kind: .wifi, ipv4Address: "10.0.0.8"),
                PathInterface(name: "en7", kind: .ethernet, ipv4Address: "10.0.0.9")
            ]
        )

        XCTAssertEqual(
            PrimaryInterfaceResolver.resolve(snapshot),
            .wifi(interfaceName: "en0", ssid: nil, ipv4Address: "10.0.0.8")
        )
    }

    func testUnsatisfiedPathIsOffline() {
        let snapshot = NetworkPathSnapshot(isSatisfied: false, interfaces: [])
        XCTAssertEqual(PrimaryInterfaceResolver.resolve(snapshot), .offline)
    }

    func testSymbolsMatchApprovedDesign() {
        XCTAssertEqual(PrimaryInterface.ethernet(name: "en7", ipv4Address: nil).symbolName, "network")
        XCTAssertEqual(PrimaryInterface.wifi(interfaceName: "en0", ssid: nil, ipv4Address: nil).symbolName, "wifi")
        XCTAssertEqual(PrimaryInterface.offline.symbolName, "network.slash")
    }
}
```

- [ ] **Step 2: Run the tests and confirm RED**

Run: `xcodebuild test -project McNetworkMenu.xcodeproj -scheme McNetworkMenu -destination 'platform=macOS' -only-testing:McNetworkMenuTests/PrimaryInterfaceResolverTests`

Expected: FAIL because `NetworkPathSnapshot` and related types do not exist.

- [ ] **Step 3: Implement the framework-neutral route types**

```swift
// McNetworkMenu/Models/NetworkPathSnapshot.swift
import Foundation

enum NetworkInterfaceKind: Equatable, Sendable {
    case wifi
    case ethernet
    case other
}

struct PathInterface: Equatable, Sendable {
    let name: String
    let kind: NetworkInterfaceKind
    let ipv4Address: String?
}

struct NetworkPathSnapshot: Equatable, Sendable {
    let isSatisfied: Bool
    let interfaces: [PathInterface]
}

enum PrimaryInterfaceResolver {
    static func resolve(_ snapshot: NetworkPathSnapshot) -> PrimaryInterface {
        guard snapshot.isSatisfied else { return .offline }

        for interface in snapshot.interfaces {
            switch interface.kind {
            case .ethernet:
                return .ethernet(name: interface.name, ipv4Address: interface.ipv4Address)
            case .wifi:
                return .wifi(interfaceName: interface.name, ssid: nil, ipv4Address: interface.ipv4Address)
            case .other:
                continue
            }
        }
        return .offline
    }
}
```

```swift
// McNetworkMenu/Models/PrimaryInterface.swift
import Foundation

enum PrimaryInterface: Equatable, Sendable {
    case wifi(interfaceName: String, ssid: String?, ipv4Address: String?)
    case ethernet(name: String, ipv4Address: String?)
    case offline

    var symbolName: String {
        switch self {
        case .wifi: "wifi"
        case .ethernet: "network"
        case .offline: "network.slash"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .wifi: "Wi-Fi is the primary network"
        case .ethernet: "Ethernet is the primary network"
        case .offline: "No network connection"
        }
    }
}
```

- [ ] **Step 4: Run route tests and the suite**

Run: `make test`

Expected: all route-selection tests PASS.

- [ ] **Step 5: Commit the route domain**

```bash
git add McNetworkMenu/Models McNetworkMenuTests/Models/PrimaryInterfaceResolverTests.swift
git commit -m "feat: resolve primary network interface"
```

---

### Task 3: Model Wi-Fi networks, signal levels, and ordered sections

**Files:**
- Create: `McNetworkMenu/Models/WiFiNetwork.swift`
- Create: `McNetworkMenu/Models/OperationState.swift`
- Create: `McNetworkMenuTests/Models/WiFiNetworkPresentationTests.swift`

**Interfaces:**
- Consumes: none beyond Foundation.
- Produces: `WiFiNetwork`, `WiFiStatus`, `WiFiNetworkSection`, `WiFiNetworkPresentation.sections(from:)`, `ScanState`, `ConnectionState`, `LocationPermission`, and `DisplayError`.

- [ ] **Step 1: Write failing presentation tests**

```swift
import XCTest
@testable import McNetworkMenu

final class WiFiNetworkPresentationTests: XCTestCase {
    func testGroupsConnectedThenKnownThenNearby() {
        let networks = [
            WiFiNetwork(ssid: "Cafe", bssid: "03", rssi: -40, isSecure: false, isKnown: false, isConnected: false),
            WiFiNetwork(ssid: "Home", bssid: "01", rssi: -55, isSecure: true, isKnown: true, isConnected: true),
            WiFiNetwork(ssid: "Office", bssid: "02", rssi: -45, isSecure: true, isKnown: true, isConnected: false)
        ]

        let sections = WiFiNetworkPresentation.sections(from: networks)

        XCTAssertEqual(sections.map(\.kind), [.connected, .known, .nearby])
        XCTAssertEqual(sections.flatMap(\.networks).map(\.ssid), ["Home", "Office", "Cafe"])
    }

    func testDeduplicatesBSSIDAndSortsStrongestFirstThenName() {
        let networks = [
            WiFiNetwork(ssid: "Zulu", bssid: "01", rssi: -70, isSecure: true, isKnown: false, isConnected: false),
            WiFiNetwork(ssid: "Zulu", bssid: "01", rssi: -40, isSecure: true, isKnown: false, isConnected: false),
            WiFiNetwork(ssid: "Alpha", bssid: "02", rssi: -40, isSecure: false, isKnown: false, isConnected: false)
        ]

        let nearby = WiFiNetworkPresentation.sections(from: networks).first?.networks
        XCTAssertEqual(nearby?.map(\.ssid), ["Alpha", "Zulu"])
        XCTAssertEqual(nearby?.last?.rssi, -40)
    }

    func testSignalLevelsUseFourStableBands() {
        XCTAssertEqual(WiFiNetwork.signalLevel(for: -45), 4)
        XCTAssertEqual(WiFiNetwork.signalLevel(for: -60), 3)
        XCTAssertEqual(WiFiNetwork.signalLevel(for: -72), 2)
        XCTAssertEqual(WiFiNetwork.signalLevel(for: -90), 1)
    }
}
```

- [ ] **Step 2: Run the tests and confirm RED**

Run: `xcodebuild test -project McNetworkMenu.xcodeproj -scheme McNetworkMenu -destination 'platform=macOS' -only-testing:McNetworkMenuTests/WiFiNetworkPresentationTests`

Expected: FAIL because the Wi-Fi model types do not exist.

- [ ] **Step 3: Implement Wi-Fi value types and deterministic presentation**

`WiFiNetwork.ID` is `bssid` when present and otherwise `ssid`. Drop blank SSIDs. For duplicate IDs, retain the entry with the highest RSSI while combining `isKnown` and `isConnected` with logical OR. Partition into `.connected`, `.known`, and `.nearby`; omit empty sections; sort each section by descending RSSI and then `localizedStandardCompare` on SSID.

```swift
struct WiFiNetwork: Identifiable, Equatable, Sendable {
    let ssid: String
    let bssid: String?
    let rssi: Int
    let isSecure: Bool
    let isKnown: Bool
    let isConnected: Bool

    var id: String { bssid ?? ssid }
    var signalLevel: Int { Self.signalLevel(for: rssi) }

    static func signalLevel(for rssi: Int) -> Int {
        switch rssi {
        case -55...: 4
        case -67...: 3
        case -80...: 2
        default: 1
        }
    }
}

struct WiFiStatus: Equatable, Sendable {
    let isPowerOn: Bool
    let connectedSSID: String?
    let rssi: Int?
}

enum WiFiNetworkSectionKind: Equatable, Sendable { case connected, known, nearby }

struct WiFiNetworkSection: Equatable, Sendable {
    let kind: WiFiNetworkSectionKind
    let networks: [WiFiNetwork]
}
```

Define operation states in `OperationState.swift`:

```swift
enum ScanState: Equatable, Sendable { case idle, scanning, failed(DisplayError) }
enum ConnectionState: Equatable, Sendable { case idle, connecting(WiFiNetwork.ID), failed(WiFiNetwork.ID, DisplayError) }
enum LocationPermission: Equatable, Sendable { case notDetermined, authorized, denied, restricted }
struct DisplayError: Error, Equatable, Sendable { let message: String }
```

- [ ] **Step 4: Run tests and verify GREEN**

Run: `make test`

Expected: all presentation and route tests PASS.

- [ ] **Step 5: Commit the Wi-Fi domain**

```bash
git add McNetworkMenu/Models McNetworkMenuTests/Models/WiFiNetworkPresentationTests.swift
git commit -m "feat: model Wi-Fi network presentation"
```

---

### Task 4: Add service contracts and the live default-route monitor

**Files:**
- Create: `McNetworkMenu/Services/ServiceProtocols.swift`
- Create: `McNetworkMenu/Services/AppleNetworkPathMonitor.swift`
- Create: `McNetworkMenuTests/Services/IPv4AddressLookupTests.swift`

**Interfaces:**
- Consumes: `NetworkPathSnapshot`, `WiFiStatus`, `WiFiNetwork`, and `LocationPermission`.
- Produces: all service protocols, `AppleNetworkPathMonitor`, and `IPv4AddressLookup.address(for:records:)`.

- [ ] **Step 1: Define the service boundary used by every later task**

```swift
protocol NetworkPathMonitoring: AnyObject {
    var updates: AsyncStream<NetworkPathSnapshot> { get }
    func start()
    func stop()
}

protocol WiFiControlling: Sendable {
    func status() async -> WiFiStatus
    func scan() async throws -> [WiFiNetwork]
    func setPower(_ enabled: Bool) async throws
    func connect(to id: WiFiNetwork.ID, password: String?) async throws
    func disconnect() async
}

protocol LocationAuthorizing: AnyObject {
    var status: LocationPermission { get }
    func request() async -> LocationPermission
}

enum LaunchAtLoginStatus: Equatable, Sendable { case enabled, requiresApproval, disabled, unavailable }

protocol LaunchAtLoginControlling: Sendable {
    func status() async -> LaunchAtLoginStatus
    func setEnabled(_ enabled: Bool) async throws -> LaunchAtLoginStatus
}

enum SystemSettingsDestination: Sendable { case network, locationPrivacy }

@MainActor
protocol SystemActions: AnyObject {
    func openSettings(_ destination: SystemSettingsDestination)
    func showAbout()
    func quit()
}
```

- [ ] **Step 2: Write a failing IPv4 selection test**

Extract address selection from `getifaddrs` into a pure record function. Test that it ignores IPv6 and other interfaces and returns the first IPv4 value for the requested BSD name.

```swift
func testReturnsOnlyMatchingIPv4Address() {
    let records = [
        InterfaceAddressRecord(name: "en0", family: AF_INET6, address: "fe80::1"),
        InterfaceAddressRecord(name: "en7", family: AF_INET, address: "192.168.1.24"),
        InterfaceAddressRecord(name: "en0", family: AF_INET, address: "10.0.0.8")
    ]
    XCTAssertEqual(IPv4AddressLookup.address(for: "en7", records: records), "192.168.1.24")
}
```

- [ ] **Step 3: Confirm the address test fails**

Run: `xcodebuild test -project McNetworkMenu.xcodeproj -scheme McNetworkMenu -destination 'platform=macOS' -only-testing:McNetworkMenuTests/IPv4AddressLookupTests`

Expected: FAIL because `InterfaceAddressRecord` does not exist.

- [ ] **Step 4: Implement path monitoring**

Create one `NWPathMonitor` and one `AsyncStream.makeStream(of: NetworkPathSnapshot.self)`. On `pathUpdateHandler`, preserve `path.availableInterfaces` order, map `.wifi` to `.wifi`, `.wiredEthernet` to `.ethernet`, everything else to `.other`, and attach the BSD interface's IPv4 address from `getifaddrs`. Set `isSatisfied` only when `path.status == .satisfied`. Start on a dedicated serial queue, make `start()` idempotent, cancel and finish the stream in `stop()`/`deinit`.

The pure lookup must have this implementation shape:

```swift
struct InterfaceAddressRecord: Equatable {
    let name: String
    let family: Int32
    let address: String
}

enum IPv4AddressLookup {
    static func address(for name: String, records: [InterfaceAddressRecord]) -> String? {
        records.first { $0.name == name && $0.family == AF_INET }?.address
    }
}
```

- [ ] **Step 5: Run the suite and commit**

Run: `make test`

Expected: all tests PASS.

```bash
git add McNetworkMenu/Services/ServiceProtocols.swift McNetworkMenu/Services/AppleNetworkPathMonitor.swift McNetworkMenuTests/Services/IPv4AddressLookupTests.swift
git commit -m "feat: monitor active network path"
```

---

### Task 5: Implement the public CoreWLAN adapter

**Files:**
- Create: `McNetworkMenu/Services/CoreWLANController.swift`
- Create: `McNetworkMenuTests/Services/CoreWLANMappingTests.swift`

**Interfaces:**
- Consumes: `WiFiControlling`, `WiFiStatus`, and `WiFiNetwork`.
- Produces: `CoreWLANController` and pure `CoreWLANNetworkMapper` helpers.

- [ ] **Step 1: Write failing CoreWLAN mapping tests**

Keep CoreWLAN object access in the adapter, but test its pure projection inputs:

```swift
func testMapsKnownSecuredConnectedNetwork() {
    let input = CoreWLANNetworkRecord(
        ssid: "Home", bssid: "AA:BB", rssi: -48,
        supportsOpenSecurity: false
    )
    let result = CoreWLANNetworkMapper.map(
        input, knownSSIDs: ["Home"], connectedSSID: "Home"
    )
    XCTAssertEqual(
        result,
        WiFiNetwork(ssid: "Home", bssid: "AA:BB", rssi: -48,
                    isSecure: true, isKnown: true, isConnected: true)
    )
}

func testDropsMissingOrBlankSSID() {
    XCTAssertNil(CoreWLANNetworkMapper.map(
        .init(ssid: " ", bssid: nil, rssi: -60, supportsOpenSecurity: true),
        knownSSIDs: [], connectedSSID: nil
    ))
}
```

- [ ] **Step 2: Run the focused test and confirm RED**

Run: `xcodebuild test -project McNetworkMenu.xcodeproj -scheme McNetworkMenu -destination 'platform=macOS' -only-testing:McNetworkMenuTests/CoreWLANMappingTests`

Expected: FAIL because the mapping records do not exist.

- [ ] **Step 3: Implement the mapper and actor-backed controller**

Implement `CoreWLANController` as an `actor` owning one `CWWiFiClient`, the default `CWInterface`, and `[WiFiNetwork.ID: CWNetwork]` from the most recent scan.

- `status()` reads `powerOn()`, `ssid()`, and `rssiValue()`.
- `scan()` throws `DisplayError(message: "No Wi-Fi interface is available.")` if no default interface exists; calls `scanForNetworks(withName: nil, includeHidden: false)`; reads known SSIDs from `configuration()?.networkProfiles`; maps and caches nonblank networks; then returns the mapped values. Presentation grouping and sorting remain in `WiFiNetworkPresentation`.
- `setPower(_:)` calls `setPower` and maps thrown errors to `DisplayError(message: "Unable to change Wi-Fi power. macOS may require administrator approval.")`.
- `connect(to:password:)` looks up the cached `CWNetwork`, throws `DisplayError(message: "That network is no longer available. Refresh and try again.")` when missing, and calls `associate(to:password:)`.
- `disconnect()` calls `disassociate()`.
- Never include `password`, SSID credentials, or the underlying error's potentially sensitive description in logging.

Use `network.supportsSecurity(.none)` to produce `supportsOpenSecurity`. Trim SSIDs with `.whitespacesAndNewlines` before mapping.

- [ ] **Step 4: Run tests and compile the live adapter**

Run: `make test`

Expected: mapping tests and all earlier tests PASS, and the app target compiles against CoreWLAN.

- [ ] **Step 5: Commit the CoreWLAN boundary**

```bash
git add McNetworkMenu/Services/CoreWLANController.swift McNetworkMenuTests/Services/CoreWLANMappingTests.swift
git commit -m "feat: add CoreWLAN Wi-Fi controller"
```

---

### Task 6: Add permission, login-item, settings, About, and Quit integrations

**Files:**
- Create: `McNetworkMenu/Services/AppleLocationAuthorizer.swift`
- Create: `McNetworkMenu/Services/AppleLaunchAtLoginController.swift`
- Create: `McNetworkMenu/Services/AppleSystemActions.swift`
- Create: `McNetworkMenuTests/Services/SystemIntegrationMappingTests.swift`

**Interfaces:**
- Consumes: `LocationAuthorizing`, `LaunchAtLoginControlling`, `SystemActions`, and their state enums.
- Produces: production Apple adapters used by `McNetworkMenuApp`.

- [ ] **Step 1: Write failing framework-status mapping tests**

```swift
import CoreLocation
import ServiceManagement

func testLocationAuthorizationMapping() {
    XCTAssertEqual(LocationPermission.map(.notDetermined), .notDetermined)
    XCTAssertEqual(LocationPermission.map(.authorizedAlways), .authorized)
    XCTAssertEqual(LocationPermission.map(.authorizedWhenInUse), .authorized)
    XCTAssertEqual(LocationPermission.map(.denied), .denied)
    XCTAssertEqual(LocationPermission.map(.restricted), .restricted)
}

func testLoginStatusMapping() {
    XCTAssertEqual(LaunchAtLoginStatus.map(.enabled), .enabled)
    XCTAssertEqual(LaunchAtLoginStatus.map(.requiresApproval), .requiresApproval)
    XCTAssertEqual(LaunchAtLoginStatus.map(.notRegistered), .disabled)
    XCTAssertEqual(LaunchAtLoginStatus.map(.notFound), .unavailable)
}
```

- [ ] **Step 2: Run focused tests and confirm RED**

Run: `xcodebuild test -project McNetworkMenu.xcodeproj -scheme McNetworkMenu -destination 'platform=macOS' -only-testing:McNetworkMenuTests/SystemIntegrationMappingTests`

Expected: FAIL because the mapping functions are missing.

- [ ] **Step 3: Implement location authorization**

`AppleLocationAuthorizer` owns a `CLLocationManager`, maps `authorizationStatus`, and uses a checked continuation completed from `locationManagerDidChangeAuthorization(_:)`. Call `requestWhenInUseAuthorization()` only from `request()` and only while status is `.notDetermined`; otherwise return the current mapped value immediately. Resume each continuation exactly once.

- [ ] **Step 4: Implement Launch at Login and system actions**

`AppleLaunchAtLoginController` maps `SMAppService.mainApp.status`. `setEnabled(true)` calls `register()`, `setEnabled(false)` calls `unregister()`, and both return the post-operation status. Map rejection to `DisplayError(message: "Launch at Login needs approval in System Settings.")`.

`AppleSystemActions` runs on `@MainActor`:

```swift
func openSettings(_ destination: SystemSettingsDestination) {
    let settingsURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
    NSWorkspace.shared.openApplication(
        at: settingsURL,
        configuration: NSWorkspace.OpenConfiguration()
    )
}

func showAbout() {
    NSApplication.shared.orderFrontStandardAboutPanel(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
}

func quit() {
    NSApplication.shared.terminate(nil)
}
```

The first release opens System Settings through the documented workspace API rather than relying on undocumented preference-pane URL strings. The panel copy tells the user which Network or Location Services page to select.

- [ ] **Step 5: Run tests and commit**

Run: `make test`

Expected: all tests PASS.

```bash
git add McNetworkMenu/Services/AppleLocationAuthorizer.swift McNetworkMenu/Services/AppleLaunchAtLoginController.swift McNetworkMenu/Services/AppleSystemActions.swift McNetworkMenuTests/Services/SystemIntegrationMappingTests.swift
git commit -m "feat: add macOS system integrations"
```

---

### Task 7: Build the main-actor network menu state machine

**Files:**
- Create: `McNetworkMenu/ViewModels/NetworkMenuModel.swift`
- Create: `McNetworkMenuTests/TestSupport/Fakes.swift`
- Create: `McNetworkMenuTests/ViewModels/NetworkMenuModelTests.swift`

**Interfaces:**
- Consumes: every protocol from `ServiceProtocols.swift` and all domain states.
- Produces: `NetworkMenuModel.start()`, `stop()`, `panelDidOpen()`, `refresh()`, `requestPassword(for:)`, `cancelPasswordPrompt()`, `connect(to:password:)`, `disconnect()`, `setLaunchAtLogin(_:)`, and footer system-action methods.

- [ ] **Step 1: Create deterministic fakes**

`FakeNetworkPathMonitor` exposes an `AsyncStream` plus `send(_:)`. Actor-backed `FakeWiFiController` records only nonsecret action metadata; its connect record contains network ID and a Boolean `credentialWasProvided`, never the password value. Add fakes for location, login, and system actions with configurable results.

- [ ] **Step 2: Write failing state-transition tests**

Cover these exact outcomes:

```swift
@MainActor
func testPathUpdateChangesPrimaryInterfaceAndMergesConnectedSSID() async {
    let harness = TestHarness(
        wifiStatus: WiFiStatus(isPowerOn: true, connectedSSID: "Home", rssi: -48),
        locationPermission: .authorized
    )
    harness.model.start()
    harness.path.send(NetworkPathSnapshot(
        isSatisfied: true,
        interfaces: [PathInterface(name: "en0", kind: .wifi, ipv4Address: "10.0.0.8")]
    ))

    await waitUntil { harness.model.primaryInterface != .offline }

    XCTAssertEqual(
        harness.model.primaryInterface,
        .wifi(interfaceName: "en0", ssid: "Home", ipv4Address: "10.0.0.8")
    )
}

@MainActor
func testFirstPanelOpenRequestsPermissionThenScans() async {
    let home = WiFiNetwork(
        ssid: "Home", bssid: "AA", rssi: -48,
        isSecure: true, isKnown: true, isConnected: true
    )
    let harness = TestHarness(
        scanResults: [home],
        locationPermission: .notDetermined,
        requestedLocationPermission: .authorized
    )

    await harness.model.panelDidOpen()

    XCTAssertEqual(harness.location.requestCount, 1)
    XCTAssertEqual(harness.model.networkSections.flatMap(\.networks), [home])
    XCTAssertEqual(harness.model.scanState, .idle)
}

@MainActor
func testDeniedPermissionDoesNotScanAndOffersPrivacyRecovery() async {
    let harness = TestHarness(locationPermission: .denied)

    await harness.model.panelDidOpen()

    let scanCount = await harness.wifi.scanCount
    XCTAssertEqual(scanCount, 0)
    XCTAssertEqual(harness.model.locationPermission, .denied)
    XCTAssertTrue(harness.model.networkSections.isEmpty)
}

@MainActor
func testStaleScanCannotReplaceNewerResults() async {
    let old = WiFiNetwork(ssid: "Old", bssid: "01", rssi: -70, isSecure: false, isKnown: false, isConnected: false)
    let new = WiFiNetwork(ssid: "New", bssid: "02", rssi: -40, isSecure: false, isKnown: false, isConnected: false)
    let harness = TestHarness(locationPermission: .authorized)

    async let first: Void = harness.model.refresh()
    async let second: Void = harness.model.refresh()
    await waitUntil { await harness.wifi.scanCount == 2 }
    await harness.wifi.resolveScan(at: 1, with: [new])
    await harness.wifi.resolveScan(at: 0, with: [old])
    _ = await (first, second)

    XCTAssertEqual(harness.model.networkSections.flatMap(\.networks), [new])
}

@MainActor
func testPasswordIsClearedAfterConnectFailure() async {
    let secured = WiFiNetwork(ssid: "Home", bssid: "AA", rssi: -48, isSecure: true, isKnown: false, isConnected: false)
    let harness = TestHarness(locationPermission: .authorized)
    await harness.wifi.setConnectError(DisplayError(message: "Unable to join Home."))
    harness.model.requestPassword(for: secured)

    await harness.model.connect(to: secured.id, password: "not-a-real-password")

    let lastConnect = await harness.wifi.lastConnect
    XCTAssertNil(harness.model.pendingPasswordNetwork)
    XCTAssertEqual(
        harness.model.connectionState,
        .failed(secured.id, DisplayError(message: "Unable to join Home."))
    )
    XCTAssertEqual(lastConnect?.credentialWasProvided, true)
}

@MainActor
func testEthernetPrimaryStillKeepsWiFiStateAvailable() async {
    let home = WiFiNetwork(ssid: "Home", bssid: "AA", rssi: -48, isSecure: true, isKnown: true, isConnected: true)
    let harness = TestHarness(scanResults: [home], locationPermission: .authorized)
    harness.model.start()
    harness.path.send(NetworkPathSnapshot(
        isSatisfied: true,
        interfaces: [PathInterface(name: "en7", kind: .ethernet, ipv4Address: "192.168.1.24")]
    ))
    await harness.model.refresh()

    XCTAssertEqual(harness.model.primaryInterface, .ethernet(name: "en7", ipv4Address: "192.168.1.24"))
    XCTAssertEqual(harness.model.networkSections.flatMap(\.networks), [home])
}
```

Implement `TestHarness` as a small factory around the fakes and add this bounded async helper so tests never use arbitrary sleeps:

```swift
@MainActor
func waitUntil(
    timeout: Duration = .seconds(1),
    condition: @escaping @MainActor () async -> Bool
) async {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !(await condition()), clock.now < deadline {
        await Task.yield()
    }
    let didMeetCondition = await condition()
    XCTAssertTrue(didMeetCondition, "Condition was not met before timeout")
}
```

- [ ] **Step 3: Run the model tests and confirm RED**

Run: `xcodebuild test -project McNetworkMenu.xcodeproj -scheme McNetworkMenu -destination 'platform=macOS' -only-testing:McNetworkMenuTests/NetworkMenuModelTests`

Expected: FAIL because `NetworkMenuModel` does not exist.

- [ ] **Step 4: Implement the minimal observable state machine**

Create `@MainActor final class NetworkMenuModel: ObservableObject` with `@Published private(set)` properties:

```swift
var primaryInterface: PrimaryInterface = .offline
var wifiStatus = WiFiStatus(isPowerOn: false, connectedSSID: nil, rssi: nil)
var networkSections: [WiFiNetworkSection] = []
var scanState: ScanState = .idle
var connectionState: ConnectionState = .idle
var locationPermission: LocationPermission
var launchAtLoginStatus: LaunchAtLoginStatus = .disabled
var pendingPasswordNetwork: WiFiNetwork?
```

Inject all five protocols through `init`. `start()` starts the path monitor once, consumes its stream in a retained task, refreshes Wi-Fi status for each route update, merges the connected SSID into `.wifi`, and reads login-item state. `stop()` cancels tasks and stops the monitor.

`panelDidOpen()` calls `refresh()` unless a scan is already active. `refresh()` requests location permission if necessary, increments a scan generation integer, awaits the scan, and publishes results only when the generation still matches. Preserve old sections while scanning.

`requestPassword(for:)` is the only setter for `pendingPasswordNetwork`; `cancelPasswordPrompt()` clears it. `connect(to:password:)` immediately sets `.connecting(id)`, copies no password into published state, clears `pendingPasswordNetwork`, awaits association, then refreshes status and scan results. On failure publish `.failed(id, DisplayError)`; ensure any local password variable leaves scope after the call. Power, disconnect, login, and system actions follow the same explicit success/failure pattern.

- [ ] **Step 5: Run model tests and full suite**

Run: `make test`

Expected: all state-machine, integration-mapping, Wi-Fi presentation, and route tests PASS.

- [ ] **Step 6: Commit the orchestration layer**

```bash
git add McNetworkMenu/ViewModels/NetworkMenuModel.swift McNetworkMenuTests/TestSupport/Fakes.swift McNetworkMenuTests/ViewModels/NetworkMenuModelTests.swift
git commit -m "feat: coordinate network menu state"
```

---

### Task 8: Build the adaptive SwiftUI menu and dynamic label

**Files:**
- Modify: `McNetworkMenu/App/McNetworkMenuApp.swift`
- Modify: `McNetworkMenu/Views/MenuPanelView.swift`
- Create: `McNetworkMenu/Views/PrimaryConnectionView.swift`
- Create: `McNetworkMenu/Views/WiFiSectionView.swift`
- Create: `McNetworkMenu/Views/NetworkRowView.swift`
- Create: `McNetworkMenu/Views/PasswordPromptView.swift`
- Create: `McNetworkMenu/Views/FooterView.swift`
- Create: `McNetworkMenuTests/Models/AccessibilityCopyTests.swift`

**Interfaces:**
- Consumes: `NetworkMenuModel` and all published state/actions.
- Produces: the complete adaptive panel and icon-only menu-bar experience.

- [ ] **Step 1: Write failing accessibility-copy tests**

```swift
func testPrimaryInterfaceAccessibilityLabelsAreExplicit() {
    XCTAssertEqual(
        PrimaryInterface.ethernet(name: "en7", ipv4Address: nil).accessibilityLabel,
        "Ethernet is the primary network"
    )
    XCTAssertEqual(PrimaryInterface.offline.accessibilityLabel, "No network connection")
}

func testSectionTitlesMatchNativeCompactLanguage() {
    XCTAssertEqual(WiFiNetworkSectionKind.connected.title, "Connected")
    XCTAssertEqual(WiFiNetworkSectionKind.known.title, "Known Networks")
    XCTAssertEqual(WiFiNetworkSectionKind.nearby.title, "Other Networks")
}
```

- [ ] **Step 2: Run the focused test and confirm RED for missing titles**

Run: `xcodebuild test -project McNetworkMenu.xcodeproj -scheme McNetworkMenu -destination 'platform=macOS' -only-testing:McNetworkMenuTests/AccessibilityCopyTests`

Expected: FAIL because `WiFiNetworkSectionKind.title` is not implemented.

- [ ] **Step 3: Implement the live app composition and dynamic label**

Construct production dependencies once in `McNetworkMenuApp.init`, wrap the model in `@StateObject`, and render:

```swift
MenuBarExtra {
    MenuPanelView(model: model)
} label: {
    Image(systemName: model.primaryInterface.symbolName)
        .accessibilityLabel(model.primaryInterface.accessibilityLabel)
}
.menuBarExtraStyle(.window)
```

Start the model from the panel's first `.task`, invoke `panelDidOpen()` from `.onAppear`, and call `stop()` when the app model is deinitialized.

- [ ] **Step 4: Implement the approved adaptive panel**

Use a fixed width of 360 points and a maximum network-list height of 340 points.

- `PrimaryConnectionView`: Ethernet shows the `network` symbol, interface name, `Connected · Primary`, IP address when present, and a green status dot. Wi-Fi shows SSID, signal icon, and primary status. Offline shows `network.slash` and `Not Connected`.
- `WiFiSectionView`: header `Wi-Fi`, native `Toggle`, Refresh button, retained list during progress, permission recovery copy, and inline scan error with Retry.
- `NetworkRowView`: checkmark for connected, lock for secure, signal symbol derived from level, disabled state while connecting, and a row-local progress indicator.
- `PasswordPromptView`: `SecureField`, Cancel, and Join; disable Join for an empty password; clear its local `@State` on cancel and immediately after submission.
- `FooterView`: first-level `Network Settings…`, Launch at Login toggle, `About McNetworkMenu`, and `Quit McNetworkMenu`. Keep Quit visible without opening a submenu.

Use `Divider`, standard `Button`/`Toggle` styles, semantic colors, Dynamic Type-compatible text, and accessibility labels for icon-only Refresh, lock, signal, and connection-state elements.

- [ ] **Step 5: Handle UI actions precisely**

- Selecting the connected network calls `disconnect()`.
- Selecting an open network calls `connect(to:password: nil)`.
- Selecting an unknown secured network calls `requestPassword(for:)` and presents the password sheet from the model's resulting `pendingPasswordNetwork`.
- Selecting a known secured network first attempts `connect(to:password: nil)` so macOS can use remembered configuration; if authentication fails, expose a `Enter Password` retry action.
- Permission denial displays why access is needed and calls `openSettings(.locationPrivacy)`.
- Launch at Login `.requiresApproval` displays `Approval required in System Settings` and a Settings button.

- [ ] **Step 6: Run automated and manual UI checks**

Run: `make test`

Expected: all tests PASS.

Run: `make run`

Expected: no Dock icon; an icon-only item appears in the menu bar; clicking it opens a 360-point adaptive panel; Quit terminates the process.

- [ ] **Step 7: Commit the complete interface**

```bash
git add McNetworkMenu/App McNetworkMenu/Views McNetworkMenu/Models/WiFiNetwork.swift McNetworkMenuTests/Models/AccessibilityCopyTests.swift
git commit -m "feat: build adaptive network menu interface"
```

---

### Task 9: Document real-Mac verification and GitHub usage

**Files:**
- Create: `docs/smoke-tests.md`
- Create: `README.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: all completed app and Make targets.
- Produces: repeatable distribution and hardware-validation instructions.

- [ ] **Step 1: Write the smoke-test checklist with observable results**

Document one checkbox for each scenario and include its expected menu-bar symbol and panel result:

1. Wi-Fi-only satisfied route → `wifi`; current SSID appears first.
2. Ethernet-first route while Wi-Fi remains connected → `network`; Ethernet is primary and Wi-Fi controls remain below.
3. Unsatisfied route → `network.slash`; `Not Connected` appears.
4. Wi-Fi power off/on → toggle and route state converge after the path update.
5. Location not determined → permission appears only after the first scan request.
6. Location denied → explanation plus Settings recovery; no crash or repeated prompt.
7. Open, secured-known, and secured-unknown connection flows → correct immediate join or password prompt.
8. Wrong password and administrator rejection → inline failure with retry; no credential in Console output.
9. Network Settings, About, Launch at Login, and Quit → each action produces its documented system behavior.
10. Logout/login with Launch at Login enabled → menu item returns without a Dock icon.

- [ ] **Step 2: Write the README**

Include:

- macOS 14+ and Xcode 16+ requirements.
- Clone, `make build`, `make test`, `make run`, `make release`, `make clean`, and `make check` commands.
- `SIGNING_IDENTITY='Certificate Name' make release` override and default ad-hoc signing behavior.
- Why location permission is requested and how to restore it in System Settings.
- Public-API limits: administrator approval may be required; Instant Hotspot-specific UI is not replicated; System Settings opens at its public application entry rather than an undocumented pane URL.
- Installation guidance to move the Release `.app` into `/Applications` before enabling Launch at Login.
- A link to `docs/smoke-tests.md`.

- [ ] **Step 3: Ensure generated output stays untracked**

Confirm `.gitignore` contains `.build/`, `DerivedData/`, `xcuserdata/`, `*.xcuserstate`, `.DS_Store`, and `.superpowers/`. Add only any missing entries.

- [ ] **Step 4: Run final verification**

Run: `make check`

Expected, in order: all XCTest cases PASS, clean succeeds, and `** BUILD SUCCEEDED **` appears for Release.

Run: `git status --short`

Expected: only `README.md`, `docs/smoke-tests.md`, and any intentional `.gitignore` change are uncommitted; `.build/` and `.superpowers/` do not appear.

- [ ] **Step 5: Commit documentation**

```bash
git add README.md docs/smoke-tests.md .gitignore
git commit -m "docs: add build and smoke-test guidance"
```

- [ ] **Step 6: Confirm the deliverable history and clean tree**

Run: `git log --oneline --decorate -10`

Expected: one focused commit for each completed task.

Run: `git status --short --branch`

Expected: current branch is clean.
