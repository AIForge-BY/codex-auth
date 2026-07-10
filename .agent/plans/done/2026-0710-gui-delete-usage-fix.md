# Task: 修复 GUI 删除卡死与用量状态不一致
Created: 2026-07-10
Status: completed
Execution Mode: solo

## 目标
修复 macOS 菜单栏 App 删除账号时界面卡死且未删除的问题，并让 GUI 中账号用量状态与 CLI 刷新失败状态保持一致。

## 计划

### Step 1: 定位删除与用量状态链路 [🔵 自动档] [✅ 完成]
- 依赖: 无
- 可并行: 否
- 执行者: lead
- 写入范围:
  - 无
- 关键决策: CodeGraph 未初始化，改用 `rg`、`sed` 和现有测试直读；已确认删除走 Swift `Process.waitUntilExit()`，GUI 用量 JSON 未携带刷新失败 override。
- 验收:
  - 明确删除卡死与用量不一致的代码路径。
<!-- 用户批注区：用户会在此下方加 `// BY ...` 行。创建/更新 plan 时此区留空，不得预填 // BY 标记或示例。 -->

### Step 2: 修复 Swift 命令执行阻塞 [🔵 自动档] [✅ 完成]
- 依赖: Step 1
- 可并行: 否
- 执行者: lead
- 写入范围:
  - macos/CodexAuthApp/Sources/CodexAuthApp/CodexAuthCLIClient.swift
  - macos/CodexAuthApp/Tests/CodexAuthAppTests/CLIClientTests.swift
- 关键决策: 将阻塞式 `Process.waitUntilExit()` 包到 detached task 中，避免从 `@MainActor` 调用链继承主线程执行导致菜单窗口不可操作。
- 验收:
  - `HOME=/tmp/codex-auth-gui-fix swift test --package-path macos/CodexAuthApp` 通过。

### Step 3: 修复 GUI 用量失败状态输出 [🔵 自动档] [✅ 完成]
- 依赖: Step 1
- 可并行: 否
- 执行者: lead
- 写入范围:
  - src/workflows/gui.zig
  - tests/workflows_core_test.zig 或 tests/cli_integration_test.zig
- 关键决策: `gui refresh` 把本轮刷新失败的 `usage_overrides` 写入 JSON；Swift 仅直出这类 override，内置 `missing_auth` 等状态仍按本地化降级显示。
- 验收:
  - `HOME=/tmp/codex-auth-gui-fix zig build test --summary all` 通过。

### Step 4: 构建与运行验证 [🔵 自动档] [✅ 完成]
- 依赖: Step 2, Step 3
- 可并行: 否
- 执行者: lead
- 写入范围:
  - 无
- 关键决策: 按项目规则，修改 `.zig` 后运行 `zig build run -- list`；Swift 侧运行最相关 Swift 测试。
- 验收:
  - `HOME=/tmp/codex-auth-gui-fix zig build run -- list` 通过。
  - `HOME=/tmp/codex-auth-gui-fix swift test --package-path macos/CodexAuthApp` 通过。

## 关键上下文
- 用户反馈：菜单栏 App 点击删除后卡死，实际未删除；未选中账号的用量数据与 `codex-auth list` 不一致。
- 截图中 CLI 第三个账号显示 `401 token_invalidated`，GUI 仍显示旧的百分比。
- `src/workflows/gui.zig` 当前 `gui refresh` 虽然拿到 `usage_state.usage_overrides`，但 `writeStateJson` 只输出 registry 中的历史 `last_usage`。

## 已改动文件汇总
- .agent/plans/active/2026-0710-gui-delete-usage-fix.md (Step 1)
- macos/CodexAuthApp/Sources/CodexAuthApp/CodexAuthCLIClient.swift (Step 2)
- macos/CodexAuthApp/Sources/CodexAuthApp/Models.swift (Step 3)
- macos/CodexAuthApp/Tests/CodexAuthAppTests/ModelsTests.swift (Step 3)
- src/workflows/gui.zig (Step 3)
