# 241 节点可玩行为树显示优化评价方案

## 1. 评价目的

项目的主要目标是让游戏开发者更方便地理解、定位和编辑复杂行为树，而不是降低运行时资源消耗。因此评价分成两个层级：

1. 客观装置实验确认显示方法确实改变画布密度、上下文范围和交互状态，并且不会产生卡片重叠或修改资源布局；
2. 真人开发任务实验比较完成时间、成功率、错误、导航操作、可读性和认知负担。

客观面积和切换计时是辅助证据，不能替代真人可用性结果。完整人工实验以 `human_comparison_study_protocol.md` 为准。

## 2. 固定测试对象

- 资源：`res://behavior_trees/complex_display_tree_241.tres`
- 资源节点：241
- 画布卡片：202
- 附加 Decorator：39
- 节点类型：Root、Sequence、Selector、Random Selector、Parallel、Repeat、Action、Condition、Wait、Decorator
- 游戏行为：恢复、闪避、方向近战、跳跃越障、攀爬、远程投射物、中距离施压、追击、最后位置搜索、返回、巡逻和待机
- 固定搜索目标：`Patrol Route Choice`
- 固定 Focus 目标：`11 Layered Patrol`
- 环境：Godot 4.6 stable、Compatibility renderer、1600×900、同一台 GPU

## 3. 客观装置实验

运行材料结构测试：

```powershell
.\Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path .\testgame\testgame --script res://tests/run_playable_complex_tree_tests.gd
.\Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path .\testgame\testgame --script res://tests/run_complex_display_tree_tests.gd
```

运行真实 GPU 重复实验：

```powershell
.\Godot_v4.6-stable_win64_console.exe --rendering-method gl_compatibility --audio-driver Dummy --path .\testgame\testgame --script res://tests/run_complex_display_experiment.gd
```

每个条件先预热 3 次，再正式测量 30 次。六个条件按轮次循环换序，30 轮中每个条件在六个顺序位置各出现 5 次。每次正式观测前恢复同一展开、缩放、搜索和 Focus 状态。

| 条件 | 机制检查 | 主要客观指标 |
| --- | --- | --- |
| Baseline | 完整卡片基准 | 卡片数、卡片面积、边界面积、重叠 |
| Compact Cards | 压缩卡片信息 | 卡片面积、字段数、重叠 |
| Optimized Overview | Compact + Semantic Zoom | 卡片面积、边界面积、重叠 |
| Optimized Search | 搜索 `Patrol Route Choice` | 被弱化卡片、目标隔离、重叠 |
| Subtree Focus | 聚焦 `11 Layered Patrol` | 可见卡片、保留子树、边界面积 |
| Context Collapse | 折叠其他优先级分支 | 可见卡片、上下文范围、重叠 |

原始观测写入 `res://test_results/complex_display_experiment_raw.csv`，统计摘要写入 `res://test_results/complex_display_experiment_summary.csv`。报告 Median、Q1、Q3 和 P95，不选择单次最好结果。

通过标准：

- 资源节点恰为 241，基准画布卡片恰为 202；
- 所有条件卡片重叠为 0；
- Compact 卡片面积至少减少 40%；
- Overview 卡片面积至少减少 70%；
- Search 弱化至少 95% 的非目标卡片；
- Focus 和 Collapse 可见卡片至少减少 70%；
- 所有条件结束后资源节点位置与开始时一致；
- 任意 ERROR、SCRIPT ERROR、FAIL、崩溃或泄漏均判失败。

## 4. 拖拽交互对照

拖拽只用于说明大图编辑交互是否卡顿，不评价运行时资源效率。使用同一节点、同一 240 步轨迹和同一 241 节点树比较优化前后版本，分别预热后测量 5 次，报告中位数和范围：

```powershell
.\Godot_v4.6-stable_win64_console.exe --rendering-method gl_compatibility --audio-driver Dummy --path .\testgame\testgame --script res://tests/run_drag_performance_benchmark.gd
```

结果文件为 `drag_performance_baseline.csv`、`drag_performance_optimized.csv` 和 `drag_performance_comparison.csv`。该对照只能说明固定拖拽路径的处理时间变化；是否被人感觉更流畅仍属于人工实验问题。

## 5. 真人开发者可用性实验

正式主实验采用 12 人六条件被试内设计，在同一棵可玩 241 节点树上完成：

1. 根据游戏行为需求定位 Action；
2. 根据 Live Debug 追踪七节点运行路径；
3. 找到 Action 的附加 Decorator 并修改 Duration。

六个方法为 Baseline、Compact、Collapse、Fisheye、Search 和 Minimap。六组真实目标覆盖跳跃、攀爬、远程、施压、搜索和巡逻；方法顺序、任务顺序以及“方法×目标”均预先平衡。记录封顶时间、成功率、错误、Zoom、Pan、可读性和认知负担。

- 完整协议：`human_comparison_study_protocol.md`
- 记录工作簿：`behavior_tree_human_comparison_study.xlsx`
- 统计脚本：`analyze_human_study_results.py`

没有真人观测时，只能报告“实验装置已实现和验证，参与者数据待采集”，不能声称显示方法已经提高人的可读性、降低认知负担或缩短任务时间。
