# Codex Auth macOS Menu App Design

## Goal

Build a macOS SwiftUI menu bar app for managing Codex accounts on the current Mac. The app should make account switching, adding, deleting, aliasing, and usage review convenient while preserving the existing `codex-auth` CLI as the source of truth for account behavior.

## Scope

The first version targets Codex CLI users. Switching accounts updates the managed Codex auth state used by new `codex` CLI sessions. The app will not mutate or restart already-running `codex` processes.

Included:

- menu bar account overview;
- fast account switching;
- usage refresh for 5h and 7d windows;
- add account through the existing login flow;
- import auth file support;
- delete account with confirmation;
- alias set and clear;
- open a new Terminal session running `codex`;
- Chinese user-facing GUI text.

Deferred:

- hot-switching already-running Codex CLI sessions;
- forced restart of Terminal or Codex processes;
- Codex App launch management as a primary workflow;
- direct Swift parsing or writing of `~/.codex` auth files.

## Architecture

The app has two layers:

- SwiftUI macOS app under `macos/CodexAuthApp/`, responsible for menu bar UI, management windows, Chinese copy, and user interaction.
- Zig CLI backend, responsible for all account reads and writes under the resolved Codex home.

SwiftUI invokes the local `codex-auth` executable through `Process`. Development builds can point to the repository build output. Packaged builds should include the CLI binary in the app bundle under `Contents/Resources/`.

The Swift app must not parse, edit, or infer registry file internals. It consumes stable JSON returned by dedicated `codex-auth gui ...` commands and sends account keys back to those commands for mutations.

## CLI JSON Contract

Add a `gui` command namespace for stable machine-readable operations:

```text
codex-auth gui state [--api|--skip-api] [--active]
codex-auth gui refresh [--api|--skip-api] [--active]
codex-auth gui switch <account_key>
codex-auth gui login
codex-auth gui import <path> [--alias <alias>]
codex-auth gui remove <account_key>
codex-auth gui alias set <account_key> <alias>
codex-auth gui alias clear <account_key>
```

JSON output uses English snake_case keys. CLI diagnostics and help remain English only, matching project rules. The Swift app translates common outcomes and errors into Chinese UI copy, with raw English error details available in an expandable details area.

The state response should include:

- `schema_version`;
- `codex_home`;
- `active_account_key`;
- `generated_at`;
- `accounts[]`;
- `refresh`;
- `warnings[]`.

Each account object should include:

- `account_key`;
- `display_name`;
- `alias`;
- `email`;
- `account_name`;
- `plan`;
- `auth_mode`;
- `is_active`;
- `usage.five_hour`;
- `usage.seven_day`;
- `last_usage_at`;
- `last_refresh_at`.

Usage windows include remaining percent, total, used, reset time, and status. Unknown or errored usage must be represented explicitly rather than omitted.

## UI Design

The app uses a `MenuBarExtra` as the primary entry point.

Menu bar popover:

- current account summary at the top;
- compact account rows with alias or masked email, masked email/account label, plan, active marker, 5h/7d remaining values, and reset times;
- remaining usage below 20% is red; otherwise it is green;
- one-click switch for inactive accounts;
- single-line toolbar actions for refresh, add account, manage accounts, new Codex session, and quit;
- inline add-account alias input before launching the login flow;
- inline management mode that replaces switch actions with delete and alias actions.
- ordinary success notices are not shown in the menu footer; command errors are still shown.

Management window:

- searchable account list;
- sorting by name, active state, remaining usage, and last activity;
- details pane for plan, email, account name, auth mode, usage windows, reset times, and recent refresh state;
- actions for switch, set alias, clear alias, delete, import auth file, and refresh.

All GUI text is Chinese. Example labels:

- `刷新`;
- `添加账号`;
- `管理`;
- `新会话`;
- `切换`;
- `删除`;
- `设置别名`;
- `新的 Codex CLI 会话将使用此账号`.

## Account Switching Semantics

After switching, the UI immediately updates the active account from the command result. The success message states that new Codex CLI sessions will use the selected account. The app does not claim that existing terminal sessions are updated.

The app provides a nearby `新建 Codex 会话` action. On macOS it asks the user to choose a working directory, then opens Ghostty and asks Codex to resume the latest session for that directory, falling back to a new session when Codex has nothing to resume.

## Error Handling

Backend operations return non-zero exit codes on failure. The Swift app maps known failures to Chinese messages:

- missing CLI binary;
- no accounts;
- account not found;
- login cancelled or failed;
- import path invalid;
- delete failed;
- API refresh failed;
- network or `curl` unavailable;
- malformed JSON.

For API refresh failures, local account switching remains available. The UI displays stale data with a visible timestamp and error marker.

Deletion is destructive and must require confirmation in the Swift UI. Removing the current account delegates replacement behavior to the existing CLI backend.

## Security And Privacy

The Swift app must never display raw access tokens or API keys. It must not log JSON responses that could contain sensitive fields. The GUI JSON contract must exclude raw auth secrets.

All account file permissions and backups remain handled by the existing Zig registry layer.

## Documentation

Add implementation-specific documentation under `docs/`, not `README.md`, unless public command behavior needs a concise mention. CLI command docs should describe the `gui` namespace only if it is intended as supported public surface; otherwise keep details in a GUI integration doc.

## Testing And Verification

Zig:

- parser tests for `gui` subcommands;
- workflow tests for JSON state shape and mutation results;
- tests proving GUI state excludes raw tokens;
- existing required verification after `.zig` edits: `zig build run -- list`.

Swift:

- model decoding tests for representative JSON state;
- CLI client tests using a fake executable;
- view model tests for refresh, switch, delete confirmation state, and Chinese messages;
- `swift test`;
- `swift build`.

Manual:

- launch app on macOS;
- verify menu bar presence;
- verify switching changes the active account for a new `codex` process;
- verify existing sessions are not promised to change;
- verify failed usage refresh does not block switching.

## Risks

The largest correctness risk is duplicated account logic. This is avoided by keeping Swift as a thin UI over the Zig CLI.

The largest UX risk is implying hot switching for already-running Codex CLI sessions. The UI must clearly say the switch applies to new sessions.

The largest delivery risk is packaging the CLI binary into the `.app`. First implementation can support a configurable CLI path and document development usage before packaging automation is added.
