import SwiftUI
import McNetworkMenuCore

struct PasswordPromptView: View {
    let network: WiFiNetwork
    let onJoin: (String) async -> Void
    let onCancel: () -> Void
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Join \(network.ssid)").font(.headline)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .onSubmit(join)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Join", action: join)
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private func join() {
        let credential = password
        password = ""
        Task { await onJoin(credential) }
    }
}
