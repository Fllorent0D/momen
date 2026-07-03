import SwiftUI
import StandupKit

@main
struct StandupTimerApp: App {
    @State private var manager: MeetingManager
    @State private var proAccess = ProAccessManager()
    private let overlay: OverlayPanel
    @Environment(\.openWindow) private var openWindow

    init() {
        ProAccessManager.configureRevenueCat()
        Analytics.configure()
        let overlay = OverlayPanel()
        self.overlay = overlay
        _manager = State(initialValue: MeetingManager(
            sound: MacSoundPlayer(),
            export: MacExportService(),
            overlay: overlay,
            launchAtLogin: MacLaunchAtLogin()
        ))
    }

    var body: some Scene {
        MenuBarExtra {
            ConfigurationView()
                .environment(manager)
                .environment(proAccess)
                .onAppear {
                    // Wire the overlay's rendered content here so the panel
                    // stays decoupled from the core (it references the manager).
                    overlay.content = { [manager] in
                        AnyView(OverlayView().environment(manager))
                    }
                    manager.openPaywall = { reason in
                        proAccess.presentPaywall(reason)
                    }
                    proAccess.openPaywallWindow = {
                        openWindow(id: "paywall")
                    }
                    manager.isProUnlocked = {
                        proAccess.isProUnlocked
                    }
                    manager.enforceFreePlanIfNeeded(isProUnlocked: proAccess.isProUnlocked)
                    // Synchro iCloud = feature Pro (D9).
                    CloudSyncStore.shared.setEnabled(proAccess.isPurchased)
                }
                .onChange(of: proAccess.isProUnlocked) { _, isUnlocked in
                    manager.enforceFreePlanIfNeeded(isProUnlocked: isUnlocked)
                }
                .onChange(of: proAccess.isPurchased) { _, isPurchased in
                    CloudSyncStore.shared.setEnabled(isPurchased)
                }
        } label: {
            if manager.isActive {
                Text(manager.menuBarLabel)
            } else {
                Label("Momen", systemImage: "timer")
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(manager)
                .environment(proAccess)
        }


        // The Pro screen lives in its own window — a sheet on the menu-bar
        // popover dies the moment a click dismisses the popover.
        Window("Momen Pro", id: "paywall") {
            PaywallView()
                .environment(proAccess)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 420, height: 620)
        .windowStyle(.hiddenTitleBar)

        // Stats get a real resizable window — the participants / history / awards
        // tabs are unreadable crammed into the narrow menu-bar popover.
        Window("Statistiques", id: "stats") {
            StatsWindowView()
                .environment(manager)
                .environment(proAccess)
        }
        .defaultSize(width: 680, height: 720)
        .windowResizability(.contentMinSize)
    }
}
