# Codex Auth macOS Menu App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a SwiftUI menu bar app that manages Codex accounts through stable `codex-auth gui` JSON commands.

**Architecture:** The Zig CLI remains the account authority and exposes machine-readable GUI commands. The SwiftUI app is a thin macOS menu bar client that invokes the CLI, decodes JSON, presents Chinese UI, and never reads auth files directly.

**Tech Stack:** Zig CLI, Zig tests, Swift Package Manager, SwiftUI, XCTest, macOS `Process`.

---

## File Structure

- Create `src/workflows/gui.zig`: GUI JSON workflows for state, refresh, switch, login, import, remove, and alias.
- Modify `src/workflows/root.zig`: route parsed GUI commands to `workflows/gui.zig`.
- Modify `src/cli/types.zig`: add `GuiOptions` and subcommand types.
- Modify `src/cli/commands/root.zig`: parse `gui` namespace.
- Modify `src/cli/help.zig`: add English help for GUI commands if help exposes all namespaces.
- Create `tests/gui_command_test.zig`: parser and JSON behavior tests.
- Modify `build.zig`: include new Zig tests when needed.
- Create `docs/gui.md`: document the GUI backend contract.
- Create `macos/CodexAuthApp/Package.swift`: Swift package for the macOS app.
- Create `macos/CodexAuthApp/Sources/CodexAuthApp/CodexAuthApp.swift`: app entry point.
- Create `macos/CodexAuthApp/Sources/CodexAuthApp/Models.swift`: JSON models.
- Create `macos/CodexAuthApp/Sources/CodexAuthApp/CodexAuthCLIClient.swift`: CLI process client.
- Create `macos/CodexAuthApp/Sources/CodexAuthApp/AppState.swift`: observable state and actions.
- Create `macos/CodexAuthApp/Sources/CodexAuthApp/MenuBarView.swift`: menu bar popover UI.
- Create `macos/CodexAuthApp/Sources/CodexAuthApp/ManageAccountsView.swift`: management window UI.
- Create `macos/CodexAuthApp/Tests/CodexAuthAppTests/ModelsTests.swift`: JSON decoding tests.
- Create `macos/CodexAuthApp/Tests/CodexAuthAppTests/CLIClientTests.swift`: fake CLI execution tests.
- Create `macos/CodexAuthApp/Tests/CodexAuthAppTests/AppStateTests.swift`: state transition tests.

## Task 1: Zig Parser Contract

**Files:**
- Modify: `src/cli/types.zig`
- Modify: `src/cli/commands/root.zig`
- Test: `tests/gui_command_test.zig`

- [ ] **Step 1: Write failing parser tests**

Add tests that parse:

```text
codex-auth gui state
codex-auth gui refresh --skip-api
codex-auth gui switch account-key
codex-auth gui remove account-key
codex-auth gui alias set account-key Work
codex-auth gui alias clear account-key
```

Expected: tests fail because `gui` is not recognized.

- [ ] **Step 2: Run parser tests**

Run: `zig build test --summary all`

Expected: FAIL with unknown command or missing `GuiOptions` errors.

- [ ] **Step 3: Implement minimal parser types and routing**

Add GUI command enums and parser branches without implementing workflows.

- [ ] **Step 4: Run parser tests**

Run: `zig build test --summary all`

Expected: parser tests pass or fail only because workflow symbols are not implemented.

## Task 2: Zig GUI State JSON

**Files:**
- Create: `src/workflows/gui.zig`
- Modify: `src/workflows/root.zig`
- Test: `tests/gui_command_test.zig`
- Create: `docs/gui.md`

- [ ] **Step 1: Write failing JSON state tests**

Test that `gui state --skip-api` returns JSON with `schema_version`, `codex_home`, `active_account_key`, `accounts`, and no raw token fields.

- [ ] **Step 2: Run JSON state tests**

Run: `zig build test --summary all`

Expected: FAIL because workflow is missing.

- [ ] **Step 3: Implement state JSON using registry display data**

Load and sync the registry like `list`, optionally refresh usage, then write compact JSON to stdout.

- [ ] **Step 4: Add docs**

Document commands and JSON fields in `docs/gui.md`; keep implementation details out of `README.md`.

- [ ] **Step 5: Run tests and required command**

Run: `zig build test --summary all`

Run: `zig build run -- list`

Expected: both exit 0.

## Task 3: Zig GUI Mutations

**Files:**
- Modify: `src/workflows/gui.zig`
- Test: `tests/gui_command_test.zig`

- [ ] **Step 1: Write failing mutation tests**

Cover `switch`, `remove`, `alias set`, `alias clear`, and `import` success/error JSON envelopes.

- [ ] **Step 2: Run mutation tests**

Run: `zig build test --summary all`

Expected: FAIL because mutation workflows are missing.

- [ ] **Step 3: Implement mutation workflows by delegating to existing registry operations**

Use existing registry functions for account activation, removal, aliasing, and import. Return JSON summaries without secrets.

- [ ] **Step 4: Run tests and required command**

Run: `zig build test --summary all`

Run: `zig build run -- list`

Expected: both exit 0.

## Task 4: Swift Models And CLI Client

**Files:**
- Create: `macos/CodexAuthApp/Package.swift`
- Create: `macos/CodexAuthApp/Sources/CodexAuthApp/Models.swift`
- Create: `macos/CodexAuthApp/Sources/CodexAuthApp/CodexAuthCLIClient.swift`
- Create: `macos/CodexAuthApp/Tests/CodexAuthAppTests/ModelsTests.swift`
- Create: `macos/CodexAuthApp/Tests/CodexAuthAppTests/CLIClientTests.swift`

- [ ] **Step 1: Write failing Swift decoding tests**

Decode representative `gui state` JSON and assert account labels, active account, usage windows, and Chinese fallback labels are derived correctly.

- [ ] **Step 2: Run Swift tests**

Run from `macos/CodexAuthApp`: `swift test`

Expected: FAIL because models do not exist.

- [ ] **Step 3: Implement models and CLI client**

Add `CodexAuthState`, `CodexAccount`, `UsageWindow`, `CodexAuthCLIClient`, and a fake-process injection point for tests.

- [ ] **Step 4: Run Swift tests**

Run from `macos/CodexAuthApp`: `swift test`

Expected: PASS.

## Task 5: Swift App State And UI

**Files:**
- Create: `macos/CodexAuthApp/Sources/CodexAuthApp/CodexAuthApp.swift`
- Create: `macos/CodexAuthApp/Sources/CodexAuthApp/AppState.swift`
- Create: `macos/CodexAuthApp/Sources/CodexAuthApp/MenuBarView.swift`
- Create: `macos/CodexAuthApp/Sources/CodexAuthApp/ManageAccountsView.swift`
- Create: `macos/CodexAuthApp/Tests/CodexAuthAppTests/AppStateTests.swift`

- [ ] **Step 1: Write failing app state tests**

Test refresh loading, switch success message, stale refresh error display, and delete confirmation state.

- [ ] **Step 2: Run Swift tests**

Run from `macos/CodexAuthApp`: `swift test`

Expected: FAIL because app state does not exist.

- [ ] **Step 3: Implement `AppState`**

Add async refresh, switch, remove, alias, import, login, and new Terminal session actions. Keep user-facing strings in Chinese.

- [ ] **Step 4: Implement SwiftUI views**

Build `MenuBarExtra`, compact account rows, toolbar buttons, management window, confirmation dialogs, and error details.

- [ ] **Step 5: Run Swift build and tests**

Run from `macos/CodexAuthApp`: `swift test`

Run from `macos/CodexAuthApp`: `swift build`

Expected: both exit 0.

## Task 6: Final Integration Verification

**Files:**
- Modify as needed based on failures.

- [ ] **Step 1: Run Zig verification**

Run: `zig build test --summary all`

Run: `zig build run -- list`

Expected: both exit 0.

- [ ] **Step 2: Run Swift verification**

Run from `macos/CodexAuthApp`: `swift test`

Run from `macos/CodexAuthApp`: `swift build`

Expected: both exit 0.

- [ ] **Step 3: Review docs**

Confirm `README.md` has no low-level implementation details and `docs/gui.md` covers the JSON backend.

## Self-Review

Spec coverage:

- macOS SwiftUI menu bar app: Task 5.
- CLI-backed account authority: Tasks 1-3.
- JSON contract: Task 2 and `docs/gui.md`.
- switching, add, delete, alias, import, usage: Tasks 2-5.
- Chinese GUI text and English CLI output: Tasks 4-5.
- verification: Task 6.

Placeholder scan: no unresolved placeholder markers or deferred implementation placeholders are present in implementation steps.

Type consistency: `account_key`, `CodexAuthState`, `CodexAccount`, and `UsageWindow` names are used consistently across Swift and Zig-facing plan steps.
