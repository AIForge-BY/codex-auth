import XCTest
@testable import CodexAuthApp

@MainActor
final class AppStateTests: XCTestCase {
    func testSwitchUpdatesStateAndChineseMessage() async throws {
        let initial = CodexAuthState.empty(codexHome: "/tmp/codex")
        let switched = CodexAuthState(
            schemaVersion: 1,
            codexHome: "/tmp/codex",
            activeAccountKey: "acct-2",
            generatedAt: Date(timeIntervalSince1970: 0),
            refresh: RefreshInfo(attempted: false, status: "skipped", message: nil),
            warnings: [],
            accounts: [
                CodexAccount.sample(accountKey: "acct-2", alias: "备用号", isActive: true)
            ]
        )
        let client = StubCodexAuthClient(state: initial)
        client.switchState = switched
        let appState = AppState(client: client)

        await appState.refresh()
        await appState.switchAccount(accountKey: "acct-2")

        XCTAssertEqual(appState.state?.activeAccountKey, "acct-2")
        XCTAssertEqual(appState.notice, "已切换账号。新的 Codex CLI 会话将使用此账号。")
    }

    func testDeleteRequiresConfirmation() {
        let appState = AppState(client: StubCodexAuthClient(state: .empty(codexHome: "/tmp/codex")))
        let account = CodexAccount.sample(accountKey: "acct-1", alias: "工作号", isActive: true)

        appState.requestDelete(account)

        XCTAssertEqual(appState.pendingDeleteAccount?.accountKey, "acct-1")
        XCTAssertTrue(appState.isShowingDeleteConfirmation)
    }

    func testLoginUpdatesStateAndChineseMessage() async {
        let loggedIn = CodexAuthState(
            schemaVersion: 1,
            codexHome: "/tmp/codex",
            activeAccountKey: "acct-1",
            generatedAt: Date(timeIntervalSince1970: 0),
            refresh: RefreshInfo(attempted: false, status: "skipped", message: nil),
            warnings: [],
            accounts: [
                CodexAccount.sample(accountKey: "acct-1", alias: "工作号", isActive: true)
            ]
        )
        let client = StubCodexAuthClient(state: .empty(codexHome: "/tmp/codex"))
        client.loginState = loggedIn
        let appState = AppState(client: client)

        await appState.login()

        XCTAssertEqual(appState.state?.activeAccountKey, "acct-1")
        XCTAssertEqual(appState.notice, "已添加账号。")
    }

    func testLoginWithAliasPersistsAliasOnNewActiveAccount() async {
        let loggedIn = CodexAuthState(
            schemaVersion: 1,
            codexHome: "/tmp/codex",
            activeAccountKey: "acct-1",
            generatedAt: Date(timeIntervalSince1970: 0),
            refresh: RefreshInfo(attempted: false, status: "skipped", message: nil),
            warnings: [],
            accounts: [
                CodexAccount.sample(accountKey: "acct-1", alias: nil, isActive: true)
            ]
        )
        let renamed = CodexAuthState(
            schemaVersion: 1,
            codexHome: "/tmp/codex",
            activeAccountKey: "acct-1",
            generatedAt: Date(timeIntervalSince1970: 0),
            refresh: RefreshInfo(attempted: false, status: "skipped", message: nil),
            warnings: [],
            accounts: [
                CodexAccount.sample(accountKey: "acct-1", alias: "工作号", isActive: true)
            ]
        )
        let client = StubCodexAuthClient(state: .empty(codexHome: "/tmp/codex"))
        client.loginState = loggedIn
        client.aliasState = renamed
        let appState = AppState(client: client)

        await appState.login(alias: "工作号")

        XCTAssertEqual(client.setAliasAccountKey, "acct-1")
        XCTAssertEqual(client.setAliasValue, "工作号")
        XCTAssertEqual(appState.state?.activeAccount?.primaryLabel, "工作号")
        XCTAssertEqual(appState.notice, "已添加账号并设置别名。")
    }

    func testSetAliasUpdatesStateAndChineseMessage() async {
        let renamed = CodexAuthState(
            schemaVersion: 1,
            codexHome: "/tmp/codex",
            activeAccountKey: "acct-1",
            generatedAt: Date(timeIntervalSince1970: 0),
            refresh: RefreshInfo(attempted: false, status: "skipped", message: nil),
            warnings: [],
            accounts: [
                CodexAccount.sample(accountKey: "acct-1", alias: "新名字", isActive: true)
            ]
        )
        let client = StubCodexAuthClient(state: .empty(codexHome: "/tmp/codex"))
        client.aliasState = renamed
        let appState = AppState(client: client)

        await appState.setAlias(accountKey: "acct-1", alias: "新名字")

        XCTAssertEqual(appState.state?.accounts.first?.primaryLabel, "新名字")
        XCTAssertEqual(appState.notice, "已更新别名。")
    }

    func testOpenCodexSessionUsesDirectoryAndChineseMessage() async {
        let client = StubCodexAuthClient(state: .empty(codexHome: "/tmp/codex"))
        let appState = AppState(client: client)

        await appState.openNewCodexSession(at: "/Users/me/project")

        XCTAssertEqual(client.openedSessionDirectoryPath, "/Users/me/project")
        XCTAssertEqual(appState.notice, "已打开 Codex，会恢复最近会话或创建新会话。")
    }

    func testRefreshOnAppLaunchRunsUsageRefreshOnlyOnce() async {
        let client = StubCodexAuthClient(state: .empty(codexHome: "/tmp/codex"))
        let appState = AppState(client: client)

        await appState.refreshOnAppLaunch()
        await appState.refreshOnAppLaunch()

        XCTAssertEqual(client.refreshCallCount, 1)
        XCTAssertEqual(client.loadStateCallCount, 0)
    }

    func testRefreshOnMenuOpenRunsUsageRefreshEveryTime() async {
        let client = StubCodexAuthClient(state: .empty(codexHome: "/tmp/codex"))
        let appState = AppState(client: client)

        await appState.refreshOnMenuOpen()
        await appState.refreshOnMenuOpen()

        XCTAssertEqual(client.refreshCallCount, 2)
        XCTAssertEqual(client.loadStateCallCount, 0)
    }

    func testPeriodicRefreshTickRunsUsageRefresh() async {
        let client = StubCodexAuthClient(state: .empty(codexHome: "/tmp/codex"))
        let appState = AppState(client: client)

        await appState.refreshOnPeriodicTimer()

        XCTAssertEqual(client.refreshCallCount, 1)
        XCTAssertEqual(client.loadStateCallCount, 0)
    }

    /// 验证 25% 和 10% 阈值各提醒一次，并在额度恢复后重新开放提醒资格。
    func testUsageAlertsTriggerOncePerThresholdAndResetAfterRecovery() async {
        let client = StubCodexAuthClient(state: makeUsageState(remainingPercent: 24))
        let presenter = RecordingUsageAlertPresenter()
        let appState = AppState(client: client, usageAlertPresenter: presenter)

        appState.prepareUsageAlerts()
        await appState.refresh()
        client.state = makeUsageState(remainingPercent: 20)
        await appState.refresh()
        client.state = makeUsageState(remainingPercent: 9)
        await appState.refresh()
        await appState.refresh()
        client.state = makeUsageState(remainingPercent: 30)
        await appState.refresh()
        client.state = makeUsageState(remainingPercent: 24)
        await appState.refresh()

        XCTAssertEqual(presenter.prepareCallCount, 1)
        XCTAssertEqual(presenter.alerts.map(\.threshold), [25, 10, 25])
        XCTAssertEqual(presenter.alerts.map(\.remainingPercent), [24, 9, 24])
        XCTAssertTrue(presenter.alerts.allSatisfy { $0.windowLabel == "7 天" })
    }

    /// 验证刷新失败和缺失窗口不会产生低额度提醒。
    func testUsageAlertsIgnoreUnavailableWindows() async {
        let unavailableWindow = UsageWindow(
            status: "network_error",
            remainingPercent: nil,
            total: nil,
            used: nil,
            resetAt: nil
        )
        let client = StubCodexAuthClient(state: makeUsageState(sevenDay: unavailableWindow))
        let presenter = RecordingUsageAlertPresenter()
        let appState = AppState(client: client, usageAlertPresenter: presenter)

        await appState.refresh()

        XCTAssertTrue(presenter.alerts.isEmpty)
    }

    func testSwitchResultIsNotOverwrittenByOlderRefresh() async {
        let original = CodexAuthState(
            schemaVersion: 1,
            codexHome: "/tmp/codex",
            activeAccountKey: "acct-1",
            generatedAt: Date(timeIntervalSince1970: 0),
            refresh: RefreshInfo(attempted: false, status: "skipped", message: nil),
            warnings: [],
            accounts: [
                CodexAccount.sample(accountKey: "acct-1", alias: "原账号", isActive: true),
                CodexAccount.sample(accountKey: "acct-2", alias: "新账号", isActive: false),
            ]
        )
        let switched = CodexAuthState(
            schemaVersion: 1,
            codexHome: "/tmp/codex",
            activeAccountKey: "acct-2",
            generatedAt: Date(timeIntervalSince1970: 1),
            refresh: RefreshInfo(attempted: false, status: "skipped", message: nil),
            warnings: [],
            accounts: [
                CodexAccount.sample(accountKey: "acct-1", alias: "原账号", isActive: false),
                CodexAccount.sample(accountKey: "acct-2", alias: "新账号", isActive: true),
            ]
        )
        let client = DelayedRefreshCodexAuthClient(refreshState: original, switchState: switched)
        let appState = AppState(client: client)

        let refreshTask = Task { await appState.refreshOnMenuOpen() }
        await client.waitUntilRefreshStarted()

        await appState.switchAccount(accountKey: "acct-2")
        client.finishRefresh()
        await refreshTask.value

        XCTAssertEqual(appState.state?.activeAccountKey, "acct-2")
        XCTAssertEqual(appState.notice, "已切换账号。新的 Codex CLI 会话将使用此账号。")
    }
}

/// 记录提醒展示调用，避免单元测试访问真实系统通知中心。
@MainActor
final class RecordingUsageAlertPresenter: UsageAlertPresenting {
    private(set) var prepareCallCount = 0
    private(set) var alerts: [UsageAlert] = []

    /// 记录通知权限准备调用，不访问真实系统通知中心。
    func prepare() {
        prepareCallCount += 1
    }

    /// 记录阈值提醒，供 AppState 测试断言。
    func present(_ alert: UsageAlert) {
        alerts.append(alert)
    }
}

/// 创建仅包含 7 天窗口的测试状态，默认窗口状态为可用。
private func makeUsageState(
    remainingPercent: Int? = nil,
    sevenDay: UsageWindow? = nil
) -> CodexAuthState {
    let resolvedSevenDay = sevenDay ?? UsageWindow(
        status: "ok",
        remainingPercent: remainingPercent,
        total: 100,
        used: remainingPercent.map { 100 - $0 },
        resetAt: nil
    )
    let account = CodexAccount(
        accountKey: "acct-alert",
        displayName: "提醒账号",
        alias: "提醒账号",
        email: "alert@example.com",
        accountName: nil,
        plan: "pro",
        authMode: "chatgpt",
        isActive: true,
        usage: UsageInfo(fiveHour: nil, sevenDay: resolvedSevenDay),
        lastUsageAt: nil,
        lastRefreshAt: nil
    )
    return CodexAuthState(
        schemaVersion: 1,
        codexHome: "/tmp/codex",
        activeAccountKey: account.accountKey,
        generatedAt: Date(timeIntervalSince1970: 0),
        refresh: RefreshInfo(attempted: true, status: "ok", message: nil),
        warnings: [],
        accounts: [account]
    )
}

final class StubCodexAuthClient: CodexAuthClientProtocol {
    var state: CodexAuthState
    var switchState: CodexAuthState?
    var loginState: CodexAuthState?
    var aliasState: CodexAuthState?
    var openedSessionDirectoryPath: String?
    var setAliasAccountKey: String?
    var setAliasValue: String?
    var loadStateCallCount = 0
    var refreshCallCount = 0

    init(state: CodexAuthState) {
        self.state = state
    }

    func loadState(apiMode: CodexAuthAPIMode) async throws -> CodexAuthState {
        loadStateCallCount += 1
        return state
    }

    func refresh(apiMode: CodexAuthAPIMode) async throws -> CodexAuthState {
        refreshCallCount += 1
        return state
    }

    func switchAccount(accountKey: String) async throws -> CodexAuthState {
        switchState ?? state
    }

    func removeAccount(accountKey: String) async throws -> CodexAuthState {
        state
    }

    func setAlias(accountKey: String, alias: String) async throws -> CodexAuthState {
        setAliasAccountKey = accountKey
        setAliasValue = alias
        return aliasState ?? state
    }

    func clearAlias(accountKey: String) async throws -> CodexAuthState {
        state
    }

    func login() async throws -> CodexAuthState {
        loginState ?? state
    }

    func importAuth(path: String, alias: String?) async throws -> CodexAuthState {
        state
    }

    func openNewCodexSession(at directoryPath: String) async throws {
        openedSessionDirectoryPath = directoryPath
    }
}

@MainActor
final class DelayedRefreshCodexAuthClient: CodexAuthClientProtocol {
    let refreshState: CodexAuthState
    let switchState: CodexAuthState
    private var refreshContinuation: CheckedContinuation<Void, Never>?
    private var refreshStartedContinuation: CheckedContinuation<Void, Never>?

    init(refreshState: CodexAuthState, switchState: CodexAuthState) {
        self.refreshState = refreshState
        self.switchState = switchState
    }

    func waitUntilRefreshStarted() async {
        if refreshContinuation != nil {
            return
        }
        await withCheckedContinuation { continuation in
            refreshStartedContinuation = continuation
        }
    }

    func finishRefresh() {
        refreshContinuation?.resume()
        refreshContinuation = nil
    }

    func loadState(apiMode: CodexAuthAPIMode) async throws -> CodexAuthState {
        refreshState
    }

    func refresh(apiMode: CodexAuthAPIMode) async throws -> CodexAuthState {
        await withCheckedContinuation { continuation in
            refreshContinuation = continuation
            refreshStartedContinuation?.resume()
            refreshStartedContinuation = nil
        }
        return refreshState
    }

    func switchAccount(accountKey: String) async throws -> CodexAuthState {
        switchState
    }

    func removeAccount(accountKey: String) async throws -> CodexAuthState {
        refreshState
    }

    func setAlias(accountKey: String, alias: String) async throws -> CodexAuthState {
        refreshState
    }

    func clearAlias(accountKey: String) async throws -> CodexAuthState {
        refreshState
    }

    func login() async throws -> CodexAuthState {
        refreshState
    }

    func importAuth(path: String, alias: String?) async throws -> CodexAuthState {
        refreshState
    }

    func openNewCodexSession(at directoryPath: String) async throws {}
}
