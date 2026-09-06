# Deferred real-Mac smoke tests

These checks require real interfaces, authorization prompts, keychain state, or GUI effects. They are intentionally not executed or marked as passed during the current mock-only phase.

## Default route and menu-bar presentation

- [ ] With Wi-Fi carrying the default route, the menu-bar symbol is `wifi` and the panel identifies Wi-Fi as primary.
- [ ] With Ethernet carrying the default route while Wi-Fi remains enabled, the symbol changes to the network-nodes `network` icon, Ethernet appears first, and Wi-Fi controls remain available below.
- [ ] With no usable route, the symbol changes to `network.slash` and the panel reports Offline.
- [ ] Route changes update without relaunching the app.

## Wi-Fi and permission behavior

- [ ] Opening the panel for the first named scan asks for Location access only when status is not determined.
- [ ] Granting access displays nearby SSIDs and correct Connected, Known Networks, and Other Networks groups.
- [ ] Denying or restricting access shows guidance without repeatedly prompting or starting a named scan.
- [ ] Wi-Fi power can be turned off and back on from the panel.
- [ ] A visible open network can be joined without a password prompt.
- [ ] A remembered secure network can be joined with macOS-managed credentials.
- [ ] An unknown secure network shows the secure password prompt and joins with a valid password.
- [ ] A wrong password reports a sanitized failure and the entered password is cleared.
- [ ] Disconnect ends the current Wi-Fi association.
- [ ] An administrator or system-policy rejection produces sanitized user-facing feedback.

## System integration

- [ ] Network Settings opens the System Settings application.
- [ ] About displays the standard About panel for McNetworkMenu.
- [ ] After installing in `/Applications`, enabling Launch at Login registers the main app and survives logout/login.
- [ ] A `requiresApproval` login-item result is explained in the panel.
- [ ] Disabling Launch at Login unregisters the app.
- [ ] The app has no Dock icon while running.
- [ ] Quit McNetworkMenu terminates the app and removes its menu-bar item.
