# 生成说明

本版本保留用户修改后的DOCX作为不可覆盖的检查点，并把其中的前置部分及前三章整理为新的Markdown正文。第4章以后沿用第15版内容。

主要文件：

- `source/用户修改原稿_前三章_2026-08-28.docx`：用户原稿检查点。
- `source/论文内容_中文.md`：本版本DOCX和PDF共同使用的正文来源。
- `source/用户修订提取记录.json`：输入文件校验值和本次非结构性修正记录。
- `output/行为树论文_中文_用户前三章修订_引用复核版_2026-08-28.docx`：可编辑版本。
- `output/行为树论文_中文_用户前三章修订_引用复核版_2026-08-28.pdf`：论文模板PDF版本。
- `引用核验与待确认事项.md`：引用检查结果和暂缓修改的结构事项。

重新生成正文来源：

```powershell
python .\tools\prepare_user_revision.py
```

生成DOCX和PDF：

```powershell
.\tools\build.ps1
```

