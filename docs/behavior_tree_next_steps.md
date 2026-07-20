# 行为树插件后续开发计划

## 1. 总体目标

接下来项目的重点不只是让敌人在测试场景中移动，而是把当前插件完善成一个更完整、更易用、可评价的 Godot 行为树编辑与运行系统。

后续开发应围绕三个方向推进：

- 完善行为树功能，使其支持更丰富的节点类型和更复杂的 NPC 决策。
- 改善编辑器体验，使大规模行为树更容易阅读、编辑和调试。
- 准备可用于毕业设计的评价内容，证明系统的功能性和改进价值。

## 2. 必须完成的核心功能

### 2.1 补全行为树节点类型

当前已有节点：

```text
Root
Sequence
Selector
Action
Condition
Decorator
```

后续应优先补充：

```text
Parallel
Random Selector
Random Sequence
Loop
Until Success
Until Failure
Wait
Cooldown
Succeeder
Failer
Inverter
```

其中最重要的是：

- `Parallel`：允许多个子节点同时运行，用于监听、持续检测、组合行为。
- `Random Selector`：从子节点中随机选择一个执行，增加行为变化。
- `Loop`：支持重复执行某个子树。
- `Wait`：支持等待一段时间，方便制作巡逻、攻击间隔等行为。

验收标准：

- 新节点能在编辑器中创建。
- 新节点能保存到 `.tres` 行为树资源。
- 运行时能正确执行新节点逻辑。
- 测试场景中至少有一个敌人行为使用新增节点。

### 2.2 完善黑板系统

当前黑板只是 `BehaviorTreeComponent` 中的 `Dictionary`：

```gdscript
@export var blackboard: Dictionary = {}
```

后续应升级为更接近 UE 的黑板系统：

- 新增 `BlackboardResource`。
- 支持定义黑板变量名称。
- 支持变量类型，例如 `bool`、`int`、`float`、`String`、`Vector2`、`NodePath`。
- 支持默认值。
- 行为树资源可以绑定一个黑板资源。
- 编辑器中提供黑板变量查看和编辑区域。

验收标准：

- 可以创建并保存黑板资源。
- 行为树可以引用黑板资源。
- Condition 和 Decorator 可以从黑板变量列表中选择 key。
- Live Debug 中可以查看运行时黑板值。

### 2.3 强化 Condition 和 Decorator

当前 Condition 和 Decorator 已经能读取黑板，但还比较基础。

后续应支持：

- `equals`
- `not_equals`
- `greater`
- `less`
- `greater_or_equal`
- `less_or_equal`
- `exists`
- `not_exists`
- `is_true`
- `is_false`

还可以增加常用装饰器：

- `Blackboard Decorator`
- `Cooldown Decorator`
- `Time Limit Decorator`
- `Inverter Decorator`
- `Repeat Decorator`

验收标准：

- 编辑器中能方便配置这些判断。
- 配置错误时能给出提示。
- 测试行为树能用这些条件实现更复杂决策。

## 3. 编辑器体验改进

### 3.1 节点折叠和展开

导师特别提到，可视化编程系统的一个问题是节点太多时难以阅读。因此需要支持节点折叠。

计划功能：

- 节点可以折叠自身内容，只显示标题和类型。
- 子树可以整体折叠，只显示一个父节点。
- 折叠后仍然保留连接关系。
- 可以一键展开全部或折叠全部。

验收标准：

- 超过 30 个节点的树仍然能较清楚地查看结构。
- 折叠状态可以保存。
- 折叠不会破坏运行时逻辑。

### 3.2 紧凑显示模式

当前节点信息较多，占用空间较大。

计划增加两种显示模式：

```text
Detailed Mode
Compact Mode
```

`Detailed Mode` 显示：

- 标题
- 类型
- 描述
- 参数
- 装饰器
- 运行时状态

`Compact Mode` 只显示：

- 标题
- 类型颜色
- 执行状态

验收标准：

- 用户可以在工具栏切换显示模式。
- 切换显示模式不会影响节点连接和保存。
- 大树在 Compact Mode 下更容易浏览。

### 3.3 鼠标悬停放大或聚焦显示

导师提出了类似 Mac Dock 的想法：鼠标靠近某个节点时，该节点或附近节点变大，显示更多信息。

可以实现为：

- 默认节点较小。
- 鼠标悬停时节点展开显示完整信息。
- 鼠标离开后恢复紧凑状态。
- 当前选中节点保持展开。

验收标准：

- 鼠标悬停能显示节点详细信息。
- 不影响拖拽和连线。
- 能作为项目的“编辑器创新点”进行说明。

### 3.4 更清楚的视觉编码

当前节点主要通过颜色区分类型。后续可以增加形状或图标。

建议：

- `Action` 使用矩形或绿色标识。
- `Condition` 使用菱形或红色标识。
- `Selector` 使用橙色。
- `Sequence` 使用蓝色。
- `Decorator` 使用紫色小标签。
- 当前执行节点使用明显高亮边框。

验收标准：

- 不看文字也能大致判断节点类型。
- Live Debug 状态清晰可见。
- 节点视觉风格统一。

## 4. 运行时系统改进

### 4.1 更可靠的 RUNNING 状态

当前运行时已经支持 `RUNNING`，但复杂节点增加后需要更严格处理。

需要检查：

- Sequence 记住当前正在执行的子节点。
- Selector 记住当前正在执行的子节点。
- Parallel 能同时维护多个子节点状态。
- 节点中断时能正确清理临时状态。

验收标准：

- 长时间动作不会每帧从头开始。
- 节点失败后能正确重置子树。
- 不会出现动作卡住或状态残留。

### 4.2 行为树组件 API 整理

需要让 `BehaviorTreeComponent` 更像一个可复用组件。

建议 API：

```gdscript
start_tree()
stop_tree()
restart_tree()
set_actor(actor)
set_blackboard_value(key, value)
get_blackboard_value(key)
clear_blackboard()
tick(delta)
```

验收标准：

- 外部脚本可以方便控制行为树。
- 组件可以挂到不同 NPC 上复用。
- 示例代码清晰。

### 4.3 调试信息增强

已有 Live Debug，需要继续完善：

- 显示当前 active path。
- 显示每个节点最近一次返回状态。
- 显示黑板变量值。
- 显示失败原因，例如某个 decorator 条件未满足。

验收标准：

- 运行时能快速看出 NPC 为什么选择某个行为。
- 行为树停止运行时状态能自动清除。
- 调试信息不会影响正常游戏画面。

## 5. 测试游戏改进

当前测试游戏只展示基础移动和攻击。后续需要让 Demo 更能证明行为树系统的能力。

建议增加：

- 敌人巡逻。
- 发现玩家后追击。
- 玩家进入范围后攻击。
- 玩家离开后返回巡逻。
- 敌人低血量时后退或逃跑。
- 攻击带冷却。
- 随机选择嘲讽、等待或巡逻方向。

可以设计 2-3 种敌人：

- `Patrol Enemy`：巡逻和攻击。
- `Guard Enemy`：守卫区域，玩家靠近后攻击。
- `Coward Enemy`：低血量逃跑。

验收标准：

- 每种敌人的行为都由行为树控制。
- 每种敌人使用不同节点组合。
- Demo 能清楚展示黑板、装饰器、选择器、序列、随机或并行节点。

## 6. 文档和毕业设计材料

需要准备以下文档：

- 插件实现说明。
- 行为树理论简介。
- 节点类型说明。
- 黑板系统说明。
- Live Debug 说明。
- 测试游戏说明。
- 系统评价说明。

目前已有：

```text
docs/behavior_tree_plugin_implementation.md
```

后续建议新增：

```text
docs/behavior_tree_node_reference.md
docs/blackboard_system_design.md
docs/live_debug_design.md
docs/evaluation_plan.md
```

## 7. 评价实验计划

导师强调系统需要评价。可以从以下角度评价：

### 7.1 功能完整性评价

统计系统支持的节点类型，并与基础行为树系统或 UE 行为树概念进行对比。

评价指标：

- 支持节点数量。
- 支持的决策模式。
- 是否支持黑板。
- 是否支持运行时调试。

### 7.2 编辑器可用性评价

比较改进前后编辑行为树的体验。

可测试任务：

- 创建一棵指定行为树所需时间。
- 在大树中找到某个节点所需时间。
- 理解当前执行路径所需时间。
- 修改某个条件所需步骤数。

### 7.3 可视化改进评价

如果实现折叠、紧凑模式或悬停放大，可以进行对比。

评价指标：

- 同屏可读节点数量。
- 用户主观清晰度评分。
- 查找节点耗时。
- 误操作次数。

### 7.4 运行性能评价

可以测试不同行为树规模下的执行时间。

测试规模：

```text
10 nodes
50 nodes
100 nodes
200 nodes
```

评价指标：

- 每帧 tick 时间。
- 内存占用。
- 多 NPC 同时运行时的性能。

## 8. 推荐开发顺序

建议按照以下顺序推进：

1. 修稳定现有功能。
2. 补 `Parallel`、`Random Selector`、`Loop`、`Wait`。
3. 完善 Condition 和 Decorator。
4. 做独立 `BlackboardResource`。
5. 改进测试游戏敌人行为。
6. 增强 Live Debug，显示失败原因和黑板值。
7. 做节点折叠和紧凑模式。
8. 尝试悬停放大或聚焦显示。
9. 写节点说明文档和黑板说明文档。
10. 做评价实验和毕业设计总结。

## 9. 当前最优先任务

短期内最应该完成：

- 增加 `Parallel` 节点。
- 增加 `Random Selector` 节点。
- 增加 `Loop` 和 `Wait` 节点。
- 做一个更完整的敌人行为树 Demo。
- 让 Live Debug 更稳定，并显示黑板值和失败原因。
- 做节点折叠或紧凑显示，作为编辑器改进亮点。

这些任务完成后，项目就不只是一个基础 Demo，而是一个较完整、有展示价值、也能回应导师要求的行为树编辑器系统。
