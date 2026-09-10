---
name: skill-sync
description: 在 skills 仓库中创建、更新或重命名一个 skill，只提交相关变更并推送，再通过已配置的个人 APM 入口刷新受管安装；未采用 APM 的环境使用 npx skills。用于维护 Skill 源码与多 Agent 安装的一致性。
---

# Skill Sync

在开始前，确认当前仓库是否以 `skills/<skill-name>/` 组织 skill。默认交付物至少包含 `SKILL.md`；如果仓库已经使用 `agents/openai.yaml`，也一并创建或更新。

## 已采用个人 APM 管理时

在选择安装器前，读取当前用户目录下 `.apm/agent-config.json`（若存在）。这是本机登记信息，包含 `repository` 配置仓库路径和 `entrypoint` 入口文件；不要把其中的机器路径或个人清单提交到此 Skill 源码仓库。

- 对用户级受管 Skill，检查登记仓库的 `apm.yml` 是否明确引用当前仓库的目标 Skill 子目录。命中时，下面的源码编辑、验证、提交和推送步骤仍执行；发布成功后，以登记入口执行 `update --source <owner/repo/skill-subdirectory>`，然后执行 `check`。Windows 使用该仓库的 `manage.ps1`，Linux 使用 `manage.sh`。
- 更新通过后，只提交、推送个人配置仓库中的清单版本变化，不加入缓存、锁文件或机器状态。必须先发布 Skill 源码，再固定该源码提交。
- 受管目标及数量以个人清单为准，不再运行后文的全局 `npx skills add/update/remove`，也不扩展到默认全 Agent 列表。APM 失败时保留错误和旧版本，不自动切回另一安装器。
- 如果登记文件存在但入口无效，停止受管同步并报告路径问题。新增或重命名尚未在清单中的 Skill，先显式修改个人清单并核对旧路径迁移，不自行混用两个安装器。
- 明确的项目级安装仍遵守该项目自己的管理方式；没有 APM 登记、且不属于受管清单的环境，才继续下方原有 npx 流程。

## 未采用 APM 的默认目标

- 默认附加 agent 目标：`codex`、`claude-code`、`openclaw`、`cursor`、`opencode`、`qoder`、`trae`、`trae-cn`、`windsurf`。
- `Universal` 由 `npx skills` 自动包含，对应 `.agents/skills`；默认不要额外写 `-a universal`。
- 如果用户明确要求只更新其中一部分 agent，就把默认目标集缩小到用户指定范围。
- 统一约定：只有在“全部 skill + 全部受支持 agent”都要同步时才使用 `--all`。
- 不要再使用 `--skill '*'`；当前 Windows 环境下它可能不会按“全部 skill”解析。

## Workflow

1. 建立变更范围。
   - 确认目标 skill 名，使用小写加连字符。
   - 检查 `skills/` 下是否重名；更新已有 skill 时复用原目录。
   - 如果是重命名 skill，明确旧名和新名，并把这次工作视为“新增新 skill + 删除旧 skill + 清理旧安装”。
   - 只处理本次目标 skill 相关文件，不要混入仓库里其他未完成变更。

2. 实现或更新 skill。
   - 写清 YAML frontmatter 中的 `name` 和 `description`。
   - 保持 `SKILL.md` 简洁，把流程、命令和决策规则写清即可。
   - 如果仓库已有 `agents/openai.yaml` 约定，保持它与 `SKILL.md` 同步。
   - 如果是重命名 skill，目录名、frontmatter 的 `name`、`agents/openai.yaml` 里的 `$skill-...` 提示词都要一起改掉。

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
     - 重命名 skill：`feat(skills): rename <old-skill-name> to <new-skill-name>`
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

   - 用户要求“全部 skill + 全部受支持 agent”时，统一使用：

```powershell
cmd /c "mise exec node@24 -- npx skills add <source> -g --all"
```

   - 用户要求“仓库内全部 skill，但 agent 仍限默认目标集”时，不要用 `--skill '*'`，先列出 skill，再显式传入：

```powershell
cmd /c "mise exec node@24 -- npx skills add <source> -g --list"
cmd /c "mise exec node@24 -- npx skills add <source> -g -a codex -a claude-code -a openclaw -a cursor -a opencode -a qoder -a trae -a trae-cn -a windsurf --skill <skill-1> <skill-2> ... -y"
```

   - `skills add` 可同时承担新增和刷新已安装 skill 的职责；只有用户明确要批量刷新所有已安装来源时，再考虑 `npx skills update`。
   - 默认安装到全局 scope（`-g`）并同步到本技能定义的默认 agent 列表。只有用户明确要求项目级或其他 agent 组合时才改动目标。
   - 这里的 `<source>` 默认应是 `git remote get-url origin` 返回的远端仓库地址，而不是本地路径。
   - `Universal` 会自动一起更新，因此命令里只列需要额外显式安装的 agent。
   - 如果是重命名 skill，先安装新 skill，再删除旧 skill 的本地安装：

```powershell
cmd /c "mise exec node@24 -- npx skills remove -g -a codex -a claude-code -a openclaw -a cursor -a opencode -a qoder -a trae -a trae-cn -a windsurf --skill <old-skill-name> -y"
```

8. 验证结果。
   - 优先运行 `cmd /c "mise exec node@24 -- npx skills list -g --json"`，确认目标 skill 的 `agents` 列表中包含预期目标。
   - 如果是重命名 skill，确认新 skill 已出现，旧 skill 已消失。
   - 必要时再用按 agent 过滤的方式 spot-check，例如 `-a claude-code`、`-a openclaw`、`-a cursor`、`-a opencode`、`-a qoder`、`-a trae`、`-a trae-cn`、`-a windsurf`。
   - 向用户说明：提交是否已完成、是否已 push 成功、使用了哪个远端同步来源、以及哪些 agent 已完成更新。

## Guardrails

- 不要把无关未提交改动一起 stage 或 commit。
- 不要等待额外确认才 commit、push、同步；默认按本技能流程完成闭环。
- 不要假设远端地址已经包含当前本地改动；必须先 push 成功再从远端安装。
- 不要默认 push 其他分支、tag 或发布 release。
- 不要因为 push 失败就改用本地路径偷偷同步，这会掩盖远端状态不一致的问题。
- 不要再把“只更新 Codex”当成默认行为；默认是更新本技能定义的多 Agent 目标集，并自动包含 Universal。
- 不要把 `--all` 当成“全部 skill + 默认 agent 列表”；`--all` 的含义是全部 skill + 全部受支持 agent。
- 如果 `origin` 缺失，或远端不是本次应使用的仓库，再向用户确认具体地址。
