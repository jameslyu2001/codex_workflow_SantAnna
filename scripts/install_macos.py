#!/usr/bin/env python3
"""Install the Codex academic workflow into a macOS user profile."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional


DEFAULT_REPOSITORY_URL = "https://github.com/pedrohcgs/claude-code-my-workflow.git"
DEFAULT_REPOSITORY_REF = "be53c12f235996dff41fb7f21580506fd2dd8d50"
AGENT_BASE_NAMES = (
    "beamer-translator",
    "claim-verifier",
    "domain-referee",
    "domain-reviewer",
    "editor",
    "humanize-auditor",
    "methods-referee",
    "pedagogy-reviewer",
    "promote-memory-council",
    "proofreader",
    "quarto-critic",
    "quarto-fixer",
    "r-package-reviewer",
    "r-reviewer",
    "sim-reviewer",
    "slide-auditor",
    "tikz-reviewer",
    "verifier",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-path", help="Existing upstream checkout for offline installation")
    parser.add_argument("--install-root", help="Alternate home directory, mainly for isolated testing")
    parser.add_argument("--repository-url", default=DEFAULT_REPOSITORY_URL)
    parser.add_argument("--repository-ref", default=DEFAULT_REPOSITORY_REF)
    parser.add_argument("--bypass-github-proxy", action="store_true")
    parser.add_argument("--skip-global-agents-block", action="store_true")
    parser.add_argument("--skip-hooks", action="store_true")
    parser.add_argument("--skip-cli-ui-defaults", action="store_true")
    return parser.parse_args()


class Installer:
    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
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
        self.vendor_root = self.codex_home / "vendor" / "academic-workflow"
        self.agents_file = self.codex_home / "AGENTS.md"
        self.agents_override_file = self.codex_home / "AGENTS.override.md"
        self.custom_agents_root = self.codex_home / "agents"
        self.rules_root = self.codex_home / "rules"
        self.hooks_root = self.codex_home / "hooks" / "academic-workflow"
        self.hooks_config_file = self.codex_home / "hooks.json"
        self.config_file = self.codex_home / "config.toml"
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        self.backup_root = self.codex_home / "backups" / "academic-workflow" / timestamp
        self.package_version = (
            (self.package_root / "VERSION").read_text(encoding="utf-8").strip()
            if (self.package_root / "VERSION").is_file()
            else "development"
        )

    @staticmethod
    def write_text(path: Path, value: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", encoding="utf-8", newline="\n") as handle:
            handle.write(value)

    def backup_file(self, path: Path) -> None:
        if not path.is_file():
            return
        self.backup_root.mkdir(parents=True, exist_ok=True)
        path_hash = hashlib.sha256(str(path.resolve()).lower().encode("utf-8")).hexdigest()[:12]
        safe_leaf = re.sub(r"[^A-Za-z0-9._-]", "_", path.name)
        shutil.copy2(path, self.backup_root / f"{path_hash}-{safe_leaf}")

    def git(self, arguments: list[str], failure_message: str) -> str:
        command = ["git"]
        if self.args.bypass_github_proxy:
            command.extend(
                ["-c", "http.https://github.com.proxy=", "-c", "https.https://github.com.proxy="]
            )
        command.extend(arguments)
        result = subprocess.run(command, text=True, capture_output=True, check=False)
        if result.stdout:
            print(result.stdout, end="")
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
        if result.returncode != 0:
            raise RuntimeError(failure_message)
        return result.stdout.strip()

    def resolve_source(self) -> Path:
        if self.args.source_path:
            source = Path(self.args.source_path).expanduser().resolve()
            if not (source / ".claude" / "skills").is_dir():
                raise RuntimeError(f"Source path does not contain .claude/skills: {source}")
            return source
        self.vendor_root.parent.mkdir(parents=True, exist_ok=True)
        if (self.vendor_root / ".git").is_dir():
            self.git(
                ["-C", str(self.vendor_root), "fetch", "--prune", "origin"],
                f"Could not fetch the vendor source at {self.vendor_root}",
            )
        elif self.vendor_root.exists():
            raise RuntimeError(
                f"Vendor target already exists but is not a Git repository: {self.vendor_root}"
            )
        else:
            self.git(
                ["clone", self.args.repository_url, str(self.vendor_root)],
                f"Could not clone {self.args.repository_url}",
            )
        self.git(
            ["-C", str(self.vendor_root), "checkout", "--detach", self.args.repository_ref],
            f"Could not check out pinned upstream ref {self.args.repository_ref}",
        )
        return self.vendor_root

    @staticmethod
    def frontmatter_value(text: str, key: str) -> Optional[str]:
        match = re.search(rf"(?m)^{re.escape(key)}:\s*(.+)$", text)
        return match.group(1).strip().strip('"').strip("'") if match else None

    @staticmethod
    def remove_frontmatter(text: str) -> str:
        return re.sub(r"\A---\s*\r?\n.*?\r?\n---\s*\r?\n", "", text, flags=re.S)

    @staticmethod
    def copy_contents(source: Path, destination: Path) -> None:
        if not source.is_dir():
            return
        destination.mkdir(parents=True, exist_ok=True)
        for item in source.iterdir():
            target = destination / item.name
            if item.is_dir():
                shutil.copytree(item, target, dirs_exist_ok=True)
            elif item.is_file():
                shutil.copy2(item, target)

    def convert_text(self, text: str, skill_names: list[str]) -> str:
        converted = text
        replacements = (
            ("$ARGUMENTS", "<user-input>"),
            ("$CLAUDE_PROJECT_DIR", "the current Git repository root"),
            (".claude/rules/", "../academic-workflow-core/references/rules/"),
            ("../../rules/", "../academic-workflow-core/references/rules/"),
            (".claude/references/", "../academic-workflow-core/references/upstream/"),
            ("../../references/", "../academic-workflow-core/references/upstream/"),
            ("../../../templates/", "../academic-workflow-core/assets/templates/"),
            ("Task tool", "Codex subagent tools"),
            ("via Task", "with a Codex subagent"),
            ("`Task`", "Codex subagent delegation"),
            ("Grep / Read / Glob", "search and read the cited files"),
            ("Glob/Read", "file search and reading"),
            ("`Glob`/`Read`", "file search and reading"),
            ("AskUserQuestion", "ask the user"),
            ("Monitor tool", "Codex background-process monitoring or wait tools"),
            ("the Monitor tool", "Codex background-process monitoring or wait tools"),
            ("`run_in_background: true`", "background execution enabled"),
            ("run_in_background: true", "background execution enabled"),
            ("the `bash_id`", "the returned process identifier"),
            (
                "Anthropic's **Codex background-process monitoring or wait tools**",
                "Codex background-process monitoring or wait tools",
            ),
            ("via Bash", "using the available background-process mechanism"),
            ("using Bash", "using the available background-process mechanism"),
            ("context: fork", "fork_turns: none"),
            ("context=fork", 'fork_turns="none"'),
            ("subagent_type=", "agent_type="),
            ("WebSearch", "web search"),
            ("WebFetch", "page retrieval"),
        )
        for old, new in replacements:
            converted = converted.replace(old, new)
        converted = re.sub(r"\bOpus(?:\s+\d+(?:\.\d+)*)?", "the configured high-judgment Codex model", converted)
        converted = re.sub(r"\bSonnet(?:\s+\d+(?:\.\d+)*)?", "the configured balanced Codex model", converted)
        converted = re.sub(r"\bHaiku(?:\s+\d+(?:\.\d+)*)?", "the configured fast Codex model", converted)
        for old, new in (
            ("`Glob`", "file search"),
            ("`Grep`", "text search"),
            ("`Read`", "file reading"),
            ("`Write`", "file writing"),
            ("`Edit`", "file editing"),
            ("`MultiEdit`", "file editing"),
            ("`Bash`", "the shell"),
            ("[Claude Code](https://claude.com/claude-code)", "Codex"),
            ("Claude Code", "Codex"),
        ):
            converted = converted.replace(old, new)
        converted = re.sub(r"(?<![A-Za-z0-9_-])claude\s+--continue\b", "codex resume --last", converted, flags=re.I)
        converted = re.sub(r"(?<![A-Za-z0-9_-])claude\s+-p\b", "codex exec", converted, flags=re.I)
        converted = re.sub(r"(?<![A-Za-z0-9_-])claude\s+mcp\b", "codex mcp", converted, flags=re.I)
        converted = re.sub(r"\bClaude\b", "Codex", converted)
        for old, new in (
            ("CLAUDE.md", "AGENTS.md"),
            (".claude/state/personal-memory.md", "~/.codex/academic-workflow-state/personal-memory.md"),
            (".claude/state/", "~/.codex/academic-workflow-state/"),
            ("CLAUDE_STRICT_PATHS", "CODEX_ACADEMIC_STRICT_PATHS"),
            ("CLAUDE_COMPILE_GATE", "CODEX_ACADEMIC_COMPILE_GATE"),
            ("CLAUDE_PRECOMPACT_BLOCK_ON_DRAFT", "CODEX_ACADEMIC_PRECOMPACT_BLOCK_ON_DRAFT"),
        ):
            converted = converted.replace(old, new)
        converted = re.sub(
            r"(?m)^- `\.claude/hooks/pre-compact\.py`.*$",
            "- The Codex-native PreCompact hook records plan and session state; use "
            "`$academic-workflow-compress-session` for an explicit durable handoff.",
            converted,
        )
        converted = re.sub(
            r" or sets `verifyClaims\.allowHighWarn: true` in `\.claude/settings\.json`",
            "",
            converted,
        )
        converted = re.sub(
            r"\[`?\.claude/agents/([a-z0-9-]+)\.md`?\]\((?:\.\./)+agents/\1\.md\)",
            lambda match: f"`academic_{match.group(1).replace('-', '_')}` custom agent",
            converted,
        )
        converted = re.sub(
            r"(?:\.claude/agents/|(?:\.\./)+agents/)([a-z0-9-]+)\.md",
            lambda match: f"`academic_{match.group(1).replace('-', '_')}` custom agent",
            converted,
        )
        converted = re.sub(
            r"\[[^\]]+\]\(`?(academic_[a-z0-9_]+)`? custom agent\)",
            lambda match: f"`{match.group(1)}` custom agent",
            converted,
        )
        converted = re.sub(
            r"\.claude/skills/([a-z0-9-]+)(?:/SKILL\.md)?",
            lambda match: f"$academic-workflow-{match.group(1)}",
            converted,
        )
        for old, new in (
            (".claude/skills/", "~/.agents/skills/"),
            (".claude/agents/", "~/.codex/agents/"),
            (".claude/hooks/", "~/.codex/hooks/academic-workflow/"),
            (".claude/output-styles/academic-writing.md", "$academic-workflow-style-academic-writing"),
            (".claude/output-styles/referee.md", "$academic-workflow-style-referee"),
            (".claude/settings.local.json", ".codex/config.toml"),
            (".claude/settings.json", "~/.codex/config.toml"),
        ):
            converted = converted.replace(old, new)
        for base_name in AGENT_BASE_NAMES:
            agent_name = "academic_" + base_name.replace("-", "_")
            for old, new in (
                (f"`{base_name}`", f"`{agent_name}`"),
                (f"{base_name}.md", f"{agent_name}.toml"),
                (f"agent_type={base_name}", f"agent_type={agent_name}"),
                (f"{base_name} agent", f"`{agent_name}` custom agent"),
                (f"{base_name} subagent", f"`{agent_name}` custom agent"),
                (f"({base_name})", f"(`{agent_name}`)"),
            ):
                converted = converted.replace(old, new)
        for skill_name in skill_names:
            converted = converted.replace(f"../{skill_name}/", f"../academic-workflow-{skill_name}/")
            converted = re.sub(
                rf"(?<![A-Za-z0-9_.-])/{re.escape(skill_name)}\b",
                f"$academic-workflow-{skill_name}",
                converted,
            )
        return converted

    def install_global_agents_block(self) -> None:
        block = (self.package_root / "templates" / "global-AGENTS.block.md").read_text(encoding="utf-8").strip()
        start = "<!-- BEGIN academic-workflow -->"
        end = "<!-- END academic-workflow -->"
        if self.agents_file.is_file():
            self.backup_file(self.agents_file)
            existing = self.agents_file.read_text(encoding="utf-8")
            pattern = re.escape(start) + r".*?" + re.escape(end)
            if re.search(pattern, existing, flags=re.S):
                merged = re.sub(pattern, lambda _: block, existing, flags=re.S)
            else:
                merged = existing.rstrip() + "\n\n" + block + "\n"
        else:
            merged = block + "\n"
        self.write_text(self.agents_file, merged)

    def install_core_skill(self, source: Path) -> None:
        core = self.skills_root / "academic-workflow-core"
        references = core / "references"
        assets = core / "assets"
        for directory in (references / "rules", references / "upstream", references / "codex", assets / "templates"):
            directory.mkdir(parents=True, exist_ok=True)
        core_skill = """---
name: academic-workflow-core
description: Coordinate rigorous academic work using scoped planning, evidence checks, independent review, fixes, and final verification. Use for complex papers, slides, data analyses, replication packages, and research workflows.
---

# Academic Workflow Core

1. Resolve deliverables, inputs, constraints, assumptions, and acceptance checks.
2. Inspect the actual repository and preserve unrelated changes.
3. Separate implementation, verification, and independent review.
4. Delegate only independent bounded work and require evidence-backed findings.
5. Fix confirmed critical and major issues, rerun checks, and repeat until dry or a five-round safety cap is reached.
6. Report unresolved disagreement, missing inputs, unavailable tools, and failed checks honestly.
7. Save durable review evidence under `quality_reports/` when that convention is present.

Load `references/codex/folder-organization.md` whenever deciding where to create, move, or save research data, code, figures, tables, temporary files, or documents. Load only other relevant files under `references/` for the current task. Project-specific paths and commands belong in the repository `AGENTS.md`.
"""
        self.write_text(core / "SKILL.md", core_skill)
        self.copy_contents(source / ".claude" / "rules", references / "rules")
        self.copy_contents(source / ".claude" / "references", references / "upstream")
        self.copy_contents(source / "templates", assets / "templates")
        self.copy_contents(source / "Preambles", assets / "Preambles")
        self.copy_contents(source / "Quarto", assets / "Quarto")
        if (source / "CHANGELOG.md").is_file():
            legacy = references / "CHANGELOG.md"
            if legacy.is_file():
                self.backup_file(legacy)
                legacy.unlink()
            shutil.copy2(source / "CHANGELOG.md", references / "upstream" / "CHANGELOG.md")
        skill_names = sorted(path.name for path in (source / ".claude" / "skills").iterdir() if path.is_dir())
        for asset_file in (assets / "templates").rglob("*"):
            if not asset_file.is_file() or asset_file.suffix.lower() not in {".md", ".txt", ".yaml", ".yml"}:
                continue
            asset_text = asset_file.read_text(encoding="utf-8")
            asset_text = re.sub(
                r"\[[^\]]+\]\([^)]*\.claude/rules/([^\)#]+)(?:#[^)]+)?\)",
                lambda match: f"`academic-workflow-core` rule `{match.group(1)}`",
                asset_text,
            )
            asset_text = re.sub(
                r"\[[^\]]+\]\([^)]*\.claude/references/([^\)#]+)(?:#[^)]+)?\)",
                lambda match: f"`academic-workflow-core` reference `{match.group(1)}`",
                asset_text,
            )
            asset_text = asset_text.replace(".claude/rules/", "__ASSET_RULE__/")
            asset_text = asset_text.replace(".claude/references/", "__ASSET_REFERENCE__/")
            asset_text = self.convert_text(asset_text, skill_names)
            asset_text = asset_text.replace("__ASSET_RULE__/", "academic-workflow-core rule ")
            asset_text = asset_text.replace("__ASSET_REFERENCE__/", "academic-workflow-core reference ")
            asset_text = asset_text.replace(
                "Copy this file to `academic-workflow-core rule constitutional-governance.md`",
                "Adapt this file into the repository `AGENTS.md` or a checked-in governance document referenced from it",
            )
            asset_text = asset_text.replace(
                "File saved to `academic-workflow-core rule constitutional-governance.md`",
                "Governance decisions recorded in project `AGENTS.md` or linked project documentation",
            )
            self.write_text(asset_file, asset_text)
        shutil.copy2(self.package_root / "templates" / "codex-skill-template.md", assets / "templates" / "skill-template.md")
        self.copy_contents(self.package_root / "templates" / "codex-references", references / "codex")
        for reference_file in references.rglob("*.md"):
            original = reference_file.read_text(encoding="utf-8")
            is_rule = references.joinpath("rules") in reference_file.parents
            protected = original.replace(".claude/rules/", "__ACADEMIC_RULES__/")
            protected = protected.replace("../../rules/", "__ACADEMIC_RULES__/")
            protected = protected.replace(".claude/references/", "__ACADEMIC_REFERENCES__/")
            protected = protected.replace("../../references/", "__ACADEMIC_REFERENCES__/")
            converted = self.convert_text(protected, skill_names)
            converted = re.sub(
                r"\[[^\]]+\]\(\.\./hooks/([^)]+)\)",
                lambda match: f"`Codex hook {match.group(1)}` under `~/.codex/hooks/academic-workflow/`",
                converted,
            )
            converted = re.sub(
                r"\.\./skills/([a-z0-9-]+)/SKILL\.md",
                lambda match: f"../../../academic-workflow-{match.group(1)}/SKILL.md",
                converted,
            )
            if is_rule:
                converted = converted.replace("../../CHANGELOG.md", "../upstream/CHANGELOG.md")
                converted = self.remove_frontmatter(converted)
                converted = converted.replace("__ACADEMIC_RULES__/", "./")
                converted = converted.replace("__ACADEMIC_REFERENCES__/", "../upstream/")
                converted = converted.replace("../references/", "../upstream/")
            else:
                converted = converted.replace("../../CHANGELOG.md", "./CHANGELOG.md")
                converted = converted.replace("__ACADEMIC_RULES__/", "../rules/")
                converted = converted.replace("__ACADEMIC_REFERENCES__/", "./")
                converted = converted.replace("../references/", "./")
            if converted != original:
                note = (
                    "> Codex port note: This reference was adapted from the upstream workflow. "
                    "Use active Codex configuration under `~/.codex`, user skills under "
                    "`~/.agents/skills`, native hooks under `~/.codex/hooks/academic-workflow`, "
                    "and the named `academic_*` custom agents.\n\n"
                )
                converted = note + converted
            self.write_text(reference_file, converted)

    def install_converted_skills(self, source: Path) -> None:
        skill_directories = sorted(path for path in (source / ".claude" / "skills").iterdir() if path.is_dir())
        skill_names = [path.name for path in skill_directories]
        for skill_directory in skill_directories:
            source_skill = skill_directory / "SKILL.md"
            if not source_skill.is_file():
                continue
            destination_name = f"academic-workflow-{skill_directory.name}"
            destination = self.skills_root / destination_name
            destination.mkdir(parents=True, exist_ok=True)
            for item in skill_directory.iterdir():
                if item.name == "SKILL.md":
                    continue
                target = destination / item.name
                if item.is_dir():
                    shutil.copytree(item, target, dirs_exist_ok=True)
                elif item.is_file():
                    shutil.copy2(item, target)
            original = source_skill.read_text(encoding="utf-8")
            description = self.frontmatter_value(original, "description") or (
                f"Academic workflow adapted from the upstream {skill_directory.name} skill."
            )
            description = self.convert_text(description, skill_names)
            description = description.replace("WebSearch/WebFetch", "web search and page retrieval")
            description = description.replace("Claude Code", "Codex").replace("<", "").replace(">", "")
            body = self.convert_text(self.remove_frontmatter(original), skill_names)
            compatibility = (
                f"> Codex port note: invoke this skill as ${destination_name}. Treat `<user-input>` "
                "as a placeholder for the relevant value from the user prompt and substitute the "
                "actual value before running commands. Use the current operating system's shell "
                "syntax and Codex filesystem, web, planning, background-process, and subagent tools. "
                "Resolve relative project paths from the current Git repository. If an optional "
                "upstream reference or project asset is absent, report it and continue with the "
                "parts that can be verified.\n\n"
            )
            converted = (
                f"---\nname: {destination_name}\ndescription: "
                f"{json.dumps('Codex port: ' + description, ensure_ascii=False)}\n---\n\n"
                + compatibility
                + body
            )
            self.write_text(destination / "SKILL.md", converted)

    def install_skill_overrides(self) -> None:
        for override_root in (
            self.package_root / "templates" / "skill-overrides",
            self.package_root / "templates" / "macos-skill-overrides",
        ):
            if not override_root.is_dir():
                continue
            for override_file in sorted(override_root.glob("*.md")):
                destination = self.skills_root / override_file.stem / "SKILL.md"
                self.write_text(destination, override_file.read_text(encoding="utf-8"))

    def install_codex_only_skills(self) -> None:
        root = self.package_root / "templates" / "codex-only-skills"
        if not root.is_dir():
            return
        for skill_directory in sorted(path for path in root.iterdir() if path.is_dir()):
            if (skill_directory / "SKILL.md").is_file():
                shutil.copytree(skill_directory, self.skills_root / skill_directory.name, dirs_exist_ok=True)

    def install_converted_agents(self, source: Path) -> None:
        skill_names = sorted(path.name for path in (source / ".claude" / "skills").iterdir() if path.is_dir())
        self.custom_agents_root.mkdir(parents=True, exist_ok=True)
        for agent_file in sorted((source / ".claude" / "agents").glob("*.md")):
            original = agent_file.read_text(encoding="utf-8")
            base_name = agent_file.stem
            agent_name = "academic_" + base_name.replace("-", "_")
            description = self.frontmatter_value(original, "description") or (
                f"Academic specialist adapted from the upstream {base_name} agent."
            )
            description = self.convert_text(description, skill_names)
            body = self.convert_text(self.remove_frontmatter(original), skill_names)
            sandbox = "workspace-write" if re.search(r"fixer|translator", base_name) else "read-only"
            toml = (
                f'name = "{agent_name}"\n'
                f"description = {json.dumps('Codex port: ' + description, ensure_ascii=False)}\n"
                f'sandbox_mode = "{sandbox}"\n'
                f"developer_instructions = {json.dumps(body, ensure_ascii=False)}\n"
            )
            destination = self.custom_agents_root / f"{agent_name}.toml"
            self.backup_file(destination)
            self.write_text(destination, toml)

    @staticmethod
    def is_academic_hook_group(group: Any) -> bool:
        if not isinstance(group, dict) or not isinstance(group.get("hooks"), list):
            return False
        for handler in group["hooks"]:
            if not isinstance(handler, dict):
                continue
            commands = " ".join(str(handler.get(name, "")) for name in ("command", "commandWindows", "command_windows"))
            if re.search(r"[\\/]academic-workflow[\\/]", commands):
                return True
        return False

    def install_hooks(self) -> None:
        source = self.package_root / "templates" / "hooks"
        if not source.is_dir():
            raise RuntimeError(f"Hook templates are missing: {source}")
        self.hooks_root.mkdir(parents=True, exist_ok=True)
        for hook_file in sorted(path for path in source.iterdir() if path.is_file()):
            destination = self.hooks_root / hook_file.name
            self.backup_file(destination)
            shutil.copy2(hook_file, destination)
        self.backup_file(self.hooks_config_file)
        if self.hooks_config_file.is_file():
            config = json.loads(self.hooks_config_file.read_text(encoding="utf-8"))
        else:
            config = {"description": "User-level Codex hooks", "hooks": {}}
        if not isinstance(config, dict):
            raise RuntimeError(f"Hook config must be a JSON object: {self.hooks_config_file}")
        hooks = config.setdefault("hooks", {})
        if not isinstance(hooks, dict):
            raise RuntimeError(f"The hooks field must be a JSON object: {self.hooks_config_file}")
        definitions = (
            ("PreToolUse", r"^(Bash|apply_patch|Edit|Write)$", "git_guardrails.py", "Checking academic workflow guardrails", 10, True),
            ("PostToolUse", r"^(apply_patch|Edit|Write)$", "claim_reconcile.py", "Checking tracked claim provenance", 10, True),
            ("PreCompact", r"^(manual|auto)$", "pre_compact.py", "Saving academic workflow state", 10, False),
            ("SessionStart", r"^(compact|resume)$", "post_compact_restore.py", "Restoring academic workflow state", 10, True),
            ("Stop", None, "session_log.py", "Updating the academic session log", 15, False),
        )
        for event, matcher, script, status, timeout, allows_context in definitions:
            script_path = self.hooks_root / script
            handler: dict[str, Any] = {
                "type": "command",
                "command": f"{shlex.quote(sys.executable)} {shlex.quote(str(script_path))}",
                "timeout": timeout,
                "statusMessage": status,
            }
            if allows_context:
                handler["additionalContextLimit"] = 2500
            group: dict[str, Any] = {"hooks": [handler]}
            if matcher:
                group["matcher"] = matcher
            existing = hooks.get(event, [])
            if not isinstance(existing, list):
                raise RuntimeError(f"hooks.{event} must be an array")
            hooks[event] = [item for item in existing if not self.is_academic_hook_group(item)] + [group]
        self.write_text(self.hooks_config_file, json.dumps(config, indent=2, ensure_ascii=False) + "\n")

    def install_cli_ui_defaults(self) -> None:
        status_line = 'status_line = ["model-with-reasoning", "context-remaining", "git-branch", "current-dir"]'
        if self.config_file.is_file():
            text = self.config_file.read_text(encoding="utf-8")
            if re.search(r"(?m)^\s*status_line\s*=", text):
                return
            self.backup_file(self.config_file)
            match = re.search(r"(?m)^\[tui\]\s*$", text)
            addition = "\n# Added by the Codex academic workflow installer.\n" + status_line
            if match:
                text = text[: match.end()] + addition + text[match.end() :]
            else:
                text = text.rstrip() + "\n\n[tui]" + addition + "\n"
        else:
            text = "[tui]\n# Added by the Codex academic workflow installer.\n" + status_line + "\n"
        self.write_text(self.config_file, text)

    def install_project_initializer(self, source: Path) -> None:
        skill = self.skills_root / "academic-workflow-init"
        assets = skill / "assets"
        scripts = skill / "scripts"
        assets.mkdir(parents=True, exist_ok=True)
        scripts.mkdir(parents=True, exist_ok=True)
        shutil.copy2(self.package_root / "templates" / "project-AGENTS.md", assets / "project-AGENTS.md")
        shutil.copy2(self.package_root / "templates" / "project-MEMORY.md", assets / "project-MEMORY.md")
        self.copy_contents(self.package_root / "templates" / "project-scripts", assets / "project-scripts")
        template = (self.package_root / "templates" / "init-project.py.template").read_text(encoding="utf-8")
        template = template.replace("__SOURCE_ROOT_JSON__", json.dumps(str(source), ensure_ascii=False))
        template = template.replace(
            "__CORE_TEMPLATES_ROOT_JSON__",
            json.dumps(str(self.skills_root / "academic-workflow-core" / "assets" / "templates"), ensure_ascii=False),
        )
        self.write_text(scripts / "init-project.py", template)
        skill_text = """---
name: academic-workflow-init
description: Initialize the current repository for the global Codex academic workflow on macOS without overwriting existing project files. Use when starting or adopting a paper, lecture, analysis, or replication project.
---

# Initialize an academic project on macOS

1. Inspect the repository and identify existing `AGENTS.md`, document sources, analysis scripts, templates, and build commands.
2. Run `python3 scripts/init-project.py <repository-root>` from this skill directory. It merges only missing scaffold files and never overwrites existing project files.
3. Add `--include-automation` only when the user wants upstream `.github`, `.githooks`, and `.vscode` templates; inspect them before enabling a Git hook or CI workflow.
4. Customize the resulting project `AGENTS.md` with real project identity, canonical files, commands, and verification criteria.
5. Inspect actual dependencies and run real build or analysis checks when available. Report missing optional tools honestly.
6. Report created files, preserved files, missing dependencies, and the recommended first workflow skill.

The initializer creates `.codex/academic-workflow.json` and the default `data/source/output` stage mirror plus `temp/` and `documents/`. Stateful global academic hooks use the marker so they do not modify unrelated repositories.
"""
        self.write_text(skill / "SKILL.md", skill_text)

    def install_personal_state(self) -> None:
        memory = self.codex_home / "academic-workflow-state" / "personal-memory.md"
        if not memory.is_file():
            self.write_text(
                memory,
                "# Personal academic workflow memory\n\n"
                "Store machine-specific or personal reusable lessons here. Keep project facts in "
                "the nearest project `AGENTS.md` or checked-in project documentation.\n",
            )

    def install(self) -> None:
        if sys.version_info < (3, 9):
            raise RuntimeError("Python 3.9 or newer is required.")
        if shutil.which("git") is None:
            raise RuntimeError("Git is required. Install Xcode Command Line Tools or Homebrew Git.")
        self.codex_home.mkdir(parents=True, exist_ok=True)
        self.skills_root.mkdir(parents=True, exist_ok=True)
        source = self.resolve_source()
        source_commit = None
        if (source / ".git").is_dir():
            source_commit = self.git(["-C", str(source), "rev-parse", "HEAD"], "Could not read source commit").splitlines()[0]
        if not self.args.skip_global_agents_block:
            self.install_global_agents_block()
            if self.agents_override_file.is_file() and self.agents_override_file.read_text(encoding="utf-8").strip():
                print(
                    f"Warning: non-empty {self.agents_override_file} takes precedence over AGENTS.md. "
                    "Merge the academic workflow block there if you want the global guidance active.",
                    file=sys.stderr,
                )
        self.install_core_skill(source)
        self.install_converted_skills(source)
        self.install_skill_overrides()
        self.install_codex_only_skills()
        self.install_converted_agents(source)
        self.rules_root.mkdir(parents=True, exist_ok=True)
        rules_file = self.rules_root / "academic-workflow.rules"
        self.backup_file(rules_file)
        shutil.copy2(self.package_root / "templates" / "academic-workflow.rules", rules_file)
        self.install_project_initializer(source)
        self.install_personal_state()
        if not self.args.skip_hooks:
            self.install_hooks()
        if not self.args.skip_cli_ui_defaults:
            self.install_cli_ui_defaults()
        manifest = {
            "installed_at": datetime.now(timezone.utc).isoformat(),
            "platform": "macos",
            "source": str(source),
            "repository_url": self.args.repository_url,
            "repository_ref": None if self.args.source_path else self.args.repository_ref,
            "source_commit": source_commit,
            "package_version": self.package_version,
            "skills_root": str(self.skills_root),
            "agents_root": str(self.custom_agents_root),
            "rules_file": str(rules_file),
            "hooks_root": None if self.args.skip_hooks else str(self.hooks_root),
            "hooks_config": None if self.args.skip_hooks else str(self.hooks_config_file),
            "cli_ui_defaults_installed": not self.args.skip_cli_ui_defaults,
            "personal_memory_file": str(self.codex_home / "academic-workflow-state" / "personal-memory.md"),
            "backup_root": str(self.backup_root),
        }
        self.write_text(
            self.codex_home / "academic-workflow-install.json",
            json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        )
        print("Installed the Codex academic workflow for macOS.")
        print("Restart Codex, then invoke $academic-workflow-init in a target repository.")
        if not self.args.skip_hooks:
            print("In the Codex CLI, run /hooks and review/trust the five academic workflow hook definitions.")
        if self.backup_root.exists():
            print(f"Backups: {self.backup_root}")


def main() -> int:
    try:
        Installer(parse_args()).install()
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as exc:
        print(f"Installation failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
