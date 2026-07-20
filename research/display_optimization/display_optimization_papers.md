# 节点折叠、紧凑显示与大树可读性优化相关论文整理

## 说明

本文件整理与行为树编辑器显示优化相关的论文和资料，重点关注：

- 大规模树结构可视化
- 节点折叠与展开
- Focus+Context / Fisheye 视图
- Mac Dock 式局部放大
- 大型 node-link diagram 可读性
- 复杂图的隐藏、折叠、聚合与保持 mental map

这些资料可以作为后续改进 Godot 行为树插件显示方式的理论依据。

## 1. A Focus+Context Technique Based on Hyperbolic Geometry for Visualizing Large Hierarchies

链接：

https://doi.org/10.1145/223904.223956

备用页面：

https://www.researchgate.net/publication/2540931_A_FocusContext_Technique_Based_on_Hyperbolic_Geometry_for_Visualizing_Large_Hierarchies

作者：

John Lamping, Ramana Rao, Peter Pirolli

年份：

1995

简介：

这是一篇经典的 Focus+Context 层级结构可视化论文。它提出使用双曲几何来显示大型层级结构，让用户关注的区域占据更多屏幕空间，同时仍保留整体上下文。用户可以通过点击或拖动改变焦点，系统会平滑过渡视图。

和本项目的关系：

这篇论文非常适合支撑导师提到的“像 Mac Dock 一样，鼠标靠近的节点变大，远处节点变小”的想法。行为树本质上是层级结构，因此可以借鉴这种 Focus+Context 思路：当前关注节点显示完整信息，周围节点压缩显示，远处节点只显示简略状态。

可用于插件的设计点：

- 鼠标悬停节点时，该节点和附近节点放大。
- 当前执行路径保持详细显示，其他分支压缩。
- 保留全树上下文，而不是只显示局部子树。

## 2. Generalized Fisheye Views

链接：

https://doi.org/10.1145/22339.22342

作者：

George W. Furnas

年份：

1986

简介：

这是 Fisheye View 的基础论文之一。核心思想是根据信息的重要程度和距离焦点的远近决定显示细节：离焦点越近、越重要的信息显示越详细；离焦点越远的信息显示越简略或隐藏。

和本项目的关系：

行为树节点很多时，完整显示每个节点会导致界面拥挤。Fisheye View 可以作为“紧凑显示 + 焦点展开”的理论基础。

可用于插件的设计点：

- 当前鼠标悬停节点显示完整参数。
- 当前执行节点和父链条显示完整内容。
- 非重点分支只显示标题和类型颜色。
- 根据节点与焦点距离动态调整显示大小。

## 3. A Framework for Focus+Context Visualization

链接：

https://www.sciweavers.org/publications/framework-focuscontext-visualization

作者：

Staffan Björk, Lars Erik Holmquist, Johan Redström

年份：

1999

简介：

这篇论文对 Focus+Context 技术进行了系统化总结，提出用于描述和构建 Focus+Context 可视化的框架。它强调同时显示细节和概览，而不是在 detail view 和 overview 之间频繁切换。

和本项目的关系：

行为树编辑器既需要看清某个节点的参数，也需要理解整棵树的结构。Focus+Context 框架可以帮助设计一种“当前节点详细、其他节点简略”的编辑模式。

可用于插件的设计点：

- 不单独打开属性窗口，而是在节点图中直接展开焦点节点。
- 焦点节点显示参数、Decorator、运行状态。
- 上下文节点保持可见，但只显示标题或图标。

## 4. Collapsible Cylindrical Trees: A Fast Hierarchical Navigation Technique

链接：

https://doi.org/10.1109/INFVIS.2001.963284

备用页面：

https://www.researchgate.net/publication/221006096_Collapsible_Cylindrical_Trees_A_Fast_Hierarchical_Navigation_Technique

作者：

Raimund Dachselt, Jürgen Ebert

年份：

2001

简介：

这篇论文提出 Collapsible Cylindrical Trees，一种用于中等规模树结构的快速导航技术。它通过动态显示或隐藏子节点，在细节和上下文之间取得平衡。重点是通过折叠和展开减少层级结构的视觉复杂度。

和本项目的关系：

行为树是一种典型树结构。节点折叠是导师明确提到的方向之一，因此这篇论文可以作为“子树折叠/展开”的理论依据。

可用于插件的设计点：

- 行为树节点可以折叠其子树。
- 折叠后的节点显示子节点数量。
- 点击节点展开局部分支。
- 只展开当前正在编辑或正在执行的子树。

## 5. A Comparative Evaluation on Tree Visualization Methods for Hierarchical Structures with Large Fan-outs

链接：

https://www.microsoft.com/en-us/research/publication/comparative-evaluation-tree-visualization-methods-hierarchical-structures-large-fan-outs/

作者：

Hyunjoo Song, Bohyoung Kim, Bongshin Lee, Jinwook Seo

年份：

2010

简介：

这篇 CHI 论文比较了大 fan-out 层级结构的几种树可视化方法。传统 node-link tree 在子节点太多时会迅速拥挤。论文提出并比较了 list view 和 multi-column interface，实验结果显示 multi-column 在浏览和理解大 fan-out 树结构时更快，用户也更喜欢。

和本项目的关系：

行为树中 Selector 或 Sequence 可能有很多子节点，传统上下树布局会变宽或变乱。这篇论文可以支撑“横向多列布局”“分栏显示子节点”等设计。

可用于插件的设计点：

- 对子节点很多的 Selector 使用多列布局。
- 大分支可以用列表或分组方式显示。
- 自动布局不一定只用传统树状布局，可以针对大 fan-out 节点做特殊显示。

## 6. The Impact of Context-Aware Fisheye Models on Understanding Business Processes

链接：

https://doi.org/10.1016/j.im.2006.10.004

页面：

https://www.sciencedirect.com/science/article/abs/pii/S0378720606001108

作者：

相关页面未完整显示全部作者信息，可在 ScienceDirect 页面查看。

年份：

2007

简介：

这篇论文通过实验研究 context-aware fisheye model 对数据流图理解的影响。结果显示，在业务流程图理解任务中，使用 fisheye 方式的参与者表现优于传统展示方式，尤其对复杂任务和经验较少的用户有帮助。

和本项目的关系：

行为树和数据流图都属于节点连接图。该论文可以支持一个重要观点：Focus+Context 不只是视觉效果，而是可能提高用户理解复杂图的效率。

可用于插件的设计点：

- 用实验比较普通行为树显示和 fisheye 行为树显示。
- 指标可以是查找节点时间、理解执行路径时间、修改条件所需时间。
- 将 fisheye 作为毕业设计中的可评价创新点。

## 7. Motion to Support Rapid Interactive Queries on Node-Link Diagrams

链接：

https://doi.org/10.1145/1008722.1008724

页面：

https://scholars.unh.edu/ccom/1006/

作者：

Colin Ware, Robert Bobrow

年份：

2004

简介：

这篇论文研究在大型 node-link diagram 中使用动态效果辅助用户快速识别相关子图。作者提出鼠标触碰节点时，使该节点及其相关子图产生运动高亮。实验表明，运动高亮比静态高亮更快且错误更少。

和本项目的关系：

行为树 Live Debug 目前使用静态颜色高亮当前执行链。该论文说明可以进一步使用轻微动画或脉冲效果强化当前节点和执行路径。

可用于插件的设计点：

- 当前执行节点轻微闪烁或呼吸动画。
- 鼠标悬停节点时，高亮其父链和子树。
- Decorator 失败时，用短暂动画提示失败位置。

## 8. Efficient Methods and Readily Customizable Libraries for Managing Complexity of Large Networks

链接：

https://pmc.ncbi.nlm.nih.gov/articles/PMC5973603/

作者：

论文页面可查看完整作者信息。

年份：

2018

简介：

这篇论文讨论大型网络可视化中的复杂度管理，重点包括 expand-collapse、hide-show、布局重排以及保持用户 mental map。它指出，如果展开/折叠后布局完全变化，用户会迷失原有认知地图。

和本项目的关系：

行为树插件如果加入折叠、展开、隐藏分支，就必须考虑布局变化不要太剧烈，否则用户会找不到原来的节点位置。

可用于插件的设计点：

- 折叠/展开时尽量保持节点相对位置。
- 使用动画过渡，避免突然跳动。
- 展开子树时只局部重排，避免整棵树大幅移动。

## 9. A Multi-Graph Approach to Complexity Management in Interactive Graph Visualization

链接：

https://doi.org/10.1016/j.cag.2005.10.015

页面：

https://www.sciencedirect.com/science/article/abs/pii/S0097849305002128

作者：

Ugur Dogrusoz, B. Genc

年份：

2006

简介：

这篇论文提出一种 multi-graph 方法，用于交互式图可视化中的复杂度管理。它支持嵌套图、导航链接、ghosting、folding、隐藏不需要的图元素等操作。

和本项目的关系：

行为树可以看作具有嵌套结构的图。子树折叠、隐藏非当前分支、显示 ghost node 都可以借鉴该论文中的复杂度管理思想。

可用于插件的设计点：

- 折叠子树后，用一个 summary node 代表内部结构。
- 被隐藏的分支可以用半透明 ghost 显示。
- 当前编辑区域和整体行为树之间建立导航链接。

## 10. On the Readability of Graphs Using Node-Link and Matrix-Based Representations

链接：

https://doi.org/10.1057/palgrave.ivs.9500092

备用页面：

https://www.researchgate.net/publication/48415749_On_the_Readability_of_Graphs_Using_Node-Link_and_Matrix-Based_Representations_A_Controlled_Experiment_and_Statistical_Analysis

作者：

Mohammad Ghoniem, Jean-Daniel Fekete, Philippe Castagliola

年份：

2005

简介：

这篇论文通过控制实验比较 node-link diagram 和矩阵表示在不同图任务中的可读性。结果显示，当图变大或变密时，node-link diagram 在许多任务上表现会下降，而矩阵方式在部分任务中更好。

和本项目的关系：

行为树插件目前采用 node-link diagram。该论文可以支撑一个背景论点：节点连接图在规模变大时会出现可读性问题，因此需要折叠、紧凑显示、焦点显示等优化。

可用于插件的设计点：

- 在论文中说明为什么大规模行为树需要显示优化。
- 作为评价实验设计参考。
- 用节点数量增加时的可读性下降作为问题背景。

## 11. Developing and Evaluating Quilts for the Depiction of Large Layered Graphs

链接：

https://doi.org/10.1109/TVCG.2011.187

页面：

https://pubmed.ncbi.nlm.nih.gov/22034346/

作者：

Juhee Bae, Ben Watson

年份：

2011

简介：

这篇论文研究大型分层图的显示方式。传统 flow chart 或 node-link 图在复杂时难以理解，Quilts 使用类似矩阵的方式显示大型分层图。实验显示，在大型图中的路径查找任务上，Quilts 比 node-link 和 matrix 更快。

和本项目的关系：

行为树是分层结构，且执行路径查找是调试中的重要任务。虽然本项目不一定要实现 Quilts，但这篇论文能说明传统 node-link 不是唯一方案，大树可以考虑更紧凑的层级布局。

可用于插件的设计点：

- 对 Live Debug 路径使用独立的紧凑路径视图。
- 大树调试时突出路径，而不是显示所有节点细节。
- 可以将行为树某些层级压缩成行列结构。

## 12. Fluidly Revealing Information: A Survey of Un/foldable Data Visualizations

链接：

https://doi.org/10.1111/cgf.70152

页面：

https://onlinelibrary.wiley.com/doi/10.1111/cgf.70152

作者：

Bludau 等，具体作者可在 Wiley 页面查看。

年份：

2025

简介：

这是一篇关于可展开/可折叠数据可视化的综述论文。它整理了多种 un/folding 技术，包括层级数据、node-link diagram、treemap、focus+context 等。论文特别提到，对于 node-link diagram 和层级数据，展开子层级、聚焦特定元素、变换表示方式和动画过渡都是常见策略。

和本项目的关系：

这篇综述很适合作为毕业设计中“节点折叠与展开设计”的近期参考文献。它可以帮助说明折叠/展开不是简单隐藏节点，而是一类成熟的信息可视化技术。

可用于插件的设计点：

- 折叠子树时使用动画展开。
- 从简略节点平滑展开到详细节点。
- 支持同一行为树在详细视图和紧凑视图之间切换。

## 13. Block-based or Graph-based? Why Not Both? Designing a Hybrid Programming Environment for End-users

链接：

https://doi.org/10.1093/iwc/iwaf028

页面：

https://academic.oup.com/iwc/article/38/1/40/8151473

作者：

论文页面可查看完整作者信息。

年份：

2025

简介：

这篇论文研究终端用户编程环境中 block-based 和 graph-based 两种可视化编程方式的优缺点，并提出混合式编程环境。实验发现，虽然图式编程有吸引力，但块式表示在某些任务中更容易让终端用户成功完成任务。

和本项目的关系：

行为树插件面向的用户可能包括非程序员。该论文可以帮助说明：节点图虽然直观，但也容易产生视觉负担，因此需要合理压缩、分组和限制信息量。

可用于插件的设计点：

- 节点不要显示过多参数，默认应保持简洁。
- 复杂参数放入 Inspector，节点图中只显示核心信息。
- 可以提供图形行为树 + 简略文本结构视图的混合界面。

## 对本项目最有价值的方向总结

### A. 节点折叠和展开

参考：

- Collapsible Cylindrical Trees
- Efficient Methods and Readily Customizable Libraries for Managing Complexity of Large Networks
- Fluidly Revealing Information

适合实现：

- 折叠子树
- 展开当前分支
- 保持布局稳定
- 折叠节点显示子节点数量

### B. Mac Dock 式悬停放大

参考：

- Generalized Fisheye Views
- A Focus+Context Technique Based on Hyperbolic Geometry
- The Impact of Context-Aware Fisheye Models

适合实现：

- 鼠标悬停节点展开详情
- 当前节点放大，周围节点缩小
- 当前执行路径保持详细显示

### C. 大树可读性优化

参考：

- A Comparative Evaluation on Tree Visualization Methods for Hierarchical Structures with Large Fan-outs
- On the Readability of Graphs Using Node-Link and Matrix-Based Representations
- Developing and Evaluating Quilts

适合实现：

- 多列布局
- Compact Mode
- 大树只显示标题和类型
- 对执行路径单独显示

### D. Live Debug 视觉增强

参考：

- Motion to Support Rapid Interactive Queries on Node-Link Diagrams
- Focus+Context 相关论文

适合实现：

- 当前执行节点动画高亮
- Decorator 失败节点闪烁提示
- 鼠标悬停时高亮相关子树

## 推荐用于毕业设计的表述

可以将显示优化部分概括为：

> 传统节点连接图在节点数量增加时容易出现视觉拥挤、连线交叉、细节过载等问题。针对行为树编辑器，本项目参考 Focus+Context、Fisheye View 和 Collapsible Tree 等信息可视化技术，设计节点折叠、紧凑显示和焦点展开机制，以提升大规模行为树的可读性和编辑效率。

## 推荐优先阅读顺序

1. Generalized Fisheye Views
2. A Focus+Context Technique Based on Hyperbolic Geometry for Visualizing Large Hierarchies
3. Collapsible Cylindrical Trees
4. A Comparative Evaluation on Tree Visualization Methods for Hierarchical Structures with Large Fan-outs
5. Motion to Support Rapid Interactive Queries on Node-Link Diagrams
6. Fluidly Revealing Information

