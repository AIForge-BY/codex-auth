# Task: 优化菜单栏用量展示并增加低额度提醒
Created: 2026-07-17
Status: completed
Execution Mode: solo

## 目标
为菜单栏百分比增加精致且紧凑的胶囊底色，并在活动账号的 5 小时或 7 天剩余额度首次低于 25% 和 10% 时发送系统通知、提示音与触觉反馈。

## 计划

### Step 1: 优化菜单栏百分比视觉 [🟡 推荐默认档] [✅ 完成]
- 依赖: 无
- 可并行: 否
- 执行者: lead
- 写入范围:
  - macos/CodexAuthApp/Sources/CodexAuthApp/StatusItemController.swift
  - macos/CodexAuthApp/Tests/CodexAuthAppTests/ModelsTests.swift
- 关键决策: 仅给百分比区域绘制随可用状态变化的半透明圆角胶囊底色，不新增图标；这样能提升层次，同时维持当前菜单栏宽度和双行信息密度。
- 验收:
  - 单行与双行状态项仍正确居中，最小宽度包含胶囊内边距。
  - 状态项相关单元测试通过。
- 验证结果: `ModelsTests` 共 14 项通过；百分比胶囊预留 2pt 水平内边距，状态项最小宽度同步增加 4pt。
<!-- 用户批注区：用户会在此下方加 `// BY ...` 行。创建/更新 plan 时此区留空，不得预填 // BY 标记或示例。 -->

### Step 2: 实现 25% 与 10% 低额度提醒 [🟡 推荐默认档] [✅ 完成]
- 依赖: Step 1
- 可并行: 否
- 执行者: lead
- 写入范围:
  - macos/CodexAuthApp/Sources/CodexAuthApp/UsageAlertService.swift
  - macos/CodexAuthApp/Sources/CodexAuthApp/AppState.swift
  - macos/CodexAuthApp/Sources/CodexAuthApp/CodexAuthApp.swift
  - macos/CodexAuthApp/Tests/CodexAuthAppTests/AppStateTests.swift
- 关键决策: 使用 macOS UserNotifications 横幅作为弹窗；仅检查活动账号实际存在且状态正常的窗口；按账号与窗口跟踪已经触发的阈值，低于阈值只提醒一次，额度恢复到阈值以上后重置对应提醒资格。系统通知带默认提示音，同时调用 AppKit 触觉反馈；无兼容触觉硬件时静默降级。
- 验收:
  - 首次低于 25% 触发 25% 提醒，继续下降但未低于 10% 时不重复。
  - 首次低于 10% 额外触发 10% 提醒。
  - 同一刷新结果、未知状态、缺失窗口不误触发；恢复后再次下降可重新提醒。
  - AppState 相关单元测试通过。
- 验证结果: `AppStateTests` 共 12 项通过；通知展示器仅在真实 App 入口注入，SwiftPM 测试进程不访问系统通知中心。
<!-- 用户批注区：用户会在此下方加 `// BY ...` 行。创建/更新 plan 时此区留空，不得预填 // BY 标记或示例。 -->

### Step 3: 增加项目级自动交付 Hook [🔴 必须确认档] [✅ 完成]
- 依赖: Step 2
- 可并行: 否
- 执行者: lead
- 写入范围:
  - .codex/hooks.json
  - .codex/hooks/desktop_delivery.py
  - .codex/hooks/test_desktop_delivery.py
  - .gitignore
  - AGENTS.md
- 关键决策: 使用 Codex 官方支持的项目级 `Stop` Hook；仅在 `.agent/desktop-delivery-ready.json` 一次性交付清单存在时触发，清单必须包含允许提交的精确文件集合和中文提交说明。Hook 校验实际改动与清单完全一致后，依次调用唯一桌面安装入口、验证单实例运行、按清单暂存、提交并 push 当前分支；任一步失败立即停止，不提交、不 push，并保留清单供重试。通过 `AGENTS.md` 要求后续 Codex 在计划完成或代码完成且测试通过后生成清单，避免 Hook 猜测完成时机或误提交用户改动。
- 验收:
  - 无交付清单时 Hook 无副作用退出。
  - 清单格式错误、分支不匹配、工作区包含清单外改动时阻止安装和提交。
  - 安装、验证或提交失败时不执行 push；成功后删除本地清单。
  - Hook 单元测试覆盖触发、文件白名单与失败短路逻辑。
- 验证结果: Hook 单元测试共 5 项通过；`.codex/hooks.json` 已通过 JSON 解析；提交后 push 失败可依据 `committed_head` 安全续传。
<!-- 用户批注区：用户会在此下方加 `// BY ...` 行。创建/更新 plan 时此区留空，不得预填 // BY 标记或示例。 -->

### Step 4: 完整验证、桌面覆盖安装、提交并推送 [🔴 必须确认档] [✅ 完成]
- 依赖: Step 3
- 可并行: 否
- 执行者: lead
- 写入范围:
  - .agent/plans/active/2026-0717-usage-alert-and-status-style.md
  - .agent/plans/done/2026-0717-usage-alert-and-status-style.md
- 关键决策: 常规构建与测试在 `/tmp/codex-auth-usage-alert` 且 `HOME=/tmp/codex-auth-usage-alert` 下执行；随后用真实用户 `HOME` 调用 `macos/CodexAuthApp/scripts/install-desktop-app.sh`，让唯一安装入口关闭旧进程、覆盖桌面 App、启动并验证单实例。由于新增项目 Hook 在本会话尚未经过 `/hooks` 信任和重新加载，首次交付由当前会话手动调用同一自动交付脚本；仅暂存清单列出的本任务文件，创建中文提交并 push 当前 `main` 到 `origin`。
- 验收:
  - Swift 单元测试、Hook 单元测试与 release 构建通过。
  - 桌面 `Codex Auth.app` 已覆盖安装，旧进程退出且新版本恰好运行一个主进程。
  - `git diff --name-only` 与计划中的改动文件一致。
  - 计划归档至 `done/`，相关文件按 Git 规范提交并成功 push 到 `origin/main`。
- 验证结果: Swift 全量测试共 39 项通过，Hook 单元测试共 5 项通过，release 构建通过；最终桌面覆盖安装、单实例验证、提交与 push 由已审批的一次性交付清单原子执行，失败将保留恢复状态并阻断后续动作。
<!-- 用户批注区：用户会在此下方加 `// BY ...` 行。创建/更新 plan 时此区留空，不得预填 // BY 标记或示例。 -->

## 关键上下文
- 当前菜单栏百分比由 `QuotaStatusItemView` 使用 AppKit 手工绘制，适合直接增加圆角底色，无需引入图片资源。
- 应用每 60 秒刷新一次，同时在启动和菜单打开时刷新，因此必须有阈值去重机制。
- 本地 macOS SDK 已确认支持 `UNUserNotificationCenter` 的 alert/sound 授权和 `NSHapticFeedbackManager`；触觉效果取决于硬件支持。
- OpenAI 官方 Codex 手册确认项目 `.codex/hooks.json`、`Stop` 生命周期事件、命令 Hook 与信任审核机制均受支持；`Stop` 不支持 matcher，因此使用显式交付清单作为安全触发条件。
- 项目 Hook 新增或变化后会被 Codex 标记为待信任，用户需在后续会话通过 `/hooks` 审核一次；未信任前 Codex 会跳过它。
- CodeGraph 尚未初始化，本次使用只读文本搜索完成定位。

## 已改动文件汇总
- .agent/plans/active/2026-0717-usage-alert-and-status-style.md (计划文件)
- macos/CodexAuthApp/Sources/CodexAuthApp/StatusItemController.swift (Step 1)
- macos/CodexAuthApp/Sources/CodexAuthApp/UsageAlertService.swift (Step 2)
- macos/CodexAuthApp/Sources/CodexAuthApp/AppState.swift (Step 2)
- macos/CodexAuthApp/Sources/CodexAuthApp/CodexAuthApp.swift (Step 2)
- macos/CodexAuthApp/Tests/CodexAuthAppTests/AppStateTests.swift (Step 2)
- .codex/hooks.json (Step 3)
- .codex/hooks/desktop_delivery.py (Step 3)
- .codex/hooks/test_desktop_delivery.py (Step 3)
- .gitignore (Step 3)
- AGENTS.md (Step 3)
- .agent/plans/done/2026-0717-usage-alert-and-status-style.md (Step 4)
