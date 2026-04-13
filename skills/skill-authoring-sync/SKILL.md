---
name: skill-authoring-sync
description: 在 `why8023/agent-skills` 中央 skills 仓库中新增、更新或重命名一个 skill，并在完成后把该 skill 安装到某个业务项目根目录时使用。适用于“新建一个 skill”“把 skill 沉淀到中央仓库”“把中央 skill 安装到当前项目”“更新项目里已安装的某个中央 skill”等请求。覆盖 `skills/skill-name/` 目录创建、`SKILL.md` 与 `agents/openai.yaml` 编写、最小验证、按目标 skill 单独提交并 push，以及在目标项目中通过 `npx skills add why8023/agent-skills --skill skill-name` 做项目级安装或刷新。
---

# Skill Authoring Sync

本技能把“中央仓库沉淀”和“项目侧安装”串成一次闭环。默认中央仓库是 `https://github.com/why8023/agent-skills.git`，默认安装方式是 `npx skills` 的 Project scope，不额外加 `-g`。

## Workflow

1. 建立范围。
   - 确认目标 skill 名称，统一使用小写加连字符。
   - 判断这次是新增、更新还是重命名；重命名按“新增新目录 + 清理旧目录 + 更新安装”的方式处理。
   - 确认目标业务项目根目录。如果用户没有给出项目路径且当前目录也不是目标项目，不要猜测目录；先完成中央仓库侧工作，再在安装前只补问一次项目路径。
   - 默认中央仓库来源使用 `git remote get-url origin`。如果它不是 `why8023/agent-skills`，或用户明确指定了其他来源，再按用户要求处理。

2. 在中央仓库中定位或创建 skill。
   - 只在中央仓库的 `skills/<skill-name>/` 下工作。
   - 新增 skill 时，优先在中央仓库的 `skills/` 目录下运行 `npx skills init <skill-name>` 生成基础骨架；如果 CLI 只生成了 `SKILL.md`，再按当前仓库约定补齐 `agents/openai.yaml`。
   - 新增 skill 时，至少交付 `SKILL.md` 和 `agents/openai.yaml`。
   - `scripts/`、`references/`、`examples/`、`assets/` 只在确有复用价值时再创建；不要为了凑结构创建空目录。
   - `SKILL.md` 的 YAML frontmatter 只保留 `name` 和 `description`；`name` 必须与目录名完全一致。
   - `description` 里直接写清“做什么”和“什么时候触发”，把典型用户说法也压进去，不要把触发条件只写在正文里。

3. 编写 skill 内容。
   - 把“中央仓库编写、Git 发布、项目侧安装”写成一条完整流程，不要只覆盖前半段。
   - 明确仓库约定：一个目录就是一个 skill；业务项目里的安装产物不作为主维护位置，需要改动时回到中央仓库演进。
   - 如果仓库已经采用 `agents/openai.yaml`，同步维护 `display_name`、`short_description` 和 `default_prompt`。
   - `default_prompt` 必须显式提到 `$<skill-name>`。
   - 只有用户明确要求复制安装时才使用 `--copy`；否则保留 CLI 默认的 symlink 方式。
   - 默认使用 Project scope；只有用户明确要求全局安装时才加 `-g`。
   - 如果用户没有指定 agent，优先使用当前会话对应的 agent 标识；在 Codex 环境默认用 `-a codex`。
   - 在 PowerShell 中优先使用 `cmd /c "mise exec node@24 -- ..."` 调用 `npx skills`，避免 `--list`、`-g`、`-a` 之类参数被 shell 或 `mise` 误解析。

4. 做最小验证。
   - 先检查 `git status --short`，确认没有把无关改动混进本次范围。
   - 用本地仓库绝对路径做一次非破坏性发现检查，确认 `npx skills` 能列出目标 skill：

```powershell
cmd /c "mise exec node@24 -- npx skills add <local-repo-absolute-path> --list"
```

   - 如果工作环境里有可用的结构校验脚本，运行它；否则至少手动核对目录名、frontmatter、`agents/openai.yaml` 三者是否一致。
   - 在 Windows 上运行 Python 校验脚本且 `SKILL.md` 含中文时，优先使用 UTF-8 模式，例如 `python -X utf8`，避免脚本按本地 `gbk` 编码读取失败。
   - 发现命名不一致、frontmatter 缺字段、`default_prompt` 未引用技能名时，先修正再继续。

5. 提交并推送中央仓库变更。
   - 再次检查 `git status --short`。
   - 只 stage 本次目标 skill 相关文件，不要混入其他未完成工作。
   - 提交信息默认使用：
     - 新增：`feat(skills): add <skill-name>`
     - 更新：`feat(skills): update <skill-name>`
     - 重命名：`feat(skills): rename <old-skill-name> to <new-skill-name>`
   - 默认推送到当前分支对应的 `origin` upstream；没有 upstream 时先用 `git push -u origin <current-branch>`。
   - 如果 push 失败，不要假装已经发布成功；先说明失败原因，再决定是否继续做本地测试安装。

6. 在目标项目根目录安装或刷新 skill。
   - 进入目标业务项目根目录后，优先用远端中央仓库地址做安装，不要默认用本地路径。
   - 首次安装或指定来源安装时，使用：

```powershell
cmd /c "mise exec node@24 -- npx skills add why8023/agent-skills --skill <skill-name> -a <agent> -y"
```

   - 只在用户明确要求全局安装时改成：

```powershell
cmd /c "mise exec node@24 -- npx skills add why8023/agent-skills -g --skill <skill-name> -a <agent> -y"
```

   - 已经安装过且只需要拉取最新版本时，可以在项目根目录执行：

```powershell
cmd /c "mise exec node@24 -- npx skills update <skill-name> -p -y"
```

   - 如果用户需要先查看中央仓库里有哪些 skill，可先运行：

```powershell
cmd /c "mise exec node@24 -- npx skills add why8023/agent-skills --list"
```

7. 验证项目侧结果。
   - 用 `npx skills list` 检查项目层级是否已经出现目标 skill，必要时用 `-a <agent>` 缩小范围：

```powershell
cmd /c "mise exec node@24 -- npx skills list -a <agent>"
```

   - 向用户明确说明：skill 目录路径、是否已 commit、是否已 push、安装使用的来源、目标项目路径、目标 agent，以及是否需要后续在项目里运行 `npx skills update`。

## Guardrails

- 不要把多个不相关 skill 混在同一次提交里。
- 不要在业务项目里直接手改安装产物并把它当成真相源。
- 不要在用户要求项目级安装时误加 `-g`。
- 不要在 push 尚未成功时把远端发布视为已完成。
- 不要因为本地仓库可以被 `npx skills add <path>` 识别，就跳过从远端发布后的安装步骤；本地路径只用于验证或用户明确要求的本地测试。
- 不要创建无内容的 `scripts/`、`references/`、`examples/` 或 `assets/` 目录。
