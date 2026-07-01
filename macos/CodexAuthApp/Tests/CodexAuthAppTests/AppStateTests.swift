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
        XCTAssertEqual(appState.notice, "已在 Ghostty 打开新的 Codex 会话。")
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
