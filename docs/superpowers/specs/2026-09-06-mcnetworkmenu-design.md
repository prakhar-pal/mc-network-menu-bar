# McNetworkMenu Design Specification

## Objective

McNetworkMenu is a native, menu-bar-only macOS utility that reports which network interface carries the Mac's active default route and provides public-API Wi-Fi controls in a compact SwiftUI panel.

The app targets macOS 14 Sonoma and newer. It is intended for source distribution on GitHub and direct, self-signed local builds rather than the Mac App Store. Its bundle identifier is `com.prakharpal.McNetworkMenu`.

Success means a user can:

- Recognize the active primary interface from the menu bar without opening the panel.
- View Ethernet or Wi-Fi connection status.
- Turn Wi-Fi on or off.
- Scan for, select, connect to, and disconnect from Wi-Fi networks using Apple's public APIs.
- Open the appropriate macOS Network or Privacy settings.
- Enable or disable Launch at Login.
- Quit the app directly from the panel.

## Product Boundaries

### Included

- A menu-bar-only SwiftUI application with no Dock or application-switcher icon.
- A compact adaptive panel that shows the primary interface before Wi-Fi controls.
- Dynamic menu-bar symbols:
  - Wi-Fi symbol when Wi-Fi carries the default route.
  - Network-nodes symbol when Ethernet carries the default route.
  - Slashed-network symbol when no usable route exists.
- Icon-only menu-bar presentation; no live throughput text.
- Ethernet service/interface name, primary status, and IP address.
- Current Wi-Fi network, signal strength, security state, nearby networks, manual refresh, connect, disconnect, and power toggle.
- In-panel password entry for secured networks when a credential is required.
- macOS-managed remembered-network behavior. McNetworkMenu does not maintain its own credential store.
- Network Settings, Privacy Settings when needed, About, Launch at Login, and Quit actions.

### Excluded

- Private or undocumented Apple APIs.
- Mac App Store packaging in the first release.
- A separate Dock application or full diagnostics dashboard.
- Continuous menu-bar throughput counters.
- A McNetworkMenu-owned Wi-Fi password database or Keychain entries.
- Exact recreation of Apple's private Continuity/Instant Hotspot metadata and controls. Personal Hotspots returned by public Wi-Fi scanning may appear as ordinary networks.

## Tech Stack

- Swift and SwiftUI for the application and panel.
- `MenuBarExtra` with `.window` style for the adaptive popover.
- Network framework (`NWPathMonitor`) for path status and interface changes.
- CoreWLAN for Wi-Fi state, scanning, association, disassociation, and power control.
- CoreLocation for the user authorization needed to expose nearby Wi-Fi network names.
- ServiceManagement (`SMAppService.mainApp`) for Launch at Login.
- AppKit (`NSWorkspace`) for opening macOS settings and terminating the application.
- XCTest for automated tests.
- Make as the public developer workflow, wrapping `xcodebuild`.
- No third-party runtime dependencies.

## Commands

The root Makefile is the supported interface. Exact schemes and paths are encapsulated by these targets.

```sh
make build    # Build the Debug macOS application.
make test     # Run the complete XCTest suite.
make clean    # Clean Xcode build products.
make run      # Build and launch McNetworkMenu locally.
make release  # Build the Release configuration.
make check    # Run tests, then produce a clean Release build.
```

## Project Structure

```text
McNetworkMenu.xcodeproj/              Xcode project
McNetworkMenu/
  App/                                App entry point and lifecycle
  Models/                             Immutable UI-facing network state
  Services/                           Public-API framework adapters
  ViewModels/                         Main-actor panel state and actions
  Views/                              SwiftUI panel components
  Resources/                          Assets and Info.plist values
McNetworkMenuTests/
  Models/                             Pure state and sorting tests
  ViewModels/                         State-transition tests with fakes
  Services/                           Adapter-level tests where practical
docs/
  smoke-tests.md                      Hardware-dependent manual checks
  superpowers/specs/                  Approved design specifications
Makefile                              Build, test, clean, run, and release entry points
README.md                             Setup, permissions, signing, and usage
```

## Architecture

### Application shell

`McNetworkMenuApp` owns a single `MenuBarExtra` scene using `.window` style. The app sets `LSUIElement` so it has no Dock or application-switcher presence. The menu-bar label reads from the same current snapshot as the panel, ensuring the icon and displayed primary interface cannot disagree.

### State model

`NetworkMenuModel` is a `@MainActor` observable model. It consumes immutable snapshots from framework adapters and exposes explicit UI states for path status, scanning, Wi-Fi power, association, permissions, and launch-at-login registration.

Frameworks are hidden behind focused protocols:

- `NetworkPathMonitoring` publishes usable-path changes and the preferred interface order.
- `WiFiControlling` reads interface state, scans, associates, disassociates, and changes power.
- `LocationAuthorizing` reports and requests permission.
- `LaunchAtLoginControlling` reads and changes login-item registration.
- `SystemSettingsOpening` opens Network, Wi-Fi, Login Items, or Privacy settings.

Production adapters use Apple frameworks. Tests use deterministic fakes.

### Primary interface selection

The first applicable interface in the current usable path's preference order is the primary interface. Ethernet and Wi-Fi are recognized explicitly. If the path is unsatisfied or contains neither as a usable primary interface, the UI reports offline/other rather than guessing from hardware presence.

When both Ethernet and Wi-Fi are connected, Ethernet is shown only if it is first on the active path. Merely plugging in a cable does not change the icon.

### Wi-Fi operations

Scanning is demand-driven: once when the panel opens, when Wi-Fi becomes available, and when the user presses Refresh. The app does not continuously scan in the background.

CoreWLAN operations execute away from the main actor because scanning and association may block. Each operation carries an identity so stale results cannot overwrite newer state. The last successful network list stays visible during refresh.

Networks are deduplicated by stable scan identity and presented in this order:

1. Currently connected network.
2. Remembered/known networks.
3. Other nearby networks.

Within a section, networks sort by signal strength and then localized display name. Hidden networks without a usable display name are omitted from the normal list and remain accessible through the system Wi-Fi settings handoff.

Selecting an open or already-authorized network starts association immediately. Selecting a secured network that needs a credential opens an in-panel password prompt. Password text is held only for the current attempt, is never logged or persisted by McNetworkMenu, and is cleared when the attempt ends.

## Interface Design

The compact adaptive panel follows standard macOS spacing, materials, controls, and accessibility behavior.

### Primary connection section

- Ethernet: network-nodes symbol, service/interface name, `Connected · Primary`, IP address, and green status indicator.
- Wi-Fi: Wi-Fi symbol, SSID, signal strength, security state, and connection status.
- Offline: slashed-network symbol and `Not Connected`.

### Wi-Fi section

- Native-style on/off toggle.
- Current network first with a checkmark.
- Known and nearby networks with signal and lock indicators.
- Progress indicator while scanning or associating.
- Refresh action.
- Concise inline failures with Retry or a relevant Settings action.

### Footer

- `Network Settings…`
- `Launch at Login` toggle
- `About McNetworkMenu`
- `Quit McNetworkMenu`

Quit is a visible first-level footer action, not hidden inside another menu.

## Permissions and Failure Handling

Location permission is requested just in time when the user first asks to scan for named nearby networks, not at process launch. The usage description explains that macOS protects Wi-Fi network names as location-related information.

If permission is denied, the panel keeps Ethernet and basic path status available, explains why nearby names cannot be displayed, and offers `Open Privacy Settings`.

Expected operational failures are modeled rather than treated as fatal errors:

- No Wi-Fi hardware or unavailable interface.
- Wi-Fi disabled.
- Location permission denied or restricted.
- Scan failure.
- Connection timeout or authentication failure.
- Administrator authorization required or rejected for association/power changes.
- Launch-at-login approval denied.
- Settings URL unavailable.

Errors appear beside the affected control and provide Retry or Settings when actionable. Errors never replace the whole panel, expose credentials, or terminate the app.

## Code Style

- Prefer small value types and narrow protocols.
- Keep Apple-framework objects inside service adapters.
- Keep UI state mutations on `@MainActor`.
- Use structured concurrency at async boundaries; do not block the UI thread.
- Name states and actions by user-visible meaning.
- Use dependency injection through initializers.
- Avoid singletons except framework-mandated shared application objects at the adapter boundary.

Representative style:

```swift
enum PrimaryInterface: Equatable, Sendable {
    case wifi(ssid: String?)
    case ethernet(name: String)
    case offline
}

protocol NetworkPathMonitoring: Sendable {
    var updates: AsyncStream<NetworkPathSnapshot> { get }
    func start()
    func stop()
}
```

## Testing Strategy

Automated XCTest coverage verifies outcomes rather than framework call sequences:

- Default-route selection and Wi-Fi/Ethernet/offline symbol mapping.
- Simultaneous Ethernet and Wi-Fi behavior.
- Network deduplication, grouping, sorting, lock indicators, and signal levels.
- Scan lifecycle and stale-result rejection.
- Connection, disconnection, timeout, authentication failure, and retry states.
- Wi-Fi power transitions and administrator-denial messaging.
- Location authorization states and privacy-settings recovery.
- Launch-at-login registration states and failures.
- Passwords are absent from persisted state and diagnostic descriptions.

Hardware and system UI behavior is covered by a repeatable real-Mac smoke checklist:

- Wi-Fi scanning and association with open and secured networks.
- Ethernet becoming and ceasing to be the default route.
- Correct icon transitions for Wi-Fi, Ethernet, and offline states.
- Administrator and location permission prompts.
- Network and Privacy Settings links.
- Launch at Login after logout/login.
- Menu-bar-only behavior and the visible Quit action.
- Direct launch of the locally signed Release application outside Xcode.

## Boundaries

### Always

- Use only Apple public APIs.
- Run `make check` before declaring a change complete.
- Keep passwords out of logs, persistence, errors, and tests.
- Keep hardware behavior behind protocols and cover domain behavior with fakes.
- Preserve accessible labels for icon-only controls and status indicators.

### Ask first

- Add a third-party dependency.
- Raise the minimum macOS version.
- Change the bundle identifier or signing/distribution strategy.
- Add privileged helpers, daemons, or private entitlements.
- Add persistent user data beyond ordinary preferences.

### Never

- Use private or undocumented Apple APIs.
- Store Wi-Fi credentials in McNetworkMenu-owned storage.
- Claim full Continuity/Instant Hotspot parity that public APIs do not provide.
- Hide failures that require user authorization.
- Require a Dock icon for normal operation.

## Acceptance Criteria

1. `make build`, `make test`, `make clean`, `make run`, `make release`, and `make check` perform the documented actions.
2. The application builds for macOS 14 or newer with bundle identifier `com.prakharpal.McNetworkMenu`.
3. The app runs exclusively from the menu bar and exposes a visible Quit action.
4. The label shows Wi-Fi for a Wi-Fi primary route, network nodes for an Ethernet primary route, and a slashed-network symbol when offline.
5. When both Ethernet and Wi-Fi are connected, the active default route determines the label and primary section.
6. The panel displays the primary interface first and Wi-Fi controls below it.
7. Users can toggle Wi-Fi, refresh scan results, connect, disconnect, and retry supported operations through CoreWLAN.
8. McNetworkMenu does not persist or log entered Wi-Fi passwords.
9. Permission and operational failures remain recoverable through inline actions.
10. Network Settings, Privacy Settings, About, Launch at Login, and Quit work as specified.
11. Automated tests pass, and the real-Mac smoke checklist documents all hardware-dependent verification.
