import Testing
@testable import McNetworkMenuCore

@Suite("IPv4 address lookup")
struct IPv4AddressLookupTests {
    @Test("Lookup selects only IPv4 records for the requested interface")
    func selectsRequestedIPv4Record() {
        let records = [
            InterfaceAddressRecord(interfaceName: "en0", family: .ipv6, address: "fe80::1"),
            InterfaceAddressRecord(interfaceName: "en7", family: .ipv4, address: "192.168.1.24"),
            InterfaceAddressRecord(interfaceName: "en0", family: .ipv4, address: "10.0.0.8")
        ]

        #expect(IPv4AddressLookup.address(for: "en7", in: records) == "192.168.1.24")
        #expect(IPv4AddressLookup.address(for: "en9", in: records) == nil)
    }
}
