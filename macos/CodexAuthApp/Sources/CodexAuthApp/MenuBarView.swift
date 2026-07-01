import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isManagingAccounts = false
    @State private var isAddingAccount = false
    @State private var newAccountAlias = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            accountList
            Divider()
            actions
            if isAddingAccount {
                addAccountPanel
            }
            if let error = appState.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .frame(width: 420)
        .background {
            MenuWindowOpenObserver {
                Task {
                    await appState.refreshOnMenuOpen()
                }
            }
            .frame(width: 0, height: 0)
        }
        .confirmationDialog(
            "确定删除此账号？",
            isPresented: Binding(
                get: { appState.isShowingDeleteConfirmation },
                set: { if !$0 { appState.cancelDelete() } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                Task { await appState.confirmDelete() }
            }
            Button("取消", role: .cancel) {
                appState.cancelDelete()
            }
        } message: {
            Text("删除后会移除此账号的本地快照。")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Codex 账号")
                .font(.headline)
            if let active = appState.state?.activeAccount {
                Text(active.primaryLabel)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            } else {
                Text("暂无活动账号")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var accountList: some View {
        if appState.isLoading && appState.state == nil {
            ProgressView("正在加载账号...")
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let accounts = appState.state?.accounts, !accounts.isEmpty {
            VStack(spacing: 8) {
                ForEach(accounts) { account in
                    AccountRow(account: account, isManaging: isManagingAccounts)
                }
            }
        } else {
            Text("没有已保存的账号")
                .foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        HStack(spacing: 6) {
            Button {
                Task { await appState.refreshUsage() }
            } label: {
                compactLabel("刷新", systemImage: "arrow.clockwise")
            }
            .frame(maxWidth: .infinity)

            Button {
                withAnimation(.snappy) {
                    isAddingAccount.toggle()
                }
            } label: {
                compactLabel("添加", systemImage: "plus.circle")
            }
            .frame(maxWidth: .infinity)

            Button {
                openCodexSessionAfterChoosingDirectory()
            } label: {
                compactLabel("会话", systemImage: "terminal")
            }
            .frame(maxWidth: .infinity)

            Button {
                withAnimation(.snappy) {
                    isManagingAccounts.toggle()
                }
            } label: {
                Label(
                    isManagingAccounts ? "完成" : "管理",
                    systemImage: isManagingAccounts ? "checkmark.circle" : "slider.horizontal.3"
                )
                .labelStyle(.titleAndIcon)
            }
            .frame(maxWidth: .infinity)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                compactLabel("退出", systemImage: "power")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }

    private func compactLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.titleAndIcon)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }

    private var addAccountPanel: some View {
        HStack(spacing: 8) {
            TextField("新账号别名（可选）", text: $newAccountAlias)
                .textFieldStyle(.roundedBorder)

            Button("登录") {
                let alias = newAccountAlias.trimmingCharacters(in: .whitespacesAndNewlines)
                newAccountAlias = ""
                isAddingAccount = false
                Task { await appState.login(alias: alias) }
            }
            .buttonStyle(.borderedProminent)

            Button("取消") {
                newAccountAlias = ""
                isAddingAccount = false
            }
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
