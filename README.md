# Codex Auth [![latest release](https://img.shields.io/github/v/release/Loongphy/codex-auth?sort=semver&label=latest)](https://github.com/Loongphy/codex-auth/releases/latest) [![latest pre-release](https://img.shields.io/github/v/release/Loongphy/codex-auth?include_prereleases&sort=semver&filter=*-*&label=pre-release)](https://github.com/Loongphy/codex-auth/releases)

![command list](https://github.com/user-attachments/assets/6c13a2d6-f9da-47ea-8ec8-0394fc072d40)

`codex-auth` 是一个用于管理和切换 Codex 账号的命令行工具，也提供 macOS 菜单栏 App，方便在本机快速查看账号额度并切换账号。

## 安装

使用 npm 全局安装：

```shell
npm install -g @loongphy/codex-auth
```

也可以不全局安装，直接通过 `npx` 运行：

```shell
npx @loongphy/codex-auth list
```

如果主要使用 VS Code 扩展或 Codex App，也建议安装 Codex CLI，因为它能让登录和添加账号更简单：

```shell
npm install -g @openai/codex
```

安装后可通过以下命令登录并添加账号：

```shell
codex-auth login
codex-auth login --device-auth
```

## 支持的平台

`codex-auth` 支持以下 Codex 客户端：

- Codex CLI
- VS Code 扩展
- Codex App
- macOS 菜单栏 App

> [!IMPORTANT]
> 对于 **Codex CLI** 和 **Codex App**，切换账号后需要重启客户端，新的账号才会生效。
>
> 如果需要不重启即可无缝切换账号，可以使用增强版 Codex CLI 分支 [`codext`](https://github.com/Loongphy/codext)。
>
> 安装方式：
>
> ```bash
> npm i -g @loongphy/codext
> ```
>
> 然后运行 `codext`。

## 常用命令

完整命令文档见 [docs/commands/README.md](./docs/commands/README.md)。

> [!NOTE]
> 本文档基于 **v0.3.x**。部分命令可能尚未包含在当前稳定版中。
>
> 如需体验最新功能，可安装 alpha 版本：
>
> ```bash
> npm install -g @loongphy/codex-auth@next
> ```
>
> 如果需要降级到 **v0.2.x**，可能需要手动把 `~/.codex/accounts/registry.json` 中的版本改为：
>
> ```json
> "schema_version": 3
> ```

### 账号管理

| 命令 | 说明 |
|------|------|
| [`codex-auth list [--live] [--active] [--api\|--skip-api]`](./docs/commands/list.md) | 列出已保存账号和额度状态 |
| [`codex-auth login [--device-auth]`](./docs/commands/login.md) | 运行 `codex login`，并把当前账号加入管理列表 |
| [`codex-auth switch [--live] [--api\|--skip-api]`](./docs/commands/switch.md) | 交互式切换活动账号 |
| [`codex-auth switch <query>`](./docs/commands/switch.md) | 通过行号或账号选择器直接切换 |
| [`codex-auth remove [--live] [--api\|--skip-api]`](./docs/commands/remove.md) | 交互式移除账号 |
| [`codex-auth remove <query> [<query>...]`](./docs/commands/remove.md) | 通过选择器移除账号 |
| [`codex-auth remove --all`](./docs/commands/remove.md) | 移除所有已保存账号 |
| [`codex-auth alias set <query> <alias>`](./docs/commands/alias.md) | 设置账号别名 |
| [`codex-auth alias clear <query>`](./docs/commands/alias.md) | 清除账号别名 |

### 导入、导出与维护

| 命令 | 说明 |
|------|------|
| [`codex-auth import <path> [--alias <alias>]`](./docs/commands/import.md) | 导入单个认证文件，或批量导入文件夹 |
| [`codex-auth import --cpa [<path>]`](./docs/commands/import.md) | 导入 CLIProxyAPI token JSON |
| [`codex-auth import --purge [<path>]`](./docs/commands/import.md) | 从认证文件重建 `registry.json` |
| [`codex-auth export [<dir>]`](./docs/commands/export.md) | 导出已保存账号的认证文件 |
| [`codex-auth export --cpa [<dir>]`](./docs/commands/export.md) | 导出 CLIProxyAPI token JSON |
| [`codex-auth clean`](./docs/commands/clean.md) | 删除托管备份和过期账号文件 |

### 配置

| 命令 | 说明 |
|------|------|
| [`codex-auth config live --interval <seconds>`](./docs/commands/config.md) | 配置 live TUI 的刷新间隔 |

## 快速示例

```shell
codex-auth list
codex-auth list --active
codex-auth switch
codex-auth switch 02
codex-auth remove work
codex-auth import /path/to/auth.json --alias personal
codex-auth list --skip-api
```

## macOS 菜单栏 App

仓库包含一个 macOS 菜单栏 App，用于在图形界面中管理账号。它适合需要频繁查看当前账号额度、快速切换账号或启动新 Codex 会话的场景。

主要能力：

- 菜单栏实时显示当前活动账号的 5 小时和 7 天剩余额度。
- 点击菜单栏图标可查看所有账号、额度刷新时间和账号状态。
- 支持刷新额度、添加账号、切换账号、设置别名、删除账号。
- 支持选择目录并打开新的 Codex 会话。
- 剩余额度低于 20% 时百分比标红，否则标绿。

开发运行：

```bash
macos/CodexAuthApp/scripts/run-app.sh
```

安装到桌面：

```bash
macos/CodexAuthApp/scripts/install-shortcut.sh desktop
```

安装到 Applications：

```bash
macos/CodexAuthApp/scripts/install-shortcut.sh applications
```

更多说明见 [macos/CodexAuthApp/README.md](./macos/CodexAuthApp/README.md)。

## Codex App

> [!IMPORTANT]
> `app` 命令仍是实验功能，未来不保证稳定。
>
> 它用于在不重启 Codex App 的情况下尽量实现账号切换。该能力依赖 `CODEX_CLI_PATH` 环境变量，把托管的 `codext` CLI 注入到 Codex App 的认证流程中。
>
> 由于官方 Codex App 和 [Codex CLI](https://github.com/openai/codex) 仍在变化，该命令可能无法生效，也可能导致 App 行为异常。

| 命令 | 说明 |
|------|------|
| [`codex-auth app [--id <id>] [--codex-cli-path <path>]`](./docs/commands/app.md) | 实验功能：用检测到的默认值、`CODEX_HOME`、`CODEX_CLI_PATH` 和平台参数启动 Codex App |

目标支持以下场景的无缝账号切换：

- 新建对话
- 恢复或继续已有对话
- 继续已经完成、中断或手动停止的对话

## 卸载

移除 npm 包：

```shell
npm uninstall -g @loongphy/codex-auth
```

## 常见问题

### 为什么额度没有刷新？

默认情况下，`codex-auth` 会通过 API 刷新额度。如果传入 `--skip-api`，工具会改为扫描本地 `~/.codex/sessions/**/rollout-*.jsonl` 文件。近期 Codex 版本经常写入 `rate_limits: null` 的 `token_count` 事件。本地文件可能仍有旧的可用额度数据，但实际可能滞后数小时。

- 上游 Codex issue：[openai/codex#14880](https://github.com/openai/codex/issues/14880)

使用默认 API 刷新：

```shell
codex-auth list
```

只运行一次本地扫描：

```shell
codex-auth list --skip-api
```

可用下面命令触发 Codex 生成新的本地事件后再检查：

```shell
codex exec "say hello"
```

## 免责声明

本项目按现状提供，使用风险由你自行承担。

**额度数据刷新来源：**

`codex-auth` 支持两种额度刷新来源：

1. **API（默认）：** 工具会使用账号 access token 直接请求 OpenAI 相关接口，以刷新额度和团队名称。运行环境需要可用的 `curl`。
2. **仅本地：** 使用单次命令参数 `--skip-api` 时，工具会扫描本地 `~/.codex/sessions/*/rollout-*.jsonl` 文件，并跳过团队名称刷新 API。这个模式更保守，但可能不够准确，因为近期 Codex rollout 文件经常包含 `rate_limits: null`，导致本地额度数据滞后。

**API 调用说明：**

使用默认 API 刷新时，工具会把你的 ChatGPT access token 发送到 OpenAI 服务器，用于额度和团队名称刷新。当前涉及的接口包括：

- `GET https://chatgpt.com/backend-api/wham/usage`
- `GET https://chatgpt.com/backend-api/accounts`

该行为可能被 OpenAI 检测到，并可能违反其服务条款，进而带来账号限制、暂停或其他风险。是否使用该功能以及由此产生的后果，均由你自行承担。
