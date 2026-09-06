# Repository Guidelines

## Project Structure & Module Organization

McNetworkMenu is a Swift Package targeting macOS 14+. `Sources/McNetworkMenu/` contains the SwiftUI menu-bar app and views; keep presentation code here. `Sources/McNetworkMenuCore/` contains models, service protocols and Apple-backed integrations, plus `NetworkMenuModel`. Mirror these boundaries under `Tests/McNetworkMenuCoreTests/` and `Tests/McNetworkMenuUITests/`. Shared test doubles belong in `Tests/McNetworkMenuCoreTests/TestSupport/`. App metadata lives in `Support/Info.plist`; design notes and manual hardware checks live under `docs/`.

## Build, Test, and Development Commands

Use the Makefile and Swift CLI; this repository intentionally has no Xcode project.

- `make build`: create an ad-hoc-signed Debug app in `.build/apps/debug/`.
- `make run`: build and open the Debug app.
- `make test`: run the hardware-free Swift test suite.
- `make release`: create and verify `.build/apps/release/McNetworkMenu.app`.
- `make check`: run all tests, then build and verify the Release bundle.
- `make clean`: remove generated `.build/` output.

Override `SDKROOT` or `SIGNING_IDENTITY` only when the local toolchain or signing setup requires it.

## Coding Style & Naming Conventions

Use four-space indentation and standard Swift API naming: `UpperCamelCase` for types, `lowerCamelCase` for methods and properties. Suffix SwiftUI components with `View`, protocols with capability-oriented names such as `NetworkPathMonitoring`, and test doubles with `Fake`. Prefer small value types conforming to `Equatable` and `Sendable`; isolate UI state with `@MainActor` and external operations with actors where appropriate. No formatter or linter is configured, so match nearby code and treat compiler warnings carefully.

## Testing Guidelines

Tests use Swift Testing (`@Suite`, `@Test`, and `#expect`). Give tests behavior-focused names, for example `"Route monitoring starts before the panel opens"`. Reproduce bugs with a failing test before changing production code. Keep automated checks deterministic: use mock path, Wi-Fi, permission, login-item, and application-action data rather than requiring network hardware. Run `make check` before submission.

## Commit & Pull Request Guidelines

History follows Conventional Commit prefixes such as `feat:`, `fix:`, and `docs:`. Write focused, imperative subjects, e.g. `fix: draw Ethernet icon with angle brackets`. Pull requests should explain the user-visible outcome, note verification performed, link relevant issues, and include before/after screenshots for UI changes. Keep unrelated refactors separate.

## Security & Platform Constraints

Use public Apple APIs only. Never log or persist Wi-Fi credentials, bypass macOS permission prompts, or manage remembered networks outside CoreWLAN behavior. Preserve the project’s GitHub self-publishing and ad-hoc/self-signed distribution model.

## Agent-Specific Instructions

Do not create or use Git worktrees. Work only in the current checkout and preserve unrelated user changes.
