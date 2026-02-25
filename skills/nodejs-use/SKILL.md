---
name: nodejs-use
description: 定义 Node.js 环境管理和版本管理的强制规范。当 Agent 需要使用 Node.js、管理 Node 版本、安装依赖、管理包管理器版本时必须应用此技能。强制使用 volta 或 fnm 工具，禁止手动安装 Node.js，确保项目级环境隔离。
---

# Node.js 环境管理与版本管理规范

本技能定义了 Agent 在使用 Node.js 时必须严格遵循的环境管理和版本管理规则，确保项目环境的隔离性、可复现性和团队一致性。

---

## 工具选型

本规范支持两种 Node.js 版本管理工具，根据项目实际情况选择：

| 特性 | Volta | fnm |
|------|-------|-----|
| **版本切换方式** | 自动（基于 `package.json` 中的 `volta` 字段） | 自动（基于 `.node-version` / `.nvmrc`，需启用 `--use-on-cd`） |
| **包管理器版本锁定** | 支持（npm、yarn、pnpm） | 不支持（需配合 corepack） |
| **配置文件** | `package.json` 中的 `volta` 字段 | `.node-version` 或 `.nvmrc` |
| **团队协作** | 优秀（版本信息内置于 `package.json`） | 良好（需额外配置文件） |
| **性能** | 极快（Rust 编写） | 极快（Rust 编写） |
| **全局工具管理** | 内置支持，工具绑定到特定 Node 版本 | 不涉及 |

**判断标准：**
- 若项目 `package.json` 中已有 `volta` 字段 -> 使用 Volta
- 若项目根目录存在 `.node-version` 或 `.nvmrc` -> 使用 fnm
- 若两者均无，检查当前系统可用的工具，优先使用已安装的工具
- 若均未安装，询问用户偏好

---

## 核心规则

### 规则 1：必须使用版本管理工具管理 Node.js

**规则说明：**
- 所有 Node.js 版本安装和切换操作必须通过 `volta` 或 `fnm` 执行
- **严禁**从 nodejs.org 手动下载安装包覆盖安装
- **严禁**使用 `nvm`（Windows 上的 nvm-windows 性能差且维护不活跃）
- 唯一例外：当项目明确要求使用特定工具且用户显式确认时

**原因：**
1. **自动切换**：进入项目目录时自动使用正确的 Node.js 版本，无需手动操作
2. **团队一致性**：通过配置文件锁定版本，确保所有开发者使用相同的运行时
3. **快速切换**：Volta 和 fnm 均基于 Rust 构建，版本切换几乎零延迟
4. **多版本共存**：可以同时安装多个 Node.js 版本，按项目自动路由

**违反风险：**
- 团队成员使用不同 Node.js 版本导致"在我机器上能跑"问题
- 全局 Node.js 升级意外破坏现有项目
- 版本切换操作繁琐，降低开发效率

---

### 规则 2：为每个项目固定 Node.js 版本

**规则说明：**
- 每个项目必须通过配置文件声明所需的 Node.js 版本
- Volta 项目：通过 `volta pin` 写入 `package.json`
- fnm 项目：通过 `.node-version` 文件声明
- 版本声明文件必须提交到版本控制

**原因：**
1. 新成员克隆项目后自动获得正确的 Node.js 版本
2. CI/CD 环境可以读取相同配置，保证构建一致性
3. 避免隐式依赖开发者本地的 Node.js 版本

**Volta 操作流程：**
```bash
# 固定 Node.js 版本到 package.json
volta pin node@20

# 固定到精确版本
volta pin node@20.18.1

# 同时固定包管理器
volta pin node@20 npm@10

# 固定 yarn
volta pin yarn@4.6.0

# 固定 pnpm
volta pin pnpm@9.15.0
```

写入 `package.json` 后的效果：
```json
{
  "volta": {
    "node": "20.18.1",
    "npm": "10.8.2"
  }
}
```

**fnm 操作流程：**
```bash
# 安装指定版本
fnm install 20

# 设置当前 shell 使用的版本
fnm use 20

# 创建 .node-version 文件（手动）
node -v > .node-version

# 或直接写入
echo "v20.18.1" > .node-version
```

`.node-version` 文件内容示例：
```
v20.18.1
```

**违反风险：**
- 不同开发者使用不同版本导致依赖安装差异
- CI 环境与本地环境不一致

---

### 规则 3：依赖安装仅限当前项目目录

**规则说明：**
- 所有项目依赖必须安装在项目本地的 `node_modules` 目录中
- **严禁**使用 `npm install -g` 或 `yarn global add` 安装项目依赖
- 全局工具安装应通过 Volta 管理（`volta install`）或使用 `npx`/`pnpx` 临时执行
- 开发工具（如 linter、formatter）应作为项目 `devDependencies` 安装

**原因：**
1. 全局安装的包不会记录在 `package.json` 中，其他开发者无法复现环境
2. 全局包版本可能与项目需求冲突
3. 全局安装污染系统环境，难以追踪和清理
4. 不同项目可能需要同一工具的不同版本

**违反风险：**
- 项目在其他机器上构建失败（缺少全局依赖）
- 全局工具版本升级意外破坏项目
- 环境不可复现

---

### 规则 4：确保项目环境完全隔离

**规则说明：**
- 每个项目通过独立的版本配置和 `node_modules` 实现隔离
- 不同项目间不得共享 `node_modules`
- `node_modules` 目录必须加入 `.gitignore`
- 使用锁文件（`package-lock.json` / `yarn.lock` / `pnpm-lock.yaml`）确保依赖版本精确一致
- 锁文件必须提交到版本控制

**原因：**
1. 避免项目间依赖版本冲突
2. 确保项目的可移植性和可复现性
3. 通过锁文件保证 `npm install` / `yarn install` 在任何环境产生相同结果
4. Volta 的 Node 版本绑定机制天然支持项目级隔离

**违反风险：**
- 项目间依赖相互干扰
- 构建结果不可预测
- 团队成员间出现"幽灵依赖"问题

---

## 标准命令参考

### Volta 命令

```bash
# === 安装与版本管理 ===

# 安装最新 LTS 版本的 Node.js
volta install node

# 安装指定大版本
volta install node@20

# 安装精确版本
volta install node@20.18.1

# 安装包管理器
volta install npm@10
volta install yarn@4
volta install pnpm@9

# 查看已安装的工具链
volta list

# 查看所有已安装的 Node.js 版本
volta list node

# 查看当前使用的 Node.js 版本
volta which node

# 预下载工具（不设为默认）
volta fetch node@22

# 卸载工具
volta uninstall yarn

# === 项目固定 ===

# 固定 Node.js 版本
volta pin node@20

# 固定 Node.js + 包管理器
volta pin node@20 npm@10

# 使用 LTS 版本
volta pin node@lts

# === 运行命令 ===

# 使用指定版本运行命令（不影响默认设置）
volta run --node 22 node script.js

# 使用指定版本运行（同时指定包管理器）
volta run --node 22 --npm 10 npm test

# === 全局工具 ===

# 安装全局 CLI 工具（通过 Volta 管理，与项目隔离）
volta install typescript
volta install eslint

# 全局安装的工具会绑定到安装时的 Node 版本
# 项目内使用时会自动切换到项目的 Node 版本
```

### fnm 命令

```bash
# === 安装与版本管理 ===

# 安装最新 LTS 版本
fnm install --lts

# 安装指定大版本
fnm install 20

# 安装精确版本
fnm install 20.18.1

# 切换当前 shell 使用的版本
fnm use 20

# 设置默认版本
fnm default 20

# 查看已安装的版本
fnm list

# 查看可用的远程版本
fnm list-remote

# 卸载指定版本
fnm uninstall 18

# 查看当前使用的版本
fnm current

# === Shell 集成（自动切换） ===

# Bash
eval "$(fnm env --use-on-cd --shell bash)"

# Zsh
eval "$(fnm env --use-on-cd --shell zsh)"

# PowerShell
fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression

# Fish
fnm env --use-on-cd --shell fish | source

# === Corepack（包管理器版本管理） ===

# 启用 corepack（Node.js 内置）
corepack enable

# 项目中使用 package.json 的 packageManager 字段锁定版本
# package.json: { "packageManager": "pnpm@9.15.0" }
```

---

## 最佳实践

### 1. Volta 项目标准工作流

```bash
# 1. 进入/创建项目目录
cd my-project

# 2. 初始化项目（如果尚未初始化）
npm init -y

# 3. 固定 Node.js 和包管理器版本
volta pin node@20
volta pin npm@10

# 4. 安装项目依赖
npm install

# 5. 安装开发依赖
npm install --save-dev typescript eslint prettier

# 6. 确认锁文件已生成
# package-lock.json / yarn.lock / pnpm-lock.yaml 必须存在

# 7. 提交版本配置
git add package.json package-lock.json
git commit -m "chore: pin node and npm versions via volta"
```

### 2. fnm 项目标准工作流

```bash
# 1. 进入/创建项目目录
cd my-project

# 2. 初始化项目（如果尚未初始化）
npm init -y

# 3. 安装并使用指定 Node.js 版本
fnm install 20
fnm use 20

# 4. 创建版本声明文件
node -v > .node-version

# 5. 安装项目依赖
npm install

# 6. 提交版本配置
git add .node-version package.json package-lock.json
git commit -m "chore: add .node-version for fnm"
```

### 3. 克隆项目后的环境恢复

**Volta 项目：**
```bash
git clone https://github.com/user/project.git
cd project
# Volta 自动读取 package.json 中的 volta 字段
# 如果本地没有对应版本会自动下载
npm install
```

**fnm 项目：**
```bash
git clone https://github.com/user/project.git
cd project
# fnm 自动切换到 .node-version 指定的版本（需启用 --use-on-cd）
fnm install   # 安装 .node-version 中声明的版本（如果尚未安装）
fnm use       # 切换到该版本
npm install
```

### 4. .gitignore 配置

确保将以下内容添加到 `.gitignore`：

```gitignore
# 依赖目录
node_modules/

# 构建输出
dist/
build/
out/

# 环境变量文件
.env
.env.local
.env.*.local

# 日志文件
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*
```

以下文件**必须提交**到版本控制：

```
# 版本声明（二选一）
package.json          # Volta：包含 "volta" 字段
.node-version         # fnm：Node.js 版本声明

# 锁文件（根据包管理器选择一种）
package-lock.json     # npm
yarn.lock             # yarn
pnpm-lock.yaml        # pnpm
```

### 5. 项目文件结构推荐

```
my-project/
├── node_modules/         # 依赖目录（不提交到版本控制）
├── .node-version         # Node.js 版本声明（fnm 项目）
├── package.json          # 项目配置（Volta 项目包含 volta 字段）
├── package-lock.json     # 依赖锁文件（提交到版本控制）
├── tsconfig.json         # TypeScript 配置（如适用）
├── .eslintrc.*           # ESLint 配置（如适用）
├── src/                  # 源代码
├── tests/                # 测试代码
└── .gitignore
```

---

## 常见错误及避免方法

### 错误 1：全局安装项目依赖

```bash
# ❌ 错误做法 - 全局安装项目需要的工具
npm install -g typescript
npm install -g eslint

# ✅ 正确做法（Volta）- 通过 Volta 管理全局工具
volta install typescript
volta install eslint

# ✅ 正确做法 - 作为项目 devDependencies 安装
npm install --save-dev typescript eslint

# ✅ 正确做法 - 使用 npx 临时执行
npx eslint .
npx tsc --init
```

### 错误 2：不固定 Node.js 版本

```bash
# ❌ 错误做法 - 项目没有版本声明，依赖开发者本地的 Node.js 版本
cd my-project
npm install  # 使用任意本地版本

# ✅ 正确做法（Volta）
volta pin node@20
npm install

# ✅ 正确做法（fnm）
echo "v20.18.1" > .node-version
fnm use
npm install
```

### 错误 3：手动下载 Node.js 安装包

```bash
# ❌ 错误做法 - 从官网下载安装包覆盖安装
# 下载 node-v20.18.1.msi 并运行安装向导

# ✅ 正确做法（Volta）
volta install node@20.18.1

# ✅ 正确做法（fnm）
fnm install 20.18.1
```

### 错误 4：不提交锁文件

```bash
# ❌ 错误做法 - 将锁文件加入 .gitignore
echo "package-lock.json" >> .gitignore

# ✅ 正确做法 - 锁文件必须提交
git add package-lock.json
git commit -m "chore: update lockfile"
```

### 错误 5：混用包管理器

```bash
# ❌ 错误做法 - 项目中混用 npm 和 yarn
npm install express
yarn add lodash  # 产生两套锁文件

# ✅ 正确做法 - 一个项目只使用一种包管理器
npm install express
npm install lodash

# ✅ 如果使用 Volta，固定包管理器版本
volta pin npm@10
# 或
volta pin pnpm@9
```

---

## Shell 集成配置

### Volta 安装与配置

```bash
# 安装 Volta（macOS/Linux）
curl https://get.volta.sh | bash

# 安装 Volta（Windows）
# 从 https://github.com/volta-cli/volta/releases 下载安装包
# 或使用 winget
winget install Volta.Volta

# Volta 安装后自动集成到 shell，无需额外配置
# 进入包含 volta 字段的项目目录时自动切换版本
```

### fnm 安装与配置

```bash
# 安装 fnm（macOS/Linux）
curl -fsSL https://fnm.vercel.app/install | bash

# 安装 fnm（Windows）
winget install Schniz.fnm
# 或
choco install fnm

# === Shell 自动切换配置 ===

# Bash（~/.bashrc）
eval "$(fnm env --use-on-cd --shell bash)"

# Zsh（~/.zshrc）
eval "$(fnm env --use-on-cd --shell zsh)"

# Fish（~/.config/fish/config.fish）
fnm env --use-on-cd --shell fish | source

# PowerShell（$PROFILE）
fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
```

> **重要**：fnm 必须配置 `--use-on-cd` 参数才能在进入项目目录时自动切换 Node.js 版本。不配置此参数将失去自动切换能力。

---

## 检查清单

在执行 Node.js 相关操作前，请确认：

- [ ] 当前系统是否安装了 `volta` 或 `fnm`
- [ ] 项目是否已声明 Node.js 版本（`package.json` 的 `volta` 字段或 `.node-version` 文件）
- [ ] 当前工作目录是否为项目根目录
- [ ] 依赖安装命令是否使用了全局参数（如有则移除）
- [ ] 锁文件是否存在且已提交到版本控制
- [ ] 项目是否只使用了一种包管理器

---

## 参考资源

- [Volta 官方文档](https://docs.volta.sh/)
- [Volta GitHub 仓库](https://github.com/volta-cli/volta)
- [fnm GitHub 仓库](https://github.com/Schniz/fnm)
- [fnm 配置文档](https://github.com/Schniz/fnm/blob/master/docs/configuration.md)
- [Corepack 文档](https://nodejs.org/api/corepack.html)
