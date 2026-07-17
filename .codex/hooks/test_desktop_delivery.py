#!/usr/bin/env python3
"""验证桌面自动交付 Hook 的白名单和失败短路行为。"""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from typing import Sequence

from desktop_delivery import (
    DeliveryError,
    DeliveryRequest,
    execute_delivery,
    load_request,
    require_exact_paths,
)


BASE_COMMIT = "a" * 40
COMMITTED_HEAD = "b" * 40


class FakeRunner:
    """用可预测的 Git 输出模拟成功或安装失败的交付命令。"""

    def __init__(self, fail_install: bool = False, resume_push: bool = False) -> None:
        self.fail_install = fail_install
        self.resume_push = resume_push
        self.commands: list[tuple[str, ...]] = []
        self.head_reads = 0

    def __call__(self, arguments: Sequence[str], cwd: Path) -> str:
        """记录命令并返回当前测试场景需要的结果。"""
        command = tuple(arguments)
        self.commands.append(command)
        if command == ("git", "branch", "--show-current"):
            return "main"
        if command == ("git", "rev-parse", "HEAD"):
            if self.resume_push:
                return COMMITTED_HEAD
            self.head_reads += 1
            return BASE_COMMIT if self.head_reads == 1 else COMMITTED_HEAD
        if command[:4] == ("git", "diff", "--name-only", "--no-renames"):
            return "" if self.resume_push else "Sources/App.swift"
        if command == ("git", "ls-files", "--others", "--exclude-standard"):
            return ""
        if command[:5] == ("git", "diff", "--cached", "--name-only", "--no-renames"):
            return "Sources/App.swift"
        if command == ("git", "show", "-s", "--format=%s", "HEAD"):
            return "feat: 自动交付"
        if command[0].endswith("install-desktop-app.sh") and self.fail_install:
            raise DeliveryError("simulated install failure")
        return ""


class DesktopDeliveryTests(unittest.TestCase):
    """覆盖交付清单校验、成功顺序和失败阻断。"""

    def test_load_request_rejects_path_outside_repository(self) -> None:
        """拒绝包含父目录跳转的交付清单。"""
        with tempfile.TemporaryDirectory() as temporary_directory:
            marker = Path(temporary_directory) / "request.json"
            marker.write_text(
                json.dumps(
                    {
                        "version": 1,
                        "base_commit": BASE_COMMIT,
                        "branch": "main",
                        "commit_message": "feat: 自动交付",
                        "paths": ["../secret"],
                    },
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )

            with self.assertRaises(DeliveryError):
                load_request(marker)

    def test_require_exact_paths_rejects_unexpected_changes(self) -> None:
        """工作区出现白名单外文件时必须阻止交付。"""
        with self.assertRaises(DeliveryError):
            require_exact_paths(
                {"Sources/App.swift", "README.md"},
                {"Sources/App.swift"},
                "test",
            )

    def test_execute_delivery_installs_before_commit_and_push(self) -> None:
        """成功路径必须先安装验证，再提交和推送。"""
        with tempfile.TemporaryDirectory() as temporary_directory:
            repo_root = Path(temporary_directory)
            marker = repo_root / "request.json"
            marker.write_text("{}", encoding="utf-8")
            request = DeliveryRequest(
                version=1,
                base_commit=BASE_COMMIT,
                branch="main",
                commit_message="feat: 自动交付",
                paths=("Sources/App.swift",),
            )
            runner = FakeRunner()

            execute_delivery(repo_root, marker, request, runner)

            commands = runner.commands
            install_index = next(index for index, command in enumerate(commands) if command[0].endswith("install-desktop-app.sh"))
            commit_index = next(index for index, command in enumerate(commands) if command[:2] == ("git", "commit"))
            push_index = next(index for index, command in enumerate(commands) if command[:2] == ("git", "push"))
            self.assertLess(install_index, commit_index)
            self.assertLess(commit_index, push_index)
            self.assertFalse(marker.exists())

    def test_execute_delivery_stops_before_commit_when_install_fails(self) -> None:
        """安装失败后不得继续提交或推送，并保留交付清单。"""
        with tempfile.TemporaryDirectory() as temporary_directory:
            repo_root = Path(temporary_directory)
            marker = repo_root / "request.json"
            marker.write_text("{}", encoding="utf-8")
            request = DeliveryRequest(
                version=1,
                base_commit=BASE_COMMIT,
                branch="main",
                commit_message="feat: 自动交付",
                paths=("Sources/App.swift",),
            )
            runner = FakeRunner(fail_install=True)

            with self.assertRaises(DeliveryError):
                execute_delivery(repo_root, marker, request, runner)

            self.assertFalse(any(command[:2] == ("git", "commit") for command in runner.commands))
            self.assertFalse(any(command[:2] == ("git", "push") for command in runner.commands))
            self.assertTrue(marker.exists())

    def test_execute_delivery_resumes_only_pending_push(self) -> None:
        """已有 committed_head 时只重试精确提交的 push，不重复安装和提交。"""
        with tempfile.TemporaryDirectory() as temporary_directory:
            repo_root = Path(temporary_directory)
            marker = repo_root / "request.json"
            marker.write_text("{}", encoding="utf-8")
            request = DeliveryRequest(
                version=1,
                base_commit=BASE_COMMIT,
                branch="main",
                commit_message="feat: 自动交付",
                paths=("Sources/App.swift",),
                committed_head=COMMITTED_HEAD,
            )
            runner = FakeRunner(resume_push=True)

            execute_delivery(repo_root, marker, request, runner)

            self.assertTrue(any(command[:2] == ("git", "push") for command in runner.commands))
            self.assertFalse(any(command[:2] == ("git", "commit") for command in runner.commands))
            self.assertFalse(any(command[0].endswith("install-desktop-app.sh") for command in runner.commands))
            self.assertFalse(marker.exists())


if __name__ == "__main__":
    unittest.main()
