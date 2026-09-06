import Testing
@testable import McNetworkMenuCore

@Suite("CoreWLAN mapping")
struct CoreWLANMappingTests {
    @Test("A visible record preserves security and connection metadata")
    func mapsVisibleRecord() throws {
        let record = CoreWLANNetworkRecord(
            ssid: "Home",
            bssid: "AA:BB",
            rssi: -48,
            supportsOpenSecurity: false
        )

        let network = try #require(
            CoreWLANNetworkMapper.map(record, knownSSIDs: ["Home"], connectedSSID: "Home")
        )

        #expect(network == WiFiNetwork(
            ssid: "Home", bssid: "AA:BB", rssi: -48,
            isSecure: true, isKnown: true, isConnected: true
        ))
    }

    @Test("Missing and blank SSIDs are hidden while open security stays open")
    func filtersHiddenRecords() throws {
        #expect(CoreWLANNetworkMapper.map(
            CoreWLANNetworkRecord(ssid: nil, bssid: nil, rssi: -40, supportsOpenSecurity: true),
            knownSSIDs: [], connectedSSID: nil
        ) == nil)
        #expect(CoreWLANNetworkMapper.map(
            CoreWLANNetworkRecord(ssid: "  ", bssid: nil, rssi: -40, supportsOpenSecurity: true),
            knownSSIDs: [], connectedSSID: nil
        ) == nil)

        let open = try #require(CoreWLANNetworkMapper.map(
            CoreWLANNetworkRecord(ssid: "Cafe", bssid: nil, rssi: -60, supportsOpenSecurity: true),
            knownSSIDs: [], connectedSSID: nil
        ))
        #expect(!open.isSecure)
    }

    @Test("A known secured network resolves its saved passphrase")
    func knownSecuredNetworkResolvesSavedPassphrase() {
        var lookupCount = 0

        let resolution = CoreWLANPassphrase.resolve(
            entered: nil,
            isSecure: true,
            isKnown: true,
            savedPassword: {
                lookupCount += 1
                return "saved-password"
            }
        )

        #expect(resolution == .passphrase("saved-password"))
        #expect(lookupCount == 1)
    }

    @Test("Open and manually entered associations do not read saved passphrases")
    func openAndManuallyEnteredNetworksSkipSavedPassphraseLookup() {
        var lookupCount = 0
        let lookup = {
            lookupCount += 1
            return "saved-password"
        }

        let open = CoreWLANPassphrase.resolve(
            entered: nil,
            isSecure: false,
            isKnown: true,
            savedPassword: lookup
        )
        let entered = CoreWLANPassphrase.resolve(
            entered: "typed-password",
            isSecure: true,
            isKnown: true,
            savedPassword: lookup
        )

        #expect(open == .passphrase(nil))
        #expect(entered == .passphrase("typed-password"))
        #expect(lookupCount == 0)
    }
}
