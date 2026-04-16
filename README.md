# agent-skills

This repository keeps reusable agent workflows under `skills/`.

- `skills/git-repo-normalize`: standardizes Git repository line endings by enforcing a root `.gitattributes` baseline with `* text=auto eol=lf`.
- Use this skill when the repo lacks a committed line-ending policy, when Git reports LF/CRLF drift, or when the task explicitly includes line-ending normalization.
- Do not treat it as a mandatory pre-step for routine Git work; if the repo policy is already stable, continue the main task without renormalizing.

This repository already adopts that LF baseline through `.gitattributes`, so future Git-related work should preserve and verify it instead of relying on local Git settings.
