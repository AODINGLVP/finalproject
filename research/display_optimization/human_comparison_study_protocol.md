# 241 节点可玩行为树开发者可用性实验协议

## 1. 研究状态、问题与边界

本实验研究显示优化是否让游戏开发者更方便地理解、定位和编辑复杂行为树。正式研究问题为：在同一棵 241 节点、可实际驱动敌人的行为树上，Compact、Collapse、Fisheye、Search 和 Minimap 是否会影响开发任务的完成时间、成功率、错误、导航操作和主观体验？

截至 2026 年 8 月 22 日，实验材料、平衡方案、记录表和自动验证已实现，但尚未招募真人参与者。自动面积、节点数、重叠和切换耗时只能作为界面机制的辅助证据，不能代替真人可用性结果，也不能据此声称人的可读性已经提高。

## 2. 设计概览

| 项目 | 预先固定的设计 |
| --- | --- |
| 设计 | 六条件被试内重复测量 |
| 计划样本 | 12 名参与者；若退出则补招，但不超过 15 名 |
| 正式试验 | 每人 6 方法 × 3 任务 = 18 次；总计 216 次 |
| 正式树 | `res://behavior_trees/complex_display_tree_241.tres` |
| 树内容 | 巡逻、近战、远程、跳跃越障、攀爬、追击、搜索、恢复和守卫待机 |
| 树规模 | 241 个资源节点；202 张画布卡片；39 个附加 Decorator |
| 练习树 | `res://behavior_trees/human_study_tree_121.tres` |
| Godot | 4.6 stable，Compatibility renderer，编辑器语言 English |
| 显示环境 | 1600×900；同一设备、Windows 缩放和鼠标设置 |
| 单次上限 | 180 秒 |

参与者应至少具备基础游戏开发、Godot、行为树或节点编辑器经验之一。记录经验层级和相关年限，只作描述性分组；12 人的小样本不用于夸大经验差异的推断。

## 3. 显示条件

| 条件 | 唯一实验开关 | 统一设置 |
| --- | --- | --- |
| Baseline | 六项实验功能全部关闭 | Live Debug 的 Active Path 在 Trace 任务中统一开启 |
| Compact | 仅 Compact Mode 开启 | 其他实验功能关闭 |
| Collapse | 仅 Subtree Collapse / Focus 开启 | 从同一展开状态开始 |
| Fisheye | 仅 Fisheye 开启 | 指针从画布中央开始 |
| Search | 仅 Search 开启 | 搜索框初始为空 |
| Minimap | 仅 Enhanced Minimap 开启 | 小地图固定为 230×150 |

每次试验前执行 Show All、清空搜索、清除选择、恢复 100% 缩放和固定滚动位置，然后只开启当前条件。网格、节点数据和树布局在条件间保持不变。功能组合不用于主实验，以便识别各方法的独立作用。

## 4. 三类真实开发任务

| 任务 | 参与者指令 | 成功条件 | 主要指标 |
| --- | --- | --- | --- |
| Locate Action | 根据一条游戏行为需求找到并选中指定 Action | Inspector 的节点 ID 和标题与试验卡一致 | 封顶时间、成功率 |
| Trace Active Path | 根据 Live Debug 写出或口述从 Root 到 RUNNING Action 的完整链 | 七个节点标题及顺序完全正确 | 封顶时间、成功率 |
| Edit Decorator | 找到指定 Action 附加的 Decorator，并把 Duration 增加 0.10 秒 | Decorator、模式和新值正确，其他字段未变 | 封顶时间、成功率 |

次要行为指标为错误选择数、缩放次数、平移次数以及缩放与平移总数。每次试验后记录 1–7 可读性和 1–7 认知负担：可读性越高越好，认知负担越低越好，两者未经反向编码不得相加。

## 5. 六组匹配目标

定位和路径任务使用六条长度均为七个节点的真实决策链，终点分别属于越障、垂直追击、远程压制、中距离施压、最后位置搜索和巡逻。编辑任务使用六个附加在 Action 上的 Decorator，统一修改 `Duration + 0.10 s`。

所有 ID、标题、父链、初始值和目标值以 `res://tests/fixtures/human_study_241_targets.json` 为唯一事实源。`res://tests/run_human_study_material_tests.gd` 自动验证：

- 六个 Action 目标唯一、均为七节点深度，并与真实父子关系一致；
- 六个 Decorator 目标唯一、均附加在真实 Action 上；
- 初始 Duration 与资源一致，目标值统一增加 0.10 秒；
- 12 人的每个“方法×目标”组合恰好出现两次。

因此参与者不会在六种条件下反复寻找同一个目标，降低由记住目标位置导致的学习偏差。

## 6. 顺序与目标平衡

六个显示条件使用平衡顺序表；12 名参与者分别分配到六个顺序，每个顺序使用两次。三类任务使用三种循环区组顺序，每种使用四次。

对参与者索引 `p` 和方法索引 `m`，目标索引固定为 `(m + p) mod 6`。这样每位参与者在每类任务中看到六个不同目标，而跨 12 人后每种方法与每个目标恰好配对两次。工作簿的 Trial Plan 预生成全部 216 次试验，研究者不能在看过结果后更换目标或顺序。

正式试验前，每类任务各练习一次，共三次，不计入分析。练习使用 121 节点树，可以解释功能；进入正式试验后只能重复任务文字，不得提示方向、路径或控件。

## 7. 计时与计分

计时从研究者读完指令并说“开始”时启动，到满足成功条件、参与者主动放弃或达到 180 秒时停止。超时记 `Time=180`、`Success=No`；主动放弃保留实际时间并记失败。

一次错误包括选中错误节点、提交错误路径、修改错误 Decorator 或字段、或需要研究者纠正。探索性悬停不计错误。鼠标滚轮或缩放按钮的一次离散操作计一次 Zoom；连续拖动画布从按下到松开计一次 Pan。

主完成时间采用“所有非排除试验的 180 秒封顶时间”，失败不删除。仅成功试验时间作为敏感性分析，不能只报告更有利的口径。

## 8. 假设与判定原则

- H1：显示条件对封顶完成时间存在影响。
- H2：显示条件对成功率存在影响。
- H3：显示条件对错误和导航操作存在影响。
- H4：显示条件对可读性评分和认知负担评分存在影响。

Search 预期主要帮助 Locate，Collapse/Focus 和 Minimap 预期主要帮助 Trace，Compact 与 Fisheye 可能影响定位和编辑。上述方向在采集前固定，但任何不显著、反向或混合结果都必须如实报告。

只有在校正后的配对比较显示某优化相对 Baseline 改善至少一个预先指定的主要指标，且成功率没有恶化时，论文才可声称该优化在对应任务上提供了可用性证据。不得将“面积减少”“GPU 更快”或未校正的单个 `p` 值写成总体可用性提升。

## 9. 排除、伦理与数据管理

参与者先阅读说明并明确同意；只使用匿名编号，不在仓库中保存姓名、邮箱或其他身份信息。参与者可以随时退出。若学校要求伦理审批，应在招募前完成。

试验级排除只适用于编辑器崩溃、Live Debug 过期、错误初始状态或研究者计时/提示错误，并记录原因后重排。正常超时、失败、错误和放弃不是异常值。参与者级排除只适用于未同意、主动退出，或设备/项目故障影响超过三次试验。排除规则在查看方法差异前冻结。

## 10. 统计分析

每种“方法×任务”报告有效 `N`、成功率、封顶时间 Median [Q1, Q3]、错误 Median [Q1, Q3]、导航 Median [Q1, Q3]、可读性和认知负担。均值只能作为补充。

对每类任务分别分析：

1. 连续或有序指标使用 Friedman 重复测量检验；
2. 只有总体检验达到预设阈值时，才执行各优化与 Baseline 的配对 Wilcoxon signed-rank 检验；
3. 五个 Baseline 配对使用 Holm 校正，并报告配对效应量和置信区间；
4. 成功率先用 Cochran's Q，再在需要时做 Holm 校正的配对 McNemar 检验；
5. 同时报告全部封顶试验和仅成功试验的敏感性分析；
6. 报告缺失、排除、失败和超时数量，不只报告显著结果。

若有效完整配对不足 8 人，结果只作描述性报告。若数据尚未采集，只能写“实验装置与协议已验证，参与者结果待采集”。

## 11. 执行命令

从仓库根目录运行材料完整性测试：

```powershell
.\Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path .\testgame\testgame --script res://tests/run_human_study_material_tests.gd
```

为 Trace 任务持续刷新指定路径；`target` 可取 `obstacle`、`vertical`、`ranged`、`pressure`、`search` 或 `patrol`：

```powershell
.\Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path .\testgame\testgame --script res://tests/prepare_human_study_live_debug.gd -- --duration=1800 --target=ranged
```

运行真实 GPU 视觉验证：

```powershell
.\Godot_v4.6-stable_win64_console.exe --rendering-method gl_compatibility --audio-driver Dummy --path .\testgame\testgame --script res://tests/run_human_study_visual_tests.gd
```

重新生成记录工作簿并运行导入审计：

```powershell
node research/display_optimization/build_human_comparison_study_workbook.mjs
node research/display_optimization/audit_human_comparison_study_workbook.mjs
```

## 12. 每次试验重置清单

1. 按 Trial Plan 加载 241 节点正式树、方法、任务和目标。
2. 执行 Show All，清空 Search，清除选择，恢复固定 Zoom/Pan。
3. 只开启当前方法；Trace 任务统一开启 Active Path。
4. Trace 前用对应 `--target` 写入新快照，确认 `ArenaEnemy`、`RUNNING` 和 Depth 7。
5. Edit 后把 Duration 恢复为起始值并重新加载资源，确认没有保存其他修改。
6. 当场录入原始数据；失败和超时保留。
7. 若发生允许排除的故障，记录原因并重排，不覆盖原始行。
