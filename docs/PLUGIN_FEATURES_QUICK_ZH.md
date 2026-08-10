# Godot 4.6 可视化行为树插件功能速览

## 1. 可视化编辑

- 在 Godot 底部 `Behavior Tree` 面板创建、加载和保存 `.tres` 行为树。
- 支持左侧列表单击创建、拖拽创建和画布右键创建节点。
- 节点可以自由拖动；支持删除、断开、启用/禁用、撤销和重做。
- 从父节点底部方块拖到子节点顶部方块完成连线。
- Sequence 等有序节点按照子节点横坐标从左到右执行。
- 保存前检查 Root、断开节点、循环、非法子节点和 Decorator 等错误。

## 2. 节点类型

| 节点 | 功能 |
| --- | --- |
| Root | 行为树唯一入口。 |
| Sequence | 从左到右执行，全部成功才成功。 |
| Selector | 从左到右选择，任一成功即成功；支持 Reactive。 |
| Random Selector | 随机尝试子节点，支持固定 Seed。 |
| Parallel | 同时执行多个子节点，支持成功和失败策略。 |
| Repeat | 按次数或无限重复一个子节点。 |
| Action | 调用 NPC Actor 上的具体方法。 |
| Condition | 调用 Actor 条件方法或判断 Blackboard 数据。 |
| Wait | 等待指定时间后成功。 |
| Decorator | 提供条件、冷却、超时、反转和强制结果等功能。 |

## 3. NPC 运行时

- 给 NPC 添加 `BehaviorTreeComponent` 并指定行为树资源即可运行。
- 支持 `SUCCESS`、`FAILURE`、`RUNNING` 三种状态。
- Action 和 Condition 可以调用 NPC 脚本中的方法。
- 组合节点会保存跨帧执行位置，树重启或中断时正确清理状态。
- 提供可关闭的运行时拓扑缓存，用于提升大型树或多个 NPC 的执行效率。

## 4. Blackboard

- 每个 NPC 拥有独立的 Dictionary Blackboard。
- 支持 Bool、Int、Float、String 和 Vector2 类型 Schema、默认值和说明。
- Condition 和 Decorator 支持存在、相等、不等、真假和大小比较。
- 可检查未声明键、类型错误、引用位置和未使用键。

## 5. 编辑器 Live Debug

- 游戏运行时在 Godot 编辑器中高亮当前执行节点和完整活动路径。
- 可以淡化非当前分支，并显示 Action、Condition 或 Decorator 的失败原因。
- `Runtime Path` 可以快速定位正在执行的节点。
- `Live Blackboard` 显示当前 NPC 的 Blackboard 值和类型。
- 游戏画面中不会出现行为树调试覆盖层。

## 6. 大树显示优化

- 鱼眼 Focus+Context。
- 子树折叠、展开和隐藏节点摘要。
- Compact Mode 和 Semantic Zoom。
- 搜索、高亮、前后结果导航。
- 增强小地图、Fit、Focus、Show All 和 Breadcrumb。
- 路径摘要、非当前分支淡化和失败标注。
- 多列布局、稳定布局、直角连线和边捆绑。
- 形状图标编码和色盲友好配色。
- 每项显示优化都有独立开关，关闭后恢复基础显示状态。

## 7. 示例与测试

- 示例游戏包含玩家移动、攻击，以及敌人巡逻、索敌、追击、攻击、搜索、撤退和治疗。
- 当前核心测试结果：Runtime `153/153`、Editor `195/195`、基础游戏 `13/13`、复杂游戏 `26/26`、GPU 视觉 `72/72`。
- 核心测试合计：`459/459`。

完整说明见 `docs/BEHAVIOR_TREE_PLUGIN_FUNCTIONS_ZH.md`，当前已引用论文见 `research/currently_cited_references/`。
