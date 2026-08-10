# 当前论文初稿已引用资料

本目录只收录当前中英文论文初稿参考文献表中已经出现的来源。判定依据是：

- `thesis_draft/english/bibliography.tex`
- `thesis_draft/chinese/bibliography.tex`

当前共包含 **11 项学术来源**和 **3 项官方技术资料**。其中 5 篇论文已取得并核对公开全文，放在 `papers/`；其余 6 项没有确认到可合法直接下载的公开全文，因此只提供 DOI/出版页，不用错误文件或摘要页冒充论文。

## 一、已引用学术来源

| # | 文献 | 年份 | DOI / 出版页 | 公开全文地址 | 本地状态 | 在项目中的用途 |
| ---: | --- | ---: | --- | --- | --- | --- |
| 1 | Behavior Trees in Robotics and AI: An Introduction | 2018 | https://doi.org/10.1201/9780429489105 | 未确认公开全文 | 书籍，未下载 | SUCCESS/FAILURE/RUNNING、组合节点和行为树理论基础。 |
| 2 | Generalized Fisheye Views | 1986 | https://doi.org/10.1145/22339.22342 | 未确认公开全文 | 未下载 | Fisheye / Focus+Context 的兴趣度和局部放大依据。 |
| 3 | A Focus+Context Technique Based on Hyperbolic Geometry for Visualizing Large Hierarchies | 1995 | https://doi.org/10.1145/223904.223956 | 未确认公开全文 | 未下载 | 焦点与周边上下文同时保留的设计依据。 |
| 4 | A Review of Overview+Detail, Zooming, and Focus+Context Interfaces | 2008 | https://doi.org/10.1145/1456650.1456652 | 未确认公开全文 | 未下载 | 比较鱼眼、小地图、缩放和 Overview+Detail 的任务适用性。 |
| 5 | A Comparative Evaluation on Tree Visualization Methods for Hierarchical Structures with Large Fan-outs | 2010 | https://doi.org/10.1145/1753326.1753359 | https://www.microsoft.com/en-us/research/publication/comparative-evaluation-tree-visualization-methods-hierarchical-structures-large-fan-outs/ | `papers/Song_2010_Large_Fanout_Tree_Visualization.pdf` | Multi-column Layout、大扇出组合节点和对比实验设计。 |
| 6 | Developing and Evaluating Quilts for the Depiction of Large Layered Graphs | 2011 | https://doi.org/10.1109/TVCG.2011.187 | https://pubmed.ncbi.nlm.nih.gov/22034346/ | `papers/Bae_Watson_2011_Quilts_Large_Layered_Graphs.pdf` | Path Summary、复杂层级图的紧凑辅助表示和路径任务。 |
| 7 | Efficient Methods and Readily Customizable Libraries for Managing Complexity of Large Networks | 2018 | https://doi.org/10.1371/journal.pone.0197238 | https://journals.plos.org/plosone/article/file?id=10.1371/journal.pone.0197238&type=printable | `papers/Dogrusoz_et_al_2018_Large_Network_Complexity.pdf` | 子树折叠、隐藏/显示、局部布局和复杂网络管理。 |
| 8 | Layout Adjustment and the Mental Map | 1995 | https://doi.org/10.1006/jvlc.1995.1010 | 未确认公开全文 | 未下载 | Stable Incremental Layout 和编辑后位置连续性。 |
| 9 | Tidier Drawings of Trees | 1981 | https://doi.org/10.1109/TSE.1981.234519 | 未确认公开全文 | 未下载 | 自动树布局、层级间距和子树不重叠。 |
| 10 | SpaceTree: Supporting Exploration in Large Node Link Tree, Design Evolution and Empirical Evaluation | 2002 | https://doi.org/10.1109/INFVIS.2002.1173148 | https://drum.lib.umd.edu/bitstreams/4712e278-dc6f-483a-92d3-849acf631914/download | `papers/Plaisant_et_al_2002_SpaceTree.pdf` | 选择性展开、隐藏分支摘要、动态布局、搜索和重访任务。 |
| 11 | The Eyes Have It: A Task by Data Type Taxonomy for Information Visualizations | 1996 | https://doi.org/10.1109/VL.1996.545307 | https://drum.lib.umd.edu/bitstreams/5f7e640d-1669-496a-90a5-85737df97e88/download | `papers/Shneiderman_1996_The_Eyes_Have_It.pdf` | Overview first、Zoom/filter、Details on demand、Search 和淡化。 |

## 二、已引用官方技术资料

| # | 资料 | 链接 | 用途 |
| ---: | --- | --- | --- |
| 12 | Godot GraphEdit Class Reference | https://docs.godotengine.org/en/stable/classes/class_graphedit.html | 2D 节点画布、连接、缩放、滚动和 Minimap 实现。 |
| 13 | Godot EditorPlugin Class Reference | https://docs.godotengine.org/en/stable/classes/class_editorplugin.html | 插件注册、底部面板和编辑器生命周期。 |
| 14 | Behavior Tree in Unreal Engine: Overview | https://dev.epicgames.com/documentation/en-us/unreal-engine/behavior-tree-in-unreal-engine---overview | Blackboard、Decorator 和编辑器 Live Debug 工作流对照。 |

## 三、目录说明

- `papers/`：已核对的 5 篇公开论文 PDF。
- `links/`：11 项学术来源和 3 项官方资料的 Windows Internet Shortcut，可双击在浏览器打开。
- `references.bib`：与论文初稿一致的 BibTeX 记录。
- `manifest_sha256.csv`：本地 PDF 的文件大小、页数和 SHA-256，用于证明文件完整性。

## 四、使用注意

1. “未下载”只表示当前没有确认到合法公开全文，不表示该文献不存在。可通过 Warwick Library、作者主页或出版商机构访问补充。
2. DOI 是长期标识符；出版商可能拒绝自动请求，但通常仍可在浏览器中打开。
3. 本目录没有包含 `reference_library/02_additional_recommendations` 中尚未写入初稿的推荐文献，避免混淆“已引用”和“候选引用”。
4. 引用时以 `references.bib` 和论文最终参考文献格式为准，不以 PDF 文件名作为正式题名。
