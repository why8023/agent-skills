---
name: gh-repo-bootstrap
description: 当用户希望 Agent 通过 GitHub CLI `gh` 自动创建 GitHub 仓库，并配合 `git` 完成首次 `add`、`commit`、`push`、绑定远程仓库或发布本地项目到 GitHub 时使用。覆盖环境检查、`gh auth` 认证、仓库可见性与 owner 决策、非交互命令模板，以及公开仓库或首次推送前的安全约束。
---

# GH Repo Bootstrap

本技能用于“本地已有代码，准备发布到 GitHub”的场景。

`gh` 负责 GitHub 平台动作，例如认证和创建仓库；`git` 负责本地版本历史和推送。不要把 `gh` 当成 AI 专用工具，它只是 GitHub CLI；只有当 Agent 能执行终端命令时，这条路径才成立。

## Preconditions

- Agent 能运行 shell 命令。
- `git` 与 `gh` 已安装。
- 目标环境已登录 GitHub，或允许执行 `gh auth login`。
- 若后续要直接 `git push`，优先执行 `gh auth setup-git` 让 Git 复用 GitHub CLI 凭据。

## Workflow

1. 先做预检，不要直接建远程仓库。
   - 运行 `git --version`、`gh --version`、`gh auth status`。
   - 运行 `git rev-parse --is-inside-work-tree`、`git status --short`、`git remote -v`。
   - 如果当前目录已经绑定 GitHub 远程仓库，优先转成“补充 commit / push”流程，而不是重复建仓。
   - 如果工作区里有密钥、`.env`、大体积构建产物或无关改动，先收敛范围再继续。

2. 只收集最少但关键的决策。
   - 仓库名。
   - Owner，使用 `<user>/<repo>` 或 `<org>/<repo>`。
   - 可见性。默认 `--private`；只有用户明确要求时才用 `--public` 或 `--internal`。
   - 是否允许立即推送当前分支。
   - 仅在用户要求时再处理附加项：description、README、`.gitignore`、license、disable issues/wiki、team、template。

3. 准备认证。
   - 本地交互式使用：`gh auth login`。
   - 无头自动化：优先使用 `GH_TOKEN`；只有必须从标准输入读取令牌时才考虑 `gh auth login --with-token`。
   - 如果后续要让 `git push` 直接复用 GitHub CLI 凭据，执行 `gh auth setup-git`。
   - 依赖 `gh auth setup-git` 时优先使用 HTTPS；只有环境本来就配好了 SSH，或用户明确要求 SSH 时才切到 SSH。

4. 规范本地 Git 状态。
   - 如果当前目录还不是 Git 仓库，执行 `git init`。
   - 只 stage 本次要发布的文件。
   - 使用 `--push` 前先确保已经有本地 commit。
   - 除非仓库策略明确要求固定分支名，否则优先使用 `git push -u origin HEAD`，不要硬编码 `main`。

5. 用 `gh` 创建远程仓库。
   - 当前目录作为源目录：

```bash
gh repo create <repo-or-owner/repo> --private --source . --remote origin
```

   - 当前目录已有 commit，创建后立即推送：

```bash
gh repo create <repo-or-owner/repo> --private --source . --remote origin --push
```

   - 远程优先，再 clone 到本地：

```bash
gh repo create <repo-or-owner/repo> --private --clone
```

   - `--clone` 只适合空工作区或“先建再拉”的流程，不要对已有本地项目误用。
   - 不要静默覆盖或替换现有 `origin`。

6. 推送并验证。
   - 如果没有使用 `--push`，执行 `git push -u origin HEAD`。
   - 用 `git remote -v` 和 `gh repo view` 验证远程仓库是否正确创建。
   - 向用户回报最终仓库 URL、remote 名称和已推送的分支。

## Safe Defaults

- 默认创建私有仓库。
- 默认 remote 名称为 `origin`。
- 默认首次提交信息可以使用 `chore: initialize repository`，除非项目已有更明确的提交规范。
- 未指定 owner 时，优先使用当前认证用户。

## Command Templates

### 发布当前目录中的现有项目

```bash
git init
git add .
git commit -m "chore: initialize repository"
gh auth setup-git
gh repo create my-demo-repo --private --source . --remote origin --push
```

### 先建远程仓库，再单独 push

```bash
gh repo create my-demo-repo --private --source . --remote origin
git push -u origin HEAD
```

## Guardrails

- 除非用户明确要求，否则不要创建公开仓库。
- 不要把 secrets、`.env`、本地凭据文件或无关改动推上去。
- 不要在未经确认的情况下删除、重命名或覆盖现有 remote。
- 不要在首次发布时做 `git push --force`，除非用户明确要求。
- 组织仓库创建失败时，优先把权限问题说明白，不要私自切回个人账号重试。
- 如果用户只要求“建 GitHub 仓库”，不要顺手加 README、license、模板文件或 workflow。

## Escape Hatch

当 `gh` 的现成子命令不够用时，可以使用 `gh api` 发 GitHub REST 或 GraphQL 请求；但认证检查、可见性默认值和推送安全规则保持不变。
