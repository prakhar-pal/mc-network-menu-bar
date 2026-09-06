import CoreWLAN
import Foundation

public struct CoreWLANNetworkRecord: Equatable, Sendable {
    public let ssid: String?
    public let bssid: String?
    public let rssi: Int
    public let supportsOpenSecurity: Bool

    public init(ssid: String?, bssid: String?, rssi: Int, supportsOpenSecurity: Bool) {
        self.ssid = ssid
        self.bssid = bssid
        self.rssi = rssi
        self.supportsOpenSecurity = supportsOpenSecurity
    }
}

public enum CoreWLANNetworkMapper {
    public static func map(
        _ record: CoreWLANNetworkRecord,
        knownSSIDs: Set<String>,
        connectedSSID: String?
    ) -> WiFiNetwork? {
        guard let ssid = record.ssid,
              !ssid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return WiFiNetwork(
            ssid: ssid,
            bssid: record.bssid,
            rssi: record.rssi,
            isSecure: !record.supportsOpenSecurity,
            isKnown: knownSSIDs.contains(ssid),
            isConnected: connectedSSID == ssid
        )
    }
}

public actor CoreWLANController: WiFiControlling {
    private let client: CWWiFiClient
    private let interface: CWInterface?
    private var scanCache: [String: CWNetwork] = [:]

    public init(client: CWWiFiClient = .shared()) {
        self.client = client
        interface = client.interface()
    }

    public func status() async throws -> WiFiStatus {
        guard let interface else { throw DisplayError("No Wi-Fi interface is available.") }
        return WiFiStatus(
            isPoweredOn: interface.powerOn(),
            connectedSSID: interface.ssid(),
            rssi: interface.ssid() == nil ? nil : interface.rssiValue()
        )
    }

    public func scan() async throws -> [WiFiNetwork] {
        guard let interface else { throw DisplayError("No Wi-Fi interface is available.") }
        do {
            let scanned = try interface.scanForNetworks(withSSID: nil, includeHidden: false)
            let profileObjects = interface.configuration()?.networkProfiles.array ?? []
            let knownSSIDs = Set(profileObjects.compactMap { ($0 as? CWNetworkProfile)?.ssid })
            let connectedSSID = interface.ssid()
            var cache: [String: CWNetwork] = [:]

            let mapped = scanned.compactMap { network -> WiFiNetwork? in
                let record = CoreWLANNetworkRecord(
                    ssid: network.ssid,
                    bssid: network.bssid,
                    rssi: network.rssiValue,
                    supportsOpenSecurity: network.supportsSecurity(.none)
                )
                guard let value = CoreWLANNetworkMapper.map(
                    record,
                    knownSSIDs: knownSSIDs,
                    connectedSSID: connectedSSID
                ) else { return nil }
                cache[value.id] = network
                return value
            }
            scanCache = cache
            return mapped
        } catch {
            throw DisplayError("Wi-Fi networks could not be scanned.")
        }
    }

    public func setPower(_ enabled: Bool) async throws {
        guard let interface else { throw DisplayError("No Wi-Fi interface is available.") }
        do {
            try interface.setPower(enabled)
        } catch {
            throw DisplayError("Wi-Fi power could not be changed.")
        }
    }

    public func connect(to networkID: String, password: String?) async throws {
        guard let interface else { throw DisplayError("No Wi-Fi interface is available.") }
        guard let network = scanCache[networkID] else {
            throw DisplayError("Refresh networks and try again.")
        }
        do {
            try interface.associate(to: network, password: password)
        } catch {
            throw DisplayError("Could not join the Wi-Fi network.")
        }
    }

    public func disconnect() async throws {
        guard let interface else { throw DisplayError("No Wi-Fi interface is available.") }
        interface.disassociate()
    }
}
