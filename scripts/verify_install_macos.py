#!/usr/bin/env python3
"""Verify a macOS Codex academic workflow installation."""

from __future__ import annotations

import argparse
import ast
import json
import os
import platform
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install-root", help="Alternate home used by an isolated installation")
    return parser.parse_args()


class Verifier:
    def __init__(self, args: argparse.Namespace) -> None:
        self.package_root = Path(__file__).resolve().parents[1]
        self.home = (
            Path(args.install_root).expanduser().resolve()
            if args.install_root
            else Path.home().resolve()
        )
        self.codex_home = (
            self.home / ".codex"
            if args.install_root
            else Path(os.environ.get("CODEX_HOME", self.home / ".codex")).expanduser().resolve()
        )
        self.skills_root = self.home / ".agents" / "skills"
        self.failures: list[str] = []
        self.release = json.loads((self.package_root / "RELEASE.json").read_text(encoding="utf-8"))

    def fail(self, message: str) -> None:
        print(f"FAIL  {message}")
        self.failures.append(message)

    @staticmethod
    def passed(message: str) -> None:
        print(f"PASS  {message}")

    def require_file(self, path: Path, label: str) -> None:
        if path.is_file():
            self.passed(label)
        else:
            self.fail(f"{label}: {path}")

    @staticmethod
    def academic_hook_group(group: Any) -> bool:
        if not isinstance(group, dict) or not isinstance(group.get("hooks"), list):
            return False
        commands = " ".join(
            str(handler.get(name, ""))
            for handler in group["hooks"]
            if isinstance(handler, dict)
            for name in ("command", "commandWindows", "command_windows")
        )
        return bool(re.search(r"[\\/]academic-workflow[\\/]", commands))

    def verify(self) -> int:
        manifest_path = self.codex_home / "academic-workflow-install.json"
        self.require_file(manifest_path, "installation manifest")
        if not manifest_path.is_file():
            return 1
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        expected_version = (self.package_root / "VERSION").read_text(encoding="utf-8").strip()
        if manifest.get("package_version") == expected_version:
            self.passed(f"package version {expected_version}")
        else:
            self.fail(f"package version {manifest.get('package_version')} (expected {expected_version})")
        if manifest.get("source_commit") == self.release.get("upstream_commit"):
            self.passed(f"upstream source commit {self.release['upstream_commit']}")
        else:
            self.fail("upstream source commit mismatch")

        agents_file = self.codex_home / "AGENTS.md"
        self.require_file(agents_file, "global AGENTS.md")
        if agents_file.is_file():
            text = agents_file.read_text(encoding="utf-8")
            if text.count("<!-- BEGIN academic-workflow -->") == 1 and text.count("<!-- END academic-workflow -->") == 1:
                self.passed("one global academic workflow block")
            else:
                self.fail("global academic workflow block count")

        skill_directories = sorted(self.skills_root.glob("academic-workflow-*"))
        expected_skills = int(self.release.get("expected_skills", 56))
        print(f"INFO  converted skills: {len(skill_directories)}")
        if len(skill_directories) == expected_skills:
            self.passed("converted skill count")
        else:
            self.fail(f"converted skill count {len(skill_directories)}/{expected_skills}")
        stale_patterns = (
            r"the arguments and context supplied by the user",
            r"(?i)\bclaude\s+(--continue|-p|mcp)\b",
            r"CLAUDE_PROJECT_DIR",
            r"(?i)(?<![A-Za-z0-9_-])\.claude[\\/]",
            r"(?i)\bMonitor tool\b",
            r"context\s*[:=]\s*fork",
            r"subagent_type=",
        )
        for directory in skill_directories:
            skill_file = directory / "SKILL.md"
            if not skill_file.is_file():
                self.fail(f"skill missing SKILL.md: {directory.name}")
                continue
            text = skill_file.read_text(encoding="utf-8")
            match = re.match(r"\A---\s*\n(.*?)\n---\s*\n", text, flags=re.S)
            if not match:
                self.fail(f"skill invalid frontmatter: {directory.name}")
                continue
            fields = []
            values: dict[str, str] = {}
            for line in match.group(1).splitlines():
                field = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
                if field:
                    fields.append(field.group(1))
                    values[field.group(1)] = field.group(2).strip().strip('"').strip("'")
            if set(fields) != {"name", "description"} or values.get("name") != directory.name:
                self.fail(f"skill frontmatter/folder mismatch: {directory.name}")
            for pattern in stale_patterns:
                if re.search(pattern, text):
                    self.fail(f"active Claude residue in skill: {directory.name} ({pattern})")
                    break
        if not any(item.startswith(("skill ", "active Claude residue")) for item in self.failures):
            self.passed("skill frontmatter, folder names, and Codex conversion")

        agent_files = sorted((self.codex_home / "agents").glob("academic_*.toml"))
        expected_agents = int(self.release.get("expected_custom_agents", 18))
        print(f"INFO  converted agents: {len(agent_files)}")
        if len(agent_files) == expected_agents:
            self.passed("converted agent count")
        else:
            self.fail(f"converted agent count {len(agent_files)}/{expected_agents}")
        for agent_file in agent_files:
            text = agent_file.read_text(encoding="utf-8")
            for field in ("name", "description", "developer_instructions"):
                if not re.search(rf"(?m)^{field}\s*=", text):
                    self.fail(f"agent missing {field}: {agent_file.name}")
            if not re.search(r'(?m)^sandbox_mode\s*=\s*"(read-only|workspace-write)"\s*$', text):
                self.fail(f"agent invalid sandbox_mode: {agent_file.name}")
            for pattern in stale_patterns:
                if re.search(pattern, text):
                    self.fail(f"agent Claude residue: {agent_file.name} ({pattern})")
                    break
        if not any(item.startswith("agent ") for item in self.failures):
            self.passed("agent fields, sandboxes, and Codex conversion")

        rules_file = self.codex_home / "rules" / "academic-workflow.rules"
        self.require_file(rules_file, "global Git safety rules")
        self.require_file(self.codex_home / "academic-workflow-state" / "personal-memory.md", "personal workflow memory")
        self.require_file(
            self.skills_root / "academic-workflow-init" / "scripts" / "init-project.py",
            "macOS project initializer",
        )
        self.require_file(
            self.skills_root / "academic-workflow-init" / "assets" / "project-scripts" / "compile-latex.sh",
            "macOS LaTeX project script",
        )
        self.require_file(
            self.skills_root / "academic-workflow-init" / "assets" / "project-scripts" / "sync-to-docs.sh",
            "macOS Quarto deployment script",
        )

        hooks_config_path = self.codex_home / "hooks.json"
        hooks_root = self.codex_home / "hooks" / "academic-workflow"
        if manifest.get("hooks_config"):
            self.require_file(hooks_config_path, "Codex hook configuration")
            hook_scripts = sorted(hooks_root.glob("*.py"))
            expected_hook_scripts = int(self.release.get("expected_hook_scripts", 6))
            if len(hook_scripts) == expected_hook_scripts:
                self.passed(f"Codex hook scripts ({expected_hook_scripts})")
            else:
                self.fail(f"Codex hook script count {len(hook_scripts)}/{expected_hook_scripts}")
            for hook_script in hook_scripts:
                try:
                    ast.parse(hook_script.read_text(encoding="utf-8"))
                except SyntaxError as exc:
                    self.fail(f"hook Python parse: {hook_script.name}: {exc}")
            if not any(item.startswith("hook Python parse") for item in self.failures):
                self.passed("hook Python syntax")
            if hooks_config_path.is_file():
                config = json.loads(hooks_config_path.read_text(encoding="utf-8"))
                hooks = config.get("hooks", {})
                groups = [
                    (event, group)
                    for event, event_groups in hooks.items()
                    if isinstance(event_groups, list)
                    for group in event_groups
                    if self.academic_hook_group(group)
                ]
                expected_groups = int(self.release.get("expected_hook_groups", 5))
                if len(groups) == expected_groups:
                    self.passed(f"Codex academic hook groups ({expected_groups})")
                else:
                    self.fail(f"Codex academic hook groups {len(groups)}/{expected_groups}")
                for event, group in groups:
                    for handler in group.get("hooks", []):
                        has_limit = "additionalContextLimit" in handler
                        if event in {"PreToolUse", "PostToolUse", "SessionStart"} and not has_limit:
                            self.fail(f"missing additionalContextLimit for {event} academic hook")
                        if event in {"PreCompact", "Stop"} and has_limit:
                            self.fail(f"unsupported additionalContextLimit for {event} academic hook")
                if not any("additionalContextLimit" in item for item in self.failures):
                    self.passed("hook additionalContextLimit event compatibility")

        if manifest.get("cli_ui_defaults_installed"):
            config_file = self.codex_home / "config.toml"
            if config_file.is_file() and re.search(r"(?m)^\s*status_line\s*=", config_file.read_text(encoding="utf-8")):
                self.passed("Codex native status line configuration")
            else:
                self.fail("Codex native status line configuration")

        init_script = self.skills_root / "academic-workflow-init" / "scripts" / "init-project.py"
        if init_script.is_file():
            try:
                ast.parse(init_script.read_text(encoding="utf-8"))
                self.passed("macOS project initializer syntax")
            except SyntaxError as exc:
                self.fail(f"macOS project initializer syntax: {exc}")
        bash = shutil.which("bash")
        if platform.system() == "Darwin" and bash:
            for script in (
                self.skills_root / "academic-workflow-init" / "assets" / "project-scripts" / "compile-latex.sh",
                self.skills_root / "academic-workflow-init" / "assets" / "project-scripts" / "sync-to-docs.sh",
            ):
                if script.is_file():
                    result = subprocess.run([bash, "-n", str(script)], capture_output=True, text=True, check=False)
                    if result.returncode != 0:
                        self.fail(f"shell syntax: {script.name}: {result.stderr.strip()}")
            if not any(item.startswith("shell syntax") for item in self.failures):
                self.passed("macOS project shell syntax")
        elif platform.system() != "Darwin":
            print("INFO  macOS project shell execution deferred: verifier is not running on macOS")
        else:
            self.fail("bash is required on macOS")

        for tool in ("git", "codex", "python3", "xelatex"):
            status = "available" if shutil.which(tool) else "missing"
            print(f"INFO  tool {status}: {tool}")
        for tool in ("Rscript", "quarto"):
            status = "available" if shutil.which(tool) else "missing"
            print(f"INFO  optional tool {status}: {tool}")

        if self.failures:
            print(f"\nVerification failed with {len(self.failures)} finding(s).", file=sys.stderr)
            return 1
        print("\nStatic macOS installation checks passed. Restart Codex to refresh skills and custom agents.")
        return 0


def main() -> int:
    try:
        return Verifier(parse_args()).verify()
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"Verification failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
