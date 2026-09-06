import Testing
@testable import McNetworkMenuCore

@Suite("Network menu model", .serialized)
@MainActor
struct NetworkMenuModelTests {
    private let home = WiFiNetwork(
        ssid: "Home", bssid: "AA:BB", rssi: -45,
        isSecure: true, isKnown: true, isConnected: true
    )

    @Test("Route monitoring starts before the panel opens")
    func monitoringStartsOnCreation() async throws {
        let path = FakePathMonitor()
        let model = makeModel(
            path: path,
            wifi: FakeWiFiController(),
            location: FakeLocationAuthorizer(current: .authorized)
        )

        path.send(.init(
            isSatisfied: true,
            interfaces: [.init(name: "en9", kind: .ethernet, ipv4Address: "192.168.29.190")]
        ))
        let receivedRoute = try await waitForPrimaryInterface(
            model,
            .ethernet(name: "en9", ipv4Address: "192.168.29.190")
        )

        #expect(path.startCount == 1)
        #expect(receivedRoute)
        #expect(model.primaryInterface == .ethernet(
            name: "en9",
            ipv4Address: "192.168.29.190"
        ))
    }

    @Test("Wi-Fi route gains connected SSID and Ethernet keeps Wi-Fi data")
    func routeMergingAndRetention() async throws {
        let path = FakePathMonitor()
        let wifi = FakeWiFiController(
            status: .success(.init(isPoweredOn: true, connectedSSID: "Home", rssi: -45)),
            scanPlans: [.init(delayNanoseconds: 0, result: .success([home]))]
        )
        let model = makeModel(path: path, wifi: wifi, location: .init(current: .authorized))

        model.start()
        path.send(.init(isSatisfied: true, interfaces: [.init(name: "en0", kind: .wifi, ipv4Address: "10.0.0.8")]))
        await model.panelOpened()

        #expect(model.primaryInterface == .wifi(interfaceName: "en0", ssid: "Home", ipv4Address: "10.0.0.8"))
        #expect(model.sections.first?.networks == [home])

        path.send(.init(isSatisfied: true, interfaces: [.init(name: "en7", kind: .ethernet, ipv4Address: "192.168.1.24")]))
        let receivedRoute = try await waitForPrimaryInterface(
            model,
            .ethernet(name: "en7", ipv4Address: "192.168.1.24")
        )
        #expect(receivedRoute)
        #expect(model.primaryInterface == .ethernet(name: "en7", ipv4Address: "192.168.1.24"))
        #expect(model.sections.first?.networks == [home])
    }

    @Test("Scan asks just in time and denial prevents CoreWLAN scan")
    func permissionGate() async {
        let wifi = FakeWiFiController(scanPlans: [.init(delayNanoseconds: 0, result: .success([home]))])
        let location = FakeLocationAuthorizer(current: .notDetermined, requested: .denied)
        let model = makeModel(wifi: wifi, location: location)

        await model.refresh()
        let calls = await wifi.calls()

        #expect(location.requestCount == 1)
        #expect(model.locationPermission == .denied)
        #expect(calls.scans == 0)
    }

    @Test("A late scan cannot replace a newer result")
    func rejectsStaleScan() async throws {
        let old = WiFiNetwork(ssid: "Old", bssid: nil, rssi: -50, isSecure: false)
        let newest = WiFiNetwork(ssid: "Newest", bssid: nil, rssi: -40, isSecure: false)
        let wifi = FakeWiFiController(scanPlans: [
            .init(delayNanoseconds: 80_000_000, result: .success([old])),
            .init(delayNanoseconds: 0, result: .success([newest]))
        ])
        let model = makeModel(wifi: wifi, location: .init(current: .authorized))

        let first = Task { await model.refresh() }
        try await Task.sleep(nanoseconds: 10_000_000)
        await model.refresh()
        await first.value

        #expect(model.sections.flatMap(\.networks).map(\.ssid) == ["Newest"])
    }

    @Test("Wi-Fi controls and system actions route through dependencies")
    func controlsAndSystemActions() async {
        let wifi = FakeWiFiController()
        let login = FakeLaunchAtLoginController()
        let system = FakeSystemActions()
        let model = makeModel(wifi: wifi, location: .init(current: .authorized), login: login, system: system)

        model.select(home)
        #expect(await waitForDisconnection(from: wifi))
        await model.setWiFiEnabled(false)
        await model.setLaunchAtLogin(true)
        model.openNetworkSettings()
        model.showAbout()
        model.quit()

        let calls = await wifi.calls()
        #expect(calls.connections.isEmpty)
        #expect(calls.powers == [false])
        #expect(calls.disconnects == 1)
        #expect(login.values == [true])
        #expect(system.settingsCount == 1)
        #expect(system.aboutCount == 1)
        #expect(system.quitCount == 1)
    }

    @Test("Non-current Wi-Fi selections open Network Settings")
    func nonCurrentWiFiSelectionsOpenNetworkSettings() async {
        let nearby = WiFiNetwork(
            ssid: "Nearby", bssid: "11:22", rssi: -50,
            isSecure: true
        )
        let remembered = WiFiNetwork(
            ssid: "Remembered", bssid: "22:33", rssi: -50,
            isSecure: true, isKnown: true
        )
        let open = WiFiNetwork(
            ssid: "Cafe", bssid: "33:44", rssi: -50,
            isSecure: false
        )

        for network in [nearby, remembered, open] {
            let wifi = FakeWiFiController()
            let system = FakeSystemActions()
            let model = makeModel(
                wifi: wifi,
                location: .init(current: .authorized),
                system: system
            )

            model.select(network)

            #expect(model.passwordPrompt == nil)
            #expect(system.settingsCount == 1)
            #expect((await wifi.calls()).connections.isEmpty)
        }
    }

    private func makeModel(
        path: FakePathMonitor = .init(),
        wifi: FakeWiFiController,
        location: FakeLocationAuthorizer,
        login: FakeLaunchAtLoginController? = nil,
        system: FakeSystemActions? = nil
    ) -> NetworkMenuModel {
        NetworkMenuModel(
            pathMonitor: path,
            wifi: wifi,
            location: location,
            launchAtLogin: login ?? FakeLaunchAtLoginController(),
            systemActions: system ?? FakeSystemActions()
        )
    }

    private func waitForPrimaryInterface(
        _ model: NetworkMenuModel,
        _ expected: PrimaryInterface
    ) async throws -> Bool {
        for _ in 0..<100 {
            if model.primaryInterface == expected { return true }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        return false
    }

    private func waitForDisconnection(from wifi: FakeWiFiController) async -> Bool {
        for _ in 0..<100 {
            if (await wifi.calls()).disconnects == 1 { return true }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return false
    }
}
