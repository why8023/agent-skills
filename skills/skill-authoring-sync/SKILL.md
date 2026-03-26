---
name: skill-authoring-sync
description: 在 skills 仓库中创建或更新一个 skill，并在编辑完成后暂停等待用户确认是否同步到本机。确认后，只提交本次相关 skill 变更，自动生成 Git commit，并用 `npx skills` 按当前仓库来源将目标 skill 安装或更新到本机 Codex。适用于维护 `skills/` 仓库、创建新 skill、修订已有 skill，以及需要把结果立即同步到本机测试的场景。
---

# Skill Authoring Sync

在开始前，确认当前仓库是否以 `skills/<skill-name>/` 组织 skill。默认交付物至少包含 `SKILL.md`；如果仓库已经使用 `agents/openai.yaml`，也一并创建或更新。

## Workflow

1. 建立变更范围。
   - 确认目标 skill 名，使用小写加连字符。
   - 检查 `skills/` 下是否重名；更新已有 skill 时复用原目录。
   - 只处理本次目标 skill 相关文件，不要混入仓库里其他未完成变更。

2. 实现或更新 skill。
   - 写清 YAML frontmatter 中的 `name` 和 `description`。
   - 保持 `SKILL.md` 简洁，把流程、命令和决策规则写清即可。
   - 如果仓库已有 `agents/openai.yaml` 约定，保持它与 `SKILL.md` 同步。

3. 在询问同步前先本地验证。
   - 先看 `git status --short`，确认当前仓库还有哪些改动。
   - 做一次非破坏性检查，确认 `npx skills` 能发现目标 skill。
   - 仓库若已有 `mise.toml`、`.mise.toml` 或 `.tool-versions`，按仓库声明执行；否则在一次性命令中使用 `mise exec node@24 -- ...`。
   - 在 Windows PowerShell 中，用 `cmd /c "mise exec node@24 -- npx skills add <source> --list"` 转发参数，避免 `--list`、`-g` 之类的参数被 PowerShell 或 `mise` 误解析。
   - 如果要验证当前工作区里尚未 push 的最新结果，`<source>` 用当前仓库根目录绝对路径；如果要验证远端仓库可见内容，`<source>` 用 `git remote get-url origin`。

4. 暂停并等待用户确认。
   - 变更完成后，不要直接 commit 或同步。
   - 明确问一句：`是否现在同步到本机 Codex skills？`
   - 用户未明确同意前，只汇报结果，停在这里。

5. 用户确认后提交 Git 变更。
   - 再次检查 `git status --short`。
   - 只 stage 本次 skill 相关文件；不要把无关改动一起提交。
   - 提交信息默认使用：
     - 新增 skill：`feat(skills): add <skill-name>`
     - 更新 skill：`feat(skills): update <skill-name>`
   - 如果相关变更已经提交，直接进入同步，不要重复制造空提交。
   - 除非用户明确要求，不要 push。

6. 解析同步来源。
   - 优先级：用户显式给出的仓库来源 -> `git remote get-url origin` -> 当前仓库根目录绝对路径。
   - 如果刚提交的变更还没有 push，而用户要“立即在本机用到最新内容”，优先使用当前仓库根目录绝对路径。
   - 如果用户明确要求按 GitHub 地址同步，就使用 `origin`；同时提示未 push 的本地提交不会出现在远端安装结果里。

7. 用 `vercel-labs/skills` 同步到本机 Codex。
   - 同步单个 skill：

```powershell
cmd /c "mise exec node@24 -- npx skills add <source> -g -a codex --skill <skill-name> -y"
```

   - 用户要求同步仓库内全部 skill 时：

```powershell
cmd /c "mise exec node@24 -- npx skills add <source> -g -a codex --skill '*' -y"
```

   - `skills add` 可同时承担新增和刷新已安装 skill 的职责；只有用户明确要批量刷新所有已安装来源时，再考虑 `npx skills update`。
   - 默认安装到全局 Codex skills（`-g -a codex`）。只有用户明确要求项目级或其他 agent 时才改动目标。

8. 验证结果。
   - 运行 `cmd /c "mise exec node@24 -- npx skills list -g -a codex"` 或等价命令，确认目标 skill 已出现在本机 Codex skills 中。
   - 向用户说明：提交是否已完成、使用了哪个同步来源、以及本机 Codex 是否已经看到目标 skill。

## Guardrails

- 不要把无关未提交改动一起 stage 或 commit。
- 不要假设远端地址一定代表当前本地最新提交。
- 不要在用户确认前执行 commit 或安装。
- 不要默认 push、tag 或发布 release。
- 如果 `origin` 缺失且用户坚持用远端来源，再向用户确认具体地址。
