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
            appState.startPeriodicRefresh()
            await appState.refreshOnAppLaunch()
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
