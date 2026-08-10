import fs from "node:fs/promises";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outputDir = "research/display_optimization";
const outputPath = `${outputDir}/behavior_tree_display_optimization_methods.xlsx`;
const previewPath = `${outputDir}/behavior_tree_display_optimization_methods_preview.png`;

const rows = [
  ["Fisheye / Focus+Context", "鼠标附近看不清，但又不想整体放大", "鼠标附近节点放大，远处节点保持上下文；当前最大倍率 1.20x", "Medium", "High", "Completed", "Good for large behavior trees because it preserves global context while enlarging local detail.", "Focus+context visualization, fisheye view"],
  ["Subtree Collapse / Expand", "节点太多，整棵树铺满屏幕", "折叠子树并显示隐藏节点数量与两层摘要", "Medium", "Very High", "Completed", "Directly addresses behavior tree readability and matches large-network complexity management research.", "Expand-collapse, hide-show, mental map preservation"],
  ["Compact Mode", "节点卡片太大，同屏显示节点太少", "节点只显示短标题和类型颜色；详细参数保留在 Inspector", "Low", "Very High", "Completed", "Fast to implement and easy to explain in the graduation project as a readability improvement.", "Compact display, semantic zoom"],
  ["Active Path Highlight", "Live Debug 时不知道 NPC 正在执行哪条链", "高亮 Root 到当前执行节点的整条链并显示叶节点状态", "Low", "Very High", "Completed", "Strongly supports behavior tree debugging and makes the plugin feel closer to UE behavior tree debugging.", "Path finding, live debugging"],
  ["Non-active Branch Dimming", "调试时视觉噪声太多", "运行时降低非当前分支透明度，只突出当前链条和失败条件", "Low", "High", "Completed", "Pairs well with active path highlight and is simple to validate visually.", "Focus+context, visual filtering"],
  ["Multi-column Layout", "一个 Selector 或 Sequence 有很多子节点时横向太长", "宽扇出分支自动分列，同时保留从左到右执行顺序", "Medium", "High", "Completed", "Supported by large fan-out tree visualization research; useful when selectors have many actions.", "Large fan-outs, multi-column interface"],
  ["Overview + Detail / Enhanced Minimap", "用户在大树中迷路", "230x150 小地图显示全部节点、当前视口和运行状态", "Medium", "Medium", "Completed", "Useful for navigation, but less central than collapse or active path highlighting.", "Overview+detail, navigation"],
  ["Semantic Zoom", "缩小时文字看不清，放大后信息又太多", "缩小时逐级隐藏次要字段，放大后显示参数、描述和 Decorator", "Medium", "High", "Completed", "Works naturally with GraphEdit zoom and can be described as multi-scale visualization.", "Semantic zoom, multi-scale visualization"],
  ["Path Summary View", "大树里只想快速知道当前执行链", "顶部显示可点击的运行链并跳转节点", "Low", "High", "Completed", "Simple and very useful for live debugging; complements visual highlighting.", "Path summary, breadcrumb"],
  ["Decorator Condition Badges", "判断条件藏在 JSON 参数里，不直观", "在节点卡片显示黑板条件、Cooldown 和 Time Limit 摘要", "Low", "Very High", "Completed", "Makes behavior tree logic readable without opening the inspector.", "Visual encoding, condition labels"],
  ["Search + Highlight", "大树中找节点、Action 或 blackboard key 困难", "搜索标题、类型、描述、方法和参数，并高亮/跳转结果", "Low", "High", "Completed", "High usability gain with low implementation cost.", "Interactive search, highlighting"],
  ["Orthogonal Edges", "曲线连接太多时上下关系不清楚", "使用直角折线连接降低层次关系歧义", "Medium", "Medium", "Completed", "Improves UE-like appearance, but may require custom connection drawing.", "Graph drawing aesthetics, edge bends"],
  ["Edge Bundling", "大量连线互相遮挡", "同父同向连线共享主干以降低视觉噪声", "High", "Medium", "Completed", "More useful for dense graphs than pure trees; good as an advanced discussion point.", "Edge bundling, visual clutter reduction"],
  ["Stable Incremental Layout", "每次自动排列后节点大幅跳动，用户失去空间记忆", "自动布局尽量保留已有节点位置，只处理冲突节点", "Medium", "High", "Completed", "Important for preserving the user's mental map when editing large trees.", "Incremental layout, mental map"],
  ["Breadcrumb Navigation", "选中深层节点后不知道它属于哪个分支", "显示选中节点祖先路径并支持点击跳转", "Low", "Medium", "Completed", "Simple navigation aid, especially useful after subtree collapse is added.", "Breadcrumb, hierarchy navigation"],
  ["Failure Reason Annotation", "Decorator 失败后不知道为什么", "Live Debug 标注 FAILURE 节点和具体失败原因", "Medium", "Very High", "Completed", "Directly improves runtime debugging and demonstrates behavior tree execution transparency.", "Runtime explanation, debug visualization"],
];

const sources = [
  ["A Comparative Evaluation on Tree Visualization Methods for Hierarchical Structures with Large Fan-outs", "Hyunjoo Song; Bohyoung Kim; Bongshin Lee; Jinwook Seo", "https://doi.org/10.1145/1753326.1753359", "Supports multi-column layout for large fan-out tree structures."],
  ["Developing and Evaluating Quilts for the Depiction of Large Layered Graphs", "Juhee Bae; Ben Watson", "https://doi.org/10.1109/TVCG.2011.187", "Supports path readability and alternative views for large layered graphs."],
  ["Efficient Methods and Readily Customizable Libraries for Managing Complexity of Large Networks", "Ugur Dogrusoz et al.", "https://doi.org/10.1371/journal.pone.0197238", "Supports expand-collapse, hide-show, incremental layout, and mental map preservation."],
  ["An Information-Theoretic Framework for Evaluating Edge Bundling Visualization", "Zhou et al.", "https://pmc.ncbi.nlm.nih.gov/articles/PMC7513140/", "Explains how edge bundling reduces clutter but may introduce uncertainty."],
  ["Divided Edge Bundling for Directional Network Data", "David Selassie; Brandon Heller; Jeffrey Heer", "https://doi.org/10.1109/TVCG.2011.190", "Reference for directional edge bundling and clutter reduction."],
];

const workbook = Workbook.create();
const sheet = workbook.worksheets.add("Optimization Methods");
const sourceSheet = workbook.worksheets.add("References");

sheet.showGridLines = false;
sourceSheet.showGridLines = false;

sheet.getRange("A1:H1").merge();
sheet.getRange("A1").values = [["Behavior Tree Display Optimization Methods"]];
sheet.getRange("A1").format = {
  fill: "#123047",
  font: { bold: true, color: "#FFFFFF", size: 16 },
  horizontalAlignment: "center",
  verticalAlignment: "center",
};
sheet.getRange("A1").format.rowHeight = 34;

sheet.getRange("A3:H3").values = [[
  "Method",
  "Problem Solved",
  "How To Apply In Godot Behavior Tree Plugin",
  "Difficulty",
  "Recommendation",
  "Priority",
  "Graduation Project Value",
  "Related Keywords",
]];
sheet.getRange("A4:H19").values = rows;

const table = sheet.tables.add("A3:H19", true, "DisplayOptimizationMethods");
table.style = "TableStyleMedium2";
table.showFilterButton = true;

sheet.getRange("A3:H3").format = {
  fill: "#0F766E",
  font: { bold: true, color: "#FFFFFF" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
};
sheet.getRange("A4:H19").format = {
  wrapText: true,
  verticalAlignment: "top",
};
sheet.getRange("D4:F19").format.horizontalAlignment = "center";
sheet.getRange("A:A").format.columnWidth = 24;
sheet.getRange("B:B").format.columnWidth = 28;
sheet.getRange("C:C").format.columnWidth = 48;
sheet.getRange("D:D").format.columnWidth = 12;
sheet.getRange("E:E").format.columnWidth = 16;
sheet.getRange("F:F").format.columnWidth = 18;
sheet.getRange("G:G").format.columnWidth = 48;
sheet.getRange("H:H").format.columnWidth = 30;
sheet.getRange("A4:H19").format.rowHeight = 58;
sheet.freezePanes.freezeRows(3);

sheet.getRange("D4:D19").dataValidation = { rule: { type: "list", values: ["Low", "Medium", "High"] } };
sheet.getRange("E4:E19").dataValidation = { rule: { type: "list", values: ["Medium", "High", "Very High"] } };
sheet.getRange("F4:F19").dataValidation = { rule: { type: "list", values: ["Completed", "Improve Later", "Optional", "Research Extension"] } };

sourceSheet.getRange("A1:D1").merge();
sourceSheet.getRange("A1").values = [["Reference Papers and Sources"]];
sourceSheet.getRange("A1").format = {
  fill: "#123047",
  font: { bold: true, color: "#FFFFFF", size: 16 },
  horizontalAlignment: "center",
};
sourceSheet.getRange("A3:D3").values = [["Paper", "Authors", "URL", "Useful For"]];
sourceSheet.getRange("A4:D8").values = sources;
const sourceTable = sourceSheet.tables.add("A3:D8", true, "ReferencePapers");
sourceTable.style = "TableStyleMedium4";
sourceTable.showFilterButton = true;
sourceSheet.getRange("A3:D3").format = {
  fill: "#334155",
  font: { bold: true, color: "#FFFFFF" },
  horizontalAlignment: "center",
};
sourceSheet.getRange("A4:D8").format = { wrapText: true, verticalAlignment: "top" };
sourceSheet.getRange("A:A").format.columnWidth = 54;
sourceSheet.getRange("B:B").format.columnWidth = 34;
sourceSheet.getRange("C:C").format.columnWidth = 46;
sourceSheet.getRange("D:D").format.columnWidth = 46;
sourceSheet.getRange("A4:D8").format.rowHeight = 54;
sourceSheet.freezePanes.freezeRows(3);

const preview = await workbook.render({
  sheetName: "Optimization Methods",
  range: "A1:H19",
  scale: 1,
  format: "png",
});
await fs.writeFile(previewPath, new Uint8Array(await preview.arrayBuffer()));

const inspect = await workbook.inspect({
  kind: "table",
  sheetId: "Optimization Methods",
  range: "A3:H19",
  tableMaxRows: 5,
  tableMaxCols: 8,
  maxChars: 2500,
});
console.log(inspect.ndjson);

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 50 },
  summary: "final formula error scan",
});
console.log(errors.ndjson);

await fs.mkdir(outputDir, { recursive: true });
const xlsx = await SpreadsheetFile.exportXlsx(workbook);
await xlsx.save(outputPath);
console.log(`Saved ${outputPath}`);
