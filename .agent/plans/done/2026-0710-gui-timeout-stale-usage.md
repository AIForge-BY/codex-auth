# Task: GUI 超时时保留历史用量
Created: 2026-07-10
Status: completed
Execution Mode: solo

## 目标
GUI 刷新遇到临时 `TimedOut` 时展示上一次成功用量，其他刷新错误继续显示真实错误信息。

## 计划

### Step 1: 调整 GUI 用量覆盖规则 [🟡 推荐默认档] [✅ 完成]
- 依赖: 无
- 可并行: 否
- 执行者: lead
- 写入范围:
  - src/workflows/gui.zig
- 关键决策: 当本轮状态为 `TimedOut` 且已有历史窗口时忽略错误覆盖，保留历史百分比和原刷新时间；无历史窗口时仍输出 `TimedOut`；其他错误继续覆盖历史值并清空百分比字段。
- 验收:
  - Zig 单元测试覆盖“超时有历史数据”“超时无历史数据”“非超时错误覆盖历史数据”三种情况。

### Step 2: 格式化并验证 [🔵 自动档] [✅ 完成]
- 依赖: Step 1
- 可并行: 否
- 执行者: lead
- 写入范围:
  - src/workflows/gui.zig
- 关键决策: 使用隔离 HOME 执行测试；因修改 `.zig`，必须额外运行 `zig build run -- list`。
- 验收:
  - `zig fmt src/workflows/gui.zig`
  - `HOME=/tmp/codex-auth-gui-timeout zig build test --summary all`
  - `HOME=/tmp/codex-auth-gui-timeout zig build run -- list`
  - `HOME=/tmp/codex-auth-gui-timeout swift test --package-path macos/CodexAuthApp`

### Step 3: 构建并覆盖安装桌面 App [🔴 必须确认档] [✅ 完成]
- 依赖: Step 2
- 可并行: 否
- 执行者: lead
- 写入范围:
  - /Users/boyan/Desktop/Codex Auth.app
- 关键决策: 退出正在运行的旧 App 后覆盖安装并重新启动，使新规则立即生效；不改系统配置。
- 验收:
  - 桌面 App 成功构建、覆盖安装并启动。
  - 启动后无残留旧版 App 进程。

## 关键上下文
- 当前 `src/workflows/gui.zig` 会把所有 `usage_override` 都写入 `status` 并清空历史百分比，因此瞬时 `TimedOut` 会遮蔽可用的旧数据。
- SwiftUI 已能直接显示后端透传的非内置错误，无需新增桌面端错误映射。
- 工作树中已有上一轮未提交的 `MenuBarView.swift` 删除确认改动，本计划不修改、不暂存该文件。
- 验证结果：Zig 412 个测试通过、8 个跳过；Swift 33 个测试通过；`zig build run -- list` 退出码为 0。
- 安装结果：已覆盖 `/Users/boyan/Desktop/Codex Auth.app` 并启动，进程检查仅保留一个新版 App 主进程。

## 已改动文件汇总
- .agent/plans/done/2026-0710-gui-timeout-stale-usage.md (计划文件)
- src/workflows/gui.zig (Step 1)
