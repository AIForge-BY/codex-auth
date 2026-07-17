import SwiftUI

@main
struct CodexAuthMenuApp: App {
    @StateObject private var appState: AppState
    @StateObject private var statusItemController: StatusItemController

    /// 创建真实系统提醒展示器，并启动周期刷新和首次用量加载。
    init() {
        let appState = AppState(usageAlertPresenter: SystemUsageAlertPresenter())
        _appState = StateObject(wrappedValue: appState)
        _statusItemController = StateObject(wrappedValue: StatusItemController(appState: appState))
        Task { @MainActor in
            appState.prepareUsageAlerts()
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
