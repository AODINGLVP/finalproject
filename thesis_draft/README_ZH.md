# 行为树毕业论文双语初稿

本目录基于 `University_of_Warwick_Thesis_Template__2024___1_.zip` 建立，并按照 MSc Games Engineering Dissertation Workshop 的要求组织为：Abstract、Introduction、Literature Review、Research Methodology、Method、Results and Analysis、Discussion、Conclusions 和 Appendices。

## 交付内容

- `english/uwthesis.tex`：英文主稿入口，约 9,025 词，低于 15,000 词上限。
- `chinese/uwthesis.tex`：与英文版章节、研究问题、图表和结论对应的中文稿。
- `english/uwthesis.pdf`、`chinese/uwthesis.pdf`：编译预览。
- `CHAPTER_ALIGNMENT.md`：中英章节对照表。
- `build_all.ps1`：使用便携 Tectonic 编译两版。

## 提交前必须修改

1. 替换 `[AUTHOR NAME]` / `[作者姓名]`、`[STUDENT NUMBER]` / `[学号]`。
2. 根据学校规定修改 Declaration，并如实填写生成式 AI 使用情况。
3. 在 Tabula 核对实际截止日期和最终词数计算规则。
4. 正式人体实验尚未实施。不能把协议和 270 行空白实验模板写成真实参与者结果。
5. 请导师确认研究问题、伦理流程和是否需要进一步扩大文献综述。

## 编译

从仓库根目录运行：

```powershell
.\thesis_draft\build_all.ps1
```

构建脚本会在 `.codex_tmp/tectonic-0.17.0/` 查找便携 Tectonic。若不存在，需要先安装 Tectonic 或修改脚本中的路径。

模板原版默认使用 `euler-math`，便携 Tectonic 的 bundle 不包含该包，因此论文副本改用同样规范的 `unicode-math` 和 `latinmodern-math.otf`。文献表使用 `natbib` 加内嵌作者--年份书目，以避免额外依赖 `biber.exe`。原始模板 ZIP 没有被修改。
