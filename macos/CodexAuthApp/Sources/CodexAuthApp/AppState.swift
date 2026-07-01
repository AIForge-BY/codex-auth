import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var state: CodexAuthState?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var notice: String?
    @Published var pendingDeleteAccount: CodexAccount?

    private let client: CodexAuthClientProtocol
    private var didRefreshOnAppLaunch = false

    init(client: CodexAuthClientProtocol = CodexAuthCLIClient()) {
        self.client = client
    }

    var isShowingDeleteConfirmation: Bool {
        pendingDeleteAccount != nil
    }

    func refresh(apiMode: CodexAuthAPIMode = .automatic) async {
        await load { try await client.loadState(apiMode: apiMode) }
    }

    func refreshOnAppLaunch(apiMode: CodexAuthAPIMode = .automatic) async {
        guard !didRefreshOnAppLaunch else {
            return
        }
        didRefreshOnAppLaunch = true
        await refreshUsage(apiMode: apiMode)
    }

    func refreshOnMenuOpen(apiMode: CodexAuthAPIMode = .automatic) async {
        guard !isLoading else {
            return
        }
        await refreshUsage(apiMode: apiMode)
    }

    func refreshUsage(apiMode: CodexAuthAPIMode = .automatic) async {
        await load { try await client.refresh(apiMode: apiMode) }
    }

    func switchAccount(accountKey: String) async {
        await load {
            let state = try await client.switchAccount(accountKey: accountKey)
            notice = "已切换账号。新的 Codex CLI 会话将使用此账号。"
            return state
        }
    }

    func requestDelete(_ account: CodexAccount) {
        pendingDeleteAccount = account
    }

    func cancelDelete() {
        pendingDeleteAccount = nil
    }

    func confirmDelete() async {
        guard let account = pendingDeleteAccount else {
            return
        }
        pendingDeleteAccount = nil
        await load {
            let state = try await client.removeAccount(accountKey: account.accountKey)
            notice = "已删除账号。"
            return state
        }
    }

    func login(alias: String? = nil) async {
        await load {
            let state = try await client.login()
            let trimmedAlias = alias?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmedAlias.isEmpty, let accountKey = state.activeAccountKey ?? state.activeAccount?.accountKey else {
                notice = "已添加账号。"
                return state
            }
            let renamedState = try await client.setAlias(accountKey: accountKey, alias: trimmedAlias)
            notice = "已添加账号并设置别名。"
            return renamedState
        }
    }

    func importAuth(path: String, alias: String?) async {
        await load {
            let state = try await client.importAuth(path: path, alias: alias)
            notice = "已导入账号。"
            return state
        }
    }

    func setAlias(accountKey: String, alias: String) async {
        await load {
            let state = try await client.setAlias(accountKey: accountKey, alias: alias)
            notice = "已更新别名。"
            return state
        }
    }

    func clearAlias(accountKey: String) async {
        await load {
            let state = try await client.clearAlias(accountKey: accountKey)
            notice = "已清除别名。"
            return state
        }
    }

    func openNewCodexSession(at directoryPath: String) async {
        do {
            try await client.openNewCodexSession(at: directoryPath)
            notice = "已在 Ghostty 打开新的 Codex 会话。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func load(_ operation: () async throws -> CodexAuthState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            state = try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
