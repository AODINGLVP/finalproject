# 行为树大图显示优化人工对比实验协议

## 1. 实验状态与目的

本文件定义可直接执行的受控实验，但截至 2026 年 8 月 9 日尚未招募参与者，也没有人工可用性结果。实验只用于比较显示方法对大规模行为树任务的影响，不把节点面积、可见节点数或自动综合分直接解释为人的可读性提升。

实验采用被试内设计，计划招募 8 至 15 名参与者。每名参与者使用全部六种方法完成三类任务，共 18 次正式试验。建议同时记录参与者的 Godot、行为树和节点编辑器经验，并将经验作为描述性分组变量，不在小样本中夸大推断。

## 2. 固定材料

| 项目 | 固定内容 |
| --- | --- |
| Godot | 4.6 stable，编辑器语言设为 English |
| 分辨率 | 1600×900，Windows 缩放保持一致 |
| 行为树 | `res://behavior_trees/human_study_tree_364.tres` |
| 定位目标 | Action `#363`，标题 `STUDY_TARGET_ACTION` |
| 编辑目标 | Decorator `#364`，标题 `STUDY_TARGET_DECORATOR` |
| 编辑内容 | 将 Blackboard 比较值从 `true` 改为 `false`，验证后恢复 |
| 固定运行链 | `Root > Decision Hub > Branch_005 > Branch_014 > Branch_041 > Branch_122 > STUDY_TARGET_ACTION` |
| 运行链 ID | `1 > 2 > 5 > 14 > 41 > 122 > 363` |

树文件由 `res://tests/generate_human_study_trees.gd` 确定性生成。正式实验前运行一次生成脚本并保留日志。Live Debug 任务使用 `res://tests/prepare_human_study_live_debug.gd` 每 0.25 秒刷新快照，避免编辑器的两秒过期规则导致状态消失。

## 3. 比较方法

| 方法 | 独立开关设置 | 其余设置 |
| --- | --- | --- |
| Baseline | 六项实验方法全部关闭 | Grid 和 Path Summary 可保持默认；禁止 Search |
| Compact | 仅 Compact 开启 | 其他实验方法关闭 |
| Collapse | 仅 Subtree Collapse 开启 | 从统一的预设折叠状态开始 |
| Fisheye | 仅 Fisheye 开启 | 鼠标从画布固定起点开始 |
| Search | 仅 Search 开启 | 搜索框起始为空 |
| Minimap | 仅 Enhanced Minimap 开启 | 小地图尺寸保持 230×150 |

每次试验前必须使用“重置清单”恢复相同树、相同窗口大小、相同初始缩放和平移、空搜索词、无选中目标、无残留折叠和无残留鱼眼缩放。方法之间只改变本行定义的独立开关。

## 4. 三类任务与成功条件

| 任务 | 给参与者的指令 | 成功条件 | 树规模 |
| --- | --- | --- | ---: |
| Locate Action | 找到并选中 `STUDY_TARGET_ACTION` | Inspector 显示 `Editing Node #363` | 364 |
| Trace Active Path | 写出或口述当前 RUNNING 节点链 | 七个标题及顺序完全正确 | 364 |
| Edit Decorator | 找到目标 Action 附带的 Decorator，并将比较值由 true 改为 false | Inspector 中值正确，未改动其他字段 | 364 |

计时从研究者读完指令并说“开始”时启动，到满足成功条件或达到 180 秒上限时停止。超时记为失败并保留 `180` 秒；参与者可主动放弃，记为失败并记录实际时间与原因。

## 5. 顺序控制

工作簿提供六个平衡序列，每个序列以不同方法开始，15 名参与者按编号循环分配。每名参与者依次完成三个任务区组，每个区组内使用所属序列的六种方法。为降低任务顺序偏差，参与者的任务区组按三种循环顺序分配：Locate→Trace→Edit、Trace→Edit→Locate、Edit→Locate→Trace。

正式试验前安排三次不计入数据的练习，每类任务一次，使用 121 节点练习树。练习阶段可以解释功能；进入正式试验后只允许重复任务文字，不能提示目标方向或操作步骤。

## 6. 记录字段

每次试验记录完成时间、错误次数、缩放次数、平移次数、成功与否、可读性 1–7、认知负担 1–7 和备注。一次错误包括选择错误节点、提交错误路径、修改错误字段或需要研究者纠正；探索性悬停不计错误。鼠标滚轮或缩放按钮的一次离散操作计一次缩放，连续拖动画布从按下到松开计一次平移。

可读性评分：1 表示“非常难读”，7 表示“非常容易读”。认知负担评分：1 表示“非常轻松”，7 表示“非常费力”。两项评分方向相反，分析时不得直接相加，除非先把认知负担反向编码并明确说明。

## 7. 排除和异常规则

参与者级排除仅适用于未完成知情说明、设备或项目在超过三次试验中发生故障、或参与者主动退出。试验级排除适用于编辑器崩溃、Live Debug 快照过期、研究者误操作或目标树不处于固定初始状态。正常的超时、错误和任务失败不是异常值，不应删除。

分析前冻结排除规则。若完成时间有效但任务失败，原始时间仍保留，成功率单独统计；主时间比较可同时报告“全部试验封顶时间”和“仅成功试验时间”，不得只选择更有利的口径。

## 8. 分析与报告

首先按方法和任务报告样本量、成功率、完成时间均值/中位数、错误、导航次数、可读性和认知负担。由于是被试内设计，正式推断优先使用重复测量方法；样本较小或分布明显偏斜时，可使用 Friedman 检验，并在显著后执行带多重比较校正的配对检验。报告效应量和置信区间，不只报告显著性。

毕业论文中必须分别呈现自动几何证据和人工任务证据。若参与者数据尚未采集，只能写“实验协议与数据模板已完成”，不能写某方法已经提升人的可读性或降低认知负担。

## 9. 执行命令

从仓库根目录生成固定树：

```powershell
.\Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path .\testgame\testgame --script res://tests/generate_human_study_trees.gd --log-file <absolute-log-path>
```

在正式 Live Debug 任务期间持续刷新 30 分钟；该进程可在实验结束后用 `Ctrl+C` 停止：

```powershell
.\Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path .\testgame\testgame --script res://tests/prepare_human_study_live_debug.gd -- --duration=1800
```

运行可复现 GPU 截图验证：

```powershell
.\Godot_v4.6-stable_win64_console.exe --rendering-method gl_compatibility --audio-driver Dummy --path .\testgame\testgame --script res://tests/run_human_study_visual_tests.gd --log-file <absolute-log-path>
```

## 10. 实验前检查清单

1. 确认树生成测试无失败，目标 ID、标题和父子关系正确。
2. 确认 Godot 编辑器为 English、窗口 1600×900、系统显示缩放未变化。
3. 确认只有当前实验方法的开关开启，并执行 Show All、Fit 和清空搜索。
4. Trace Active Path 任务开始前确认顶部显示 `StudyNPC`、`RUNNING` 和七节点路径。
5. 每次 Edit Decorator 后把值恢复为 `true`，重新载入资源确认无其他改动。
6. 在工作簿 Raw Data 当场录入，不删除失败或超时试验。
7. 发生崩溃、过期快照或错误初始状态时标记“试验级排除”并写明原因，再重新安排该试验。
