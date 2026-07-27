---
name: uv-centralized-envs
description: 将 UV 项目的大型 .venv 迁移到用户指定的集中缓存根目录，同时保留项目内 .venv 入口并兼容 VS Code、uv 和 AI Agent。用于“把 Python 环境移到其他盘/目录”“外移 .venv”“集中管理 uv 虚拟环境”“保留 VS Code 解释器路径”等需求。
---

# UV 集中项目环境迁移

把每个项目的真实虚拟环境放在调用者指定的宿主机位置，同时让
`${workspaceFolder}/.venv` 保持为项目的唯一入口。每个项目仍独立，绝不共享同一个环境。

## 输入

开始前确认以下信息；不要把示例盘符或物理路径写进项目文件。

- `central_cache_root`：必填，当前主机上 UV 缓存与集中环境的绝对根目录。
- `project_roots`：要迁移的一个或多个项目根目录。
- `backup_root`：可选；迁移期间旧环境的临时备份位置。未给出时，先询问或在 `central_cache_root` 的同盘安全位置创建带日期的备份目录。
- `parity_required`：旧环境是否必须逐包保持完全一致；基准、生产或没有依赖清单的项目默认设为 `true`。

`central_cache_root` 是主机本地配置，不属于 Git，也不要求在不同机器上相同。

## 工作流

1. 先审计，不移动任何文件。
   - 检查 `uv --version`、`pyproject.toml`、`uv.lock`、`.venv`、`.gitignore`、`.vscode/settings.json` 与项目级 `AGENTS.md`。
   - 确认 `.venv` 是实体目录、Junction 还是 symlink；如果已是链接，先解析并记录真实目标，绝不递归删除链接目标。
   - 对旧环境记录 `uv pip freeze`、Python 版本、关键导入和 `uv pip check` 结果。

2. 先让依赖可复现。
   - 已有 `pyproject.toml` 与 `uv.lock`：运行 `uv lock --check`，以 `uv sync --locked` 为恢复方式。
   - 缺少清单：根据项目代码、脚本和现有环境识别直接依赖，创建最小 `pyproject.toml`，再生成并提交 `uv.lock`。
   - 当 `parity_required=true`：以旧环境的完整版本快照约束解析，生成锁文件后比较迁移前后的 `uv pip freeze`；不要凭猜测重建环境或顺手升级包。

3. 配置集中位置。
   - 在当前主机的用户级 `uv.toml` 中保留既有配置并设置 `cache-dir = "<central_cache_root>"`。Windows 路径可使用正斜杠。
   - 在项目 `pyproject.toml` 的 `[tool.uv]` 中启用 `preview-features = ["centralized-project-envs"]`；若已有其他预览功能，合并而非覆盖。
   - 不把 `central_cache_root`、缓存目录名或物理环境路径提交到项目。

4. 安全迁移。
   - 先把完整旧环境移到已验证的 `backup_root`，并确认备份中的 Python 可执行；不要在没有可用备份时移除旧环境。
   - 仅移除项目内 `.venv` 这个入口；若它是 Junction/symlink，只移除链接本身。
   - 从项目根目录运行 `uv sync --locked`，让 UV 在集中缓存位置创建真实环境，并重新生成项目 `.venv` 入口。
   - 物理环境必须由 UV 管理；不要手工复制、共享或硬编码它的名称。

5. 保持编辑器和 Agent 无感。
   - `.vscode/settings.json` 使用 `"python.defaultInterpreterPath": "${workspaceFolder}/.venv"`。
   - `.gitignore` 忽略 `.venv/`，但不要忽略或提交真实集中环境目录。
   - 项目 `AGENTS.md` 说明：执行用 `uv run <command>`；恢复用 `uv sync --locked`；不要替换 `.venv` 链接，也不要写入物理缓存路径。

6. 验收后再清理。
   - 运行 `uv lock --check`、`uv sync --locked --offline`、`uv pip check` 和关键模块导入。
   - 当 `parity_required=true`，比较新旧 `uv pip freeze`，必须零差异后才删除备份。
   - 最后确认 `.venv` 指向集中环境，并报告：输入的根目录、项目入口、是否锁定、验证结果、删除的备份及可释放空间。

## 约束

- 优先使用项目的现有 `pyproject.toml`、`uv.lock` 和依赖声明；不要新增 pip、conda、Poetry 或共享虚拟环境方案。
- 不因迁移而自动升级 UV 或依赖；确实需要升级时，使用 UV 的官方升级方式，并单独验证。
- `.venv` 的入口保持项目内，因此 VS Code、工具脚本和 Agent 不需要知道真实路径。
- 在另一台机器上使用时，只需重新提供该机器的 `central_cache_root` 并运行 `uv sync --locked`；不要复制宿主机的环境目录。
