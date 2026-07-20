# Developing and Evaluating Quilts for the Depiction of Large Layered Graphs 对照翻译

原论文文件：

```text
research/Developing_and_Evaluating_Quilts_for_the_Depiction_of_Large_Layered_Graphs.pdf
```

在线链接：[https://doi.org/10.1109/TVCG.2011.187](https://doi.org/10.1109/TVCG.2011.187)

## 基本信息

| English | 中文 |
| --- | --- |
| Developing and Evaluating Quilts for the Depiction of Large Layered Graphs | 面向大型分层图显示的 Quilts 方法开发与评价 |
| Juhee Bae and Ben Watson | Juhee Bae、Ben Watson |
| Keywords: Graph drawing, layered graphs, matrix based depiction, node-link diagram | 关键词：图绘制、分层图、基于矩阵的表示、节点-连线图 |

## 摘要对照翻译

| English | 中文 |
| --- | --- |
| Traditional layered graph depictions such as flow charts are in wide use. | 传统分层图表示方式，例如流程图，被广泛使用。 |
| Yet as graphs grow more complex, these depictions can become difficult to understand. | 然而，随着图结构变得更加复杂，这些表示方式会变得难以理解。 |
| Quilts are matrix-based depictions for layered graphs designed to address this problem. | Quilts 是一种面向分层图的基于矩阵的表示方法，旨在解决这一问题。 |
| The authors improve Quilts by developing three design alternatives, and then compare the best alternative to node-link and matrix depictions. | 作者首先提出三种 Quilts 设计方案并进行改进，然后将其中最佳方案与节点-连线图和矩阵图进行比较。 |
| Results show that users can find paths through graphs significantly faster with Quilts than with node-link or matrix diagrams. | 结果显示，相比节点-连线图或矩阵图，用户使用 Quilts 能显著更快地在图中寻找路径。 |
| This advantage is even greater in large graphs. | 在大型图中，这种优势更加明显。 |

## 研究动机对照翻译

| English | 中文 |
| --- | --- |
| Node-link diagrams are easy to read and understand, but as graphs become more complex, they suffer from link overlap and occlusion. | 节点-连线图易于阅读和理解，但当图变得复杂时，会出现连线重叠和遮挡问题。 |
| Matrices avoid link occlusion by assigning a unique spatial position to each possible link. | 矩阵图通过给每条可能连接分配唯一空间位置，避免了连线遮挡问题。 |
| However, matrices can be less intuitive for users who are used to node-link diagrams. | 然而，对于习惯节点-连线图的用户来说，矩阵图可能不够直观。 |
| Quilts attempt to combine advantages of matrix-based depictions with layered graph readability. | Quilts 试图结合矩阵表示的优势和分层图的可读性。 |

## 方法对照翻译

| English | 中文 |
| --- | --- |
| The paper focuses on layered graphs, where nodes are organized into layers and links connect nodes across layers. | 论文关注分层图，即节点被组织到不同层中，连接则跨层连接节点。 |
| The authors compare different ways of showing skip links, links that do not simply connect to the next layer. | 作者比较了几种显示 skip link 的方式，也就是那些不只是连接到下一层的跨层连接。 |
| They test color-only, text-only, and mixed color-and-text depictions. | 他们测试了仅颜色、仅文本、颜色加文本混合三种显示方式。 |
| After selecting the best Quilt design, they compare it with node-link diagrams and centered matrices. | 在选择最佳 Quilts 设计后，作者将其与节点-连线图和居中矩阵图进行比较。 |

## 实验结果对照翻译

| English | 中文 |
| --- | --- |
| Color-only skip link depiction was significantly slower and less accurate for path finding. | 仅使用颜色表示 skip link 时，路径查找速度显著更慢，准确率也更低。 |
| In some cases, the mixed depiction offered an advantage over text-only depiction. | 在某些情况下，颜色与文本混合的表示方式优于仅文本表示。 |
| In the second study, users found paths faster with Quilts than with node-link diagrams or matrices. | 在第二个实验中，用户使用 Quilts 查找路径的速度快于节点-连线图或矩阵图。 |
| The speed advantage became larger in 200-node graphs. | 在 200 个节点的图中，这种速度优势更明显。 |

## 结论对照翻译

| English | 中文 |
| --- | --- |
| Traditional node-link depictions are not always the best choice for large layered graphs. | 对于大型分层图，传统节点-连线表示并不总是最佳选择。 |
| Matrix-inspired layouts can improve path-finding performance when graph complexity increases. | 当图复杂度增加时，受矩阵启发的布局可以提高路径查找效率。 |
| The paper shows the importance of evaluating visual encodings through user studies. | 论文说明了通过用户研究评价视觉编码的重要性。 |

## 对本项目的启发

行为树也是一种分层结构。虽然行为树通常比一般图更规则，但当节点数量增加后，传统节点-连线显示仍然会出现拥挤、路径难找、连线难读的问题。

可以应用到你的插件中：

- 对 Live Debug 当前执行路径提供独立的“路径视图”，不一定只依赖整棵树高亮。
- 对大型行为树提供紧凑的层级/矩阵式概览。
- 对执行路径、失败 Decorator、当前节点使用颜色 + 文本混合编码，而不是只用颜色。
- 在论文中说明：传统节点-连线图在大规模分层结构中有局限，因此本项目考虑折叠、紧凑显示和路径强调。
