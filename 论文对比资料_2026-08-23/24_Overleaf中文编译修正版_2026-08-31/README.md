# Overleaf 中文编译修正版

这个文件夹包含当前论文的中英文 LaTeX 工程，并针对 Overleaf 中文编译问题做了修正。

## 为什么要修正

原来的中文包使用：

```latex
\usepackage[UTF8,fontset=fandol]{ctex}
```

但你当前 Overleaf 环境报错：

```text
Critical Package ctex Error: CTeX fontset `fandol' is unavailable in current mode.
```

同时日志里还出现 `pdflatex`，说明 Overleaf 当前正在用 pdfLaTeX。中文论文需要 XeLaTeX 或 LuaLaTeX，否则很容易因为中文字体失败。

## 这版改了什么

中文 `main.tex` 改为：

```latex
\usepackage[UTF8,fontset=none]{ctex}
\setCJKmainfont{Noto Serif CJK SC}
\setCJKsansfont{Noto Sans CJK SC}
\setCJKmonofont{Noto Sans Mono CJK SC}
```

并且中英文工程都加入了 `.latexmkrc`，让 Overleaf 默认使用 XeLaTeX 编译。

## 上传方法

- 如果只编辑中文论文，上传 `中文论文_LaTeX_Overleaf_XeLaTeX修正版_2026-08-31.zip`。
- 如果只编辑英文论文，上传 `English_Dissertation_LaTeX_Overleaf_XeLaTeX_2026-08-31.zip`。
- 如果想同时备份中英文，上传 `中英文合集_LaTeX_Overleaf_XeLaTeX修正版_2026-08-31.zip`。

如果 Overleaf 仍然没有自动切到 XeLaTeX，可以点左上角 Overleaf 图标旁边或项目标题附近的下拉/设置入口，找到 Compiler，并手动选择 XeLaTeX。你截图里的界面确实没有传统的 `Menu` 按钮，这是新版界面差异。
