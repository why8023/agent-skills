---
name: skill-authoring-sync
description: 在 skills 仓库中创建或更新一个 skill，并在编辑完成后只提交本次相关 skill 变更、推送到远端仓库，再用 `npx skills` 从远端仓库将目标 skill 安装或更新到本机多 Agent 环境。默认同步 Universal、Codex、Claude Code、OpenClaw、Cursor、OpenCode、Qoder、Trae、Trae CN、Windsurf，适用于维护 `skills/` 仓库、创建新 skill、修订已有 skill，以及需要把远端最新结果立即同步到本机测试的场景。
---

# Skill Authoring Sync

在开始前，确认当前仓库是否以 `skills/<skill-name>/` 组织 skill。默认交付物至少包含 `SKILL.md`；如果仓库已经使用 `agents/openai.yaml`，也一并创建或更新。

## Default Sync Targets

- 默认附加 agent 目标：`codex`、`claude-code`、`openclaw`、`cursor`、`opencode`、`qoder`、`trae`、`trae-cn`、`windsurf`。
- `Universal` 由 `npx skills` 自动包含，对应 `.agents/skills`；默认不要额外写 `-a universal`。
- 如果用户明确要求只更新其中一部分 agent，就把默认目标集缩小到用户指定范围。
- 如果用户明确要求同步到工具支持的全部 agent，使用 `-a '*'`，不要手写长名单。

## Workflow

1. 建立变更范围。
   - 确认目标 skill 名，使用小写加连字符。
   - 检查 `skills/` 下是否重名；更新已有 skill 时复用原目录。
   - 只处理本次目标 skill 相关文件，不要混入仓库里其他未完成变更。

2. 实现或更新 skill。
   - 写清 YAML frontmatter 中的 `name` 和 `description`。
   - 保持 `SKILL.md` 简洁，把流程、命令和决策规则写清即可。
   - 如果仓库已有 `agents/openai.yaml` 约定，保持它与 `SKILL.md` 同步。

3. 发布前先本地验证。
   - 先看 `git status --short`，确认当前仓库还有哪些改动。
   - 做一次非破坏性检查，确认 `npx skills` 能发现目标 skill。
   - 仓库若已有 `mise.toml`、`.mise.toml` 或 `.tool-versions`，按仓库声明执行；否则在一次性命令中使用 `mise exec node@24 -- ...`。
   - 在 Windows PowerShell 中，用 `cmd /c "mise exec node@24 -- npx skills add <source> --list"` 转发参数，避免 `--list`、`-g` 之类的参数被 PowerShell 或 `mise` 误解析。
   - 这里的 `<source>` 优先使用当前仓库根目录绝对路径，用来确认工作区里的最新 skill 内容可被发现。

4. 提交 Git 变更。
   - 再次检查 `git status --short`。
   - 只 stage 本次 skill 相关文件；不要把无关改动一起提交。
   - 提交信息默认使用：
     - 新增 skill：`feat(skills): add <skill-name>`
     - 更新 skill：`feat(skills): update <skill-name>`
   - 如果相关变更已经提交，直接进入推送，不要重复制造空提交。
   - 默认提交到当前分支；除非用户明确要求，不要改写历史。

5. 推送到远端仓库。
   - 先确认当前分支名和 `origin` 远端都存在。
   - 还没有 upstream 时，执行 `git push -u origin <current-branch>`。
   - 已有 upstream 时，执行 `git push origin <current-branch>`。
   - 如果 push 因远端分叉、权限或保护分支失败，不要强推；先把失败原因说明清楚再停下。

6. 解析远端同步来源和目标 agents。
   - 默认使用 `git remote get-url origin` 作为唯一同步来源。
   - 推送成功后再继续；不要从尚未包含最新提交的旧远端结果进行本机安装。
   - 如果仓库缺少 `origin`，或用户明确指定另一个远端地址，再按用户要求处理。
   - 如果用户没有给出其他要求，默认目标集使用本技能的多 Agent 默认列表。

7. 用 `vercel-labs/skills` 从远端同步到本机多 Agent 环境。
   - 同步单个 skill：

```powershell
cmd /c "mise exec node@24 -- npx skills add <source> -g -a codex -a claude-code -a openclaw -a cursor -a opencode -a qoder -a trae -a trae-cn -a windsurf --skill <skill-name> -y"
```

   - 用户要求同步仓库内全部 skill 时：

```powershell
cmd /c "mise exec node@24 -- npx skills add <source> -g -a codex -a claude-code -a openclaw -a cursor -a opencode -a qoder -a trae -a trae-cn -a windsurf --skill '*' -y"
```

   - 用户明确要求同步到所有受支持 agent 时：

```powershell
cmd /c "mise exec node@24 -- npx skills add <source> -g -a '*' --skill <skill-name> -y"
```

   - `skills add` 可同时承担新增和刷新已安装 skill 的职责；只有用户明确要批量刷新所有已安装来源时，再考虑 `npx skills update`。
   - 默认安装到全局 scope（`-g`）并同步到本技能定义的默认 agent 列表。只有用户明确要求项目级或其他 agent 组合时才改动目标。
   - 这里的 `<source>` 默认应是 `git remote get-url origin` 返回的远端仓库地址，而不是本地路径。
   - `Universal` 会自动一起更新，因此命令里只列需要额外显式安装的 agent。

8. 验证结果。
   - 优先运行 `cmd /c "mise exec node@24 -- npx skills list -g --json"`，确认目标 skill 的 `agents` 列表中包含预期目标。
   - 必要时再用按 agent 过滤的方式 spot-check，例如 `-a claude-code`、`-a openclaw`、`-a cursor`、`-a opencode`、`-a qoder`、`-a trae`、`-a trae-cn`、`-a windsurf`。
   - 向用户说明：提交是否已完成、是否已 push 成功、使用了哪个远端同步来源、以及哪些 agent 已完成更新。

## Guardrails

- 不要把无关未提交改动一起 stage 或 commit。
- 不要等待额外确认才 commit、push、同步；默认按本技能流程完成闭环。
- 不要假设远端地址已经包含当前本地改动；必须先 push 成功再从远端安装。
- 不要默认 push 其他分支、tag 或发布 release。
- 不要因为 push 失败就改用本地路径偷偷同步，这会掩盖远端状态不一致的问题。
- 不要再把“只更新 Codex”当成默认行为；默认是更新本技能定义的多 Agent 目标集，并自动包含 Universal。
- 如果 `origin` 缺失，或远端不是本次应使用的仓库，再向用户确认具体地址。
