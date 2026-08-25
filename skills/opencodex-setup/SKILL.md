---
name: opencodex-setup
description: 配置和管理 OpenCodex 本地代理服务，包括安装、多模型提供商（DeepSeek、阿里云、OpenAI）、上下文窗口调优、reasoning_effort 降级、自动启动、托盘管理，以及常见故障排查（502 代理断连、400 参数不兼容、模型目录过时）。适用于"帮我配置 opencodex"、"opencodex 报错了"、"切换模型后报错"、"GPT 连不上"、"设置开机自启"等场景。
---

# OpenCodex Setup

配置、管理和排障 OpenCodex 本地代理服务。

## 什么时候用这个 Skill

- 安装或升级 OpenCodex
- 添加/修改模型提供商（DeepSeek、阿里云、OpenAI 等）
- 配置上下文窗口、reasoning_effort 降级
- 设置 Windows 开机自启、托盘、后台服务
- 排查 502、400、模型不可用等错误

## 核心文件

| 文件 | 路径 | 用途 |
|------|------|------|
| 主配置 | ~/.opencodex/config.json | 所有 provider、代理、认证设置 |
| 服务日志 | ~/.opencodex/service.log | 启动日志、连接重试、路由警告 |
| 请求日志 | ~/.opencodex/usage.jsonl | 每次请求的状态码、耗时、错误详情 |
| API token | ~/.opencodex/service-api-token | 管理 API 认证 |

## 安装与升级

    mise use -g node@24
    npm install -g @bitkyc08/opencodex

升级后如果 ocx 命令丢失，通常是 mise 切换了 Node 版本导致全局包丢失，重新 npm install -g 即可。

## 添加模型提供商

### DeepSeek

在 config.json 的 providers 下添加：

    "deepseek": {
      "adapter": "openai-chat",
      "baseUrl": "https://api.deepseek.com/v1",
      "authMode": "key",
      "apiKey": "sk-xxx",
      "selectedModels": ["deepseek-v4-flash-vision-exp"],
      "modelContextWindows": { "deepseek-v4-flash-vision-exp": 128000 }
    }

注意：deepseek-chat 和 deepseek-reasoner 已下线，不要用旧模型 ID。

### 阿里云（百炼）

阿里云百炼的 compatible-mode 端点同时支持 Chat Completions 和 Responses 两种协议。建议创建两个 provider 条目，分别走不同协议：

**aliyun_r（Responses 协议，用于 qwen3.8-max 等通义模型）**：

    "aliyun_r": {
      "adapter": "openai-responses",
      "baseUrl": "https://ws-xxx.cn-beijing.maas.aliyuncs.com/compatible-mode/v1",
      "authMode": "key",
      "apiKey": "sk-xxx",
      "defaultModel": "qwen3.8-max",
      "modelContextWindows": { "qwen3.8-max": 983616 },
      "modelReasoningEfforts": { "qwen3.8-max": ["low", "medium", "xhigh"] },
      "modelDefaultReasoningEfforts": { "qwen3.8-max": "xhigh" }
    }

**aliyun_c（Chat 协议，用于 kimi-k3 等第三方模型）**：

    "aliyun_c": {
      "adapter": "openai-chat",
      "baseUrl": "https://ws-xxx.cn-beijing.maas.aliyuncs.com/compatible-mode/v1",
      "authMode": "key",
      "apiKey": "sk-xxx"
    }

关键点：

- 同一 baseUrl、同一 API Key，但 adapter 不同
- aliyun_r 走 Responses 协议，适合 qwen3.8-max 等通义自研模型
- aliyun_c 走 Chat Completions 协议，适合 kimi-k3 等第三方模型
- 通过 provider/model 前缀显式指定走哪条路线，例如 aliyun_c/kimi-k3
- 两条路互不干扰，可以同时在 Codex 中切换使用
- modelReasoningEfforts 和 modelDefaultReasoningEfforts 必须配置，否则 reasoning_effort max 会导致 400

## reasoning_effort 降级

部分模型对 reasoning_effort 有严格枚举限制。qwen3.8-max 只接受 none/minimal/low/medium/high/xhigh，Codex 客户端可能发送 max，需要降级。

在 provider 配置中添加：

    "modelReasoningEfforts": { "<model>": ["low", "medium", "xhigh"] },
    "modelDefaultReasoningEfforts": { "<model>": "xhigh" }

这样 OpenCodex 会把不支持的值自动降级到列表中最近的合法值。

## 代理设置（关键）

Windows 上通过托盘或计划任务启动的进程不会继承当前 shell 的 HTTP_PROXY/HTTPS_PROXY 环境变量。必须在 config.json 中显式设置：

    {
      "proxy": "http://127.0.0.1:7890"
    }

OpenCodex 的 applyProxyEnv() 会在每次启动时把这个值注入到环境变量，无论通过哪种方式启动都能生效。

## 自动启动

OpenCodex 自带两种自启机制，优先使用原生方案：

1. **后台服务**：面板「启动安全」页点「安装」。登录时启动，崩溃后自动重启。
2. **Codex launcher shim**：面板「启动安全」页点「安装」。终端敲 codex 命令时自动检查并拉起代理。

不要手动加计划任务或注册表启动项 -- OpenCodex 原生机制已覆盖。

托盘图标只是控制器，不是重启保护。真正的崩溃恢复靠后台服务。

## 排障流程

按以下顺序排查：

    代理健康 --> 路由配置 --> 上游连通性 --> 认证状态 --> 请求参数

### 第一步：代理健康

    ocx health --json

不正常则看 service.log 尾部。

### 第二步：查看错误请求

    Get-Content ~/.opencodex/usage.jsonl -Tail 40 | Where-Object { $_ -match '"status":(4|5)' }
    ocx logs explain <requestId> --json

### 第三步：常见错误对照

| 错误码 | 可能原因 | 排查方向 |
|--------|---------|---------|
| 502 upstream_server_error | 上游不可达 | 检查 proxy 配置、网络连通性 |
| 400 invalid_request_error | 参数不兼容 | 检查 reasoning_effort、模型名是否正确 |
| 401 unauthorized | 认证失败 | 检查 API key 或 OAuth 状态 |
| 模型不出现在列表 | 模型 ID 过时 | 检查 selectedModels 是否为当前可用 ID |

### 502 connection reset 专项

如果 service.log 出现大量 connection reset：

1. 确认 config.json 中有 proxy 字段
2. 确认代理端口可用（如 curl -x http://127.0.0.1:7890 https://chatgpt.com）
3. ocx restart 后重试

### 400 reasoning_effort 专项

如果图片请求 400 但文本正常：

1. 确认模型是否支持当前 reasoning_effort 值
2. 检查是否有 modelReasoningEfforts 降级配置
3. 分别测试文本和图片场景（同一模型可能对不同内容类型有不同校验严格度）

## 验证清单

配置完成后逐项验证：

- [ ] ocx health 返回 ok:true
- [ ] ocx account list 显示所有账号 active
- [ ] 每个 provider 至少发一次测试请求（文本）
- [ ] 如果模型支持图片，发一次图片请求
- [ ] service.log 无持续错误
- [ ] usage.jsonl 最近请求均为 200
