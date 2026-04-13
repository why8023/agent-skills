---
name: docling-word
description: 使用 Docling CLI 解析 `.docx` Word 文件并导出 Markdown，同时把提取出的图片等附件统一整理到 Markdown 同级的 `attachments/` 目录。用于用户要求用 Docling 转 Word、要求通过 `uv tool install` 安装 Docling、或要求修正 Docling 附件路径与目录结构时。
---

# Docling Word

使用 Docling 处理 `.docx` 时，优先走这个 skill 自带脚本，而不是直接调用裸 `docling` 命令。这样可以统一安装方式、附件目录规则和 Markdown 里的图片引用。

## Workflow

1. 只把 `.docx` 作为直接输入。
   如果用户给的是旧版 `.doc`，先提示另存为 `.docx` 再继续。
2. 先确认 `uv` 可用，再检查 `docling` CLI 是否已经安装。
   缺失时使用 `uv tool install docling` 安装，不要改用 `pip`、`conda` 或项目虚拟环境安装。
3. 优先使用 `scripts/docling_word_to_markdown.py` 执行转换。
   这个脚本会调用 `docling --from docx --to md --image-export-mode referenced`，再把附件整理到固定的 `attachments/` 目录。
4. 让 Markdown 输出路径显式可控。
   如果用户已经有目标 Markdown 文件路径，就把它传给脚本；附件目录始终按该 Markdown 文件所在目录来决定。
5. 保持附件目录稳定。
   如果 Markdown 同级已经存在 `attachments/`，直接把新附件加入进去，不要清空旧内容。
   如果不存在，就在该 Markdown 文件同级创建 `attachments/`。
6. 转换完成后，检查 Markdown 中的图片链接是否都指向相对路径 `attachments/<filename>`，不要保留 Docling 默认的绝对路径。

## Preferred Command

在目标项目根目录运行：

```bash
python /path/to/skills/docling-word/scripts/docling_word_to_markdown.py input.docx --markdown-path output.docling.md
```

如果当前 agent 已经把 skill 安装到项目中，直接使用 skill 目录里的同名脚本即可。

## Output Rules

- Markdown 文件路径由 `--markdown-path` 决定。
- 附件目录固定为 `Markdown 所在目录/attachments/`。
- 已存在的 `attachments/` 目录只追加内容，不做删除。
- 新增附件若与已有文件重名且内容不同，脚本会自动改名，避免覆盖旧文件。
- Markdown 里的附件引用统一写成相对路径，并使用正斜杠。

## Troubleshooting

- 如果 `uv tool install docling` 失败，先把错误原样告诉用户，再说明是安装问题而不是解析逻辑问题。
- 如果 `docling` 转换成功但没有生成 Markdown，先检查输入是否真的是 `.docx`，再检查 Docling CLI 返回日志。
- 如果图片仍然是绝对路径，说明没有走 skill 自带脚本，重新用 `scripts/docling_word_to_markdown.py` 执行一次。
