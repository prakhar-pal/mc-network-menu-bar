import ServiceManagement

public enum LaunchAtLoginStatusMapper {
    public static func map(_ status: SMAppService.Status) -> LaunchAtLoginStatus {
        switch status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notRegistered: return .disabled
        case .notFound: return .notFound
        @unknown default: return .notFound
        }
    }
}

@MainActor
public final class AppleLaunchAtLoginController: LaunchAtLoginControlling {
    private let service: SMAppService

    public init(service: SMAppService = .mainApp) {
        self.service = service
    }

    public func status() async -> LaunchAtLoginStatus {
        LaunchAtLoginStatusMapper.map(service.status)
    }

    public func setEnabled(_ enabled: Bool) async throws -> LaunchAtLoginStatus {
        do {
            if enabled {
                try service.register()
            } else {
                try await service.unregister()
            }
            return LaunchAtLoginStatusMapper.map(service.status)
        } catch {
            throw DisplayError(enabled
                ? "Launch at Login could not be enabled."
                : "Launch at Login could not be disabled.")
        }
    }
}
