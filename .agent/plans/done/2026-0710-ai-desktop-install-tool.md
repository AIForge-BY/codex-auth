# Task: AI 桌面 App 安装工具
Created: 2026-07-10
Status: completed
Execution Mode: solo

## 目标
提供一个项目内单入口工具，让 AI 在用户要求安装或桌面改动需要验收时，可靠完成编译、覆盖安装、重启和进程验证。

## 计划

### Step 1: 新增桌面安装编排脚本 [🟡 推荐默认档] [✅ 完成]
- 依赖: 无
- 可并行: 否
- 执行者: lead
- 写入范围:
  - macos/CodexAuthApp/scripts/install-desktop-app.sh
- 关键决策: 复用现有 `install-shortcut.sh desktop`，不复制构建逻辑；先通过 AppleScript 优雅退出旧 App，超时后仅终止桌面 App Bundle 路径下的残留进程；覆盖安装后启动并验证主进程。
- 验收:
  - 脚本开启严格模式，失败时非零退出。
  - 所有终端输出为英文，新增函数均有中文注释。
  - 不新增第三方依赖。

### Step 2: 写入 AI 调用规则 [🟡 推荐默认档] [✅ 完成]
- 依赖: Step 1
- 可并行: 否
- 执行者: lead
- 写入范围:
  - AGENTS.md
- 关键决策: 用户明确要求“安装”时视为已授权覆盖；其他需要用户验收的桌面改动，AI 必须先说明会退出并覆盖桌面 App，获得确认后调用单入口脚本。
- 验收:
  - AGENTS.md 明确触发条件、命令、影响和禁止手工拼接重复流程。

### Step 3: 静态验证脚本 [🔵 自动档] [✅ 完成]
- 依赖: Step 1, Step 2
- 可并行: 否
- 执行者: lead
- 写入范围:
  - macos/CodexAuthApp/scripts/install-desktop-app.sh
- 关键决策: 使用系统 Bash 做语法检查，并检查脚本权限与最终差异；不修改 Zig 文件，因此不需要运行 Zig 验证。
- 验收:
  - `bash -n macos/CodexAuthApp/scripts/install-desktop-app.sh`
  - 脚本具备可执行权限。
  - `git diff --check` 通过。

### Step 4: 端到端覆盖安装验证 [🔴 必须确认档] [✅ 完成]
- 依赖: Step 3
- 可并行: 否
- 执行者: lead
- 写入范围:
  - /Users/boyan/Desktop/Codex Auth.app
- 关键决策: 直接调用新工具验证完整链路，会退出当前 App、重新编译、覆盖桌面副本并启动。
- 验收:
  - 工具退出码为 0。
  - 桌面 App 安装成功且只保留一个主进程，无残留内置 CLI 进程。

## 关键上下文
- 现有 `install-shortcut.sh` 已负责构建和复制，但不会退出旧 App、重新启动或验证进程。
- 现有 `build-app.sh` 是唯一构建实现，新工具必须继续复用该链路。
- 项目要求所有用户可见 CLI 输出使用英文。
- 静态验证通过：系统 Bash 3.2 语法检查成功，脚本权限为 755，`git diff --check` 无错误。
- 端到端验证通过：工具处理了旧 App 退出超时，完成覆盖安装并启动 PID 86309；独立进程检查仅有一个主进程且无内置 CLI 残留。

## 已改动文件汇总
- .agent/plans/done/2026-0710-ai-desktop-install-tool.md (计划文件)
- macos/CodexAuthApp/scripts/install-desktop-app.sh (Step 1)
- AGENTS.md (Step 2)
