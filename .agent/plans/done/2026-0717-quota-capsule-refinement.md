# Task: 调整菜单栏额度胶囊尺寸与三色状态
Created: 2026-07-17
Status: completed
Execution Mode: solo

## 目标
缩短菜单栏状态项的外部占用但保持当前底色宽度，将额度底色按绿、黄、红三档变化，百分比文字固定为白色，并将底色高度增加约 30%。

## 计划

### Step 1: 增加三档额度颜色模型 [🟡 推荐默认档] [✅ 完成]
- 依赖: 无
- 可并行: 否
- 执行者: lead
- 写入范围:
  - macos/CodexAuthApp/Sources/CodexAuthApp/Models.swift
  - macos/CodexAuthApp/Sources/CodexAuthApp/UsageToneColor.swift
  - macos/CodexAuthApp/Tests/CodexAuthAppTests/ModelsTests.swift
- 关键决策: 保留现有 `<20%` 低额度红色边界；新增 `20–49%` 黄色档，`≥50%` 为绿色，未知状态仍使用不可用样式。三档只改变视觉，不改 25%/10% 通知阈值。
- 验收:
  - 49%、50%、19%、20% 边界映射到预期颜色档。
  - 现有模型测试通过。
- 验证结果: 19%、20%、49%、50% 边界测试通过，分别映射红、黄、黄、绿；未知状态保持不可用样式。
<!-- 用户批注区：用户会在此下方加 `// BY ...` 行。创建/更新 plan 时此区留空，不得预填 // BY 标记或示例。 -->

### Step 2: 调整胶囊绘制尺寸与文字颜色 [🟡 推荐默认档] [✅ 完成]
- 依赖: Step 1
- 可并行: 否
- 执行者: lead
- 写入范围:
  - macos/CodexAuthApp/Sources/CodexAuthApp/StatusItemController.swift
  - macos/CodexAuthApp/Tests/CodexAuthAppTests/ModelsTests.swift
- 关键决策: 当前底色左右各 7pt 内边距保持不变；将状态项外边距由总计 8pt 缩至 2pt，从而缩短菜单栏占用但不裁切底色。单行底色高度从 `textHeight + 2` 调至 `textHeight + 6`（约增加 30%），百分比统一纯白。受 macOS 约 24pt 菜单栏高度限制，双行模式保持原高度，避免两个 18pt 胶囊严重重叠。
- 验收:
  - 单行状态项宽度缩小，底色宽度不变且不裁切。
  - 胶囊高度约增加 30%，单行和双行均保持垂直居中且不重叠。
  - 百分比文字在绿、黄、红底色上均为白色。
- 验证结果: 胶囊水平内边距固定为 14pt，状态项总外边距缩至 2pt；单行垂直内边距增至 6pt；`ModelsTests` 共 14 项通过。
<!-- 用户批注区：用户会在此下方加 `// BY ...` 行。创建/更新 plan 时此区留空，不得预填 // BY 标记或示例。 -->

### Step 3: 验证并自动交付桌面应用 [🔴 必须确认档] [✅ 完成]
- 依赖: Step 2
- 可并行: 否
- 执行者: lead
- 写入范围:
  - .agent/plans/active/2026-0717-quota-capsule-refinement.md
  - .agent/plans/done/2026-0717-quota-capsule-refinement.md
- 关键决策: 在隔离目录运行 Swift 全量测试和 release 构建；通过后生成精确交付清单，由项目自动交付脚本关闭旧进程、覆盖桌面 App、启动验证、创建中文提交并 push `origin/main`。
- 验收:
  - Swift 全量测试和 release 构建通过。
  - 桌面 App 覆盖安装后仅运行一个新进程。
  - 工作区干净，本地与远端 `main` 一致。
- 验证结果: Swift 全量测试共 39 项通过，release 构建通过；最终覆盖安装、单实例验证、提交和 push 由一次性交付清单执行，失败将保留恢复状态并阻断后续动作。
<!-- 用户批注区：用户会在此下方加 `// BY ...` 行。创建/更新 plan 时此区留空，不得预填 // BY 标记或示例。 -->

## 关键上下文
- 当前百分比底色水平内边距为左右各 7pt，状态项额外外边距合计 8pt。
- 当前 `UsageTone` 只有 available/low/unavailable，需要新增黄色中间档并同步 SwiftUI/AppKit 两套颜色映射。
- 用户要求底色高度增加 30%；采用整数像素近似，目标从约 14pt 调整到约 18pt。
- 当前工作区干净，没有其他活动计划。

## 已改动文件汇总
- .agent/plans/active/2026-0717-quota-capsule-refinement.md (计划文件)
- macos/CodexAuthApp/Sources/CodexAuthApp/Models.swift (Step 1)
- macos/CodexAuthApp/Sources/CodexAuthApp/UsageToneColor.swift (Step 1)
- macos/CodexAuthApp/Sources/CodexAuthApp/StatusItemController.swift (Step 2)
- macos/CodexAuthApp/Tests/CodexAuthAppTests/ModelsTests.swift (Step 1, Step 2)
- .agent/plans/done/2026-0717-quota-capsule-refinement.md (Step 3)
