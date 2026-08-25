# Godot 4.6 可视化行为树插件用户手册

## 1. 安装与打开

活动示例项目位于 `testgame/testgame`，可分发插件源码位于 `visual_scripting/addons/behavior_tree_editor`。推荐直接解压 `dist/behavior-tree-editor-0.9.0.zip` 到目标Godot项目根目录，确认最终路径是 `addons/behavior_tree_editor/plugin.cfg`；也可以手动复制整个插件文件夹。进入 `Project > Project Settings > Plugins`，启用 `Behavior Tree Editor`，编辑器底部会出现 `Behavior Tree` 面板。

发布包只包含插件目录，内含MIT许可证、英文README和SHA-256文件清单。仓库维护者可运行 `./tools/package_behavior_tree_plugin.ps1` 重新生成包；脚本会校验目录边界和每个文件哈希，并在临时空项目中真实启用插件启动Godot 4.6。

插件界面保持英文，便于与Godot术语一致。运行游戏时不会在游戏画面覆盖行为树；运行状态只显示在Godot编辑器面板。

## 2. 创建与保存行为树

1. 点击 `New` 创建树；保存时选择项目内的 `.tres` 资源位置。
2. 在画布空白处右键，选择需要的节点类型并在鼠标位置创建。
3. 先创建唯一的 `Root`，再从父节点下方端口拖到子节点上方端口连接。
4. 同一父节点的子节点按照画布横坐标从左到右执行。
5. 拖动节点调整顺序，使用 `Undo` / `Redo` 撤销或重做编辑。
6. 点击 `Save Tree`。保存前会检查Root、断线、循环、叶节点子节点、Decorator和Schema错误。

画布中的节点可以直接拖动。单击节点只会选中，不会触发重新布局；小于10个屏幕像素的微调只移动当前节点，允许保留少量遮挡。超过该范围后才会启动实时避让，并在释放时做最后一次检查。避让只保护原本就满足“父节点底部高于子节点顶部”的连线；原本横向、倒置或互相遮挡的自由摆放不会被强制改成上下分层。右键节点可断开、删除或切换启用状态；右键自定义连接线可断开该连接。`Auto Arrange`自动排布，`Fit`将完整可见树适配到视口。

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
4. 插件自动淡化非当前分支，并在失败节点和 `Failures` 列表中显示原因，不需要额外开启显示开关。
5. `Blackboard`查看运行值；顶部状态文字继续显示当前Actor、状态和活动路径。

如果没有反应，先检查编辑器中打开的资源路径是否与组件使用的树完全相同，再确认组件正在运行且`editor_debug_bridge_enabled`开启。

## 7. 大树显示功能

插件内部保留24项显示状态，但只把仍需用户选择的功能放进菜单。Enhanced Minimap、Search、Active Path Highlight、Non-active Branch Dimming、Failure Reason Annotation、Decorator Condition Badges和Straight Connections是默认能力。Grid、Always Curved Edges、Multi-column Layout、Path Summary、Edge Bundling和Orthogonal Edges默认关闭且没有菜单入口。内部实现仍保留，旧配置也会被整理为这些固定状态。其余选择保存到`user://behavior_tree_editor_view.cfg`。常用方式如下：

- 定位未知区域：直接使用默认Minimap，可再开启`Semantic Zoom + Breadcrumb`。
- 定位已知节点：直接在默认Search栏输入查询；清空查询即可复位。无障碍模式下可用`Ctrl+F`、`F3`、`Shift+F3`。
- 减少结构：`Subtree Collapse`或选中后`Focus`；`Show All`恢复。
- 低缩放识别：`Shape / Icon Type Encoding + Accessibility / Colorblind Palette`。
- 运行诊断：Live Debug有数据时自动高亮活动路径、淡化其他分支并标注失败原因。
- 连线显示：Straight Connections固定使用父节点底部到子节点顶部的直线；`Single Connection Rendering`决定是否只显示这一条自定义连接，关闭后回到Godot原生线。

菜单中的可选显示功能关闭后会恢复相应基线视觉状态。默认能力按查询、详情层或运行数据自动出现和复位，不修改行为树运行数据。

## 8. 示例与验证

运行`res://scenes/test_game.tscn`。玩家使用A/D移动、W跳跃或攀爬、S向下攀爬、J或鼠标左键攻击、Space冲刺、C隐身、H治疗、T暂停AI、R重置。场景固定包含五个不会自动复活的敌人，分别使用31、61、121、241和364节点的真实行为树；玩家为无限生命，击败全部敌人后出现胜利界面。241节点Tactician覆盖巡逻、索敌、追击、方向近战、远程投射物、跳跃、攀爬、搜索最后位置、返回、撤退和治疗。详细演示见`testgame/testgame/COMPLEX_ARENA_GUIDE.md`。

自动验证命令见 `docs/TECHNICAL_DOCUMENTATION_ZH.md` 和游戏演示指南。测试结果以当前运行日志为准，不在本指南中保留容易过期的固定总数。测试证据目录含 `.gdignore`，不会被Godot误当成重复插件源码扫描。
