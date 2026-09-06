import CoreWLAN
import Foundation
import Security

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

enum CoreWLANPassphrase: Equatable {
    case passphrase(String?)
    case unavailableSavedPassword

    static func resolve(
        entered: String?,
        isSecure: Bool,
        isKnown: Bool,
        savedPassword: () -> String?
    ) -> CoreWLANPassphrase {
        if let entered { return .passphrase(entered) }
        guard isSecure, isKnown else { return .passphrase(nil) }
        guard let savedPassword = savedPassword(), !savedPassword.isEmpty else {
            return .unavailableSavedPassword
        }
        return .passphrase(savedPassword)
    }
}

enum CoreWLANKeychain {
    static func password(for ssid: String) -> String? {
        password(for: ssid) { domain, ssidData in
            findPassword(in: domain, for: ssidData)
        }
    }

    static func password(
        for ssid: String,
        find: (CWKeychainDomain, Data) -> String?
    ) -> String? {
        guard let ssidData = ssid.data(using: .utf8) else { return nil }
        return find(.user, ssidData) ?? find(.system, ssidData)
    }

    private static func findPassword(in domain: CWKeychainDomain, for ssidData: Data) -> String? {
        var password: NSString?
        let status = CWKeychainFindWiFiPassword(domain, ssidData, &password)
        guard status == errSecSuccess else { return nil }
        return password as String?
    }
}

public actor CoreWLANController: WiFiControlling {
    private struct CachedNetwork {
        let network: CWNetwork
        let ssid: String
        let isSecure: Bool
        let isKnown: Bool
    }

    private let client: CWWiFiClient
    private let interface: CWInterface?
    private var scanCache: [String: CachedNetwork] = [:]

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
            var cache: [String: CachedNetwork] = [:]

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
                cache[value.id] = CachedNetwork(
                    network: network,
                    ssid: value.ssid,
                    isSecure: value.isSecure,
                    isKnown: value.isKnown
                )
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
        guard let cachedNetwork = scanCache[networkID] else {
            throw DisplayError("Refresh networks and try again.")
        }
        do {
            let resolution = CoreWLANPassphrase.resolve(
                entered: password,
                isSecure: cachedNetwork.isSecure,
                isKnown: cachedNetwork.isKnown,
                savedPassword: { CoreWLANKeychain.password(for: cachedNetwork.ssid) }
            )
            guard case let .passphrase(passphrase) = resolution else {
                throw DisplayError("Saved Wi-Fi password is unavailable. Open Network Settings to reconnect.")
            }
            try interface.associate(to: cachedNetwork.network, password: passphrase)
        } catch {
            throw (error as? DisplayError) ?? DisplayError("Could not join the Wi-Fi network.")
        }
    }

    public func disconnect() async throws {
        guard let interface else { throw DisplayError("No Wi-Fi interface is available.") }
        interface.disassociate()
    }
}
