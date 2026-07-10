# Language

- All user-facing CLI output, prompts, help text, warnings, and error messages must be written in English only.

# Validation

After modifying any `.zig` file, always run `zig build run -- list` to verify the changes work correctly.

# Execution Isolation

- Run tests, review commands, and other side-effecting tooling from an isolated directory under `/tmp/<task-name>` with `HOME=/tmp/<task-name>`.

# Desktop App Installation

- Use `macos/CodexAuthApp/scripts/install-desktop-app.sh` as the single entry point for compiling, overwriting, launching, and verifying the desktop app on the user's Desktop.
- When the user explicitly asks to install, reinstall, or overwrite the desktop app, that request authorizes the tool to quit the running desktop app, overwrite `~/Desktop/Codex Auth.app`, and relaunch it after normal code validation succeeds.
- When a completed desktop app change needs user verification but the user has not explicitly requested installation, explain that the running app will be quit and the Desktop copy overwritten, then wait for confirmation before running the tool.
- Run this tool with the real user `HOME`; this is a scoped exception to Execution Isolation because its target is the real Desktop. Build and test commands outside this installation workflow must remain isolated.
- Do not manually compose the build, quit, copy, launch, and process-check commands unless diagnosing a failure in the installation tool itself.

# Release Process

- When updating and pushing a release version, always follow [docs/release.md](./docs/release.md).

# Docs

- Do not add low-level technical implementation details to `README.md`. Put implementation-specific behavior in `docs/*.md` or `AGENTS.md` instead.

# Zig API Discovery

- Do not guess Zig APIs from memory or from examples targeting other Zig versions.
- Before using or changing a Zig API, run `zig env` and `zig version` to confirm the local toolchain and source layout.
- Use the paths reported by `zig env` as the source of truth, especially `std_dir` for the standard library and `lib_dir` for other bundled Zig libraries.
- Prefer evidence from local sources: symbol definitions, nearby tests, and existing call sites in this repository.
- If the needed behavior is not clear from `std_dir`, inspect other Zig sources and tests under the local `lib_dir` tree as needed.
