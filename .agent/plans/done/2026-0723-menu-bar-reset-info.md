# Task: 菜单栏显示 Codex Reset 机会
Created: 2026-07-23
Status: completed
Execution Mode: solo

## 目标
在菜单栏状态项中显示当前活动账号可直接使用的 Codex reset 次数及最近到期时间。

## 计划

### Step 1: 明确数据边界与展示文案 [🟡] [✅]
- 依赖: 无
- 可并行: 否
- 执行者: lead
- 写入范围:
  - macos/CodexAuthApp/Sources/CodexAuthApp/Models.swift
- 关键决策: Codex reset banking 使用独立的 `/wham/rate-limit-reset-credits` 接口；只展示当前活动账号的 `available_count` 和 available credit 中最近的 `expires_at`，不把 5 小时/7 天窗口当作 reset 机会。
- 验收:
  - 明确 CLI GUI JSON 的 reset 字段和缺失/查询失败时的降级行为。

### Step 2: 增加 reset credit 查询并输出 GUI JSON [🟡] [✅]
- 依赖: Step 1
- 可并行: 否
- 执行者: lead
- 写入范围:
  - src/api/usage.zig
  - src/workflows/gui.zig
  - docs/gui.md
- 关键决策: 查询 reset credit 详情为 best-effort，仅在 GUI 刷新时查询当前活动账号；失败时输出 `null`，不覆盖既有 usage 刷新结果。
- 验收:
  - `gui refresh` 能输出 reset 次数和最近到期时间，且不会输出 token。

### Step 3: 更新菜单栏展示并补测试 [🟡] [✅]
- 依赖: Step 2
- 可并行: 否
- 执行者: lead
- 写入范围:
  - macos/CodexAuthApp/Sources/CodexAuthApp/Models.swift
  - macos/CodexAuthApp/Sources/CodexAuthApp/StatusItemController.swift
  - macos/CodexAuthApp/Tests/CodexAuthAppTests/ModelsTests.swift
  - tests/api_usage_test.zig
  - src/api/usage.zig
- 关键决策: 菜单栏新增一行 reset 信息；缺失数据时不新增占位行，不改变既有 5h/7d 行。
- 验收:
  - `HOME=/tmp/codex-auth-reset swift test --disable-sandbox` 通过：40 tests, 0 failures。
  - `HOME=/tmp/codex-auth-reset zig build` 通过。
  - `HOME=/tmp/codex-auth-reset zig build run -- list` 通过。
  - `zig build test` 已完成编译，但仓库既有集成测试进程无输出挂起，已停止等待；未观察到新增编译错误。

## 关键上下文
- reset credit 查询只发生在 `gui refresh` 且 API 未禁用时，当前活动账号查询失败会降级为 `null`。
- GUI JSON 只输出可用数量和最近到期时间，不输出 token 或完整 reset credit 详情。
- 不执行桌面安装；用户未明确要求覆盖正在运行的 Desktop App。

## 已改动文件汇总
- docs/gui.md
- macos/CodexAuthApp/Sources/CodexAuthApp/Models.swift
- macos/CodexAuthApp/Sources/CodexAuthApp/StatusItemController.swift
- macos/CodexAuthApp/Tests/CodexAuthAppTests/ModelsTests.swift
- src/api/usage.zig
- src/workflows/gui.zig
- tests/api_usage_test.zig
