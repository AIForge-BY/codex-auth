import SwiftUI

@main
struct CodexAuthMenuApp: App {
    @StateObject private var appState: AppState

    init() {
        let appState = AppState()
        _appState = StateObject(wrappedValue: appState)
        Task { @MainActor in
            await appState.refreshOnAppLaunch()
        }
    }

    var body: some Scene {
        MenuBarExtra("Codex Auth", systemImage: "person.crop.circle.badge.checkmark") {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("管理账号", id: "manage-accounts") {
            ManageAccountsView()
                .environmentObject(appState)
                .frame(minWidth: 760, minHeight: 480)
        }
    }
}
