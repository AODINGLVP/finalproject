# Godot 4.6 可视化行为树插件用户手册

## 1. 安装与打开

活动示例项目位于 `testgame/testgame`，可分发插件源码位于 `visual_scripting/addons/behavior_tree_editor`。推荐直接解压 `dist/behavior-tree-editor-0.9.0.zip` 到目标Godot项目根目录，确认最终路径是 `addons/behavior_tree_editor/plugin.cfg`；也可以手动复制整个插件文件夹。进入 `Project > Project Settings > Plugins`，启用 `Behavior Tree Editor`，编辑器底部会出现 `Behavior Tree` 面板。

发布包只包含插件目录，内含MIT许可证、英文README和SHA-256文件清单。仓库维护者可运行 `./tools/package_behavior_tree_plugin.ps1` 重新生成包；脚本会校验目录边界和每个文件哈希，并在临时空项目中真实启用插件启动Godot 4.6。

插件界面保持英文，便于与Godot术语一致。运行游戏时不会在游戏画面覆盖行为树；运行状态只显示在Godot编辑器面板。

## 2. 创建与保存行为树

1. 点击 `New Tree`，填写 `Resource Path`，路径必须以 `res://` 开头并以 `.tres` 结尾。
2. 从左侧 `Node Palette` 拖入节点，或在画布空白处右键创建。
3. 先创建唯一的 `Root`，再从父节点下方端口拖到子节点上方端口连接。
4. 也可以选中父节点后点击 `Add Child`。同一父节点的子节点按照画布横坐标从左到右执行。
5. 拖动节点调整顺序，使用 `Undo` / `Redo` 撤销或重做编辑。
6. 点击 `Save Tree`。保存前会检查Root、断线、循环、叶节点子节点、Decorator和Schema错误。

画布中的节点可以直接拖动。右键节点可断开、删除或切换启用状态；右键自定义连接线可断开该连接。`Auto Arrange`自动排布，`Fit`将完整可见树适配到视口。

## 3. 节点功能

| 节点 | 功能 |
| --- | --- |
| Root | 行为树唯一入口，只允许一个直接子节点 |
| Sequence | 从左到右执行；任一失败则失败，全部成功才成功 |
| Selector | 从左到右尝试；任一成功则成功，可启用Reactive模式 |
| Random Selector | 随机顺序尝试子节点；可设置固定seed复现实验 |
| Parallel | 同时Tick多个子节点，支持成功/失败策略 |
| Repeat | 有限次数或无限重复唯一子节点 |
| Action | 调用Actor上的具体方法 |
| Condition | 调用Actor条件方法或比较Blackboard值 |
| Wait | 等待指定秒数后成功 |
| Decorator | 为节点添加条件、冷却、超时或结果转换 |

选中节点后，在右侧 `Node Inspector` 编辑标题、类型、说明和类型化参数。`Advanced JSON`只用于自定义或兼容参数，常用字段无需手写JSON。

## 4. Blackboard Schema

点击顶栏 `Edit Schema` 打开声明编辑器。`Add Key`添加一行，可设置Key、Bool/Int/Float/String/Vector2类型、默认值和说明。重复键或空键会立即显示红色错误，错误未修复时禁止保存。

编辑 Blackboard Condition 或 Blackboard Decorator 时，`Blackboard Key`文本框下方会出现Schema下拉框，选项显示为 `key [Type]`。可直接选择已声明键，也可继续自由输入；自由输入用于 `Allow Dynamic Keys` 开启时的动态键。严格模式关闭动态键后，空引用或未声明引用会阻止保存。

Schema摘要会显示引用数量和未使用声明。把鼠标停在摘要上可查看引用节点的ID、标题、类型和未使用键；这样可以定位拼写错误、确认一个键被哪些节点消费，而不必人工遍历整棵树。

`Allow Dynamic Keys`开启时，Actor可在运行时增加未声明键；关闭时，未声明键会在Live Blackboard中报告Schema错误。Schema编辑支持Undo/Redo，并随行为树`.tres`资源保存。

`Blackboard`按钮打开的是运行时值面板，与`Edit Schema`声明面板相互独立。前者显示当前Actor的Key、运行类型、值和Schema状态，后者用于设计资源。

## 5. 绑定Actor并运行

在NPC下添加 `BehaviorTreeComponent`，给`behavior_tree`指定`.tres`树。组件作为NPC子节点时可让`actor_path`为空；否则把它指向拥有行为方法的Actor。选择Process或Physics Tick，不要同时开启两者。

Action方法示例：

```gdscript
func chase_target(blackboard: Dictionary, delta: float, node: Resource) -> int:
	velocity.x = sign(blackboard.get("target_x", global_position.x) - global_position.x) * 100.0
	move_and_slide()
	return BTStatus.RUNNING
```

方法可返回`BTStatus.SUCCESS`、`FAILURE`、`RUNNING`，也可返回`true/false`。缺少方法时Runner安全返回FAILURE并记录原因，不会崩溃。

`use_runtime_cache`默认开启，用于加速大树拓扑查找；可关闭做性能对比或诊断。它不缓存Action/Condition结果，不会跳过动态逻辑。每次外部Tick都会校验精确拓扑签名，所以同数量节点的换序、改父级、Decorator重新归属或节点实例替换也会自动重建缓存。

## 6. Live Debug

1. 在行为树面板加载NPC实际使用的`.tres`。
2. 保持 `Live Debug`开启并运行游戏。
3. 顶部显示Actor、状态和完整活动路径；节点与连接高亮当前执行链。
4. `Dim Inactive`淡化非当前分支；`Failure Reasons`在节点和列表显示失败原因。
5. `Blackboard`查看运行值。点击Runtime Path按钮可展开折叠子树并定位节点。

如果没有反应，先检查编辑器中打开的资源路径是否与组件使用的树完全相同，再确认组件正在运行且`editor_debug_bridge_enabled`开启。

## 7. 大树显示开关

`Display Features`中19项功能相互独立并保存到`user://behavior_tree_editor_view.cfg`。常用组合如下：

- 定位未知区域：`Minimap + Semantic Zoom + Breadcrumb`。
- 定位已知节点：`Search + Highlight`，无障碍模式下可用`Ctrl+F`、`F3`、`Shift+F3`。
- 减少结构：`Subtree Collapse`或选中后`Focus`；`Show All`恢复。
- 低缩放识别：`Shape / Icon Type Encoding + Accessibility / Colorblind Palette`。
- 运行诊断：`Active Path + Dim Inactive + Failure Reasons + Path Summary`。
- 连线显示：默认`Single Connection Rendering`仅显示一条底部到顶部连接；关闭后回到Godot原生线。

每个显示功能关闭后都会恢复基线视觉状态，不修改行为树运行数据。

## 8. 示例与验证

运行`res://scenes/test_game.tscn`。玩家使用A/D移动、J或鼠标左键攻击、Space冲刺、C隐身、H治疗、T暂停AI、R重置。EnemyB/EnemyC使用复杂行为树，覆盖巡逻、索敌、追击、左右攻击、搜索最后位置、撤退、治疗、Random Selector、Parallel、Repeat、Wait和Decorator。

自动验证命令和预期结果见 `docs/TECHNICAL_DOCUMENTATION_ZH.md`。最终基线为核心 `447/447`、固定研究视觉 `21/21`、运行时性能 `511/511` 和发布包 `53/53`。测试证据目录含 `.gdignore`，不会被Godot误当成重复插件源码扫描。
