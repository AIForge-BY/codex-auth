import SwiftUI

struct ManageAccountsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var selectedAccountID: CodexAccount.ID?

    private var filteredAccounts: [CodexAccount] {
        let accounts = appState.state?.accounts ?? []
        guard !searchText.isEmpty else {
            return accounts
        }
        return accounts.filter { account in
            [account.primaryLabel, account.secondaryLabel, account.accountKey]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            List(filteredAccounts, selection: $selectedAccountID) { account in
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.primaryLabel)
                    Text(account.secondaryLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .searchable(text: $searchText, prompt: "搜索账号")
            .navigationTitle("账号")
            .toolbar {
                Button {
                    Task { await appState.login() }
                } label: {
                    Label("添加账号", systemImage: "plus")
                }
                Button {
                    Task { await appState.refreshUsage() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            }
        } detail: {
            if let account = selectedAccount ?? filteredAccounts.first {
                AccountDetailView(account: account)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("没有账号")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if appState.state == nil {
                await appState.refresh()
            }
        }
    }

    private var selectedAccount: CodexAccount? {
        guard let selectedAccountID else {
            return nil
        }
        return filteredAccounts.first { $0.id == selectedAccountID }
    }
}

private struct AccountDetailView: View {
    @EnvironmentObject private var appState: AppState
    let account: CodexAccount
    @State private var aliasText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(account.primaryLabel)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(account.secondaryLabel.isEmpty ? account.accountKey : account.secondaryLabel)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                GridRow {
                    Text("套餐")
                    Text(account.planLabel)
                }
                GridRow {
                    Text("认证")
                    Text(account.authMode ?? "未知")
                }
                if let fiveHourUsageText = account.fiveHourUsageText {
                    GridRow {
                        Text("5小时额度")
                        Text(fiveHourUsageText)
                    }
                }
                GridRow {
                    Text("7天额度")
                    Text(account.sevenDayUsageText)
                }
            }

            HStack {
                Button("切换") {
                    Task { await appState.switchAccount(accountKey: account.accountKey) }
                }
                .disabled(account.isActive)

                Button("删除", role: .destructive) {
                    appState.requestDelete(account)
                }

                Button("新建 Codex 会话") {
                    openCodexSessionAfterChoosingDirectory()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("别名")
                    .font(.headline)
                HStack {
                    TextField("输入别名", text: $aliasText)
                        .textFieldStyle(.roundedBorder)
                    Button("保存") {
                        Task { await appState.setAlias(accountKey: account.accountKey, alias: aliasText) }
                    }
                    .disabled(aliasText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("清除") {
                        Task { await appState.clearAlias(accountKey: account.accountKey) }
                    }
                }
            }

            Spacer()
        }
        .padding(24)
        .onAppear {
            aliasText = account.alias ?? ""
        }
        .onChange(of: account.accountKey) { _ in
            aliasText = account.alias ?? ""
        }
    }

    @MainActor
    private func openCodexSessionAfterChoosingDirectory() {
        CodexDirectoryPicker.chooseDirectory { directoryPath in
            guard let directoryPath else {
                return
            }
            Task { await appState.openNewCodexSession(at: directoryPath) }
        }
    }
}
