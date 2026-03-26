# 生态资料来源与补充检查

只加载与当前项目匹配的部分，不要把所有生态的内容都带进上下文。

## JavaScript / TypeScript

- 先查 `package.json`、锁文件和现有依赖，避免重复引入同类库。
- 在 npm 注册表、官方文档、源码仓库里确认下载量、发布时间、TypeScript 支持、Node 或浏览器兼容性、ESM/CJS 形态、SSR 兼容性。
- 注意包体积、副作用标记、tree-shaking 友好性，以及是否依赖原生模块。

## Python

- 先查 `pyproject.toml`、锁文件和现有依赖。
- 在 PyPI、官方文档、源码仓库里确认 Python 版本要求、wheel 支持、可选 extras、发布频率和维护状态。
- 特别注意是否需要本地编译、系统库依赖、跨平台兼容性和许可证。

## Java / Kotlin

- 先查构建文件和现有 BOM 或 framework starter。
- 在 Maven Central、官方文档、源码仓库里确认最近版本、JDK 要求、Spring 或 Micronaut 兼容性、传递依赖规模。
- 留意 shaded jar、annotation processor、AOT/native image 兼容性。

## Go

- 先查标准库是否已覆盖需求。
- 在 `pkg.go.dev`、源码仓库和 release/tag 里确认模块活跃度、语义化版本策略和 import path 稳定性。
- 留意是否引入 CGO、是否依赖外部服务或庞大子模块。

## Rust

- 先查 `Cargo.toml` 和现有 workspace crate。
- 在 crates.io、docs.rs、源码仓库里确认维护状态、feature flags、MSRV、unsafe 使用情况和原生依赖。
- 留意默认启用的 feature 是否过重，必要时改为最小 features。

## .NET

- 先查现有 `Directory.Packages.props`、项目文件和共享基础库。
- 在 NuGet、官方文档、源码仓库里确认目标框架、最近版本、AOT/trim 兼容性、source generator 或 analyzer 要求。
- 留意是否与现有 ASP.NET Core、EF Core、Azure SDK 版本线冲突。

## 通用红旗

- 长时间不发版，但 issue 持续堆积。
- 许可证与项目要求冲突。
- 文档薄弱，示例不足，错误处理不透明。
- 传递依赖过多，或一旦引入就要求改动大量基础设施。
- 只解决 10% 需求，却引入 90% 复杂度。
