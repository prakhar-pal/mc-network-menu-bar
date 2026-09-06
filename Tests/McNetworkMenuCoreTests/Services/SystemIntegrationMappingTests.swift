import CoreLocation
import ServiceManagement
import Testing
@testable import McNetworkMenuCore

@Suite("System integration mappings")
struct SystemIntegrationMappingTests {
    @Test("Core Location authorization states remain distinct")
    func locationMapping() throws {
        #expect(LocationAuthorizationMapper.map(.authorizedAlways) == .authorized)
        let whenInUse = try #require(CLAuthorizationStatus(rawValue: 4))
        #expect(LocationAuthorizationMapper.map(whenInUse) == .authorized)
        #expect(LocationAuthorizationMapper.map(.notDetermined) == .notDetermined)
        #expect(LocationAuthorizationMapper.map(.denied) == .denied)
        #expect(LocationAuthorizationMapper.map(.restricted) == .restricted)
    }

    @Test("Service Management status maps to domain state")
    func loginItemMapping() {
        #expect(LaunchAtLoginStatusMapper.map(.enabled) == .enabled)
        #expect(LaunchAtLoginStatusMapper.map(.requiresApproval) == .requiresApproval)
        #expect(LaunchAtLoginStatusMapper.map(.notRegistered) == .disabled)
        #expect(LaunchAtLoginStatusMapper.map(.notFound) == .notFound)
    }
}
