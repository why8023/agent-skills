---
name: oracle-consult
description: Use this skill when an agent should decide whether to call Oracle for controlled second-model consultation, code review, debugging, external evidence lookup, Deep Research, or important document/plan review. Trigger when local attempts are insufficient, the decision is high-risk, current external sources are needed, or the user asks to use Oracle. Do not use for simple local edits, formatting, obvious code reading tasks, repeated identical questions, or any context that would send secrets, credentials, customer data, production logs, cookies, tokens, or unredacted private data.
---

# Oracle Consult

Use Oracle as a controlled external expert, not as a default action. Prefer local inspection, tests, and normal docs/web search first.

## Decision Check

Before calling Oracle, write a short preflight summary:

```text
task_type: consult | debug | code-review | search | deep-research | doc-polish
why_oracle: <why local work is insufficient>
local_attempts: <commands, logs, inspections, or reasoning already tried>
expected_output: <root cause, recommendation, report, review, rewrite, etc.>
files_to_send: <minimum required files>
risk_level: low | medium | high
approval_required: yes | no
```

Use these defaults:

- Local-only work: do not call Oracle.
- Simple current fact lookup: use normal web/docs search first.
- Debug, review, consult, and document polish: Oracle is allowed after dry-run if no sensitive data is included.
- Deep Research, API engine, multi-model panels, high-risk decisions, or possibly sensitive context: ask for confirmation before the formal call.
- Do not call Oracle more than twice for the same task unless the second call explains what the first answer lacked.

## Required Workflow

1. Build a standalone prompt with background, goal, constraints, local attempts, and required output format.
2. Select the smallest useful file set.
3. Run a dry-run with file reporting before the formal call.
4. Refuse or reduce context if dry-run includes secrets, credentials, cookies, tokens, customer data, production logs, build artifacts, dependency folders, or unrelated files.
5. Run Oracle in browser mode by default. Do not use API mode unless explicitly requested. For both local and remote browser runs, keep the current ChatGPT-selected model by default: pass `--browser-model-strategy current` or set `browser.modelStrategy = "current"` in the user Oracle config.
6. Always write output to `.oracle-runs/`.
7. Convert Oracle output into accepted findings, rejected findings, verification-needed findings, and local next actions.
8. Verify locally before treating Oracle output as final.

## Preferred Command Path

If `scripts/oracle-gate.ps1` exists, use it as the single entrypoint:

```powershell
.\scripts\oracle-gate.ps1 `
  -TaskType debug `
  -Slug "short-task-slug" `
  -Risk medium `
  -PromptPath ".oracle-runs\prompts\<date>-debug-short-task-slug.md" `
  -Files @("src/**/*.ts", "tests/**/*.ts") `
  -Run
```

For Deep Research:

```powershell
.\scripts\oracle-gate.ps1 `
  -TaskType deep-research `
  -Slug "short-topic" `
  -Risk high `
  -PromptPath ".oracle-runs\prompts\<date>-deep-research-short-topic.md" `
  -DeepResearch `
  -Run `
  -Approved
```

If the wrapper is unavailable, call Oracle directly:

```powershell
oracle `
  --engine browser `
  --browser-manual-login `
  --browser-model-strategy current `
  --dry-run summary `
  --files-report `
  -p "<task summary>" `
  --file "<files>"
```

Then formal call:

```powershell
oracle `
  --engine browser `
  --browser-manual-login `
  --browser-model-strategy current `
  --write-output ".oracle-runs/<date>-<task-type>-<slug>.md" `
  --slug "<task-type>-<slug>" `
  -p "<formal prompt>" `
  --file "<files>"
```

## Result Format

After Oracle returns, summarize in this shape:

```text
Oracle output: <path>

Accepted findings:
- <finding and why accepted>

Rejected findings:
- <finding and why rejected>

Needs verification:
- <finding and validation plan>

Local validation:
- <command or manual check>: <result>

Final decision:
- <what the agent will do next>
```
