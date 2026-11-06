# 中央 Skills 维护进展

## 当前状态

2026-11-06：`wiki-application` 已发布，并以 `54cdf49036d9ad744c4a202060872e9d7c8bcbaa` 固定版本通过个人 APM 安装到本机 Codex、Claude Code、OpenCode。结构、三项独立离线情景与安装核验通过，无未完成安装。

## 2026-11-06：通用 Wiki 申请填报

- 目标：复用新建或更新申请的流程，适配实际栏目，避免绑定某个业务、页面或统计周期。
- 工作：[主流程](../skills/wiki-application/SKILL.md)覆盖授权分流、最新人工编辑、证据口径、重点表达、截图、备份、版本冲突及发布后核验；[Confluence 参考](../skills/wiki-application/references/confluence.md)处理 storage、嵌套表格、附件和结果不明；[离线情景](../skills/wiki-application/evals/evals.json)覆盖草稿、已有授权更新和异常情况。
- 验证：`quick_validate.py` 通过；`npx skills add <local-repo> --list` 可发现该 Skill；元数据、相对引用和隐私标识检查通过。三项独立离线情景覆盖仅草稿、保留新版人工文字并按已有授权更新，以及并发版本/不完整历史/截图失败/上传不明。候选 storage 的嵌套表格和非目标字段逐字保留。测试仅用虚构材料，未向真实 Wiki 写入；模拟响应不作为真实发布、附件或图像加载证据。
- 设计决定：复用专用连接器与浏览器 Skills，不新增浏览器协议、上传服务或生产查询脚本；区分产品支持、实际配置和实测效果。业务私密材料不进入本仓库。
- 复核改进：远程入口适配当前环境和机器规则；多图替换先确认语义映射，不默认替换全页。
- 安装核验：APM `restore` / `check` 通过，受管清单从 53 项增至 54 项；原有文件与联接快照一致，无 pending 激活。新 Skill 的四个文件在三套安装目录均与源码 SHA-256 相同；Codex 全局 Skill 发现可见。个人清单在修改前后均已用 chezmoi 留存本地版本。
- 当前状态：已完成，无阻塞。后续遇到真实新申请时调用本 Skill；此次没有用新 Skill 操作真实 Wiki，也未验证其他机器的安装。
