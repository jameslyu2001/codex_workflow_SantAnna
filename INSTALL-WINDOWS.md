# Windows 安装与迁移指南（版本 2.1.0）

本包面向 Windows PowerShell，安装通用 Codex 学术工作流到用户全局目录。项目初始化是显式操作，不会自动改动你打开的每个仓库。

## 1. 前置条件

必须具备：

- Codex Desktop、CLI 或 IDE 扩展
- Git
- PowerShell 5.1 或 PowerShell 7
- Python 3，用于 Codex lifecycle hooks
- GitHub CLI `gh`，用于克隆当前私有仓库

检查：

```powershell
git --version
gh --version
python --version
codex --version
```

R、Stata、XeLaTeX、Quarto、Pandoc 和 LaTeX 包仅在对应工作流中需要。验证程序会区分必需依赖和可选依赖。

## 2. 获取安装包

### 推荐：GitHub CLI

```powershell
gh auth login
Set-Location "$HOME\Documents"
gh repo clone jameslyu2001/workflow_codex
Set-Location ".\workflow_codex"
```

仓库是私有仓库，因此使用的 GitHub 账号必须拥有访问权限。

### ZIP

登录 GitHub 后打开仓库页面，选择 **Code → Download ZIP**，解压后在 PowerShell 中进入包含 `install.ps1` 的目录。

## 3. 安装

使用单行命令，避免 PowerShell 反引号续行和复制时的隐藏空格问题：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1"
```

安装器会：

1. 获取并锁定上游提交 `be53c12f235996dff41fb7f21580506fd2dd8d50`。
2. 安装 56 个全局 skills 和 18 个 custom agents。
3. 转换 Claude 参数、CLI、工具名、模型路由和路径约定。
4. 安装 Codex 原生 hooks、execpolicy 规则和全局 `AGENTS.md` 区块。
5. 在没有个人 `tui.status_line` 时添加 Codex 原生状态栏字段。
6. 安装不会覆盖已有项目文件的 `$academic-workflow-init`。
7. 在修改现有全局文件前写入带时间戳的备份。

可选参数：

```powershell
# 本机 GitHub 代理无效时，仅对此安装过程绕过 GitHub 代理
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1" -BypassGitHubProxy

# 不安装 lifecycle hooks；核心 skills/agents 仍安装
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1" -SkipHooks

# 保留已有 CLI 状态栏配置，不添加默认 status_line
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1" -SkipCliUiDefaults

# 不写入全局 AGENTS.md 区块
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1" -SkipGlobalAgentsBlock
```

`-SkipHooks` 是功能降级：不会有自动 session log、claim stale 提示和压缩状态恢复。

## 4. 验证

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\verify-install.ps1"
```

主要预期：

```text
PASS  package version 2.1.0
INFO  converted skills: 56
INFO  converted agents: 18
PASS  Codex hook configuration
PASS  Codex hook scripts
Static installation checks passed.
```

如果某个可选工具缺失，验证程序只会标记 `INFO optional tool missing`。Git、Codex 和已启用 hooks 所需的 Python 属于必需项。

## 5. 让 Codex 重新加载

完全退出并重新打开 Codex。Codex 在新 session 启动时重新发现全局 `AGENTS.md`、skills、agents、rules 和 hooks。

使用 Codex CLI 时输入：

```text
/hooks
```

审查并信任下列 5 组 hook：

- `PreToolUse`：Git 和硬编码路径防护
- `PostToolUse`：分析文件修改后的 claim provenance 提示
- `PreCompact`：保存计划和近期决策
- `SessionStart`：压缩或恢复后重新注入项目状态
- `Stop`：对有变化的已初始化项目追加 session log

Codex 会对 hook 定义按哈希记录信任；安装包更新 hook 后需要重新审查。

在 Codex CLI 中可用 `/statusline` 查看或重新排序原生状态栏字段。Codex Desktop 的通知请在应用设置中管理；本包不会覆盖 Desktop 已有的通知程序。

## 6. 初始化一个学术项目

在 Codex 中打开目标仓库并调用：

```text
$academic-workflow-init
```

也可以直接运行已安装脚本：

```powershell
$init = "$HOME\.agents\skills\academic-workflow-init\scripts\init-project.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $init -ProjectPath "C:\path\to\project"
```

初始化器只复制缺失文件，保留已有 `AGENTS.md`、`MEMORY.md`、scripts、模板和项目目录。它会补齐：

- `AGENTS.md` 与 `MEMORY.md` 模板（仅在不存在时）
- `.codex\academic-workflow.json` 项目 opt-in 标记
- `quality_reports` 的计划、审计、checkpoint、passport、session log 等子目录
- `explorations\ARCHIVE`
- 通用 R 脚本模板、TikZ 检查、质量评分、LaTeX 编译和 Quarto 同步脚本
- 缺失的 Preambles、Figures、Slides、Quarto 和 supporting-docs 结构

如确实希望加入上游 CI、Git-hook 文件和 VS Code 设置：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $init -ProjectPath "C:\path\to\project" -IncludeAutomation
```

该参数只复制缺失模板，不会执行 `git config core.hooksPath`，也不会启用或推送 workflow；启用前应在项目中审查它们。

初始化后必须根据真实项目填写 `AGENTS.md` 中的 canonical files、环境、分析、编译和验证命令。

## 7. 全局安装路径

```text
%USERPROFILE%\.agents\skills\academic-workflow-*
%USERPROFILE%\.codex\agents\academic_*.toml
%USERPROFILE%\.codex\hooks\academic-workflow\
%USERPROFILE%\.codex\hooks.json
%USERPROFILE%\.codex\rules\academic-workflow.rules
%USERPROFILE%\.codex\AGENTS.md
%USERPROFILE%\.codex\config.toml
%USERPROFILE%\.codex\vendor\academic-workflow\
%USERPROFILE%\.codex\academic-workflow-state\
%USERPROFILE%\.codex\academic-workflow-install.json
%USERPROFILE%\.codex\backups\academic-workflow\<timestamp>\
```

## 8. 离线或指定源码安装

如果新机器已有上游仓库的本地副本：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1" -SourcePath "D:\path\to\claude-code-my-workflow"
```

`-SourcePath` 使用该目录当前 checkout，不会自动切换提交。若要精确复现本版本，应先让源码 checkout 到：

```text
be53c12f235996dff41fb7f21580506fd2dd8d50
```

## 9. 更新

```powershell
Set-Location "$HOME\Documents\workflow_codex"
git pull
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\verify-install.ps1"
```

然后重新启动 Codex，并用 `/hooks` 重新审查变更后的 hooks。

## 10. 故障排查

### PowerShell 无法运行脚本

不要修改系统永久执行策略；继续使用进程级 `-ExecutionPolicy Bypass`：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1"
```

### 私有仓库无法克隆

```powershell
gh auth status
gh auth login
```

确认登录账号对 `jameslyu2001/workflow_codex` 有访问权限。

### GitHub 代理指向不可用的 127.0.0.1

先检查来源：

```powershell
git config --show-origin --get-regexp proxy
```

可使用安装器的 `-BypassGitHubProxy`。它只对安装器内部 Git 命令生效，不修改全局 Git 配置。

### Hooks 未运行

1. 确认没有使用 `-SkipHooks`。
2. 确认 `%USERPROFILE%\.codex\hooks.json` 存在。
3. 在 Codex CLI 中运行 `/hooks` 并信任定义。
4. 确认 Python 3 可运行。
5. 对 session log、claim reconciliation 和 compaction state，确认项目含 `.codex\academic-workflow.json`。
6. 检查 `config.toml` 中是否设置了 `[features] hooks = false`。

`PreCompact` 和 `Stop` 不支持 `additionalContextLimit`。2.1.0 起安装器不会为这两个事件写入该字段；如果看到相关 warning，请更新本仓库后重新运行安装器。事件字段以 [OpenAI Codex Hooks 官方文档](https://developers.openai.com/codex/hooks/) 为准。

### 全局 AGENTS.md 没有效果

如果 `%USERPROFILE%\.codex\AGENTS.override.md` 非空，Codex 会优先读取它而不是 `AGENTS.md`。合并学术区块到 override，或者在确认不需要后移除 override。

### 回滚

安装器会在 `%USERPROFILE%\.codex\backups\academic-workflow\<timestamp>` 保存被修改的全局文件。回滚前先完全退出 Codex，核对目标文件，再从对应时间戳目录恢复；不要盲目覆盖此后新增的个人配置。
