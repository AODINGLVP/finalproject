# 下次导师汇报辅助文档

## 一、30秒项目说明

本项目实现了Godot 4.6中的完整基础可视化行为树插件，包含图形化建模、`.tres`资源保存、运行时执行、Actor方法调用、类型化Blackboard、Decorator和编辑器内Live Debug。研究重点不是复刻UE全部功能，而是针对50节点以上行为树的可读性和调试效率，提供可独立开关的显示优化，并用固定树、GPU截图和性能数据进行验证。

## 二、会议要求与完成对应

| 导师要求 | 当前证据 |
| --- | --- |
| 先完成基本行为树 | Root、Sequence、Selector、Random Selector、Parallel、Repeat、Action、Condition、Wait、Decorator全部可编辑、保存和运行 |
| 支持循环、随机、并行和真实决策 | 复杂守卫树实际使用Repeat、Random Selector、Parallel、Wait、Blackboard和多种Decorator |
| 不把重点放在角色美术 | 示例使用基础2D形状，开发与报告集中在编辑器、运行时和评价 |
| 与UE形成有意义差异 | Fisheye、Collapse/Focus、Semantic Zoom、Search、Minimap、路径摘要、无障碍形状编码等19个独立开关 |
| 解决50节点以上可读性 | 固定31、121、364节点树，提供结构缩减、信息缩减、定位和上下文保持工具 |
| 研究Mac Dock式方法 | Fisheye以鼠标位置局部放大，关闭后完整复位，GPU视觉测试覆盖 |
| 量化优化效果 | 显示CSV/工作簿、16张核心GPU截图、270次人体实验模板、126行运行时性能数据 |
| 复杂NPC证明真运行 | 三个敌人，复杂NPC覆盖索敌、追击、左右攻击、搜索、撤退、治疗、巡逻和环境交互 |

## 三、本轮新增成果

1. 专用Blackboard Schema Editor：类型化增删改、默认值、说明、动态键策略、即时错误、撤销重做和保存重载。
2. 形状/图标类型编码：低缩放和灰度下不只依赖颜色；配套色盲安全配色与Ctrl+F/F3键盘导航。
3. 单连接显示：消除GraphEdit细黑辅助线，保留端口拖拽、右键命中、断开和Undo/Redo，并可独立切回原生模式。
4. Runner拓扑缓存：不缓存行为结果，只索引节点、子节点和Decorator；可独立关闭，树替换自动失效。
5. Blackboard引用辅助：Inspector可选Schema键也可自由输入，严格模式检查空/未知引用，摘要能列出引用节点与未使用声明。
6. 安全拓扑缓存：精确签名覆盖顺序、父级、Decorator归属和节点实例，同数量原地修改也能失效。
7. 可分发0.9.0插件：MIT许可证、README、SHA-256清单、ZIP边界检查和空项目安装启动53/53通过。
8. 可复现实验证据：最终CSV、公式工作簿、21张固定GPU截图、复现命令和严格日志索引。

## 四、量化结果怎么讲

最终核心回归是447/447：运行时153、编辑器185、基础游戏13、复杂竞技场26、GPU视觉70。另有21/21人工实验视觉准备、511/511性能断言和53/53发布包验证。

显示优化的自动指标：364节点树中Compact卡片总面积降低55.9%，Semantic信息字段从6降到1，Search淡化363/364非目标节点，Subtree Focus可见节点从364降到9，Collapse降到2，Fisheye目标节点1.20倍，Enhanced Minimap覆盖364/364节点。强调这些证明的是几何和程序效果，不等于已经证明人类可读性。

运行时缓存最终中位数收益：31节点15.98%–26.46%，121节点52.61%–56.02%，364节点76.65%–78.00%，在1/10/50 NPC下九个场景全部为正。精确拓扑校验牺牲了一部分小树收益，换来同数量换序/改父级等变化不会复用错误索引；应说明这是当前Windows/Godot 4.6固定负载结果，不是跨机器常数。

## 五、建议现场演示路线（约6分钟）

1. 打开`complex_guard_validation_tree.tres`，展示上下端口、从左到右顺序和Decorator Badge。
2. 打开`Edit Schema`，添加一个键、制造重复键错误、Undo恢复；再选中Blackboard Decorator，用Schema下拉选择`target_in_range [Bool]`并展示引用/未使用摘要。
3. 加载364节点树，依次展示Fit、Semantic Zoom、Shape Encoding、Accessibility、Search和Fisheye。
4. 展示单连接线，右键断开后Undo恢复，说明视觉优化没有破坏编辑能力。
5. 运行`test_game.tscn`，接近EnemyB观察Patrol→Chase→Attack；按C观察Search；低血量观察Retreat/Heal。
6. 回到编辑器，展示七节点Runtime Path、当前Action、Dim Inactive、Failure Reasons和Live Blackboard。
7. 打开`behavior_tree_unattended_run_evidence.xlsx`首页与Runtime Summary，再展示`dist/behavior-tree-editor-0.9.0.zip`和53/53空项目安装结果。

## 六、导师可能提问与回答

**为什么不做Service节点？** 当前会议目标是完整基本行为树和可验证创新，不是复制UE全部功能。Service会扩大运行调度和编辑语义范围，当前被明确列为范围外，除非导师调整要求。

**为什么说显示优化有效？** 可以说自动几何、定位、恢复和GPU渲染均验证有效；不能说已经证明人的认知负担下降。15人×18次、共270次试验的平衡模板已经准备，但真实参与者尚未采集。

**缓存会不会改变AI？** 缓存只保存拓扑索引，不保存Action/Condition结果或Blackboard值。153项运行时语义测试在优化后全部通过，缓存开/关所有性能样本返回相同SUCCESS；整树替换和四类同数量原地变化都有失效测试。

**与UE相比创新在哪里？** 不主张整体超越UE；创新点是Godot内的一组可组合、可关闭、可量化的大树Focus+Context显示方法，以及编辑器内运行路径、失败原因、Schema值和轻量拓扑缓存的完整闭环。

**为什么要19个开关？** 每项方法独立是为了隔离崩溃与视觉残留，也便于对照实验。测试会逐项启停，并验证组合关闭后恢复基线。

## 七、应主动说明的限制

- 人体实验未实施，不得填写或暗示已有参与者结果。
- 当前性能数字来自单台机器和构造负载，只能报告区间、环境和原始数据。
- 可安装ZIP已完成，但Asset Library页面/图标与跨Godot版本兼容矩阵尚未完成。
- Service节点不在当前毕业设计范围。

## 八、会后建议任务

1. 根据导师意见决定是否正式招募8–15名参与者，完成270次受控试验并做统计分析。
2. 冻结毕业提交范围，制作3–5分钟无剪辑演示录像与论文图表。
3. 若要求公开发布，在现有0.9.0安装包基础上补Asset Library页面、正式图标和多版本兼容矩阵。
4. 若导师更重视运行时创新，可在现有拓扑缓存上继续测内存分配和真实复杂NPC帧预算，而不是增加Service节点。

## 九、汇报材料索引

- 使用手册：`docs/USER_GUIDE_ZH.md`
- 技术文档：`docs/TECHNICAL_DOCUMENTATION_ZH.md`
- 完整验收说明：`docs/behavior_tree_validation_and_display_evaluation.md`
- 可复现实验工作簿：`research/display_optimization/behavior_tree_unattended_run_evidence.xlsx`
- 人体实验模板：`research/display_optimization/behavior_tree_human_comparison_study.xlsx`
- 最终日志：`testgame/testgame/test_results/final_unattended_regression/`
