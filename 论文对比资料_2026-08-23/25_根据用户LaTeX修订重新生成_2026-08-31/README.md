# 根据用户 LaTeX 修订重新生成的 Overleaf 包

本文件夹以用户提供的中文 `main.tex` 为准重新生成。

- 中文正文：使用用户提供的中文 LaTeX 内容，并保留 XeLaTeX / Noto CJK 配置。
- 英文正文：只同步用户修订或之前中文包遗漏的内容，并按中文意思对应翻译。没有主动删减或改写未修改部分。
- 中英文工程均包含 `.latexmkrc`，用于让 Overleaf 使用 XeLaTeX。

建议上传单独中文包或英文包到 Overleaf；如果上传合集包，需要手动选择 `zh/main.tex` 或 `en/main.tex` 作为主文件。
