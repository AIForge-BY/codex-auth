import SwiftUI

@main
struct CodexAuthMenuApp: App {
    @StateObject private var appState: AppState
    @StateObject private var statusItemController: StatusItemController

    init() {
        let appState = AppState()
        _appState = StateObject(wrappedValue: appState)
        _statusItemController = StateObject(wrappedValue: StatusItemController(appState: appState))
        Task { @MainActor in
            await appState.refreshOnAppLaunch()
        }
    }

    var body: some Scene {
        WindowGroup("管理账号", id: "manage-accounts") {
            ManageAccountsView()
                .environmentObject(appState)
                .frame(minWidth: 760, minHeight: 480)
        }
    }
}
