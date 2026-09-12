---
name: python-use
description: 使用 uv 管理 Python 版本、依赖和项目隔离环境；下载缓存与长期项目环境分开存放，项目内保留 .venv 链接。当 Agent 使用 Python、创建或恢复虚拟环境、安装依赖时应用。
---

# Python 环境管理

使用 uv 管理 Python 和依赖。每个项目使用独立环境，默认把真实环境放在主机指定的环境根目录，项目内保留 `.venv` symlink/Junction。

## 缓存与环境分开

- `uv cache dir` / `UV_CACHE_DIR` / 用户 `uv.toml` 的 `cache-dir` 只用于下载、解包、构建和 uv 临时运行缓存。
- 长期项目环境放在独立的 `environment_root`，不得等于缓存根目录，也不得与缓存目录互相包含。物理路径属于主机本地配置，不写入业务项目或公共 Skill。
- 默认不启用 `centralized-project-envs`。该预览功能会把项目环境放进 UV 缓存，`uv cache prune` 也会删除它们；它不适合本技能默认的缓存、环境分离方式。
- “集中管理环境”在本技能中指独立环境根目录加项目入口，不宣称使用 UV 原生集中缓存预览。只有用户明确选择后者时才采用，并先说明清理边界。

## 主机配置与前置检查

1. 检查项目或 UV workspace 根目录、AGENTS.md、`pyproject.toml`、`uv.lock`、`.python-version` 和现有环境入口。
2. 运行 `uv --version`、`uv cache dir`，检查用户/项目配置、`UV_CACHE_DIR`、`UV_PREVIEW`、`UV_PREVIEW_FEATURES`、`UV_PROJECT_ENVIRONMENT`、`VIRTUAL_ENV` 和包装脚本的覆盖。环境变量优先于 UV 配置文件。
3. 环境根目录优先使用用户已指定的位置或已有主机约定。可保存在用户 UV 配置目录旁的 `environment-policy.toml` 中：Linux/macOS 为 `${XDG_CONFIG_HOME:-$HOME/.config}/uv/environment-policy.toml`，Windows 为 `%APPDATA%/uv/environment-policy.toml`，内容为 `environment-root = "<本机绝对路径>"`。
   - 这是 Agent 读取的主机策略文件，**不是 UV 原生配置文件**；UV 不会自动读取它，也不能把 `environment-root` 填进 `uv.toml`。
   - 根目录尚未确定时先查已有环境和主机配置，仍无法确定再询问。已明确的位置不重复确认。
   - 修改缓存位置时同步检查 Dockerfile、Compose、启动脚本及持久挂载；不得为修配置擅自重启正在运行的容器。
4. 分离模式下，移除任务范围内配置中的 `centralized-project-envs`，保留其他预览项；若全量 preview 或外部覆盖仍会启用它，先解决覆盖再创建环境。
5. 已有有效外置链接直接复用，不按新的命名约定强制改名。损坏链接先检查目标和记录，不能覆盖。已有实体环境需迁移时按 `$uv-centralized-envs` 审计、备份和验收；当前项目任务不授权批量迁移其他项目。

## 创建或恢复环境

依赖要求决定 Python 版本：优先遵守项目声明及锁文件；不要因移动环境升级 Python 或包。使用 `uv python find/install/pin` 管理解释器，禁止向系统 Python 安装项目依赖，禁止改用 pip、Conda、Poetry 或共享环境，除非用户明确要求。

新环境使用稳定且项目独占的目录，例如 `<environment_root>/<项目名>-<规范化项目路径的短哈希>/py<主次版本>`。同名项目和不同 checkout 必须区分；已有目录先查归属，不因名称相同复用。

Linux/macOS 示例（已从主机策略读取并校验 `env_root`；Python 版本按项目实际要求替换）：

```bash
project_root="$(pwd -P)"
project_key="$(printf %s "$project_root" | sha256sum | cut -c1-12)"
project_env="$env_root/$(basename "$project_root")-$project_key/py3.12"
test ! -e .venv && test ! -L .venv || exit 1
test ! -e "$project_env" && test ! -L "$project_env" || exit 1
uv venv --python 3.12 "$project_env"
ln -s "$project_env" .venv
# 已有锁文件时恢复；新项目用 uv add 或 uv lock 建立声明和锁文件。
uv sync --locked
```

macOS 没有 `sha256sum` 时用 `shasum -a 256`。Windows 用规范化绝对路径计算稳定哈希，通过 `uv venv --python <版本> <项目独占路径>` 创建环境，再用 `New-Item -ItemType Junction -Path .venv -Target <项目独占路径>` 建立入口。创建前同样检查链接和目标，不能覆盖已有目录。

- 显式路径的 `uv venv` 是本方案有意使用的 UV 功能。不要在没有外置入口时直接运行裸 `uv venv`、`uv sync` 或 `uv add`，否则可能生成项目内实体环境。
- 正常使用项目 `.venv` 入口执行 `uv run`、`uv add` 和 `uv sync --locked`。
- 不把 `UV_PROJECT_ENVIRONMENT` 全局设置成环境根目录；UV 会把它当作一个环境，各项目会相互覆盖。必要时仅对单次命令指定当前项目独占的完整环境路径。
- 更换解释器前重新核对外置路径；需要重建时先在新外置目录创建和验证，再切换入口，避免 UV 自动重建时替换链接、丢失原环境或生成项目内实体目录。
- requirements 项目继续用 `uv pip install/sync --python .venv/bin/python ...`（Windows 为 `.venv/Scripts/python.exe`），不得凭猜测创建新依赖集或升级包。
- 一次性工具使用 `uvx` 或 `uv run --no-project --with <依赖> ...`；其可重建的临时环境允许由 UV 缓存管理，不属于长期项目环境。

## 验证与日常使用

```bash
uv run --no-sync python -c "import sys; from pathlib import Path; print(Path(sys.prefix).resolve())"
uv pip check
```

确认解析后的环境路径位于所选环境根目录内，且在缓存目录外；解释器版本符合要求，`.venv` 是有效链接。需要恢复验证时运行 `uv sync --locked --offline`，再检查环境路径和关键导入。有严格版本一致性要求时比较完整包快照；不能用会删掉额外包的 sync 代替迁移前审计。

- 添加/修改依赖：`uv add <包>`、`uv add --dev <包>`、`uv remove <包>`；依赖声明与锁文件保持一致。
- 执行：`uv run python ...`、`uv run pytest`。激活可选，VS Code 继续使用 `${workspaceFolder}/.venv`。
- `.gitignore` 使用 `.venv`，同时覆盖目录和 symlink；集中根目录若在更大的工作区仓库内，也应在该工作区本地忽略，不提交环境。
- 环境按项目备份与清理；删除项目或清理下载缓存不等于删除它的外置环境。缓存、环境之间不要建立目录级跳转来伪装分离。

参考：[UV 项目环境路径](https://docs.astral.sh/uv/concepts/projects/config/#project-environment-path)、[缓存清理](https://docs.astral.sh/uv/concepts/cache/#clearing-the-cache)、[原生集中预览](https://docs.astral.sh/uv/concepts/projects/layout/#centralized-project-environments)。
