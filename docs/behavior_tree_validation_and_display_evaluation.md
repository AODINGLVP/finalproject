# 行为树插件验收与显示优化评价

## 最终验收基线

本项目采用资源与运行时、编辑器 GUI、基础游戏、复杂竞技场和真实 GPU 视觉回归五类自动测试，另执行180物理帧竞技场烟雾测试、Godot编辑器启动和洁净安装检查。2026年8月22日的最终跨任务基线共有 **574/574** 条核心自动断言通过：资源与运行时153、编辑器GUI 250、基础游戏13、复杂竞技场34、GPU视觉回归124。竞技场在真实OpenGL渲染器下同时保持3个活动Runner，游戏HUD中没有行为树覆盖层。

严格判定将非零退出码、`FAIL:`、`ERROR:`、`SCRIPT ERROR:`、对象泄漏、原生崩溃和非法内存访问全部视为失败。完整日志位于 `testgame/testgame/test_results/full_regression/`。资源测试中“缺失 Actor 方法”的 WARNING 是故意构造的安全性用例，Runner 按预期返回 FAILURE 并记录失败原因。编辑器 `--quit-after` 检查中的扫描中断 WARNING 来自定时退出。

| 测试层 | 结果 | 主要覆盖 |
| --- | ---: | --- |
| 资源与运行时 | 153/153 | 结构校验、节点语义、Decorator、Schema引用、Actor、调试桥和缓存一致性 |
| 编辑器 GUI | 250/250 | 简化菜单、右键创建、连接、延迟敏感拖拽、撤销重做、Schema、Live Debug和19项显示功能 |
| 基础游戏 | 13/13 | 3 个 NPC、攻击伤害、巡逻、死亡重生、Runner 生命周期和无 Timer 泄漏 |
| 复杂竞技场 | 34/34 | 索敌、响应式防御、近/远程攻击、越障跳跃、梯子攀爬、搜索、撤退、治疗和Schema |
| GPU 视觉回归 | 124/124 | 26张当前1600×900截图、菜单、几何、灰度、单线、Schema、自动间距和241节点树 |

人工实验准备另有`91/91`条材料校验、`22/22`条真实GPU检查和4张当前固定截图，覆盖121节点练习树、241节点可玩树、远程攻击目标搜索和确定性七节点Live Debug路径；性能实验另有`511/511`条断言与126行原始观测；发布包另有`53/53`项边界、哈希与空项目安装检查。这些附加检查不并入核心`574`条基线。

## 本轮新增与修复

- 新增专用 Blackboard Schema Editor，可增删和编辑 Bool、Int、Float、String、Vector2 声明，支持即时重复/空键验证、动态键策略、撤销重做和持久化。
- 新增独立形状/图标编码和色盲友好配色；低缩放和灰度下仍可通过几何轮廓识别类型，并支持 `Ctrl+F`、`F3`、`Shift+F3` 键盘导航。
- 消除 GraphEdit 原生辅助线与自定义线的双线显示。自定义模式隐藏原生持久层，保留拖拽预览、自定义命中、右键断开和撤销重做；可独立切回原生模式。
- Runner 新增可独立关闭的拓扑缓存，对节点、子节点和 Decorator 查找建立索引；树替换时自动失效，所有原有运行语义测试保持通过。
- Blackboard节点Inspector新增类型化Schema key picker、自由输入回退、严格引用检查、引用位置索引与未使用键分析。
- 缓存改为每次外部Tick校验精确拓扑签名；同数量换序、改父级、Decorator归属变化和同ID节点资源替换都会自动失效。
- 完成0.9.0可分发ZIP、MIT许可证、SHA-256清单与空Godot 4.6项目安装验证；测试证据目录使用`.gdignore`隔离资源扫描。

- 新增 Parallel、Random Selector、Repeat 和 Wait，并完成编辑器、资源校验、运行时记忆、重置和示例集成。
- Inspector 使用节点类型化控件编辑 Action、Condition、Selector、Parallel、Random Selector、Repeat、Wait 和 Decorator；Advanced JSON 保留兼容入口。
- Condition 支持与 Decorator 一致的 exists、not_exists、is_true、is_false、equals、not_equals 和大小比较。
- 新增 `BTBlackboardSchema` 与 `BTBlackboardEntry`，支持 Bool、Int、Float、String、Vector2、默认值、类型校验、动态键兼容和资源持久化。
- 新增编辑器专用 Live Blackboard 四列表格，显示 Key、运行时 Type、Value 和 Schema 状态；游戏内不显示行为树 UI。
- 复杂守卫树绑定 11 个声明键，并使用 Repeat、Random Selector、Parallel 和 Wait；修复右侧 Wait 参数被重复字段覆盖。
- 自动布局改为按每层最大卡片高度动态分层，修复带多个 Decorator 的 36 节点树重叠；Fit 最小缩放支持完整大树。
- 玩家和敌人的受伤/重生反馈改为节点本地状态机，消除场景提前关闭时的 `SceneTreeTimer` 泄漏。
- 修复低缩放搜索定位混用画布坐标与缩放后 `scroll_offset` 的问题；远距目标现在会真正进入 GraphEdit 视口。
- Runtime Path 与 Selection 拆成独立可滚动行，顶栏 Live Debug 长文本使用省略和完整 tooltip，修复 1600×900 下路径互相覆盖。
- 确认 PowerShell `2>&1 | Tee-Object` 可能触发 Godot 4.6 console 退出期原生崩溃；最终回归使用 Godot `--log-file` 的绝对路径，直接启动进程，不接原生管道。

## 显示优化自动结果

自动基准使用相同生成规则的 31、121 和 364 节点树。原始数据位于 `display_optimization_raw.csv`、`branch_dimming_results.csv` 和 `enhanced_minimap_results.csv`。

| 方法（364 节点） | 实测结果 | 几何/程序指标 |
| --- | ---: | ---: |
| Compact Cards | 13,650,000 → 6,022,016 px² | 卡片总面积降低 55.9% |
| Semantic Zoom | 6 → 1 个代表信息字段 | 字段降低 83.3% |
| Search Highlight | 363/364 个非目标节点降噪 | 99.7% |
| Subtree Focus | 364 → 9 个可见节点 | 降低 97.5%，本轮重建 654.289 ms |
| Subtree Collapse | 364 → 2 个可见入口 | 降低 99.5%，本轮重建 275.309 ms |
| Fisheye | 目标节点 1.20× | 局部增加 20.0%，不减少节点 |
| Branch Dimming | 361/364 个非活动节点淡化 | 99.2%，alpha 1.00 vs 0.24 |
| Enhanced Minimap | 364/364 节点总览 | 230×150，覆盖率 100% |

本轮364节点分支淡化首次应用为45.037 ms，淡化361/364节点；增强小地图尺寸为230×150并覆盖364/364节点，开关周期为126.793 ms。耗时受机器负载、Godot帧调度和当前功能数量影响，应报告原始值与运行环境，不应视为跨设备常数。

### 可玩241节点树的生态显示实验

为了让实验直接对应游戏开发，本轮还使用实际驱动复杂敌人的`complex_display_tree_241.tres`。资源包含241个节点：202张画布卡片和39个附着Decorator。环境为Godot 4.6、OpenGL Compatibility、NVIDIA GeForce RTX 5070 Laptop GPU和1600×900 SubViewport。六个条件各预热3次并记录30次，条件顺序循环平衡，使每个条件在六个序位上各出现5次，共180条原始观测。

| 条件 | 可见卡片 | 卡片数降低 | 卡片面积降低 | 图边界面积降低 | 淡化卡片 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Baseline | 202 | 0.00% | 0.00% | 0.00% | 0 |
| Compact Cards | 202 | 0.00% | 57.93% | 5.78% | 0 |
| Optimized Overview | 202 | 0.00% | 89.48% | 8.59% | 0 |
| Optimized Search | 202 | 0.00% | 89.48% | 8.59% | 201 |
| Subtree Focus | 32 | 84.16% | 93.04% | 63.37% | 0 |
| Context Collapse | 43 | 78.71% | 90.46% | 20.99% | 0 |

六个条件均为零卡片重叠，且实验前后保存的资源位置完全一致，因此没有重现“缩小后所有节点叠在一起”的问题。各条件执行不同操作，故其耗时不作共同排名。独立的同任务拖拽实验让同一卡片沿固定路径处理240个指针采样点，一次预热后各测5轮；中位总时间从1124.693 ms降至825.571 ms，每采样点从4.686 ms降至3.440 ms，降低26.60%。该数据说明固定编写操作减少了重复处理，不证明用户必然感到更流畅。

## 评价边界与人工实验

面积、可见节点和信息字段的减少证明界面几何或信息密度发生变化，**不能单独证明人的可读性或认知负担得到改善**。Fisheye 与 Minimap 的价值更应通过目标定位时间、误选、缩放/平移次数和主观评分评价。

人体实验协议、固定121节点练习树、241节点正式树、持续刷新Live Debug工具、分析脚本和12人 × 18次试验的216行公式工作簿已经完成。实验对比Baseline、Compact、Collapse、Fisheye、Search和Minimap，分别测试按游戏需求定位Action、报告七节点活动路径和把指定Decorator持续时间增加0.10秒。六组Action/路径目标与六组Decorator目标经过平衡，使每个方法--目标配对在整个样本中恰好出现两次。主要结果为180秒上限的完成时间和成功率；次要结果为错误、缩放、平移、总导航以及1至7分可读性与认知负担。参与者尚未招募，当前为0/216条观测，因此报告只陈述客观显示结果、程序正确性和实验准备状态，不声称已经证明用户体验提升。

## 运行时缓存实验

最终回归使用31、121、364节点固定树，以及1、10、50个Runner；每个缓存开关组合预热后测7次并比较中位数。精确拓扑校验后的31节点收益为15.98%–26.46%，121节点为52.61%–56.02%，364节点为76.65%–78.00%。全部缓存/非缓存执行都返回相同SUCCESS；整树替换、同数量换序、改父级、Decorator归属变化、同ID资源实例替换和关闭缓存回退均通过。小树收益下降是每Tick执行O(n)精确签名校验的成本，换取原地拓扑变化安全。该结果只描述当前Windows、Godot 4.6和固定负载，不是跨机器常数。原始CSV和公式工作簿位于`testgame/testgame/test_results/runtime_profile.csv`与`research/display_optimization/behavior_tree_unattended_run_evidence.xlsx`。
