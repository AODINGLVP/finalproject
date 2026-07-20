# Godot 行为树编辑器插件实现说明

## 1. 插件目标

本插件基于 Godot 4.6 的 EditorPlugin 和 2D GUI 系统实现，目标是在 Godot 编辑器中提供一个可视化行为树编辑器，并配套运行时执行组件，使 NPC 可以通过行为树资源执行 AI 行为。

插件主要完成以下功能：

- 在 Godot 编辑器底部加入 `Behavior Tree` 面板。
- 支持创建、加载、保存行为树资源。
- 支持可视化节点编辑、拖拽摆放、连线、右键菜单、撤销和重做。
- 支持 `Root`、`Sequence`、`Selector`、`Action`、`Condition`、`Decorator` 等节点类型。
- 支持运行时执行行为树，让 NPC 根据行为树调用具体方法。
- 支持黑板数据和装饰器判断。
- 支持类似 UE 行为树的 Live Debug，高亮当前运行中的行为链条。

## 2. 插件目录结构

插件位于：

```text
testgame/testgame/addons/behavior_tree_editor
```

主要文件如下：

```text
plugin.cfg
plugin.gd
bt_editor_view.gd
bt_graph_edit.gd
bt_graph_node.gd
bt_palette_item.gd
bt_tree_resource.gd
bt_node_resource.gd
runtime/
  behavior_tree_component.gd
  behavior_tree_runner.gd
  bt_status.gd
  example_agent.gd
```

其中：

- `plugin.gd` 负责把行为树编辑器注册到底部面板。
- `bt_editor_view.gd` 是编辑器主界面，负责工具栏、节点面板、属性面板、保存加载、撤销重做和 Live Debug。
- `bt_graph_edit.gd` 封装 Godot 的 `GraphEdit`，用于显示行为树画布。
- `bt_graph_node.gd` 封装 Godot 的 `GraphNode`，用于显示单个行为树节点。
- `bt_tree_resource.gd` 定义整棵行为树资源。
- `bt_node_resource.gd` 定义单个行为树节点资源。
- `runtime/behavior_tree_runner.gd` 实现行为树运行时逻辑。
- `runtime/behavior_tree_component.gd` 是挂到 NPC 身上的行为树组件。
- `runtime/bt_status.gd` 定义行为树节点返回状态。

## 3. 编辑器部分实现

插件通过 `EditorPlugin.add_control_to_bottom_panel()` 将 `BTEditorView` 添加到 Godot 编辑器底部，形成一个独立的 `Behavior Tree` 面板。

编辑器面板由三部分组成：

- 左侧节点面板：提供 `Sequence`、`Selector`、`Action`、`Condition`、`Decorator`、`Root` 等节点类型。
- 中间图形画布：基于 `GraphEdit` 显示和连接节点。
- 右侧属性面板：编辑节点标题、类型、描述和参数 JSON。

节点资源使用 `BTNodeResource` 表示，每个节点保存：

```gdscript
id
title
node_type
position
parent_id
decorator_parent_id
description
parameters
enabled
```

其中 `parent_id` 表示普通父子连接关系，`decorator_parent_id` 表示装饰器附着在哪个节点上。

整棵树使用 `BTTreeResource` 表示，内部保存：

```gdscript
tree_name
root_node_id
nodes
```

编辑器保存时会把整棵树保存为 `.tres` 资源，例如：

```text
res://behavior_trees/enemy_patrol_combat.tres
```

## 4. 节点连接和执行顺序

行为树节点在 UI 上采用上下连接口：

- 上方小方块表示输入端。
- 下方小方块表示输出端。
- 父节点连接到子节点，形成从上到下的树结构。

对于 `Sequence` 和 `Selector`，子节点执行顺序通过节点的横向位置决定：

```gdscript
get_children_of(parent_id)
```

会按 `position.x` 从小到大排序。因此，在编辑器中越靠左的子节点越先执行。

## 5. 运行时执行系统

运行时核心是 `BehaviorTreeRunner`。测试场景中的敌人节点下挂有：

```text
BehaviorTreeComponent
```

它继承自 `BehaviorTreeRunner`，并导出一个行为树资源：

```gdscript
@export var behavior_tree: BTTreeResource
```

游戏运行时，组件会在 `_process()` 或 `_physics_process()` 中调用：

```gdscript
tick(delta)
```

`tick()` 从根节点开始递归执行行为树。不同节点类型的执行规则如下：

- `Root`：执行第一个子节点。
- `Sequence`：从左到右执行子节点，遇到失败立即失败，全部成功才成功。
- `Selector`：从左到右执行子节点，遇到成功立即成功，全部失败才失败。
- `Action`：调用 NPC 脚本中的具体方法。
- `Condition`：检查黑板数据或调用 NPC 的判断方法。
- `Decorator`：改变或限制子节点执行结果。

节点状态由 `bt_status.gd` 定义：

```gdscript
SUCCESS
FAILURE
RUNNING
```

## 6. Action 如何调用具体方法

`Action` 节点通过参数指定要调用的方法名：

```json
{
  "action_name": "attack_left"
}
```

运行时会在绑定的 actor 上调用该方法：

```gdscript
agent.call(method_name, blackboard, delta, node)
```

因此，NPC 脚本中只要实现对应方法即可，例如：

```gdscript
func attack_left(blackboard: Dictionary, delta: float, node: Resource) -> int:
    return _attack_action(blackboard, delta, node, -1)
```

测试游戏中的敌人实现了：

```text
move_left
move_right
attack_left
attack_right
```

行为树通过 `Action` 节点调用这些方法，从而真正驱动敌人移动和攻击。

## 7. 黑板数据

插件目前实现了简化版黑板系统。每个 `BehaviorTreeComponent` 都有自己的字典：

```gdscript
@export var blackboard: Dictionary = {}
```

测试游戏中，敌人脚本会不断更新黑板数据：

```gdscript
blackboard["player_in_range"]
blackboard["player_on_left"]
blackboard["player_on_right"]
```

行为树中的 `Condition` 或 `Decorator` 可以读取这些值进行判断。例如攻击左侧玩家时，需要满足：

```text
player_in_range == true
player_on_left == true
```

这使行为树可以根据运行时环境动态选择行为。

## 8. Decorator 装饰器

装饰器用于附加到某个节点上，在节点执行前进行额外判断或修改结果。

目前支持的装饰器模式包括：

- `blackboard`：根据黑板变量判断是否允许节点执行。
- `cooldown`：为节点增加冷却时间。
- `time_limit`：限制节点可运行时间。
- `invert`：反转子节点结果。
- `always_success`：强制返回成功。
- `always_failure`：强制返回失败。
- `repeat_forever`：循环执行子节点。

在敌人行为树中，攻击节点使用黑板装饰器判断玩家是否在范围内以及玩家位于左侧还是右侧。

## 9. Live Debug 实现

为了实现类似 UE 行为树的运行时调试效果，运行时组件会把当前执行状态写入一个调试桥接文件：

```text
res://.godot/behavior_tree_runtime_debug.json
```

写入内容包括：

- 当前 actor 名称。
- 当前行为树资源路径。
- 当前执行链条节点 id。
- 当前执行链条节点名称。
- 当前叶子节点状态。
- 黑板数据快照。

编辑器中的 `BTEditorView` 会定时读取这个文件。如果当前打开的行为树资源和运行时行为树匹配，就会在图形面板中高亮当前执行链条。

显示效果：

- 执行路径上的节点显示 `ACTIVE PATH`。
- 当前正在执行的节点显示 `CURRENT: RUNNING / SUCCESS / FAILURE`。
- 面板上方显示当前 actor、执行链条和状态。

这样可以在 Godot 编辑器中观察 NPC 当前正在执行哪个行为，接近 UE 行为树调试体验。

## 10. 测试游戏

项目中包含一个简单 2D 测试场景：

```text
res://scenes/test_game.tscn
```

场景中包含：

- 一个可控制玩家。
- 三个敌人。
- 基础移动和近战攻击。
- 敌人使用行为树组件驱动 AI。

敌人使用的行为树资源为：

```text
res://behavior_trees/enemy_patrol_combat.tres
```

默认逻辑为：

```text
Root
  Repeat Forever
    Combat Selector
      Attack Left
      Attack Right
      Patrol Sequence
        Move Left
        Move Right
```

行为树会优先尝试攻击玩家，如果玩家不在攻击范围内，则执行巡逻行为。

## 11. 总结

这个插件由编辑器可视化系统和运行时执行系统两部分组成。

编辑器部分负责让用户用图形化方式创建和维护行为树，运行时部分负责让 NPC 根据行为树真实执行 AI 行为。二者通过 `.tres` 行为树资源连接，并通过 Live Debug 文件实现运行时调试联动。

整体实现展示了一个完整的 Godot 行为树工作流：

```text
可视化编辑行为树
保存为 BTTreeResource
NPC 挂载 BehaviorTreeComponent
运行时递归执行节点
通过黑板和装饰器做判断
编辑器中 Live Debug 高亮当前行为
```

因此，它不仅是一个可视化编辑工具，也是一套可以实际驱动游戏 NPC 行为的行为树系统。
