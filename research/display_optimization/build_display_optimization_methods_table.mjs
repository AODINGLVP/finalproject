import fs from "node:fs/promises";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outputDir = "research/display_optimization";
const outputPath = `${outputDir}/behavior_tree_display_optimization_methods.xlsx`;
const previewPath = `${outputDir}/behavior_tree_display_optimization_methods_preview.png`;

const rows = [
  ["Fisheye / Focus+Context", "鼠标附近看不清，但又不想整体放大", "鼠标附近节点放大，远处节点保持上下文；当前插件已实现第一版", "Medium", "High", "Done / Improve Later", "Good for large behavior trees because it preserves global context while enlarging local detail.", "Focus+context visualization, fisheye view"],
  ["Subtree Collapse / Expand", "节点太多，整棵树铺满屏幕", "给每个节点加折叠按钮，把子树压缩成 summary node，并显示子节点数量", "Medium", "Very High", "Recommended Next", "Directly addresses behavior tree readability and matches large-network complexity management research.", "Expand-collapse, hide-show, mental map preservation"],
  ["Compact Mode", "节点卡片太大，同屏显示节点太少", "节点只显示标题、类型、状态；详细参数放到 Inspector 或悬浮详情", "Low", "Very High", "Recommended Next", "Fast to implement and easy to explain in the graduation project as a readability improvement.", "Compact display, semantic zoom"],
  ["Active Path Highlight", "Live Debug 时不知道 NPC 正在执行哪条链", "高亮 Root 到当前执行节点的整条链，其他分支变暗", "Low", "Very High", "Recommended Next", "Strongly supports behavior tree debugging and makes the plugin feel closer to UE behavior tree debugging.", "Path finding, live debugging"],
  ["Non-active Branch Dimming", "调试时视觉噪声太多", "运行时降低非当前分支透明度，只突出当前链条和失败条件", "Low", "High", "Recommended Next", "Pairs well with active path highlight and is simple to validate visually.", "Focus+context, visual filtering"],
  ["Multi-column Layout", "一个 Selector 或 Sequence 有很多子节点时横向太长", "同一父节点下超过 N 个子节点时自动分成多列，同时用编号保留从左到右执行顺序", "Medium", "High", "Recommended", "Supported by large fan-out tree visualization research; useful when selectors have many actions.", "Large fan-outs, multi-column interface"],
  ["Overview + Detail / Enhanced Minimap", "用户在大树中迷路", "强化 GraphEdit minimap，支持点击定位、显示当前视口和当前执行节点", "Medium", "Medium", "Optional", "Useful for navigation, but less central than collapse or active path highlighting.", "Overview+detail, navigation"],
  ["Semantic Zoom", "缩小时文字看不清，放大后信息又太多", "缩小时只显示类型颜色和短标题，放大后显示参数、描述、Decorator 条件", "Medium", "High", "Recommended", "Works naturally with GraphEdit zoom and can be described as multi-scale visualization.", "Semantic zoom, multi-scale visualization"],
  ["Path Summary View", "大树里只想快速知道当前执行链", "顶部显示 Root > Selector > Attack Left，点击路径项可跳转节点", "Low", "High", "Recommended Next", "Simple and very useful for live debugging; complements visual highlighting.", "Path summary, breadcrumb"],
  ["Decorator Condition Badges", "判断条件藏在 JSON 参数里，不直观", "在节点顶部显示 IF player_in_range == true、Cooldown 1.5s 等标签", "Low", "Very High", "Recommended Next", "Makes behavior tree logic readable without opening the inspector.", "Visual encoding, condition labels"],
  ["Search + Highlight", "大树中找节点、Action 或 blackboard key 困难", "搜索节点标题、Action 方法名、blackboard key，并高亮/跳转结果", "Low", "High", "Recommended", "High usability gain with low implementation cost.", "Interactive search, highlighting"],
  ["Orthogonal Edges", "曲线连接太多时上下关系不清楚", "使用 UE 蓝图风格的直角折线连接，减少线条歧义", "Medium", "Medium", "Optional", "Improves UE-like appearance, but may require custom connection drawing.", "Graph drawing aesthetics, edge bends"],
  ["Edge Bundling", "大量连线互相遮挡", "同方向、同父节点或同类型连线进行捆绑/合并显示", "High", "Medium", "Research Extension", "More useful for dense graphs than pure trees; good as an advanced discussion point.", "Edge bundling, visual clutter reduction"],
  ["Stable Incremental Layout", "每次自动排列后节点大幅跳动，用户失去空间记忆", "自动布局时尽量保持已有节点位置，只调整新增节点或重叠节点", "Medium", "High", "Recommended", "Important for preserving the user's mental map when editing large trees.", "Incremental layout, mental map"],
  ["Breadcrumb Navigation", "选中深层节点后不知道它属于哪个分支", "显示当前选择节点路径：Root / Patrol / Move Left", "Low", "Medium", "Optional", "Simple navigation aid, especially useful after subtree collapse is added.", "Breadcrumb, hierarchy navigation"],
  ["Failure Reason Annotation", "Decorator 失败后不知道为什么", "Live Debug 显示 player_in_range failed、cooldown active 等失败原因", "Medium", "Very High", "Recommended Next", "Directly improves runtime debugging and demonstrates behavior tree execution transparency.", "Runtime explanation, debug visualization"],
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
sheet.getRange("F4:F19").dataValidation = { rule: { type: "list", values: ["Done / Improve Later", "Recommended Next", "Recommended", "Optional", "Research Extension"] } };

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
