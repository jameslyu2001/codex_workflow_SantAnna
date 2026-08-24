# Codex Academic Workflow for Windows and macOS

这是 [`pedrohcgs/claude-code-my-workflow`](https://github.com/pedrohcgs/claude-code-my-workflow) 的 Codex 原生移植版。安装后，通用能力位于用户全局目录，可在任意项目使用；项目路径、命令、数据约束和研究事实仍保留在各项目中。

当前版本：`2.2.0`

锁定上游提交：`be53c12f235996dff41fb7f21580506fd2dd8d50`

## 安装内容

- 56 个全局 skills：52 个上游工作流、2 个 Codex 核心/初始化 skills、2 个 Codex 输出风格 skills
- 18 个全局 custom agents
- 5 组 Codex lifecycle hooks：Git/路径防护、claim provenance、压缩前保存、压缩后恢复、自动 session log
- 全局 `AGENTS.md` 工作规范和 Codex execpolicy 安全规则
- 全局研究文件组织规范：`raw -> derived -> analysis` 数据血缘、镜像的 `data/source/output` 阶段目录、`temp` 与 `documents` 边界
- Codex CLI 原生 status line 默认项；已有个人 `status_line` 时保持不变
- Windows PowerShell 与 macOS Bash/Python 项目初始化、LaTeX 编译和 Quarto 同步脚本
- 不覆盖现有文件的项目初始化器

完整差异和修复依据见 [AUDIT-REPORT.md](AUDIT-REPORT.md)，Claude→Codex 映射见 [MIGRATION-MAP.md](MIGRATION-MAP.md)。

## Windows 快速安装

```powershell
gh auth login
gh repo clone jameslyu2001/workflow_codex
Set-Location ".\workflow_codex"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\verify-install.ps1"
```

重新启动 Codex。若使用 Codex CLI，输入 `/hooks`，检查并信任 5 组新 hook。之后在目标学术项目中调用：

```text
$academic-workflow-init
```

## macOS 快速安装

```bash
gh auth login
gh repo clone jameslyu2001/workflow_codex
cd workflow_codex
bash ./install-macos.sh
bash ./verify-install-macos.sh
```

重新启动 Codex，在 CLI 中用 `/hooks` 审查并信任 5 组 hook，再在目标项目调用 `$academic-workflow-init`。

初始化会创建 `.codex/academic-workflow.json`。会写入项目状态的全局 hooks 仅在存在该标记时运行；Git 安全防护仍作为全局保护运行。

初始化器还会以不覆盖现有内容的方式创建 `data/{raw,derived,analysis}`、`source/{raw,derived,analysis}`、`output/{raw,derived,analysis}`、`temp/` 与 `documents/`。数据处理代码进入 `source/<stage>/`；`scripts/` 保留给编译、验证、部署等仓库基础设施。

## 全局位置

- Skills：Windows `%USERPROFILE%\.agents\skills\academic-workflow-*`；macOS `~/.agents/skills/academic-workflow-*`
- Agents：Windows `%USERPROFILE%\.codex\agents\academic_*.toml`；macOS `~/.codex/agents/academic_*.toml`
- Hooks：Windows `%USERPROFILE%\.codex\hooks\academic-workflow`；macOS `~/.codex/hooks/academic-workflow`，两者均使用用户级 `hooks.json`
- 全局规范、规则、上游快照和状态：均位于对应用户的 `.codex` 目录
- 安装清单与备份：`.codex/academic-workflow-install.json`、`.codex/backups/academic-workflow`

## 安全边界

- 不移植 Claude 的 `bypassPermissions`；Codex sandbox 和审批策略保持生效。
- 不覆盖已有 skills、agents 以外的个人文件；修改全局 `AGENTS.md`、`hooks.json`、`config.toml` 前自动备份。
- 不默认安装项目 CI、Git hooks 或编辑器设置；Windows 使用 `-IncludeAutomation`，macOS 使用 `--include-automation`，并先审查内容。
- 不自动提交、推送、部署或启用 Git hook。

详细的新机器安装、离线安装、更新和故障排查见 [Windows 指南](INSTALL-WINDOWS.md) 与 [macOS 指南](INSTALL-MACOS.md)。本项目沿用上游 MIT 许可，详见 [LICENSE](LICENSE) 与 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
