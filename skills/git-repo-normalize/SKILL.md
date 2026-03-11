---
name: git-repo-normalize
description: Standardize Git repository line-ending handling before any Git-related work. Use whenever Codex is about to operate on a Git repo, including version bumps, releases, commits, tags, diffs, CI workflow edits, or investigation of LF/CRLF warnings. On the first handling of a repo, add or reconcile the root .gitattributes rule `* text=auto eol=lf`, renormalize tracked files, review the diff, and complete this normalization before continuing with other repo work.
---

# Git Repo Normalize

## Workflow

1. Detect the repository scope first.
   - Run `git rev-parse --is-inside-work-tree` and `git rev-parse --show-toplevel`.
   - Manage `.gitattributes` only at the repository root.

2. Normalize before doing other repository work.
   - Do not postpone line-ending normalization until the end of the task.
   - Treat the first Git-facing handling of a repo as the normalization point.
   - If the root `.gitattributes` does not contain `* text=auto eol=lf`, add or merge that rule instead of replacing the file.
   - Preserve existing user rules and binary file patterns.

3. Inspect the repo signals that explain LF/CRLF drift.
   - Read `.editorconfig` when present and check whether it already declares `end_of_line = lf`.
   - Read `git config --get core.autocrlf` to explain local warnings, but do not treat global Git config as the fix.
   - Use `git ls-files --eol` on representative files when the repository state is unclear.

4. Renormalize once the repository rule is in place.
   - Run `git add --renormalize .`.
   - Review `git status --short` and `git diff --cached --stat`.
   - Spot-check any large or suspicious change set with `git diff --cached -- <path>`.
   - Keep the normalization change explicit before continuing with the original task.

5. Escalate only when the repository intentionally differs.
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

- Bump application or plugin versions.
- Prepare a release, tag, or changelog commit.
- Edit GitHub Actions, CI files, or release workflows.
- Diagnose `LF will be replaced by CRLF` or related warnings.
- Review staged diffs, branch changes, or repository-wide file churn.
- Start work in a Git repository that has no committed `.gitattributes` baseline.

## Expected outcome

- Keep line-ending policy in version control instead of relying on local Git configuration.
- Perform repository normalization on the first Git-facing handling, not as final cleanup.
- Leave the repo in a stable LF-based state so later Git work does not repeat the onboarding step.
