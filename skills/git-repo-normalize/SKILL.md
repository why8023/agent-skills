---
name: git-repo-normalize
description: Standardize Git repository line-ending handling only when a repo lacks a committed EOL policy, Git reports LF/CRLF drift, or the user explicitly asks to normalize. Use for `.gitattributes` setup, `git add --renormalize .`, and line-ending investigations; skip it for routine Git work when the repo policy is already stable.
---

# Git Repo Normalize

## When to use

1. Use this skill only when at least one trigger is present.
   - The user explicitly asks to fix `.gitattributes`, line endings, or LF/CRLF warnings.
   - Git emits `LF will be replaced by CRLF`, `CRLF will be replaced by LF`, or similar warnings.
   - The repository has no committed root `.gitattributes` EOL policy and the current task needs one.
   - A repo-wide diff or staging state suggests line-ending churn and you need to normalize intentionally.

2. Do not use this skill just because the task touches Git.
   - Routine commits, version bumps, tags, changelog edits, CI workflow edits, and diff review do not trigger normalization by themselves.
   - If the repo already has a committed EOL policy and no line-ending problem is in scope, continue the main task without renormalizing.

## Workflow

1. Confirm whether normalization is actually needed.
   - Run `git rev-parse --is-inside-work-tree` and `git rev-parse --show-toplevel`.
   - Read the root `.gitattributes` when present. Manage `.gitattributes` only at the repository root.
   - Read `.editorconfig` when present and check whether it already declares `end_of_line = lf`.
   - Read `git config --get core.autocrlf` to explain local warnings, but do not treat global Git config as the fix.
   - Use `git status --short` or `git ls-files --eol` on representative files when the repository state is unclear.
   - If the repo already has a committed EOL policy and no line-ending issue is part of the task, stop here and continue the original task.

2. Put the repository rule in place only when policy is missing or needs repair.
   - If the root `.gitattributes` does not contain `* text=auto eol=lf`, add or merge that rule instead of replacing the file, unless the repo already documents a different intended policy.
   - Preserve existing user rules and binary file patterns.

3. Renormalize only after deciding it is necessary.
   - Run `git add --renormalize .`.
   - Review `git status --short` and `git diff --cached --stat`.
   - Spot-check any large or suspicious change set with `git diff --cached -- <path>`.
   - Keep the normalization change explicit before continuing with the original task.

4. Escalate only when the repository intentionally differs.
   - If the repo already documents a different committed EOL policy and the user wants to preserve it, follow that policy instead of forcing LF.
   - If renormalization reveals real content edits beyond line endings, stop and ask how to proceed.
   - Never delete or overwrite unrelated user changes while normalizing.

## Default repository baseline

When the repository does not already define a different policy, use this root `.gitattributes` baseline:

```gitattributes
* text=auto eol=lf

*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.webp binary
*.ico binary
*.pdf binary
*.zip binary
```

## Typical triggers

- Diagnose `LF will be replaced by CRLF` or related warnings.
- Add a missing root `.gitattributes` line-ending policy.
- Repair a repository that is already showing line-ending churn.
- Intentionally prepare a dedicated normalization commit.
- Update or review a repository policy around `.gitattributes` and line endings.

## Typical non-triggers

- Routine version bumps, releases, tags, or changelog edits when the repo policy is already committed.
- Ordinary CI or workflow edits with no line-ending warnings or churn.
- General Git operations such as `status`, `diff`, `commit`, or branch inspection when line endings are not part of the task.

## Expected outcome

- Keep line-ending policy in version control instead of relying on local Git configuration.
- Normalize only when the task actually calls for it, instead of treating it as mandatory Git setup.
- Leave the repo in a stable LF-based state so later Git work does not need repeated line-ending cleanup.
