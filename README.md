# Codex Academic Workflow for Windows

这是 [`pedrohcgs/claude-code-my-workflow`](https://github.com/pedrohcgs/claude-code-my-workflow) 的 Codex 全局工作流移植版。安装后可在任意本地项目中使用，不依赖本仓库所在目录。

当前版本：`1.0.0`
锁定上游提交：`be53c12f235996dff41fb7f21580506fd2dd8d50`

## 安装内容

- 54 个用户全局 skills：`%USERPROFILE%\.agents\skills\academic-workflow-*`
- 18 个用户全局 custom agents：`%USERPROFILE%\.codex\agents\academic_*.toml`
- 全局工作规范：`%USERPROFILE%\.codex\AGENTS.md` 中的标记区块
- Git 安全规则：`%USERPROFILE%\.codex\rules\academic-workflow.rules`
- 个人工作流记忆：`%USERPROFILE%\.codex\academic-workflow-state\personal-memory.md`
- 锁定版本的上游源码：`%USERPROFILE%\.codex\vendor\academic-workflow`
- 安装清单与备份：`%USERPROFILE%\.codex\academic-workflow-install.json`、`%USERPROFILE%\.codex\backups\academic-workflow`

## 新机器快速安装

在 Windows PowerShell 中运行：

```powershell
gh auth login
$RepoDir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "workflow_codex"
gh repo clone jameslyu2001/workflow_codex $RepoDir
Set-Location $RepoDir
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\verify-install.ps1"
```

然后完全退出并重新启动 Codex。在任意研究项目中输入：

```text
Use $academic-workflow-init to initialize this repository as an academic project.
```

完整的前置条件、ZIP 安装、更新、代理故障和验证说明见 [INSTALL-WINDOWS.md](INSTALL-WINDOWS.md)。架构迁移说明见 [MIGRATION-MAP.md](MIGRATION-MAP.md)。

## 安全与覆盖范围

- 安装器只管理 `academic-workflow-*` skills、`academic_*.toml` agents、Git 规则文件，以及全局 `AGENTS.md` 中有明确起止标记的区块。
- 重装前会把已有的受管理文件备份到时间戳目录。
- 不迁移 Claude 的 `bypassPermissions`、`Bash(*)` 或 Claude hook 配置。
- 项目初始化器不会覆盖已有 `AGENTS.md`、源文件夹或脚本。
- 默认使用固定上游提交，保证不同机器得到相同工作流材料。

## 官方 Codex 参考

- [Build skills](https://learn.chatgpt.com/docs/build-skills)
- [Custom instructions with AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [Subagents and custom agents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- [Command rules](https://learn.chatgpt.com/docs/agent-configuration/rules)

## 许可与来源

上游项目使用 MIT License。参见 [LICENSE](LICENSE) 和 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
