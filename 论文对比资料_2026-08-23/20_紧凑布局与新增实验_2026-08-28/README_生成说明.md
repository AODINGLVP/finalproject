# 生成说明

本版本以第19版中文源稿为基础，替换第五章为 2026-08-28 重新实验后的结果。新实验使用压紧后的五棵真实行为树布局，加入 Smart Drag 的其他节点移动数量与总移动距离统计，并加入 Overlay 的自然遮挡与受控遮挡说明。第五章前后对比图使用约 27 英寸屏幕配置，并只截取 GraphEdit 行为树编辑区域，不包含 Inspector。

主要文件：

- `source/用户修改原稿_执行系统版_2026-08-28.docx`：本版本使用的用户原稿检查点。
- `source/论文内容_中文.md`：本版本DOCX和PDF共同使用的正文来源。
- `source/用户修改差异.txt`：用户原稿与第17版生成稿之间的文字差异记录。
- `source/新版与用户原稿差异.txt`：新版与用户原稿的最终对照，只包含本次有意进行的直白化和编号调整。
- `source/论文内容_中文.md`：本版本 DOCX 和中文 PDF 的正文来源。
- `source/dissertation_content_en.md`：英文 PDF 的正文来源，第五章已同步新实验结果。
- `output/行为树论文_中文_紧凑布局与新增实验版_2026-08-28.docx`：可编辑中文版本。
- `output/行为树论文_中文_紧凑布局与新增实验版_2026-08-28.pdf`：中文论文模板 PDF 版本。
- `output/Behaviour_Tree_Dissertation_Tight_Layout_New_Experiments_2026-08-28.pdf`：给英文导师查看的英文 PDF 版本。
- `中文简洁版_章节说明_2026-08-28.md`：只列章节标题和每节大意的中文简介版。
- `research/display_optimization/five_feature_evaluation/data/2026-08-28_tight_layout_overlay_smart_2131924`：本版第五章使用的原始实验数据、分析表格和证据图。
- `引用核验与待确认事项.md`：引用检查结果和暂缓修改的结构事项。
- `tools/render_architecture_zh.py`：重新生成使用“执行系统”名称的图4.1。

生成DOCX和PDF：

```powershell
.\tools\build.ps1
```
