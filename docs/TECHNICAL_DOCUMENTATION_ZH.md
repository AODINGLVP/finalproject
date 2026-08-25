# Godot 4.6 可视化行为树插件技术文档

## 1. 系统边界与目录

插件由编辑器层、资源层、运行时层和验证层组成。活动项目位于`testgame/testgame`，分发模板位于`visual_scripting`，两份`addons/behavior_tree_editor`代码必须保持一致。游戏只消费资源和Runner；所有行为树运行状态UI仅存在于Godot编辑器。

核心文件：

| 文件 | 职责 |
| --- | --- |
| `bt_tree_resource.gd` | 树、Root ID、节点数组、Schema、深拷贝和结构校验 |
| `bt_node_resource.gd` | 节点类型、参数、父子/Decorator归属、位置和折叠状态 |
| `bt_blackboard_schema.gd` | 类型声明、默认值、动态键策略和运行值校验 |
| `bt_editor_view.gd` | 工具栏、Palette、GraphEdit、Inspector、Schema Editor、历史和Live Debug |
| `bt_graph_node.gd` | UE风格卡片、上下端口、信息密度、运行状态和显示开关 |
| `bt_graph_edit.gd` | 自定义连线、命中、Fisheye、Minimap、拖放和画布事件 |
| `behavior_tree_runner.gd` | Tick调度、节点语义、执行记忆、Actor调用、黑板、缓存和调试快照 |

## 2. 资源与执行模型

`BTTreeResource.nodes`保存所有普通节点和附着Decorator。普通父子关系使用`parent_id`，Decorator使用`decorator_parent_id`，因此Decorator不会成为主图中的独立GraphNode。`get_children_of()`按X坐标排序，X相同再按Y排序，保证Sequence等有序节点从左到右执行。

Runner返回SUCCESS、FAILURE或RUNNING。Sequence、Selector、Random Selector、Parallel、Repeat和Wait使用`node_memory`保存跨Tick状态；树重启、替换或子树中断时清理相关记忆。Reactive Selector每Tick重新检查高优先级分支，可抢占正在运行的巡逻或搜索。

Action和Actor模式Condition通过方法名调用Actor，参数固定为`blackboard, delta, node`。Blackboard模式Condition和Decorator共用exists、not_exists、is_true、is_false、equals、not_equals、`>`、`<`、`>=`、`<=`比较。

## 3. Schema Editor与历史

Schema Editor直接编辑树的`BTBlackboardSchema`，不依赖Godot通用Resource Inspector。每次有效修改先调用树级`_push_history()`，历史快照通过`duplicate_tree()`深拷贝Schema和节点。类型变化使用安全归一化：不兼容的String→Int变为0，Vector2不兼容值变为ZERO，避免Variant转换异常。

验证包含null项、空键、重复键、不支持类型、运行值类型不符和严格模式未声明键。保存树前`validate_tree()`合并Schema与结构错误。`get_blackboard_references()`建立键到节点ID/标题/类型的索引，`get_unused_blackboard_keys()`返回未使用声明，`validate_blackboard_references()`检查空引用和严格模式未知引用。Inspector既保留自由输入，也提供带类型的Schema下拉选择。

## 4. 单连接渲染

Godot GraphEdit的槽位负责拖拽请求，但原生持久线是侧面端口曲线，与插件底部到顶部线同时显示时形成双线。插件在`Single Connection Rendering`开启时隐藏内部`_connection_layer`，自定义绘制持久线；端口拖拽开始时临时显示原生层提供预览，结束后再次隐藏。

自定义命中把鼠标位置与路由折线/贝塞尔的每段最近点比较，默认容差10像素。`Straight Connections`只返回父节点底部中心与子节点顶部中心两个端点，因此绘制、拖拽预览、缓存和命中统一使用一个直线段。右键命中发出`custom_edge_disconnect_requested`，复用编辑器原有断开与Undo/Redo逻辑。关闭单连接开关时停止自定义绘制、恢复原生层和3.5像素原生线。

## 5. 显示优化架构

`FEATURE_DEFINITIONS`登记24个独立开关，统一由`_set_feature_enabled()`、`_apply_feature_states()`和ConfigFile持久化。所有功能必须有关闭复位路径。新增类型图标由`BTTypeIcon`使用Canvas绘制圆、菱形、六边形、三角形、盾形和内部符号，不依赖外部纹理；无障碍配色采用色盲友好的蓝、橙、绿、朱红、黄和紫红，并与形状形成冗余编码。

Semantic Zoom只改变信息可见性，不改变节点尺寸，避免滚轮时卡片异常缩放。Fisheye独立修改节点倍率并在关闭时重建清理Transform。Collapse、Focus、Search、Minimap、Path Summary、Breadcrumb、Branch Dimming和Failure Annotation分别处理结构、导航和运行解释，不混用运行数据。

节点按下时只进入待拖动状态，不立即求解布局。累计位移按屏幕像素计算：不足10像素时只保存当前卡片的微调，超过阈值后锁定进入实时避让；激活后每移动8个屏幕像素才刷新一次，释放时再验证一次。父子高度约束先检查资源中的原始位置，仅当原布局已经满足父卡片在子卡片上方时，才保证重新布局后父卡片底部不低于子卡片顶部；原本自由摆放的连线不施加该约束。

开发时可在仓库根目录运行 `Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path ./testgame/testgame --script res://tests/run_zoom_drag_layout_tests.gd -- drag-rules-quick`，约数秒完成点击、微调、三档缩放、条件父子关系和241节点最大缩放检查。完整组合测试仅在最终回归时运行。

## 6. Live Debug桥

Runner把组件快照原子写入`res://.godot/behavior_tree_runtime_debug.json`，包含Actor、树路径、活动ID/标题、叶状态、节点状态、失败原因、Blackboard值和Schema类型/错误。编辑器按树资源路径筛选快照，损坏或截断JSON会保留上一完整帧，下一完整快照可自动恢复。

游戏HUD不读取该文件，也不显示行为树。编辑器顶栏长路径使用省略和Tooltip，Runtime Path与Selection使用两个独立滚动行，避免1600×900下重叠。

## 7. 运行时拓扑缓存

原始Runner每次Tick多次线性扫描节点数组。`use_runtime_cache`建立三个只读索引：ID→节点、父ID→有序子节点、Owner ID→有序Decorator。缓存只减少拓扑查询，不缓存Action、Condition、Decorator结果或Blackboard，因此动态行为保持逐Tick执行。

设置新树、重启执行或切换缓存开关时清空索引。每次外部`tick()`只执行一次完整拓扑校验；递归节点查询不重复扫描。精确签名包含Root ID、节点数、节点资源实例ID、节点ID、`parent_id`、`decorator_parent_id`和X/Y排序位置，因此同数量的换序、改父级、Decorator归属变化和同ID资源替换都会自动重建。关闭开关会直接调用原始`find_node/get_children_of/get_decorators_of`路径。

最终固定实验使用31/121/364节点、1/10/50 Runner、每组合7个预热后样本。精确安全校验后的缓存收益中位数区间为15.98%–26.46%、52.61%–56.02%、76.65%–78.00%，九个场景均为正。小树收益低于旧的“仅节点数”缓存，因为每个Tick新增O(n)精确签名校验；这是防止静默沿用错误拓扑的明确正确性/性能权衡。126行原始数据位于`test_results/runtime_profile.csv`，公式工作簿位于`research/display_optimization/behavior_tree_unattended_run_evidence.xlsx`。数值只适用于本机和该工作负载。

## 8. 测试体系与最终结果

| 套件 | 最终结果 | 覆盖 |
| --- | ---: | --- |
| Runtime/resource | 153/153 | 节点语义、校验、Schema引用、Actor、Live Debug、保存重载 |
| Editor GUI | 185/185 | CRUD、连接、拖拽、历史、Inspector key picker、19开关、Schema和Live Debug |
| Basic game | 13/13 | 三个敌人、攻击、巡逻、死亡重生和Runner生命周期 |
| Complex arena | 26/26 | 索敌、追击、攻击、搜索、撤退、治疗和新节点集成 |
| Core GPU visual | 70/70 | 17张1600×900截图、几何、灰度、单线、key picker、恢复和复杂树 |
| Human-study GPU | 21/21 | 121/364节点、目标定位和确定性七节点活动链 |
| Runtime profile | 511/511 | 九种规模/负载、状态一致、缓存开关及五类缓存失效 |
| Package validation | 53/53 | ZIP边界、关键文件、SHA-256清单和空项目启用启动 |

核心回归合计447/447；附加视觉21/21、性能511/511、发布包53/53。180物理帧烟雾测试保持3个活动Runner，游戏无行为树覆盖层。活动项目、模板和空白安装项目均通过编辑器启动，插件源码/配置/文档同步；终局日志严格扫描无FAIL、ERROR、SCRIPT ERROR、泄漏、崩溃、重复UID或非法内存访问。真实视觉使用NVIDIA GeForce RTX 5070 Laptop GPU与OpenGL 3.3 Compatibility渲染，并完成6张关键截图人工复核。

运行命令：

```powershell
./Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path ./testgame/testgame --script res://tests/run_behavior_tree_tests.gd --log-file <absolute-log>
./Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path ./testgame/testgame --script res://tests/run_editor_view_tests.gd --log-file <absolute-log>
./Godot_v4.6-stable_win64_console.exe --rendering-method gl_compatibility --audio-driver Dummy --path ./testgame/testgame --script res://tests/run_visual_regression_tests.gd --log-file <absolute-log>
./Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path ./testgame/testgame --script res://tests/run_runtime_profile.gd --log-file <absolute-log>
./tools/package_behavior_tree_plugin.ps1
```

## 9. 分发与洁净安装

`tools/package_behavior_tree_plugin.ps1`从`visual_scripting`模板生成`dist/behavior-tree-editor-0.9.0.zip`。清单记录版本、Godot 4.6、文件大小和SHA-256；脚本解压后逐文件复算哈希，随后在仓库级`.codex_tmp`创建空项目、复制并启用插件、启动Godot编辑器并扫描错误。临时源码不放进任何`res://`，`test_results/.gdignore`也阻止证据目录污染资源扫描。

## 10. 已知边界

- Service节点按导师当前范围明确不实现；项目目标是完整基本行为树，不复制UE全部功能。
- 人体实验尚未招募8–15名参与者，自动几何和性能结果不能替代可读性结论。
- 可安装ZIP、README和许可证已经完成；Godot Asset Library商店页面、正式封面图标和其他Godot版本兼容矩阵仍需后续真实环境验证。
- Live Debug使用本机JSON桥，不是网络远程调试协议。
