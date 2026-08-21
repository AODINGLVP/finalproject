# 241 节点复杂行为树显示优化测试方案

## 测试对象

- 固定资源：`res://behavior_trees/complex_display_tree_241.tres`
- 节点总数：241；其中 210 个画布卡片和 31 个附加 Decorator。
- 决策域：紧急恢复、近战、远程、追击、搜索、声音调查、小队协作、资源收集、巡逻。
- 节点类型覆盖：Root、Sequence、Selector、Random Selector、Parallel、Repeat、Action、Condition、Wait、Decorator。
- 固定生成器：`res://tests/generate_complex_display_tree.gd`。测试前重新生成，以排除人工布局差异。

## 自动量化实验

运行：

```powershell
./Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path ./testgame/testgame --script res://tests/generate_complex_display_tree.gd
./Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path ./testgame/testgame --script res://tests/run_complex_display_tree_tests.gd
./Godot_v4.6-stable_win64_console.exe --rendering-method gl_compatibility --audio-driver Dummy --path ./testgame/testgame --script res://tests/run_complex_display_benchmark.gd
```

第三条必须使用真实渲染方法。结果写入 `test_results/complex_display_optimization.csv`，比较：

| 模式 | 目的 | 主要指标 |
| --- | --- | --- |
| Baseline | 未启用压缩的参照 | 边界面积、卡片面积、重叠数 |
| Compact Cards | 测量卡片压缩 | 卡片面积减少率、信息字段数 |
| Optimized Overview | 紧凑卡片 + 语义缩放 | 总览面积、重叠数、切换耗时 |
| Optimized Search | 定位 `Execute Patrol and Idle` | 被弱化卡片数、切换耗时 |
| Subtree Focus | 只查看巡逻决策域 | 可见卡片比例、边界面积 |
| Context Collapse | 保留巡逻并折叠其他八个域 | 可见卡片比例、上下文保留量 |

从 CSV 计算相对提升：`(Baseline - Optimized) / Baseline * 100%`。面积减少、零重叠和切换耗时是客观几何/性能证据，不应直接表述为“可读性提高”。

## 人工对照实验

采用被试内设计，每位参与者分别使用 Baseline 与 Optimized Overview；顺序按 AB/BA 平衡。建议 8–15 人，先用非计分树练习。

每种模式完成三项任务：

1. 定位 Action `Execute Patrol and Idle`。
2. 从 `NPC Priority Selector` 追踪到 `Ranged Combat` 的 Assertive Action。
3. 找到巡逻分支上的 Decorator，并报告其模式与参数。

记录完成时间、错误选择数、缩放次数、平移次数、任务完成率、7 分制可读性和认知负荷。使用配对中位数及 Wilcoxon signed-rank 检验；同时报告效应量和参与者原始数量。没有真实参与者数据时，只报告自动几何结果，不生成或推断人工结果。

## 通过标准

- 资源测试全部通过，节点数固定为 241，十种节点类型均存在。
- 所有显示模式的卡片重叠数为 0。
- Compact Cards 的总卡片面积低于 Baseline。
- Search 至少弱化 95% 的非目标卡片。
- Focus 与 Collapse 均减少可见卡片，同时 Focus 保留完整巡逻子树。
- 任何 ERROR、SCRIPT ERROR、FAIL、崩溃或泄漏都判定为失败。
