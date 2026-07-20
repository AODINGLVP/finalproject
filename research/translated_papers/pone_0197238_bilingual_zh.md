# Efficient Methods and Readily Customizable Libraries for Managing Complexity of Large Networks 对照翻译

原论文文件：

```text
research/pone.0197238.pdf
```

在线链接：[https://doi.org/10.1371/journal.pone.0197238](https://doi.org/10.1371/journal.pone.0197238)

## 基本信息

| English | 中文 |
| --- | --- |
| Efficient methods and readily customizable libraries for managing complexity of large networks | 管理大型网络复杂度的高效方法与易定制库 |
| Ugur Dogrusoz, Alper Karacelik, Ilkin Safarli, Hasan Balci, Leonard Dervishi, Metin Can Siper | Ugur Dogrusoz 等 |
| Published in PLOS ONE | 发表于 PLOS ONE |

## 摘要对照翻译

| English | 中文 |
| --- | --- |
| One common problem in visualizing real-life networks, including biological pathways, is the large size of these networks. | 可视化真实网络时，一个常见问题是网络规模很大，生物通路网络也是如此。 |
| Users often face slow, non-scaling operations due to network size, or a “hairball” network that hinders effective analysis. | 由于网络规模过大，用户经常会遇到操作缓慢、无法扩展的问题，或者面对像“毛线团”一样混乱的网络，从而妨碍有效分析。 |
| One useful method for reducing complexity is hierarchical clustering and nesting, with expand-collapse operations on demand. | 降低复杂度的一种有效方法是层次聚类和嵌套，并根据需要执行展开-折叠操作。 |
| Another method is hiding currently unnecessary details and gradually revealing them on demand. | 另一种方法是隐藏当前不必要的细节，并在需要时逐步显示。 |
| Major challenges include efficiency and maintaining the user’s mental map of the drawing. | 主要挑战包括操作效率，以及在图变化后保持用户对布局的心理地图。 |
| The authors developed incremental layout methods and open-source JavaScript libraries for expand-collapse and hide-show operations. | 作者开发了增量布局方法，以及用于展开-折叠、隐藏-显示操作的开源 JavaScript 库。 |

## 研究动机对照翻译

| English | 中文 |
| --- | --- |
| Large networks can be difficult to analyze because displaying all nodes and edges at once overwhelms the user. | 大型网络难以分析，因为同时显示所有节点和边会让用户负担过重。 |
| Complexity management techniques reduce what is visible without permanently removing information. | 复杂度管理技术会减少当前可见内容，但不会永久删除信息。 |
| Expand-collapse allows users to hide internal details of a compound node and reveal them later. | 展开-折叠允许用户隐藏复合节点的内部细节，并在之后重新显示。 |
| Hide-show allows users to temporarily remove currently irrelevant elements from the view. | 隐藏-显示允许用户临时移除当前不相关的元素。 |

## 方法对照翻译

| English | 中文 |
| --- | --- |
| The paper develops specialized incremental layout algorithms for complexity management operations. | 论文提出了专门用于复杂度管理操作的增量布局算法。 |
| These algorithms aim to preserve the user’s mental map when parts of the graph are collapsed, expanded, hidden, or shown. | 这些算法的目标是在图的一部分被折叠、展开、隐藏或显示时，尽量保持用户的心理地图。 |
| The authors implement these methods as plug-ins for Cytoscape.js, a web-based graph visualization library. | 作者将这些方法实现为 Cytoscape.js 的插件，Cytoscape.js 是一个基于 Web 的图可视化库。 |
| The operations make large networks smaller and more suitable for interactive visual analysis. | 这些操作可以让大型网络变得更小，更适合交互式视觉分析。 |

## 结果对照翻译

| English | 中文 |
| --- | --- |
| The proposed methods support efficient expand-collapse and hide-show operations. | 作者提出的方法支持高效的展开-折叠和隐藏-显示操作。 |
| They help preserve the user’s mental map by updating layouts incrementally instead of completely redrawing the graph. | 这些方法通过增量更新布局，而不是完全重绘图，从而帮助保持用户的心理地图。 |
| The software libraries make these complexity management techniques available to tool developers. | 这些软件库使工具开发者能够方便地使用这些复杂度管理技术。 |

## 结论对照翻译

| English | 中文 |
| --- | --- |
| Complexity management is important for interactive visualization of large networks. | 复杂度管理对于大型网络的交互式可视化非常重要。 |
| Expand-collapse and hide-show operations can make large graphs more manageable. | 展开-折叠和隐藏-显示操作可以让大型图更容易管理。 |
| Preserving the mental map is essential when layout changes occur. | 当布局发生变化时，保持用户的心理地图非常关键。 |
| Open-source implementations help developers integrate these techniques into real visualization tools. | 开源实现可以帮助开发者把这些技术集成到真实可视化工具中。 |

## 对本项目的启发

这篇论文和你的行为树插件关系非常直接。行为树虽然是树，不是一般复杂网络，但当节点数量增加后，同样会出现视觉复杂度问题。

可以应用到你的插件中：

- 实现子树折叠与展开。
- 折叠后用一个 summary node 表示整个子树。
- 展开或折叠时尽量保持其他节点位置不变。
- 使用动画过渡，避免用户迷失。
- 支持隐藏非当前执行分支，只突出 Live Debug 当前路径。
- 保留用户 mental map，避免每次自动布局都让节点大幅跳动。

这篇论文可以作为你实现“节点折叠”和“大树可读性优化”的主要参考文献。
