# agent-skills

This repository keeps reusable agent workflows under `skills/`.

- `skills/git-repo-normalize`: standardizes Git repository line endings by enforcing a root `.gitattributes` baseline with `* text=auto eol=lf`.
- Use this skill when the repo lacks a committed line-ending policy, when Git reports LF/CRLF drift, or when the task explicitly includes line-ending normalization.
- Do not treat it as a mandatory pre-step for routine Git work; if the repo policy is already stable, continue the main task without renormalizing.

This repository already adopts that LF baseline through `.gitattributes`, so future Git-related work should preserve and verify it instead of relying on local Git settings.

- [wiki-application](skills/wiki-application/SKILL.md)：按实际模板整理各类 Wiki 申请，支持草稿、原版备份、人工修改保留、数据截图核验及按授权发布。通过已有浏览器或连接器执行，不绑定特定产品与申请表。
- [项目进展与验证记录](docs/project-progress.md)。
