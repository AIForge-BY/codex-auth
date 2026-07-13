# Task: 用量窗口按接口动态展示
Created: 2026-07-13
Status: completed
Execution Mode: solo

## 目标
取消产品层对 5 小时窗口的硬编码依赖，仅在接口实际返回 300 分钟窗口时展示并参与账号决策；当前仅有周窗口时不再显示 `5H` 或“5小时 未知”。

## 计划

### Step 1: 统一可用窗口判定与 GUI 数据契约 [🟡 推荐默认档] [✅ 完成]
- 依赖: 无
- 可并行: 否
- 执行者: lead
- 写入范围:
  - src/registry/account_ops.zig
  - src/workflows/gui.zig
  - tests/registry_test.zig
- 关键决策: 以接口返回的 `window_minutes` 为唯一窗口能力来源；保留通用窗口解析能力，不删除 300 分钟数据兼容；GUI JSON 的 `five_hour` 在没有 300 分钟窗口时输出 `null`，`seven_day` 继续按 10080 分钟窗口输出。
- 验收:
  - 无 300 分钟窗口时不会伪造或输出 5 小时用量。
  - 同时存在 300/10080 分钟窗口时保持现有百分比和错误状态行为。
  - 新增 Zig 测试覆盖“仅周窗口”“双窗口”“刷新错误”场景。

### Step 2: CLI 按数据隐藏 5H 并修正账号决策 [🟡 推荐默认档] [✅ 完成]
- 依赖: Step 1
- 可并行: 否
- 执行者: lead
- 写入范围:
  - src/tui/table.zig
  - src/cli/rows.zig
  - src/cli/table_layout.zig
  - src/cli/render.zig
  - src/cli/picker_auto.zig
  - tests/tui_table_test.zig
  - tests/table_layout_test.zig
  - tests/cli_picker_test.zig
- 关键决策: 当前账号集合没有 300 分钟窗口时，普通列表和实时选择器均省略 `5H` 列及其分隔空间；账号耗尽判断、评分和自动切号排序只使用实际存在的窗口，不把周用量复制为 5 小时用量。
- 验收:
  - 仅周窗口时 CLI 只显示 `WEEKLY`，表格对齐正常。
  - 双窗口时继续显示 `5H` 与 `WEEKLY`。
  - 自动切号在缺少 5 小时窗口时仅依据周窗口，现有双窗口行为不回归。

### Step 3: macOS App 将 5 小时窗口改为可选 [🟡 推荐默认档] [✅ 完成]
- 依赖: Step 1
- 可并行: 否
- 执行者: lead
- 写入范围:
  - macos/CodexAuthApp/Sources/CodexAuthApp/Models.swift
  - macos/CodexAuthApp/Sources/CodexAuthApp/AccountRow.swift
  - macos/CodexAuthApp/Sources/CodexAuthApp/ManageAccountsView.swift
  - macos/CodexAuthApp/Sources/CodexAuthApp/StatusItemController.swift
  - macos/CodexAuthApp/Tests/CodexAuthAppTests/ModelsTests.swift
- 关键决策: `UsageInfo.fiveHour` 改为可选；账号列表、管理详情和菜单栏仅在该窗口存在时渲染对应内容，周窗口始终保留；菜单栏宽度根据实际片段重新计算。
- 验收:
  - 仅周窗口 JSON 可正常解码，界面不出现“5小时 未知”或 `5h --`。
  - 双窗口 JSON 保持当前展示。
  - 菜单栏单行/双行状态均有模型测试覆盖。

### Step 4: 全量验证与文档检查 [🔵 自动档] [✅ 完成]
- 依赖: Step 2, Step 3
- 可并行: 否
- 执行者: lead
- 写入范围:
  - src/registry/account_ops.zig
  - src/workflows/gui.zig
  - src/tui/table.zig
  - src/cli/rows.zig
  - src/cli/table_layout.zig
  - src/cli/render.zig
  - src/cli/picker_auto.zig
  - macos/CodexAuthApp/Sources/CodexAuthApp
  - macos/CodexAuthApp/Tests/CodexAuthAppTests
  - docs/commands/list.md
  - docs/gui.md
  - docs/table-layout.md
- 关键决策: 修改 Zig API 前先确认本地 `zig env` 与 `zig version`；所有测试使用隔离 HOME；因修改 `.zig`，必须运行 `zig build run -- list`；检查现有文档是否声明固定 5H 列，仅在确有公开行为说明时同步 `docs/*.md`。
- 验收:
  - `zig fmt` 通过。
  - `HOME=/tmp/codex-auth-dynamic-windows zig build test --summary all` 通过。
  - `HOME=/tmp/codex-auth-dynamic-windows zig build run -- list` 通过。
  - `HOME=/tmp/codex-auth-dynamic-windows swift test --package-path macos/CodexAuthApp` 通过。
  - `HOME=/tmp/codex-auth-dynamic-windows swift build --package-path macos/CodexAuthApp` 通过。

### Step 5: 覆盖安装桌面 App 验收 [🔴 必须确认档] [✅ 完成]
- 依赖: Step 4
- 可并行: 否
- 执行者: lead
- 写入范围:
  - /Users/boyan/Desktop/Codex Auth.app
- 关键决策: 使用项目单入口 `macos/CodexAuthApp/scripts/install-desktop-app.sh`，退出旧 App、覆盖桌面版本并验证进程；不手工拼接安装命令。
- 验收:
  - 新工具退出码为 0。
  - 仅周窗口账号在桌面 App 中不显示 5 小时行，周用量与 CLI 一致。

## 关键上下文
- 用户提供的最新产品判断是 Codex 已取消 5 小时额度限制；截至 2026-07-13，公开的 OpenAI Codex Pricing 页面仍描述共享 5 小时窗口，因此实现不永久删除 300 分钟窗口兼容，而以接口实际返回数据为准。
- 当前账号注册表仅包含 `window_minutes = 10080` 的周窗口；旧全局 CLI 会错误地把该窗口同时显示在 `5H` 和 `WEEKLY`，当前桌面 App 则显示“5小时 未知”。
- 本任务会改变 CLI 列布局、桌面 JSON 解码和自动切号依据，必须一起修改和验证，不能只删 UI 文案。
- Zig 测试共 422 项：414 通过、8 跳过；Swift 测试 35 项全部通过，Zig/Swift 构建和 `zig build run -- list` 均通过。
- 已通过 `macos/CodexAuthApp/scripts/install-desktop-app.sh` 覆盖安装并启动桌面 App（PID 42047）；桌面安装包内 CLI 对真实账号返回 `five_hour = null`，周额度分别为 100% 和 77%。

## 已改动文件汇总
- .agent/plans/done/2026-0713-dynamic-usage-windows.md (计划文件)
- src/registry/account_ops.zig (Step 1)
- src/workflows/gui.zig (Step 1)
- tests/registry_test.zig (Step 1)
- src/tui/table.zig (Step 2)
- src/cli/rows.zig (Step 2)
- src/cli/table_layout.zig (Step 2)
- src/cli/picker_auto.zig (Step 2)
- tests/tui_table_test.zig (Step 2)
- tests/table_layout_test.zig (Step 2)
- tests/cli_picker_test.zig (Step 2)
- macos/CodexAuthApp/Sources/CodexAuthApp/Models.swift (Step 3)
- macos/CodexAuthApp/Sources/CodexAuthApp/AccountRow.swift (Step 3)
- macos/CodexAuthApp/Sources/CodexAuthApp/ManageAccountsView.swift (Step 3)
- macos/CodexAuthApp/Sources/CodexAuthApp/StatusItemController.swift (Step 3)
- macos/CodexAuthApp/Tests/CodexAuthAppTests/ModelsTests.swift (Step 3)
- docs/commands/list.md (Step 4)
- docs/gui.md (Step 4)
- docs/table-layout.md (Step 4)
