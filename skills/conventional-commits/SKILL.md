---
name: conventional-commits
description: "当 Agent 准备执行 `git commit`、编写或改写 commit message、整理 staged 变更对应的提交说明时使用。要求提交信息遵循 Conventional Commits 1.0.0：使用 `<type>[optional scope]: <description>` 结构，并且提交说明内容默认使用中文，在需要时正确表达正文、脚注和 `BREAKING CHANGE`。"
---

# Conventional Commits

本技能用于在执行 `git commit` 前，为当前变更生成符合 Conventional Commits 1.0.0 的提交信息。

官方规范参考：https://www.conventionalcommits.org/zh-hans/v1.0.0/

默认语言要求：提交信息的人类可读内容使用中文。Conventional Commits 的结构化关键字仍保持规范要求的英文形式，例如 `feat`、`fix`、`docs`、`BREAKING CHANGE`。

目标不是机械套模板，而是让提交标题准确表达“这次提交的主要意图”。如果当前暂存区混入了多个不相关变更，优先拆分提交，而不是写一个含糊的大杂烩 message。

## Workflow

1. 先看本次提交的真实范围。
   - 运行 `git status --short`、`git diff --cached --stat`，必要时查看 `git diff --cached`。
   - 只根据已经 staged 的内容写提交信息；不要把未暂存改动算进去。
   - 如果 staged 里混入多个彼此独立的意图，优先建议拆成多个 commit。

2. 判断本次提交的主要类型。
   - 新增用户可感知功能，用 `feat`。
   - 修复 bug，用 `fix`。
   - 只改文档，用 `docs`。
   - 只改测试，用 `test`。
   - 不改变行为的重构，用 `refactor`。
   - 性能优化，用 `perf`。
   - 构建、依赖、打包、运行时或外部工具链调整，用 `build`。
   - CI 或自动化流程调整，用 `ci`。
   - 纯格式调整且不改逻辑，用 `style`。
   - 其他杂项维护工作，用 `chore`。
   - 回滚既有提交时，优先用 `revert`。

3. 决定是否需要 scope。
   - scope 是可选的，但在能明显指出变更边界时应当加上。
   - scope 应该是描述代码区域、模块、包、子系统或目录的名词，例如 `api`、`parser`、`skills`、`readme`。
   - 不要为了凑格式写空泛 scope；如果范围并不清晰，可以省略。

4. 写标题行。
   - 使用格式：`<type>[optional scope]: <description>`。
   - `type` 默认使用小写。
   - 冒号必须是英文半角 `:`，后面跟一个空格。
   - `description` 必须使用中文，写成简短摘要，聚焦结果，不要堆实现细节。
   - 标题不要以句号结尾，不要写成多个并列动作。

5. 需要时补正文和脚注。
   - 当只看标题无法说明动机、背景或关键实现时，再补正文。
   - 正文与标题之间必须空一行。
   - 正文内容默认使用中文。
   - 需要引用 issue、review、兼容性说明等信息时，用脚注。
   - 脚注放在正文之后，并与正文之间空一行。
   - 常见脚注可使用 `Refs: #123`、`Reviewed-by: name` 等 trailer 风格；脚注 token 可保留英文，说明值默认使用中文。

6. 识别破坏性变更。
   - 如果本次提交引入破坏性变更，必须显式标记。
   - 可以写成 `<type>(scope)!: <description>` 或 `<type>!: <description>`。
   - 如需进一步解释影响，补充脚注：`BREAKING CHANGE: <description>`，其中说明内容默认使用中文。
   - `BREAKING CHANGE` 必须使用大写。

## Default Heuristics

- 一个提交只表达一个主要意图；不要把“新增功能 + 顺手重构 + 修文档”压成一个标题。
- 如果一个提交同时像 `feat` 又像 `fix`，回到 diff 重新判断主导意图；必要时拆 commit。
- `chore` 不是兜底垃圾桶。只在变更确实不属于更具体类型时再使用它。
- 不要根据文件扩展名机械判断类型；例如改 `README.md` 多半是 `docs`，但改生成文档的脚本可能更像 `build` 或 `feat`。
- 只修改测试来覆盖既有行为，通常是 `test`；如果是“为了交付新功能而顺带补测试”，主类型仍可能是 `feat`。

## Output Rules

- 默认先给出一个推荐标题。
- 如果正文或脚注确实有必要，一并给出完整提交信息块。
- 如果 staged 变更明显应该拆分，先指出建议的拆分方式，再分别给出每个 commit message。
- 如果仓库已经有 `commitlint`、发布脚本或团队扩展规则，在不违背官方规范核心结构的前提下优先兼容仓库现有约束。
- 除非仓库已有别的明确规范，否则不要发明团队私有 type。
- 除 `type`、可选 `scope` 和必要的结构化 token 外，默认不要输出英文描述。

## Examples

```text
feat(skills): 新增 conventional-commits 技能
```

```text
fix(parser): 修复元数据加载器对空 scope 名称的处理
```

```text
docs(readme): 补充技能安装流程说明
```

```text
refactor(sync): 拆分远端解析与安装步骤
```

```text
feat(api)!: 移除旧版令牌接口

BREAKING CHANGE: 客户端必须迁移到 v2 令牌交换接口。
```

## Guardrails

- 不要在没看 staged diff 的情况下猜测提交类型。
- 不要把未暂存内容写进 commit message。
- 不要把多项无关改动包装成一个宽泛的 `chore` 或 `misc`。
- 不要遗漏破坏性变更标记。
- 不要为了追求简短而丢掉会影响审阅和发布的重要上下文。
- 不要把标题描述、正文说明或破坏性变更说明写成英文，除非用户明确要求其他语言。
