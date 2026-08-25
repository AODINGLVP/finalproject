# Godot 4.6 可视化行为树插件功能说明

版本：0.9.0（当前工作区版本）  
活动项目：`testgame/testgame`  
分发模板：`visual_scripting/addons/behavior_tree_editor`

## 1. 项目定位

本项目是在 Godot 4.6 编辑器中运行的可视化行为树插件，同时包含可挂载到 2D NPC 的运行时组件。用户可以用节点图创建、连接、配置和保存行为树，并在游戏运行时只通过 Godot 编辑器查看当前活动路径、失败原因和 Blackboard 数据。插件不会在游戏画面中叠加行为树调试 UI。

项目的主要研究方向是大型行为树的可读性优化，而不是完整复刻 Unreal Engine。Service 节点不在当前范围内。

## 2. 安装与打开

1. 将 `addons/behavior_tree_editor` 放入 Godot 项目目录。
2. 打开 `Project > Project Settings > Plugins`。
3. 启用 `Behavior Tree Editor`。
4. 打开编辑器底部的 `Behavior Tree` 面板。

可直接使用仓库中的 `dist/behavior-tree-editor-0.9.0.zip`。插件界面使用英文，本文档使用中文解释界面和功能。

## 3. 行为树资源管理

| 功能 | 说明 |
| --- | --- |
| New Tree | 创建空行为树资源。每棵树必须有且只有一个 Root。 |
| Save Tree | 将树保存为 `.tres`，保存前执行结构、Decorator 和 Blackboard 校验。 |
| Load Tree | 从资源选择器或路径加载现有 `.tres`。 |
| Tree Picker | 列出项目中的行为树资源，减少手动输入完整路径。 |
| Deep Copy History | Undo/Redo 使用树资源深拷贝，覆盖节点、参数和 Blackboard Schema。 |
| Structural Validation | 检查重复 ID、Root、断开节点、缺失父节点、循环、叶节点子节点、不可达节点和 Decorator 归属。 |

## 4. 可视化编辑功能

### 4.1 创建和编辑节点

- 左侧 `Node Palette` 支持单击创建和拖拽到画布创建；列表高度不足时可以垂直滚动。
- 画布空白处右键可以在鼠标位置创建任意节点。
- 节点右键菜单支持断开父节点、删除、启用/禁用、折叠/展开和自动排布。
- 可以选择父节点后使用 `Add Child`，也可以手动连线。
- 节点卡片可以拖动，位置写回行为树资源；拖动支持 Undo/Redo。
- 右侧 `Node Inspector` 可以编辑标题、类型、说明和类型化参数。
- `Advanced JSON` 保留给自定义参数和兼容性需求，常用参数不需要手写 JSON。

### 4.2 连线规则

- 从父节点**底部方块**拖到子节点**顶部方块**后松开。
- 连线事件由整个 GraphEdit 画布捕获，鼠标离开起点节点后仍可完成连接。
- 预览线、目标命中和永久连线共用实际渲染端口坐标，缩放或滚动后不会使用旧的手算偏移。
- 右键单击连接线可以断开，断开操作支持 Undo/Redo。
- Root 只能有一个直接子节点；Repeat 和结构型 Decorator 只能有一个子节点。
- Action、Condition 和 Wait 是叶节点，不能连接下层节点。
- 系统拒绝自连接、循环连接、非法 Decorator 连接和超出子节点数量限制的连接。

### 4.3 执行顺序

同一个父节点的普通子节点按画布横坐标从左到右排序；横坐标相同时再按纵坐标排序。因此 Sequence、Selector、Random Selector 的候选列表和其他有序组合节点保持明确的左到右顺序。

## 5. 节点功能

| 节点 | 子节点限制 | 运行语义与参数 |
| --- | ---: | --- |
| Root | 1 | 行为树唯一入口，执行其直接子节点；空 Root 有确定结果。 |
| Sequence | 多个 | 从左到右执行；遇到 FAILURE 立即失败，遇到 RUNNING 记住当前位置，全部成功才返回 SUCCESS。 |
| Selector | 多个 | 从左到右尝试；遇到 SUCCESS 立即成功。`Reactive` 开启时每 Tick 重新检查高优先级分支并可抢占低优先级 RUNNING 分支。 |
| Random Selector | 多个 | 随机排列候选并依次尝试；RUNNING 期间保持同一顺序。`Seed=-1` 为随机，固定 Seed 可复现实验。 |
| Parallel | 多个 | 每 Tick 执行所有未完成子节点。`Success Policy` 和 `Failure Policy` 分别支持 `all` 或 `any`。终止时清理运行记忆。 |
| Repeat | 1 | `Repeat Count` 指定次数；`-1` 表示无限重复。子节点失败时向上传播 FAILURE。 |
| Action | 0 | 调用 Actor 的 `action_name` 方法，可返回 SUCCESS、FAILURE、RUNNING 或布尔值。 |
| Condition | 0 | 可以调用 Actor 的 `condition_name`，也可以读取 Blackboard 并执行比较。 |
| Wait | 0 | 按 `Duration` 累积 Tick 的 `delta`；到时成功，重启树时清除已等待时间。 |
| Decorator | 结构模式为 1；附着模式不占主图 | 既可以作为结构节点包裹一个子节点，也可以附着在普通节点上，在执行所有者前后改变条件或结果。 |

## 6. Decorator 功能

| 模式 | 功能 |
| --- | --- |
| Blackboard | 用 Blackboard 键和值决定是否允许所有者执行，可设置 `Invert`。 |
| Cooldown | 首次允许执行，随后在设定秒数内阻止重复执行。 |
| Time Limit | 子节点 RUNNING 超过设定时间后终止并返回 FAILURE。 |
| Invert | 将 SUCCESS 与 FAILURE 互换，RUNNING 保持不变。 |
| Force Success | 将所有者的终止结果转换为 SUCCESS。 |
| Force Failure | 将所有者的终止结果转换为 FAILURE。 |
| Repeat Forever | 结构型 Decorator，持续重复唯一子节点并保持 RUNNING。 |

右键菜单可快速附着 Blackboard、Cooldown 和 Time Limit Decorator。附着 Decorator 显示为所有者卡片中的条件徽章，不作为普通独立节点参与主图连线。

## 7. Blackboard 与 Schema

### 7.1 Blackboard 数据

每个 BehaviorTreeComponent 拥有运行时 `Dictionary` Blackboard。Action、Condition 和 Decorator 共享该字典，可读写目标、距离、生命值、冷却标记和最后已知位置等状态。

Blackboard 比较操作包括：`exists`、`not_exists`、`is_true`、`is_false`、`equals`、`not_equals`、`>`、`<`、`>=` 和 `<=`。

### 7.2 Blackboard Schema

- Schema 可声明 Bool、Int、Float、String 和 Vector2 类型键。
- 每个键包含名称、类型、默认值和说明，并随 `.tres` 行为树保存。
- Runner 初始化时应用默认值，但不会覆盖已有 Blackboard 值。
- `Allow Dynamic Keys` 控制是否允许运行时创建未声明键。
- 严格模式会检查节点引用的键是否声明，并报告空引用、重复键和类型错误。
- Inspector 的键选择器显示 `key [Type]`，同时保留自由输入以兼容动态键。
- Schema 摘要显示引用位置和未使用键，便于查找拼写错误或冗余声明。

### 7.3 Live Blackboard

Godot 编辑器中的 `Blackboard` 面板显示当前 Actor、键、运行类型、值和 Schema 状态。该面板与 `Edit Schema` 声明编辑器相互独立，停止 Live Debug 时会清除旧运行值。

## 8. Actor 与运行时组件

在 NPC 节点下添加 `BehaviorTreeComponent`，并给 `behavior_tree` 属性指定 `.tres`。组件是 NPC 子节点时，`actor_path` 可以为空；否则将其指向拥有行为方法的 Actor。

```gdscript
func chase_target(blackboard: Dictionary, delta: float, node: Resource) -> int:
	velocity.x = sign(blackboard.get("target_x", global_position.x) - global_position.x) * 100.0
	move_and_slide()
	return BTStatus.RUNNING
```

运行时支持以下功能：

- SUCCESS、FAILURE、RUNNING 三状态传播。
- Sequence、Selector、Random Selector、Parallel、Repeat 和 Wait 的跨 Tick 执行记忆。
- 树重启、树替换、抢占和中断时清理相关记忆。
- Process Tick 或 Physics Tick；同一组件不应同时启用两种自动 Tick。
- Actor 方法缺失或返回值非法时安全失败并记录原因，不导致游戏崩溃。
- `use_runtime_cache` 为节点、子节点和 Decorator 建立拓扑索引，不缓存 Action/Condition 结果。
- 每个外部 Tick 校验精确拓扑签名，节点换序、改父级、Decorator 改归属或资源实例替换会重建缓存。

## 9. Live Debug

Runner 将原子快照写入项目 `.godot` 目录，编辑器只读取与当前打开 `.tres` 路径一致的 Actor 快照。快照包含活动节点 ID、活动标题、状态、当前叶节点、失败原因、Blackboard 值和 Schema 错误。

| 功能 | 说明 |
| --- | --- |
| Active Path Highlight | 高亮 Root 到当前运行节点的卡片和连接。 |
| Non-active Branch Dimming | 淡化当前未执行分支；无活动路径时不会错误淡化整棵树。 |
| Failure Reason Annotation | 在节点和失败列表中显示 Condition、Action、Decorator 或禁用节点的失败原因。 |
| Runtime Path | 用可点击路径按钮显示 Actor、状态、深度和当前叶节点。 |
| Live Blackboard | 显示当前运行值和 Schema 状态。 |
| Resilient Bridge | 遇到截断或损坏 JSON 时保留上一完整帧，并在下一完整快照恢复。 |

游戏画面中没有行为树状态覆盖层；调试信息只存在于 Godot 编辑器插件。

## 10. 二十四项显示功能

每项功能都有独立开关，状态保存在 `user://behavior_tree_editor_view.cfg`。关闭功能时必须清除该功能留下的缩放、颜色、隐藏、路由或高亮状态，不改变行为树运行数据。

| # | 显示功能 | 作用 |
| ---: | --- | --- |
| 1 | Fisheye / Focus+Context | 鼠标附近节点最高放大到 1.20 倍，周围节点保持上下文；关闭后重建并清除变换。 |
| 2 | Subtree Collapse / Expand | 隐藏后代并在父卡片中显示隐藏数量和下两层摘要。 |
| 3 | Compact Mode | 缩小卡片，只保留类型颜色、短标题和必要身份信息。 |
| 4 | Shape / Icon Type Encoding | 用形状和符号冗余表示节点类型，低缩放或灰度环境仍可识别。 |
| 5 | Accessibility / Colorblind Palette | 使用色盲友好颜色并配合形状编码；提供 Ctrl+F、F3 和 Shift+F3。 |
| 6 | Single Connection Rendering | 隐藏 Godot 侧面原生持久线，只显示一条底部到顶部连接，同时保留命中与断开。 |
| 7 | Active Path Highlight | Live Debug 有活动路径时自动强调正在执行的节点链，无独立开关。 |
| 8 | Non-active Branch Dimming | 自动降低非当前分支不透明度，突出实际决策路径，无独立开关。 |
| 9 | Multi-column Layout | 内部排布实现保留，但普通界面固定关闭且不提供开关。 |
| 10 | Overview + Detail / Enhanced Minimap | 使用 230×150 小地图显示全树范围和当前视口。 |
| 11 | Semantic Zoom | 低缩放隐藏参数和说明，中等缩放显示类型，高缩放显示完整参数、说明和 Decorator；节点几何不随滚轮异常改变。 |
| 12 | Path Summary View | 内部路径摘要实现保留，但普通界面固定关闭且不提供开关。 |
| 13 | Decorator Condition Badges | 完整详情层自动在所有者卡片中显示附着条件和参数摘要。 |
| 14 | Search + Highlight | 搜索标题、类型、说明、Action、Condition 和 Decorator 参数；支持前后导航。 |
| 15 | Orthogonal Edges | 内部折线路由实现保留，但普通界面固定关闭且不提供开关。 |
| 16 | Edge Bundling | 内部共享主干实现保留，但普通界面固定关闭且不提供开关。 |
| 17 | Stable Incremental Layout | 自动排布时尽量保留已有有效位置，降低心理地图变化。 |
| 18 | Breadcrumb Navigation | 显示所选节点的 Root 到节点层级路径并支持定位。 |
| 19 | Failure Reason Annotation | Live Debug 有失败数据时自动标注失败节点和 Decorator 来源。 |
| 20 | Zoom-Aware Auto Spacing | 在缩放、卡片详情变化和拖动时临时消除重叠，保持层级与左右顺序，不写回资源坐标。 |
| 21 | Zoom View Anchor | 临时布局变化期间保持视口中心附近节点的相对观察位置。 |
| 22 | Always Curved Edges (Experiment) | 内部采样 Bezier 比较路线保留，但普通界面固定关闭且不提供开关。 |
| 23 | Translucent Cards (Experiment) | 降低卡片背景透明度，并用不透明文字轮廓阻挡后方连线干扰。 |
| 24 | Straight Connections | 默认使用父节点底部中心到子节点顶部中心的一个直线段连接，无独立开关。 |

辅助功能还包括 Grid、Fit、Collapse All、Expand All、Focus、Show All、Minimap 覆盖状态，以及相互独立的 Runtime Path 和 Selection 路径行。

## 11. 示例游戏

`res://scenes/test_game.tscn` 包含玩家、多个敌人和复杂竞技场验证：

- 玩家左右移动、近战攻击、冲刺、隐身、治疗、暂停 AI 和重置。
- 敌人通过 BehaviorTreeComponent 执行巡逻、索敌、追击、左右攻击、最后已知位置搜索、撤退和治疗。
- 复杂树使用 Sequence、Selector、Random Selector、Parallel、Repeat、Wait、Condition、Action、Decorator 和 Blackboard。
- 示例重点验证 NPC 行为确实来自行为树，而不是写死在单独状态机中。

## 12. 测试与当前结果

| 测试套件 | 当前结果 | 主要覆盖 |
| --- | ---: | --- |
| Runtime / Resource | 153/153 | 节点语义、校验、缓存、Actor、Blackboard、保存加载和 Live Debug。 |
| Editor GUI | 195/195 | CRUD、上下端口连线、缩放滚动命中、拖动、Undo/Redo、Inspector、Schema 和显示开关。 |
| Basic Game Integration | 13/13 | 基础敌人、攻击、巡逻和 Runner 生命周期。 |
| Complex Arena Integration | 26/26 | 索敌、追击、攻击、搜索、撤退、治疗和复杂节点组合。 |
| Real GPU Visual Regression | 72/72 | 1600×900 实际渲染、真实鼠标拖拽连线、卡片重叠、端口位置和显示优化恢复。 |

上述核心套件合计 `459/459`。真实 GPU 测试使用 NVIDIA GeForce RTX 5070 Laptop GPU 和 OpenGL 3.3 Compatibility。另有大树研究截图、运行时性能、发布包和人工实验模板等附加验证；人体可读性实验仍需真实招募 8–15 名参与者，不能用自动几何结果代替。

## 13. 当前限制

- Service 节点不在当前毕业设计范围内。
- 当前正式兼容目标为 Godot 4.6；其他版本需要单独安装后运行兼容矩阵。
- Live Debug 使用本机 JSON 桥，不是网络远程调试协议。
- 人体对比实验尚未完成，因此不能声称某项显示方法已经被用户研究证明更易读。
- Godot Asset Library 发布页面和最终公开图标属于发布工作，不影响当前插件核心功能。

## 14. 相关文件

- 插件用户手册：`docs/USER_GUIDE_ZH.md`
- 技术实现文档：`docs/TECHNICAL_DOCUMENTATION_ZH.md`
- 已引用论文目录：`research/currently_cited_references`
- 论文初稿：`thesis_draft/english` 与 `thesis_draft/chinese`
- 测试结果：`testgame/testgame/test_results`
