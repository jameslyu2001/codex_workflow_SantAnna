# Codex Academic Workflow for Windows

这是 [`pedrohcgs/claude-code-my-workflow`](https://github.com/pedrohcgs/claude-code-my-workflow) 的 Codex 原生移植版。安装后，通用能力位于用户全局目录，可在任意项目使用；项目路径、命令、数据约束和研究事实仍保留在各项目中。

当前版本：`2.0.0`

锁定上游提交：`be53c12f235996dff41fb7f21580506fd2dd8d50`

## 安装内容

- 56 个全局 skills：52 个上游工作流、2 个 Codex 核心/初始化 skills、2 个 Codex 输出风格 skills
- 18 个全局 custom agents
- 5 组 Codex lifecycle hooks：Git/路径防护、claim provenance、压缩前保存、压缩后恢复、自动 session log
- 全局 `AGENTS.md` 工作规范和 Codex execpolicy 安全规则
- Codex CLI 原生 status line 默认项；已有个人 `status_line` 时保持不变
- Windows PowerShell LaTeX 编译与 Quarto 同步脚本
- 不覆盖现有文件的项目初始化器

完整差异和修复依据见 [AUDIT-REPORT.md](AUDIT-REPORT.md)，Claude→Codex 映射见 [MIGRATION-MAP.md](MIGRATION-MAP.md)。

## 快速安装

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

初始化会创建 `.codex/academic-workflow.json`。会写入项目状态的全局 hooks 仅在存在该标记时运行；Git 安全防护仍作为全局保护运行。

## 全局位置

- Skills：`%USERPROFILE%\.agents\skills\academic-workflow-*`
- Agents：`%USERPROFILE%\.codex\agents\academic_*.toml`
- Hooks：`%USERPROFILE%\.codex\hooks\academic-workflow` 和 `%USERPROFILE%\.codex\hooks.json`
- 全局规范：`%USERPROFILE%\.codex\AGENTS.md`
- 命令规则：`%USERPROFILE%\.codex\rules\academic-workflow.rules`
- 上游快照：`%USERPROFILE%\.codex\vendor\academic-workflow`
- 状态与个人记忆：`%USERPROFILE%\.codex\academic-workflow-state`
- 安装清单与备份：`%USERPROFILE%\.codex\academic-workflow-install.json`、`%USERPROFILE%\.codex\backups\academic-workflow`

## 安全边界

- 不移植 Claude 的 `bypassPermissions`；Codex sandbox 和审批策略保持生效。
- 不覆盖已有 skills、agents 以外的个人文件；修改全局 `AGENTS.md`、`hooks.json`、`config.toml` 前自动备份。
- 不默认安装项目 CI、Git hooks 或编辑器设置；需要时对初始化脚本使用 `-IncludeAutomation`，并先审查内容。
- 不自动提交、推送、部署或启用 Git hook。

详细的新机器安装、离线安装、更新和故障排查见 [INSTALL-WINDOWS.md](INSTALL-WINDOWS.md)。本项目沿用上游 MIT 许可，详见 [LICENSE](LICENSE) 与 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
