---
name: python-use
description: 使用 uv 管理 Python 版本、依赖和项目隔离环境，默认将真实虚拟环境放在项目外的 uv 集中缓存中，项目内仅保留 .venv 入口。当 Agent 使用 Python、创建或恢复虚拟环境、安装依赖时应用。
---

# Python 环境管理与依赖管理规范

本技能定义了 Agent 在使用 Python 时必须严格遵循的环境管理和依赖管理规则，确保项目环境的隔离性、可复现性和安全性。

---

## 核心规则

### 规则 1：必须使用 uv 工具管理环境和依赖

**规则说明：**
- 所有 Python 环境创建、依赖安装、版本管理操作必须通过 `uv` 工具执行
- **严禁**使用 `pip`、`conda`、`poetry`、`pipenv` 或其他包管理工具
- 唯一例外：当项目明确要求使用特定工具且用户显式确认时

**原因：**
1. **速度优势**：uv 比 pip 快 10-100 倍，显著提升开发效率
2. **一致性保障**：uv 提供统一的工作流，减少工具切换带来的配置差异
3. **内置环境管理**：uv 集成了虚拟环境创建、Python 版本管理、依赖锁定等功能
4. **更好的依赖解析**：uv 拥有更先进的依赖解析算法，减少冲突

**违反风险：**
- 混用不同包管理器可能导致依赖冲突
- 环境状态难以追踪和复现
- 可能意外修改系统 Python 环境

---

### 规则 2：根据依赖要求选择合适的 Python 版本

**规则说明：**
- 安装依赖前，必须确认所需库对 Python 版本的兼容性要求
- 优先使用项目中 `pyproject.toml` 或 `.python-version` 指定的版本
- 若无指定，选择依赖库支持的最新稳定 Python 版本

**原因：**
1. 避免因版本不兼容导致的安装失败或运行时错误
2. 确保能使用依赖库的所有功能
3. 某些库可能需要特定版本的 Python 特性

**标准操作流程：**
```bash
# 查看可用的 Python 版本
uv python list

# 安装特定 Python 版本
uv python install 3.11

# 为当前项目固定 Python 版本
uv python pin 3.11

# 查找已安装的 Python 版本
uv python find
```

**违反风险：**
- 依赖安装失败
- 运行时出现兼容性错误
- 某些功能无法正常使用

---

### 规则 3：依赖仅安装到当前项目专属的外置环境

**规则说明：**
- 所有项目依赖必须安装在当前项目专属的虚拟环境中；默认启用 uv 的 `centralized-project-envs`，真实环境位于项目外，项目内 `.venv` 仅作为 uv 管理的 Junction/symlink 入口
- 创建或恢复环境前，先完成下方“默认外置环境配置”；不要直接创建项目内的实体 `.venv`
- 复用宿主机现有的外置 uv 缓存位置，不把盘符或物理环境路径写入项目；不同项目禁止共享同一环境
- **严禁**使用任何全局安装参数，包括但不限于：
  - `--global`
  - `--user`
  - `--system`
  - `--target` 指向项目外路径
- **严禁**直接向系统 Python 环境安装包

**原因：**
1. 全局安装可能破坏系统 Python 环境
2. 影响其他项目或系统工具的正常运行
3. 难以追踪和清理不再需要的依赖
4. 导致项目在不同机器上难以复现

**违反风险：**
- 污染系统环境或其他项目环境
- 造成依赖版本冲突
- 可能破坏操作系统依赖的 Python 工具
- 项目无法在其他环境正确运行

---

### 规则 4：确保项目环境完全隔离

**规则说明：**
- 每个项目必须拥有独立的虚拟环境
- 虚拟环境默认以项目目录内的 `.venv` 受管链接作为入口，实际文件位于项目外
- 不同项目间不得共享虚拟环境
- 虚拟环境目录（`.venv`）应加入 `.gitignore`

**原因：**
1. 避免项目间依赖冲突
2. 确保项目的可移植性和可复现性
3. 项目源码与大体积环境分离；删除项目不会自动清理外置环境，不能据此宣称磁盘空间已释放
4. 保护系统 Python 环境的稳定性

**违反风险：**
- 项目间依赖相互干扰
- 升级一个项目的依赖可能破坏另一个项目
- 难以确定每个项目的真实依赖

---

## 默认外置环境配置

在 `uv add`、`uv sync`、`uv run` 或 `uv venv` 首次创建环境前：

1. 检查项目配置、`.venv` 类型及 `uv --version`，运行 `uv cache dir` 确认当前主机的有效缓存位置。
   - 缓存已在项目外时直接复用，包括 uv 默认的用户缓存目录；不要为每个项目重新指定路径。
   - 用户指定其他位置时，保留用户级 `uv.toml` 既有设置，仅更新 `cache-dir`；Windows 为 `%APPDATA%/uv/uv.toml`，Linux/macOS 为 `$XDG_CONFIG_HOME/uv/uv.toml`（未设置时为 `~/.config/uv/uv.toml`）。物理路径只存于主机配置。
   - 检查 `UV_CACHE_DIR`、项目 `cache-dir`、命令包装脚本等覆盖项；若把缓存指向项目内，先在本次任务范围修正，不能只改用户配置就认定已外置。
2. 在项目 `pyproject.toml` 中合并以下配置；已有 `uv.toml` 时，将 `preview-features` 合并到该文件顶层，避免被其优先级覆盖。保留其他预览功能，不重复声明表。

   ```toml
   [tool.uv]
   preview-features = ["centralized-project-envs"]
   ```

3. 在项目或 uv workspace 根目录运行不带路径的 `uv venv`，或直接用 `uv sync --locked` / `uv add` 创建环境。
   - `uv venv .venv` 等显式路径会绕过集中环境；不要使用。
   - `UV_PROJECT_ENVIRONMENT`、`--active` 会选择显式环境，`--no-cache` 会禁用集中功能；先检查这些覆盖，不静默退回项目内环境。
   - 只有 requirements 的旧项目若需补齐项目元数据，保留其依赖管理方式，不凭空解析升级依赖。一次性脚本可用 `uv run --no-project --with <依赖> python <脚本>`，无需为此创建项目内环境。
4. 已有实体 `.venv` 时应用 `$uv-centralized-envs` 的审计、备份、按锁文件重建和验收流程；本 Skill 的默认规则不授权批量迁移其他项目或删除旧环境。已有有效外置链接时复用。
5. 验证真实位置和可用性，而非仅检查 `.venv` 存在：

   ```bash
   uv run python -c "import sys; from pathlib import Path; print(Path(sys.prefix).resolve())"
   uv pip check
   ```

   输出的真实环境必须位于项目外。需要编辑器兼容时检查 `.venv` 链接目标，VS Code 继续使用 `${workspaceFolder}/.venv`。uv 创建链接失败时可能写入路径文件；此时不能宣称编辑器或激活脚本兼容已通过。

该功能目前为预览功能。若当前 uv 不支持，报告版本限制并按当前任务授权处理升级，不擅自改为项目内实体环境。不要把集中环境当作可随意删除的下载缓存，也不要为了本任务清空整个 uv 缓存。

## 标准命令参考

以下项目命令均以前述集中配置生效为前提；优先使用 `uv run` 执行、`uv sync --locked` 恢复。

### 项目初始化

```bash
# 初始化新项目（创建 pyproject.toml）
uv init

# 初始化并指定项目名称
uv init my-project

# 先合并上述集中配置，再创建项目外环境（不传路径）
uv venv

# 创建指定 Python 版本的虚拟环境
uv venv --python 3.11

# 不使用 uv venv .venv：显式路径会绕过集中环境
```

### 依赖管理

```bash
# 添加依赖到项目
uv add requests

# 添加指定版本的依赖
uv add "requests>=2.28.0"

# 添加开发依赖
uv add --dev pytest

# 添加可选依赖组
uv add --group test pytest pytest-cov

# 从 Git 仓库添加依赖
uv add "package @ git+https://github.com/user/repo.git"

# 移除依赖
uv remove requests

# 同步项目依赖（根据 pyproject.toml 和 uv.lock）
uv sync

# 生成/更新锁文件
uv lock

# 查看依赖树
uv tree
```

### pip 接口命令（传统工作流）

```bash
# 在虚拟环境中安装包
uv pip install requests

# 安装指定版本
uv pip install "requests==2.28.0"

# 从 requirements.txt 安装
uv pip install -r requirements.txt

# 查看已安装的包
uv pip list

# 冻结当前环境依赖
uv pip freeze > requirements.txt

# 检查依赖兼容性
uv pip check

# 卸载包
uv pip uninstall requests

# 编译 requirements（生成锁定版本）
uv pip compile requirements.in -o requirements.txt

# 同步环境与锁文件
uv pip sync requirements.txt
```

### 运行命令

```bash
# 在项目环境中运行 Python 脚本
uv run python script.py

# 在项目环境中运行模块
uv run python -m pytest

# 运行项目定义的入口点
uv run my-cli-tool

# 临时添加依赖运行
uv run --with httpx python script.py
```

### 工具管理

```bash
# 临时运行工具（不安装）
uvx ruff check .

# 安装工具到用户目录
uv tool install ruff

# 列出已安装的工具
uv tool list

# 卸载工具
uv tool uninstall ruff
```

---

## 最佳实践

### 1. 项目标准工作流

```bash
# 1. 进入项目目录
cd my-project

# 2. 初始化项目（如果尚未初始化）
uv init

# 3. 设置 Python 版本
uv python pin 3.11

# 4. 先合并集中配置、确认 uv cache dir 在项目外，再创建环境
uv venv

# 5. 添加项目依赖
uv add requests pandas numpy

# 6. 添加开发依赖
uv add --dev pytest black ruff

# 7. 锁定依赖版本
uv lock

# 8. 按锁文件同步环境
uv sync --locked
```

### 2. 克隆项目后的环境恢复

```bash
# 克隆项目
git clone https://github.com/user/project.git
cd project

# 确认集中配置与项目外缓存后，按已有锁文件恢复
uv sync --locked
```

### 3. .gitignore 配置

确保将以下内容添加到 `.gitignore`：

```gitignore
# Python 虚拟环境
.venv
venv/

# uv 缓存
.uv_cache/

# Python 编译文件
__pycache__/
*.py[cod]
*$py.class
*.so

# 分发/打包
dist/
build/
*.egg-info/
```

### 4. 项目文件结构推荐

```
my-project/
├── .venv               # 指向项目外环境的受管链接（不提交）
├── .python-version     # Python 版本固定
├── pyproject.toml      # 项目配置和依赖声明
├── uv.lock             # 依赖锁文件（提交到版本控制）
├── src/                # 源代码
│   └── my_project/
├── tests/              # 测试代码
└── README.md
```

---

## 常见错误及避免方法

### 错误 1：使用 pip 安装依赖

```bash
# ❌ 错误做法
pip install requests

# ✅ 正确做法
uv add requests
# 或
uv pip install requests
```

### 错误 2：全局安装包

```bash
# ❌ 错误做法
pip install --user requests
uv pip install --system requests

# ✅ 正确做法
# 确保在项目目录中，使用虚拟环境
uv venv
uv add requests
```

### 错误 3：忘记创建虚拟环境

```bash
# ❌ 错误做法 - 直接安装到系统环境
cd my-project
uv pip install --system requests

# ✅ 正确做法 - 先创建虚拟环境
cd my-project
uv venv
uv add requests
```

### 错误 4：在错误的目录操作

```bash
# ❌ 错误做法 - 在错误目录创建环境
cd /
uv venv
uv add requests

# ✅ 正确做法 - 在项目目录操作
cd ~/projects/my-project
uv venv
uv add requests
```

### 错误 5：共享虚拟环境

```bash
# ❌ 错误做法 - 多个项目使用同一个虚拟环境
cd project-a
uv venv /shared/venv
cd ../project-b
source /shared/venv/bin/activate

# ✅ 正确做法 - 每个项目独立环境
cd project-a
uv venv
cd ../project-b
uv venv
```

---

## 环境激活（可选）

虽然 `uv run` 命令可以自动在虚拟环境中执行，但有时手动激活环境也很有用：

**Windows (PowerShell)：**
```powershell
.venv\Scripts\activate
```

**Windows (CMD)：**
```cmd
.venv\Scripts\activate.bat
```

**macOS/Linux (bash/zsh)：**
```bash
source .venv/bin/activate
```

**退出虚拟环境：**
```bash
deactivate
```

---

## 检查清单

在执行 Python 相关操作前，请确认：

- [ ] 当前工作目录是否为项目根目录
- [ ] 是否已启用集中环境，且有效缓存路径位于项目外
- [ ] 是否确认真实环境位于项目外，`.venv` 入口类型与工具兼容性符合预期
- [ ] 是否避免显式环境路径、`--active` 或 `--no-cache` 绕过集中环境
- [ ] 是否使用 `uv` 命令（而非 pip/conda 等）
- [ ] 依赖安装命令是否包含全局参数（如有则移除）
- [ ] Python 版本是否与依赖要求兼容

---

## 参考资源

- [uv 官方文档](https://docs.astral.sh/uv/)
- [uv 集中项目环境](https://docs.astral.sh/uv/concepts/projects/layout/#centralized-project-environments)
- [uv GitHub 仓库](https://github.com/astral-sh/uv)
- [pyproject.toml 规范](https://packaging.python.org/en/latest/specifications/pyproject-toml/)
