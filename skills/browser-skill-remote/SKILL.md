---
name: browser-skill-remote
description: 发现、核对和调用已配置的 BrowserSkill 原生远程浏览器连接。用户要求操作远程电脑或公司 Win10 的浏览器、确认远程连接状态、配置配对或排查连接故障时使用。在 Windows 控制端执行；网页交互沿用 browser-skill。
---

# browser-skill-remote

通过控制端的 bsk CLI 操作远端 Chromium 扩展。复用现有服务与配对授权；安装本 Skill 只提供代码和流程，在线状态需要实时查询。

## 发现连接

先确认当前 Agent 位于已经配置的 Windows 控制端，并使用 PowerShell 7。配置默认位于当前用户的 `.bsk/browser-skill-remote.json`；自定义位置通过当前调用进程的 `BSK_REMOTE_CONFIG` 指定。配置中的 `ControllerMachine` 必须匹配当前机器。

相对于本 Skill 的实际安装目录定位脚本，不根据工作目录猜测路径：

```powershell
$remote = Join-Path '<本 Skill 的实际安装目录>' 'scripts/Invoke-BrowserSkillRemote.ps1'
$connection = (& $remote discover) | ConvertFrom-Json
```

`discover` 查询专用 daemon 和授权设备列表，将配置中的 `ExpectedDeviceId` 映射到当前在线的 `browser_id`，检查浏览器类型、授权有效期、协议及响应状态。返回值包括 `ready`、`target`、`browser_id`、`device_id`、`active_sessions`。目标必须与用户指定的机器相符。

发现失败时报告具体错误。缺少本机配置、服务不可达、配对失效和浏览器离线分别处理；不要选择其他已连接浏览器，也不要切换到本机默认 bsk 实例。

## 使用连接

读取已安装的官方 `browser-skill`，遵循其页面观察、标签页借用和会话清理流程。这里的 `$remote` 替代其示例中的 `bsk`，每次创建会话都传入当次发现的目标 ID：

```powershell
$session = (& $remote session start --browser $connection.browser_id --no-focus --json) | ConvertFrom-Json
try {
    # 按用户任务导航、观察和操作，每条页面命令都传 --session。
    & $remote observe --session $session.session_id
} finally {
    & $remote session stop $session.session_id
}
```

需要展示浏览器时省略 `--no-focus`。新建会话只在 Agent Window 中工作；操作用户已有标签页前遵循官方 Skill 的显式借用流程。设备标识绑定已经确认的机器和浏览器配置文件，重新配对或扩展存储重置后重新确认映射，再更新本机配置。

其他 bsk 命令也通过同一入口调用，例如 `& $remote status --json`、`& $remote session list --json`。`BSK_HOME` 和 `BSK_AUTO_START=0` 由入口在每次调用期间设置，结束时恢复调用者环境。

## 配置与维护

安装、配对、计划任务迁移、更新或连接故障时读取 [配置与维护](references/setup.md)。运行配置、日志和配对授权放在 Skill 外部；维护源码和脚本走中央仓库及已登记的 APM 流程，不能手改受管安装目录。

普通浏览器任务只使用现有服务。服务维护沿用其计划任务或其他已有管理器，不重启共享 daemon，不删除授权目录，不自动重新配对。计划任务使用本 Skill 已安装的 `scripts/start-server.ps1`；更新 Skill 本身不会主动重启服务。

原生远程连接要求 bsk/扩展 0.3.2 或兼容版本、协议 1.3 或更高。文件上传和下载在 0.3.2 的远程模式中不受支持。对网站登录、验证码等步骤按官方 Skill 的人类协助流程处理。
