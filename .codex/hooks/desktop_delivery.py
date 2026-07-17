#!/usr/bin/env python3
"""在显式交付清单存在时完成桌面安装、提交和推送。"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from dataclasses import dataclass, replace
from pathlib import Path, PurePosixPath
from typing import Callable, Sequence


MARKER_RELATIVE_PATH = Path(".agent/desktop-delivery-ready.json")
INSTALL_SCRIPT_RELATIVE_PATH = Path("macos/CodexAuthApp/scripts/install-desktop-app.sh")
COMMIT_MESSAGE_PATTERN = re.compile(r"^(feat|fix|refactor|docs|style|chore): .+")
BRANCH_PATTERN = re.compile(r"^[A-Za-z0-9._/-]+$")


class DeliveryError(RuntimeError):
    """表示自动交付校验或命令执行失败。"""


@dataclass(frozen=True)
class DeliveryRequest:
    """描述一次经过白名单约束的桌面交付请求。"""

    version: int
    base_commit: str
    branch: str
    commit_message: str
    paths: tuple[str, ...]
    committed_head: str | None = None


CommandRunner = Callable[[Sequence[str], Path], str]


def normalize_relative_path(value: object) -> str:
    """校验并规范化仓库相对路径，拒绝越界和 Git 内部路径。"""
    if not isinstance(value, str) or not value.strip():
        raise DeliveryError("Delivery paths must be non-empty strings.")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or path.parts[0] == ".git":
        raise DeliveryError(f"Unsafe delivery path: {value}")
    normalized = path.as_posix()
    if normalized == MARKER_RELATIVE_PATH.as_posix():
        raise DeliveryError("The local delivery marker cannot be committed.")
    return normalized


def load_request(marker_path: Path) -> DeliveryRequest:
    """读取并严格校验一次性交付清单。"""
    try:
        raw = json.loads(marker_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise DeliveryError(f"Cannot read delivery marker: {error}") from error
    if not isinstance(raw, dict) or raw.get("version") != 1:
        raise DeliveryError("Delivery marker version must be 1.")

    base_commit = raw.get("base_commit")
    branch = raw.get("branch")
    commit_message = raw.get("commit_message")
    raw_paths = raw.get("paths")
    committed_head = raw.get("committed_head")
    if not isinstance(base_commit, str) or not re.fullmatch(r"[0-9a-f]{40}", base_commit):
        raise DeliveryError("base_commit must be a full Git commit hash.")
    if not isinstance(branch, str) or not BRANCH_PATTERN.fullmatch(branch) or branch.startswith("-"):
        raise DeliveryError("branch contains unsupported characters.")
    if not isinstance(commit_message, str) or not COMMIT_MESSAGE_PATTERN.fullmatch(commit_message):
        raise DeliveryError("commit_message must use '<type>: <description>'.")
    if not any(ord(character) > 127 for character in commit_message.split(":", 1)[1]):
        raise DeliveryError("The commit description must be written in Chinese.")
    if not isinstance(raw_paths, list) or not raw_paths:
        raise DeliveryError("paths must contain at least one repository file.")
    paths = tuple(sorted({normalize_relative_path(value) for value in raw_paths}))
    if len(paths) != len(raw_paths):
        raise DeliveryError("paths must not contain duplicates.")
    if committed_head is not None and (
        not isinstance(committed_head, str) or not re.fullmatch(r"[0-9a-f]{40}", committed_head)
    ):
        raise DeliveryError("committed_head must be a full Git commit hash when present.")
    return DeliveryRequest(
        version=1,
        base_commit=base_commit,
        branch=branch,
        commit_message=commit_message,
        paths=paths,
        committed_head=committed_head,
    )


def write_request(marker_path: Path, request: DeliveryRequest) -> None:
    """原子更新已提交但待推送的恢复状态。"""
    payload = {
        "version": request.version,
        "base_commit": request.base_commit,
        "branch": request.branch,
        "commit_message": request.commit_message,
        "paths": list(request.paths),
    }
    if request.committed_head is not None:
        payload["committed_head"] = request.committed_head
    temporary_path = marker_path.with_suffix(".tmp")
    temporary_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary_path.replace(marker_path)


def run_command(arguments: Sequence[str], cwd: Path) -> str:
    """运行交付命令并将非零退出转换为可读错误。"""
    try:
        result = subprocess.run(
            list(arguments),
            cwd=cwd,
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError as error:
        raise DeliveryError(f"Cannot run {' '.join(arguments)}: {error}") from error
    if result.returncode != 0:
        details = (result.stderr or result.stdout).strip()
        raise DeliveryError(f"Command failed ({' '.join(arguments)}): {details}")
    return result.stdout.strip()


def changed_paths(repo_root: Path, runner: CommandRunner) -> set[str]:
    """返回相对 HEAD 的跟踪改动和未忽略的新文件集合。"""
    tracked = runner(["git", "diff", "--name-only", "--no-renames", "HEAD"], repo_root)
    untracked = runner(["git", "ls-files", "--others", "--exclude-standard"], repo_root)
    return {line for line in f"{tracked}\n{untracked}".splitlines() if line}


def staged_paths(repo_root: Path, runner: CommandRunner) -> set[str]:
    """返回暂存区相对 HEAD 的文件集合。"""
    output = runner(["git", "diff", "--cached", "--name-only", "--no-renames", "HEAD"], repo_root)
    return {line for line in output.splitlines() if line}


def require_exact_paths(actual: set[str], expected: set[str], stage: str) -> None:
    """要求实际改动与清单白名单完全一致。"""
    if actual == expected:
        return
    missing = sorted(expected - actual)
    unexpected = sorted(actual - expected)
    raise DeliveryError(
        f"Delivery path mismatch during {stage}; missing={missing}, unexpected={unexpected}."
    )


def push_committed_request(
    repo_root: Path,
    marker_path: Path,
    request: DeliveryRequest,
    runner: CommandRunner,
) -> None:
    """恢复已经提交但尚未成功推送的交付请求。"""
    current_head = runner(["git", "rev-parse", "HEAD"], repo_root)
    if current_head != request.committed_head:
        raise DeliveryError("HEAD changed after the delivery commit; refusing to push.")
    if changed_paths(repo_root, runner):
        raise DeliveryError("The worktree changed after the delivery commit; refusing to push.")
    subject = runner(["git", "show", "-s", "--format=%s", "HEAD"], repo_root)
    if subject != request.commit_message:
        raise DeliveryError("The pending delivery commit message no longer matches HEAD.")
    runner(["git", "push", "origin", request.branch], repo_root)
    marker_path.unlink()


def execute_delivery(
    repo_root: Path,
    marker_path: Path,
    request: DeliveryRequest,
    runner: CommandRunner = run_command,
) -> None:
    """按安装、校验、提交、推送的顺序执行一次自动交付。"""
    if request.committed_head is not None:
        push_committed_request(repo_root, marker_path, request, runner)
        return

    current_branch = runner(["git", "branch", "--show-current"], repo_root)
    if current_branch != request.branch:
        raise DeliveryError(f"Expected branch {request.branch}, found {current_branch}.")
    current_head = runner(["git", "rev-parse", "HEAD"], repo_root)
    if current_head != request.base_commit:
        raise DeliveryError("HEAD changed after the delivery marker was created.")

    expected_paths = set(request.paths)
    require_exact_paths(changed_paths(repo_root, runner), expected_paths, "pre-install validation")

    install_script = repo_root / INSTALL_SCRIPT_RELATIVE_PATH
    runner([str(install_script)], repo_root)
    require_exact_paths(changed_paths(repo_root, runner), expected_paths, "post-install validation")

    runner(["git", "add", "--", *request.paths], repo_root)
    require_exact_paths(staged_paths(repo_root, runner), expected_paths, "staging validation")
    runner(["git", "commit", "-m", request.commit_message], repo_root)

    committed_head = runner(["git", "rev-parse", "HEAD"], repo_root)
    committed_request = replace(request, committed_head=committed_head)
    write_request(marker_path, committed_request)
    runner(["git", "push", "origin", request.branch], repo_root)
    marker_path.unlink()


def hook_failure(error: DeliveryError) -> None:
    """向 Stop Hook 返回可继续修复的阻断信息。"""
    print(
        json.dumps(
            {
                "continue": False,
                "stopReason": str(error),
                "systemMessage": f"Desktop delivery stopped: {error}",
            }
        )
    )


def main() -> int:
    """解析交付清单，并根据 Hook 或手动模式报告执行结果。"""
    manual_mode = "--manual" in sys.argv[1:]
    repo_root = Path(__file__).resolve().parents[2]
    marker_path = repo_root / MARKER_RELATIVE_PATH
    if not marker_path.exists():
        return 0

    try:
        request = load_request(marker_path)
        execute_delivery(repo_root, marker_path, request)
    except DeliveryError as error:
        if manual_mode:
            print(f"Desktop delivery stopped: {error}", file=sys.stderr)
            return 1
        hook_failure(error)
        return 0

    if manual_mode:
        print("Desktop delivery completed successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
