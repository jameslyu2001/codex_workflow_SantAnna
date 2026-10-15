# macOS 安装与迁移指南（版本 2.2.0）

本安装器把通用 Codex 学术工作流放入 macOS 用户全局目录。它不依赖 PowerShell，也不会自动修改每个项目；项目级文件仅在显式调用 `$academic-workflow-init` 后创建。

## 1. 前置条件

必须具备：

- macOS 上的 Codex Desktop、CLI 或 IDE 扩展
- Git
- Bash（macOS 自带）
- Python 3.9 或更高版本，用于安装器、项目初始化器和 lifecycle hooks
- GitHub CLI `gh`，用于下方克隆命令；也可直接使用 Git 克隆

建议先检查：

```bash
git --version
gh --version
python3 --version
codex --version
```

若 Git 不可用，可先运行 `xcode-select --install`。若使用 Homebrew，可安装 Python 与 GitHub CLI：

```bash
brew install python gh
```

R、Stata、MacTeX/XeLaTeX、Quarto、Pandoc 和具体 LaTeX 包只在相应工作流中需要。

## 2. 获取安装包

```bash
gh auth login
cd "$HOME/Documents"
gh repo clone jameslyu2001/codex_workflow_SantAnna
cd codex_workflow_SantAnna
```

本仓库公开可读，也可直接运行 `git clone https://github.com/jameslyu2001/codex_workflow_SantAnna.git`，无需登录 GitHub。也可以从 GitHub 下载 ZIP，解压后进入包含 `install-macos.sh` 的目录。

## 3. 一键安装

```bash
bash ./install-macos.sh
```

安装器会：

1. 获取并锁定上游提交 `be53c12f235996dff41fb7f21580506fd2dd8d50`。
2. 安装 56 个全局 skills 和 18 个 custom agents。
3. 转换 Claude 参数、CLI、工具名、模型路由和路径约定。
4. 安装 Codex 原生 hooks、execpolicy 规则和全局 `AGENTS.md` 区块。
5. 仅在没有个人 `tui.status_line` 时添加 Codex 原生状态栏字段。
6. 安装 macOS 专用的项目初始化、XeLaTeX、Quarto 和 TikZ 工作流。
7. 合并现有全局配置，并在修改前写入带时间戳的备份。

可选参数：

```bash
# 本机 GitHub 代理无效时，仅对安装器内部 Git 命令绕过代理
bash ./install-macos.sh --bypass-github-proxy

# 不安装 lifecycle hooks
bash ./install-macos.sh --skip-hooks

# 不添加默认 CLI status_line
bash ./install-macos.sh --skip-cli-ui-defaults

# 不写入全局 AGENTS.md 学术区块
bash ./install-macos.sh --skip-global-agents-block
```

`--skip-hooks` 会失去自动 session log、claim stale 提示和压缩状态恢复。

## 4. 验证

```bash
bash ./verify-install-macos.sh
```

主要预期：

```text
PASS  package version 2.1.0
INFO  converted skills: 56
INFO  converted agents: 18
PASS  Codex academic hook groups (5)
PASS  hook additionalContextLimit event compatibility
Static macOS installation checks passed.
```

验证器会区分必需工具和可选学术软件。缺少 `Rscript`、`quarto` 或 `xelatex` 会被如实报告；只有对应工作流才需要这些工具。

## 5. 重新加载和信任 hooks

完全退出并重启 Codex。在 Codex CLI 中运行：

```text
/hooks
```

审查并信任以下 5 组 hook：

- `PreToolUse`：Git 与硬编码路径防护
- `PostToolUse`：分析文件修改后的 claim provenance 提示
- `PreCompact`：保存计划和近期决策
- `SessionStart`：压缩或恢复后重新注入项目状态
- `Stop`：对有变化的已初始化项目追加 session log

Codex 会对 hook 定义按哈希记录信任；更新 hook 后需要重新审查。`additionalContextLimit` 只写入能够产生 `additionalContext` 的 `PreToolUse`、`PostToolUse` 和 `SessionStart`，不会写入 `PreCompact` 或 `Stop`。

## 6. 初始化学术项目

在 Codex 中打开目标仓库并调用：

```text
$academic-workflow-init
```

也可直接运行已安装的初始化器：

```bash
python3 "$HOME/.agents/skills/academic-workflow-init/scripts/init-project.py" "/path/to/project"
```

初始化器只复制缺失文件，保留已有 `AGENTS.md`、`MEMORY.md`、scripts 和模板。它会创建 `.codex/academic-workflow.json`、完整的 `quality_reports/` 与 `explorations/ARCHIVE`，补齐工作流需要的项目脚本和示例结构，并创建 `data/{raw,derived,analysis}`、`source/{raw,derived,analysis}`、`output/{raw,derived,analysis}`、`temp/` 与 `documents/`。

如确实希望复制上游 CI、Git hooks 和 VS Code 设置：

```bash
python3 "$HOME/.agents/skills/academic-workflow-init/scripts/init-project.py" "/path/to/project" --include-automation
```

此参数只复制缺失文件，不会执行 `git config core.hooksPath`、提交或推送。

## 7. macOS 项目命令

初始化后的项目可以使用：

```bash
bash ./scripts/compile-latex.sh "LectureName"
bash ./scripts/sync-to-docs.sh
bash ./scripts/sync-to-docs.sh "LectureName"
```

LaTeX 脚本执行 3 次 XeLaTeX，并在 `.aux` 声明 bibliography 时执行 BibTeX；未解析引用会使验证失败，overfull box 会明确告警。

## 8. 全局安装路径

```text
~/.agents/skills/academic-workflow-*
~/.codex/agents/academic_*.toml
~/.codex/hooks/academic-workflow/
~/.codex/hooks.json
~/.codex/rules/academic-workflow.rules
~/.codex/AGENTS.md
~/.codex/config.toml
~/.codex/vendor/academic-workflow/
~/.codex/academic-workflow-state/
~/.codex/academic-workflow-install.json
~/.codex/backups/academic-workflow/<timestamp>/
```

如果设置了 `CODEX_HOME`，`.codex` 下的内容改为写入该目录；skills 仍位于 `~/.agents/skills`。

## 9. 离线或指定源码安装

若已有上游仓库的本地副本：

```bash
bash ./install-macos.sh --source-path "/path/to/claude-code-my-workflow"
```

该参数使用当前 checkout，不自动切换提交。精确复现本版本时，应先 checkout：

```text
be53c12f235996dff41fb7f21580506fd2dd8d50
```

## 10. 更新

```bash
cd "$HOME/Documents/codex_workflow_SantAnna"
git pull --ff-only
bash ./install-macos.sh
bash ./verify-install-macos.sh
```

然后重启 Codex，并用 `/hooks` 重新审查发生变化的 hook。

## 11. 故障排查

### `python3` 不存在或版本太旧

```bash
brew install python
python3 --version
```

### GitHub CLI 无法克隆

```bash
gh auth status
gh auth login
```

本仓库公开可读。若 `gh` 登录异常，可直接使用 `git clone https://github.com/jameslyu2001/codex_workflow_SantAnna.git`。

### Hooks 未运行

1. 确认没有使用 `--skip-hooks`。
2. 确认 `~/.codex/hooks.json` 与 hook 脚本存在。
3. 运行 `/hooks` 并信任定义。
4. 确认安装时使用的 Python 路径仍然存在。
5. 对 stateful hooks，确认项目含 `.codex/academic-workflow.json`。
6. 检查 `config.toml` 中是否设置了 `[features] hooks = false`。

### 全局 `AGENTS.md` 无效

非空的 `~/.codex/AGENTS.override.md` 优先于 `AGENTS.md`。请把学术工作流区块合并到 override，或在确认不再需要时移除 override。

### 回滚

安装器在 `~/.codex/backups/academic-workflow/<timestamp>` 保存修改前的全局文件。回滚前退出 Codex，核对目标文件，再恢复对应备份；不要盲目覆盖安装后新增的个人配置。

Codex hooks 的事件与输出字段以 [OpenAI Codex Hooks 官方文档](https://developers.openai.com/codex/hooks/) 为准；其他 skills、全局 `AGENTS.md` 和配置位置以 [Codex 官方文档](https://developers.openai.com/codex/) 为准。
