---
name: uv-centralized-envs
description: 将 Python 项目环境迁到独立于 UV 下载缓存的集中环境目录，保留项目内 .venv 入口并兼容 VS Code、uv 和 AI Agent。用于外移 .venv、集中管理环境、分离 cache 与 env、保留编辑器解释器路径等需求。
---

# 集中环境与 UV 缓存分离

UV 负责创建环境和管理依赖；真实环境放在独立的宿主机环境根目录，项目内保留原 `.venv` symlink/Junction。不同项目绝不共享环境。

## 输入和边界

- `environment_root`：用户指定或已有主机策略登记的环境根目录。可从用户 UV 配置目录的 `environment-policy.toml` 读取 `environment-root`；这是 Agent 约定，UV 不会自动读取。
- `cache_root`：通过 `uv cache dir` 确认的下载/解包/构建缓存位置。与 `environment_root` 不相等、不互相包含。
- `project_roots`：本次授权处理的项目；没有环境的项目是否初始化以用户范围为准。
- `backup_root`：独立于下载缓存的恢复位置，可在环境根目录同盘创建带日期目录；已有用户授权时不重复确认。
- `parity_required`：生产、基准、无可靠清单的环境默认要求逐包一致。

主机绝对路径只存本机配置，不写进业务项目或公共 Skill。名称保留 `uv-centralized-envs` 以兼容已有安装；本流程不默认采用 UV 的 `centralized-project-envs` 预览功能，因为该功能把环境作为可清理缓存存放。

## 工作流

1. 审计与备份。
   - 检查项目 AGENTS.md、pyproject、锁文件、Python 版本、环境入口类型、真实目标和正在运行的进程。
   - 记录 `uv pip list/freeze`、解释器、`uv pip check`、关键导入和现有问题。Windows 环境在 Linux 上只能验证文件保留时，应明确这一限制。
   - 现有链接先解析归属，不递归删除链接目标。已在正确环境根目录的有效链接直接复用，不强行改名。
   - 依赖声明不完整、editable 路径失效或存在额外包时，保留快照并报告；不要用一次 sync 删除这些差异。

2. 配置分离位置。
   - 用户 `uv.toml` 中 `cache-dir` 仅设置缓存目录；环境目录记录在独立的 `environment-policy.toml` 或已有主机策略中。
   - 检查 `UV_CACHE_DIR`、项目配置、包装脚本、Dockerfile/Compose 覆盖及持久化。只修改本次相关项，保持现有服务运行。
   - 分离模式下移除任务范围内 `centralized-project-envs` 开关，保留其他预览设置；检查全量 preview、命令参数和环境变量不能重新启用它。
   - 不把所有项目的 `UV_PROJECT_ENVIRONMENT` 全局设置成同一个目录。该变量指定的是单个环境，绝不会自动按项目建立子目录。

3. 按授权选择迁移方式。
   - **已有外置环境只调整根目录或分离缓存**：优先保留环境文件、版本和原入口。核对内部链接、shebang、激活脚本和 editable 绝对路径；需要物理迁移时使用有备份、校验和原子切换的方式。不能把简单移动宣称为按锁文件重建。
   - **按锁文件重建**：先检查锁文件与完整包快照能否恢复原环境，在项目独占的新外置目录运行 `uv venv --python <版本> <完整环境路径>`。使用仅对本次命令生效的 `UV_PROJECT_ENVIRONMENT=<完整环境路径> uv sync --locked` 恢复并验证，之后建立/切换项目 `.venv` 链接。Windows 只在受控进程范围设置并恢复该变量。
   - **没有可靠清单**：用户只要求外移时原样保留，不自动创建元数据或安装依赖。需要重建时先从现有快照与项目代码建立可复现声明，再恢复；不凭猜测升级。
   - 新项目独占目录按项目名、规范化项目路径哈希和 Python 版本区分。同名项目、不同 checkout 不共享；已有环境不按新命名强制重排。

4. 保持项目入口。
   - 使用 symlink（Linux/macOS）或 Junction（Windows）让项目原 `.venv` 指向实际环境；已有 `venv` / `kid_ppg_env` 名称按用户范围保留。
   - `.gitignore` 的 `.venv` 同时覆盖目录和链接，VS Code 使用 `${workspaceFolder}/.venv`。
   - 日常用 `uv run` / `uv sync --locked`，不需要全局环境变量或修改业务代码。新 checkout 先建立独立外置环境及入口，不能直接裸 sync 创建项目内目录。

5. 验收和清理。
   - 验证链接真实路径在环境根目录内、缓存目录外，检查 `uv run --no-sync` 的解释器、包快照、`uv pip check` 和关键导入。
   - 重建项目额外验证 `uv lock --check`、`uv sync --locked --offline`；有严格一致性要求时必须比较完整版本快照。
   - 用临时项目与临时缓存验证清缓存不会删除外置环境，不在实际开发缓存上做破坏性验收。
   - 迁出缓存时检查指向缓存内容的符号链接；普通硬链接在删除缓存副本后仍可使用。不要保留缓存根到环境根的目录跳转来充当分离。
   - 清除已不需要的兼容链接前确认调用方和现有进程；删除备份必须符合用户授权，不因验收通过自动清空全部缓存或恢复副本。

## 报告

说明最终缓存目录、环境根目录、项目入口、原样保留还是重建、版本/运行验证及未处理的原有问题。保留逐项目清单和恢复方法。磁盘空间是否释放与路径是否外移分别报告。

参考：[UV 项目环境路径](https://docs.astral.sh/uv/concepts/projects/config/#project-environment-path)、[缓存清理](https://docs.astral.sh/uv/concepts/cache/#clearing-the-cache)、[原生集中预览](https://docs.astral.sh/uv/concepts/projects/layout/#centralized-project-environments)。
