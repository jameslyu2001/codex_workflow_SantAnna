# 在另一台 Windows 机器上安装

本说明适用于 Windows 10/11、Windows PowerShell 5.1 或 PowerShell 7，以及 Codex Desktop/CLI 的本地环境。本版本的安装脚本不是 macOS/Linux 安装器。

## 1. 安装前准备

新机器至少需要：

1. 已安装并至少启动过一次 Codex。
2. Git 可用。
3. Windows PowerShell 5.1 或 PowerShell 7 可用。
4. 因 GitHub 仓库默认为私有，使用命令行克隆时需要 GitHub CLI `gh` 并登录账号。

检查：

```powershell
git --version
gh --version
powershell.exe -NoProfile -Command '$PSVersionTable.PSVersion'
codex --version
```

如果 `gh` 尚未登录：

```powershell
gh auth login
gh auth status
```

## 2. 获取安装仓库

### 方法 A：GitHub CLI（推荐）

```powershell
$RepoDir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "workflow_codex"
gh repo clone jameslyu2001/workflow_codex $RepoDir
Set-Location $RepoDir
```

如果目录已经存在并且是该仓库的 clone：

```powershell
$RepoDir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "workflow_codex"
git -C $RepoDir pull --ff-only
Set-Location $RepoDir
```

### 方法 B：从 GitHub 网页下载 ZIP

1. 登录有权访问该私有仓库的 GitHub 账号。
2. 打开仓库页面，选择 **Code → Download ZIP**。
3. 解压到一个固定目录，例如 `Documents\workflow_codex`。
4. 在解压后的目录中打开 PowerShell。

ZIP 方法只影响这个安装仓库的获取；安装器仍需从 GitHub 获取锁定版本的上游源码。

## 3. 执行安装

在仓库根目录运行一行命令：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1"
```

安装器会检出固定的上游提交：

```text
be53c12f235996dff41fb7f21580506fd2dd8d50
```

如果你已经另行下载了上游仓库，可避免网络获取：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1" -SourcePath "D:\path\to\claude-code-my-workflow"
```

`-SourcePath` 使用该目录当前检出的内容，不会自动切换到本仓库锁定的提交；如需完全一致，请先在该上游 clone 中检出上述 commit。

如果错误明确显示 Git 被无效的本地 GitHub 代理（例如 `127.0.0.1:7890`）阻断，可仅对安装器的 Git 命令临时绕过该代理：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1" -BypassGitHubProxy
```

该开关不会修改永久 Git 配置。正常使用代理的机器不要添加它。

## 4. 验证安装

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\verify-install.ps1"
```

成功时应看到：

- 54 个 skills；
- 18 个 custom agents；
- skill frontmatter 与 agent 必填字段通过；
- Git 安全规则可由 `codex execpolicy check` 正确解析；
- 项目初始化脚本通过 PowerShell 语法检查。

`Rscript`、`quarto`、`xelatex` 等是部分研究任务的可选依赖。缺失时校验器只提示，不会把核心安装判定为失败。

## 5. 重启并确认 Codex 发现工作流

完全退出 Codex 后重新启动，建议新建一个任务。可以依次尝试：

```text
Use $academic-workflow-core to outline a rigorous workflow for this project.
```

```text
Use $academic-workflow-context-status to report the current task state.
```

如果技能没有立即出现在选择器中，重新启动 Codex。Codex 的用户级技能目录是 `$HOME/.agents/skills`，本安装器没有把技能放进单个项目。

## 6. 初始化一个研究项目

在 Codex 中打开目标项目，然后输入：

```text
Use $academic-workflow-init to initialize this repository as an academic project.
```

初始化器会：

- 只复制缺失的学术项目模板和目录；
- 已有 `AGENTS.md` 会原样保留；
- 已有 `scripts` 和源目录不会覆盖；
- 不会把上游 Claude 仓库维护脚本复制到研究项目。

初始化结束后，在项目 `AGENTS.md` 中填写真实的项目名称、研究问题、权威源文件、构建命令、分析命令和验证标准。

## 7. 全局安装路径

```text
%USERPROFILE%\.codex\AGENTS.md
%USERPROFILE%\.agents\skills\academic-workflow-*
%USERPROFILE%\.codex\agents\academic_*.toml
%USERPROFILE%\.codex\rules\academic-workflow.rules
%USERPROFILE%\.codex\academic-workflow-state\personal-memory.md
%USERPROFILE%\.codex\vendor\academic-workflow
%USERPROFILE%\.codex\academic-workflow-install.json
%USERPROFILE%\.codex\backups\academic-workflow\<timestamp>
```

如果设置了 `CODEX_HOME`，`.codex` 下的内容会安装到该目录；用户 skills 仍安装到 `%USERPROFILE%\.agents\skills`。

## 8. 更新

进入本安装仓库并拉取新版本：

```powershell
git pull --ff-only
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\verify-install.ps1"
```

每次发布可在 `VERSION` 和 README 中看到工作流版本及锁定的上游提交。安装器是幂等的；重装会更新其管理的文件并创建备份。

## 9. 常见问题

### PowerShell 提示脚本被禁止

使用上文带 `-ExecutionPolicy Bypass` 的单行命令。它只影响这次启动的 PowerShell 进程，不修改机器级执行策略。

### `git` 或 `gh` 找不到

安装 Git for Windows 和 GitHub CLI，然后重新打开 PowerShell，使 PATH 刷新。

### 私有 GitHub 仓库无权限

运行 `gh auth status`，确认登录的是有权访问 `jameslyu2001/workflow_codex` 的账号。也可在浏览器登录后下载 ZIP。

### `Could not clone` 或连接 `127.0.0.1:7890` 失败

先检查是否确实存在失效的 Git 代理配置。只有在不应使用该代理时，才用 `-BypassGitHubProxy` 重试。

### 全局 `AGENTS.md` 似乎没有生效

检查 `%USERPROFILE%\.codex\AGENTS.override.md`。Codex 在全局层只读取第一个非空文件：如果 override 文件存在且非空，它会优先于 `AGENTS.md`。不要盲目删除；先把需要的全局规则合并到 override，或在确认后移除临时 override。

### 只想暂时不写全局 `AGENTS.md`

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1" -SkipGlobalAgentsBlock
```

skills、agents 和 Git 规则仍会安装。
