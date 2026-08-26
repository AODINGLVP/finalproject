# 综述精简与近期文献扩充版论文构建说明

本目录中的构建器把 Markdown 当作唯一正文来源，不会从旧 DOCX 或 PDF 提取、补写或改写正文。

## 输入与输出

默认输入：

- `source/论文内容_中文.md`
- `source/dissertation_content_en.md`

默认输出到 `output/`：

- `行为树论文_中文_综述精简与近期文献扩充_2026-08-26.docx`
- `行为树论文_中文_综述精简与近期文献扩充_2026-08-26.pdf`
- `Behaviour_Tree_Dissertation_English_Literature_Review_Update_2026-08-26.pdf`
- `build_manifest.json`（记录正文、模板和成品的 SHA-256）

英文 Markdown 尚未建立时，构建器会正常生成中文 DOCX 和中文 PDF，并明确提示跳过英文 PDF。

## 使用方法

在仓库根目录运行完整构建：

```powershell
.\论文对比资料_2026-08-23\13_综述精简与近期文献扩充_2026-08-26\tools\build.ps1 -UpdateWordFields
```

`-UpdateWordFields` 会调用本机 Microsoft Word 更新目录、图目录和表目录。没有 Word 时可省略；生成文件已经设置为打开时自动更新域，也可以在 Word 中全选后按 `F9`。

正文尚未完成、只想检查中文 DOCX 与 LaTeX 中间文件时：

```powershell
.\论文对比资料_2026-08-23\13_综述精简与近期文献扩充_2026-08-26\tools\build.ps1 -SkipPdf
```

运行不保留成品的完整自测：

```powershell
.\论文对比资料_2026-08-23\13_综述精简与近期文献扩充_2026-08-26\tools\build.ps1 -SelfTest
```

只检查当前 Markdown 语法和必需元数据、完全不创建文档：

```powershell
.\论文对比资料_2026-08-23\13_综述精简与近期文献扩充_2026-08-26\tools\build.ps1 -ValidateOnly
```

## Markdown 约定

### 元数据

文件开头使用平面键值元数据。以下字段必须存在：

```yaml
---
title: 论文标题
author: [作者姓名]
student_number: [学号]
degree: 游戏工程理学硕士
institution: University of Warwick
department: WMG
submission: 2026年9月
language: zh
---
```

无需安装 PyYAML。构建器只读取这里使用的简单 `键: 值` 格式。

### 标题、段落与列表

- `# 致谢`、`# 声明`、`# 摘要` 会进入前置部分。
- `# 第1章　引言` 或 `# Chapter 1 Introduction` 会开始正文并重置阿拉伯页码。
- `## 1.1　研究背景` 等标题在 PDF 中由 LaTeX 自动编号；在 DOCX 中保留 Markdown 里的显式编号，便于作者直接修改。
- 支持普通段落、`-` 项目符号列表、`1.` 编号列表、引用段落和围栏代码块。
- 行内支持 `**粗体**`、`*斜体*`、反引号代码和 `[文字](链接)`。

### 表格

使用标准 Markdown 表格，并在紧随其后的单独一行写图例：

```markdown
| 条件 | 结果 |
| --- | ---: |
| 关闭 | 1 |
| 开启 | 2 |

表 3.1　关闭与开启结果
```

DOCX 保留写明的编号并嵌入 Word `SEQ Table` 域，以便生成表目录；PDF 使用模板自动编号。请勿在表格后另写重复图例。

### 图片与占位

图片路径相对于 Markdown 文件所在目录，也可以写仓库根目录下的路径：

```markdown
![图 4.1　插件架构](../figures/architecture.png)
```

当路径为空或文件尚不存在时，DOCX 和 PDF 都会生成带名称的灰色占位框，而不会悄悄删除图片或图例：

```markdown
![图 5.2　待生成的屏幕尺寸比较](../figures/screen_comparison.png)
```

### 参考文献

参考文献仍写在同一 Markdown 中，使用 `# 参考文献` / `# References` 标题。每条可写成编号列表或普通段落，DOI 使用可点击链接：

```markdown
1. Author (2026). Title. [https://doi.org/...](https://doi.org/...)
```

构建器不会改写引用内容或伪造缺失资料；作者–年份正文引用和文末条目都由 Markdown 决定。

## 模板和可复现性

- PDF 继续使用 `thesis_draft/chinese/uwthesis.sty`、Warwick 黑白校徽、`memoir` 11pt A4、左右 4 cm、上下 3 cm 和 1.5 倍行距。
- 中文 DOCX 使用相同页面边距和前置/正文分页，包含可更新的目录、图目录、表目录和页码域。
- PDF 由仓库中的 `.codex_tmp/tectonic-0.17.0/tectonic.exe` 构建。
- LaTeX 中间文件放在 `output/.build/`，它们是生成物，不是第二套正文来源。
- `build_manifest.json` 记录本次输入、模板和输出校验值，方便核对中英版本是否来自预期正文。

最终交付前仍应打开 DOCX 更新所有域，并逐页检查两份 PDF；自动构建只能确认结构可生成，不能替代内容和版面审阅。
