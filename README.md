# agent-skills

This repository keeps reusable agent workflows under `skills/`.

- `skills/git-repo-normalize`: standardizes Git repository line endings by enforcing a root `.gitattributes` baseline with `* text=auto eol=lf`.
- Use this skill for any Git-facing work such as version bumps, release/tag work, CI workflow edits, commit/diff investigation, or LF/CRLF warning cleanup.
- Apply it at the first handling of the repository, before continuing with the main task. Do not leave normalization to the end.

This repository already adopts that LF baseline through `.gitattributes`, so future Git-related work should preserve and verify it instead of relying on local Git settings.