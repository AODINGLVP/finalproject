import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const ROOT = process.cwd();
const RESULTS = path.join(ROOT, "testgame", "testgame", "test_results");
const OUTPUT_DIR = path.join(ROOT, "research", "display_optimization");
const OUTPUT = path.join(OUTPUT_DIR, "behavior_tree_complete_validation_and_display_evaluation.xlsx");
const QA_DIR = path.join(OUTPUT_DIR, "complete_evaluation_qa");

const NAVY = "#17324D";
const TEAL = "#177E78";
const BLUE = "#2E74B5";
const GOLD = "#D99B2B";
const GREEN = "#2F855A";
const RED = "#C94A4A";
const LIGHT = "#F3F7FA";
const LIGHT_TEAL = "#E8F5F3";
const LIGHT_GOLD = "#FFF5DC";
const LIGHT_RED = "#FDECEC";
const WHITE = "#FFFFFF";
const INK = "#23303D";
const MUTED = "#617181";
const GRID = "#D7E0E7";

function parseCsv(text) {
  const lines = text.trim().split(/\r?\n/);
  const headers = lines[0].split(",");
  return lines.slice(1).map((line) => {
    const values = line.split(",");
    return Object.fromEntries(headers.map((header, index) => [header, values[index]]));
  });
}

async function loadCsv(name) {
  return parseCsv(await fs.readFile(path.join(RESULTS, name), "utf8"));
}

function toNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : value;
}

function configureSheet(sheet) {
  sheet.showGridLines = false;
  sheet.getRange("A:Z").format.font = { name: "Microsoft YaHei", size: 10, color: INK };
}

function title(sheet, text, endColumn) {
  const range = sheet.getRange(`A1:${endColumn}1`);
  range.merge();
  range.values = [[text]];
  range.format = {
    fill: NAVY,
    font: { name: "Microsoft YaHei", size: 16, bold: true, color: WHITE },
    horizontalAlignment: "left",
    verticalAlignment: "center",
  };
  range.format.rowHeight = 34;
}

function section(sheet, rangeAddress, text) {
  const range = sheet.getRange(rangeAddress);
  range.merge();
  range.values = [[text]];
  range.format = {
    fill: TEAL,
    font: { name: "Microsoft YaHei", size: 11, bold: true, color: WHITE },
    verticalAlignment: "center",
  };
  range.format.rowHeight = 24;
}

function header(range) {
  range.format = {
    fill: NAVY,
    font: { name: "Microsoft YaHei", size: 10, bold: true, color: WHITE },
    horizontalAlignment: "center",
    verticalAlignment: "center",
    wrapText: true,
    borders: { preset: "all", style: "thin", color: GRID },
  };
}

function body(range, options = {}) {
  range.format = {
    font: { name: "Microsoft YaHei", size: options.size ?? 9, color: INK },
    verticalAlignment: options.verticalAlignment ?? "top",
    horizontalAlignment: options.horizontalAlignment ?? "left",
    wrapText: options.wrapText ?? true,
    borders: { preset: "all", style: "thin", color: GRID },
  };
}

function note(sheet, address, text, fill = LIGHT_GOLD, color = MUTED) {
  const range = sheet.getRange(address);
  range.merge();
  range.values = [[text]];
  range.format = {
    fill,
    font: { name: "Microsoft YaHei", size: 10, color },
    verticalAlignment: "center",
    wrapText: true,
    borders: { preset: "outside", style: "thin", color: GRID },
  };
}

const displayRows = await loadCsv("display_optimization_raw.csv");
const branchRows = await loadCsv("branch_dimming_results.csv");
const minimapRows = await loadCsv("enhanced_minimap_results.csv");
const displayLastRow = displayRows.length + 3;

const workbook = Workbook.create();
workbook.comments.setSelf({ displayName: "User" });

const overview = workbook.worksheets.add("总览");
const acceptance = workbook.worksheets.add("功能验收");
const methods = workbook.worksheets.add("显示方法");
const raw = workbook.worksheets.add("原始数据");
const comparison = workbook.worksheets.add("对比评分");
const study = workbook.worksheets.add("用户实验模板");
const guidance = workbook.worksheets.add("评价说明");
for (const sheet of workbook.worksheets.items) configureSheet(sheet);

// 原始数据：CSV 原样导入，所有汇总页均引用这里。
title(raw, "自动基准原始数据（2026-08-09）", "I");
raw.getRange("A3:I3").values = [["树节点数", "方法", "可见节点", "可见比例", "卡片总面积(px²)", "信息字段数", "降噪节点", "局部放大倍率", "刷新/重建(ms)"]];
header(raw.getRange("A3:I3"));
raw.getRange(`A4:I${displayLastRow}`).values = displayRows.map((row) => [
  toNumber(row.tree_size), row.method, toNumber(row.visible_nodes), toNumber(row.visible_ratio),
  toNumber(row.card_area_px2), toNumber(row.information_fields), toNumber(row.dimmed_nodes),
  toNumber(row.focus_scale_gain), toNumber(row.rebuild_ms),
]);
body(raw.getRange(`A4:I${displayLastRow}`), { size: 9 });
raw.getRange(`A4:A${displayLastRow}`).format.numberFormat = "0";
raw.getRange(`C4:C${displayLastRow}`).format.numberFormat = "0";
raw.getRange(`D4:D${displayLastRow}`).format.numberFormat = "0.0%";
raw.getRange(`E4:E${displayLastRow}`).format.numberFormat = "#,##0";
raw.getRange(`F4:G${displayLastRow}`).format.numberFormat = "0";
raw.getRange(`H4:H${displayLastRow}`).format.numberFormat = "0.00x";
raw.getRange(`I4:I${displayLastRow}`).format.numberFormat = "0.000";
raw.getRange("A:A").format.columnWidth = 10;
raw.getRange("B:B").format.columnWidth = 46;
raw.getRange("C:I").format.columnWidth = 15;
raw.freezePanes.freezeRows(3);

section(raw, "K1:S1", "非活动分支淡化性能");
raw.getRange("K3:S3").values = [["树节点数", "活动节点", "淡化节点", "淡化比例", "活动 Alpha", "非活动 Alpha", "亮度对比", "首次更新(ms)", "稳态更新(ms)"]];
header(raw.getRange("K3:S3"));
raw.getRange("K4:S6").values = branchRows.map((row) => Object.values(row).map(toNumber));
body(raw.getRange("K4:S6"), { size: 9, horizontalAlignment: "center" });
raw.getRange("N4:N6").format.numberFormat = "0.0%";
raw.getRange("O4:Q6").format.numberFormat = "0.00";
raw.getRange("R4:S6").format.numberFormat = "0.00000";
raw.getRange("K:S").format.columnWidth = 14;

section(raw, "K9:S9", "增强小地图性能");
raw.getRange("K11:S11").values = [["树节点数", "总览节点", "覆盖率", "宽(px)", "高(px)", "面积(px²)", "每千像素节点", "开关周期(ms)", "稳态更新(ms)"]];
header(raw.getRange("K11:S11"));
raw.getRange("K12:S14").values = minimapRows.map((row) => Object.values(row).map(toNumber));
body(raw.getRange("K12:S14"), { size: 9, horizontalAlignment: "center" });
raw.getRange("M12:M14").format.numberFormat = "0.0%";
raw.getRange("N12:Q14").format.numberFormat = "0.00";
raw.getRange("R12:S14").format.numberFormat = "0.00000";

// 功能验收：五个测试层及核心能力矩阵。
title(acceptance, "功能验收矩阵", "G");
acceptance.getRange("A3:G3").values = [["测试层", "断言数", "通过数", "结果", "主要覆盖", "证据", "日期"]];
header(acceptance.getRange("A3:G3"));
acceptance.getRange("A4:G8").values = [
  ["资源与运行时", 153, 153, "通过", "10 种节点、Decorator、Schema 引用、Actor、状态机、调试桥", "run_behavior_tree_tests.gd", "2026-08-09"],
  ["编辑器 GUI", 185, 185, "通过", "建模、历史、Schema key picker、Live Blackboard、19 项开关、单线交互与路径布局", "run_editor_view_tests.gd", "2026-08-09"],
  ["基础游戏", 13, 13, "通过", "3 个敌人、伤害、巡逻、死亡重生、Runner 生命周期", "run_game_integration_tests.gd", "2026-08-09"],
  ["复杂竞技场", 26, 26, "通过", "索敌、追击、攻击、搜索、撤退、治疗、新节点和 11 键 Schema", "run_complex_arena_tests.gd", "2026-08-09"],
  ["真实 GPU 视觉", 70, 70, "通过", "17 张核心 1600x900 截图、灰度、无障碍、单线、Schema key picker 与复杂树", "run_visual_regression_tests.gd", "2026-08-09"],
];
body(acceptance.getRange("A4:G8"), { size: 9 });
acceptance.getRange("D4:D8").format = { fill: "#DDF3E5", font: { bold: true, color: GREEN }, horizontalAlignment: "center", borders: { preset: "all", style: "thin", color: GRID } };
acceptance.getRange("A10:C10").values = [["合计", "断言", "通过"]];
header(acceptance.getRange("A10:C10"));
acceptance.getRange("A11").values = [["自动化总计"]];
acceptance.getRange("B11").formulas = [["=SUM('功能验收'!B4:B8)"]];
acceptance.getRange("C11").formulas = [["=SUM('功能验收'!C4:C8)"]];
body(acceptance.getRange("A11:C11"), { horizontalAlignment: "center" });
note(acceptance, "A13:G14", "严格判定：非零退出码、FAIL、ERROR、SCRIPT ERROR、对象泄漏、原生崩溃或非法内存访问均判定失败。另有人工实验固定场景 GPU 21/21、性能 511/511、发布包 53/53、180 物理帧烟雾测试与三个项目启动检查；最终日志扫描未发现真实错误。", LIGHT_TEAL, INK);
acceptance.getRange("A:A").format.columnWidth = 18;
acceptance.getRange("B:D").format.columnWidth = 11;
acceptance.getRange("E:E").format.columnWidth = 52;
acceptance.getRange("F:F").format.columnWidth = 34;
acceptance.getRange("G:G").format.columnWidth = 15;
acceptance.getRange("A4:G8").format.rowHeight = 44;
acceptance.freezePanes.freezeRows(3);

// 19 个显示功能，与插件开关一一对应。
title(methods, "显示优化功能（19 项独立开关）", "H");
methods.getRange("A3:H3").values = [["功能", "类别", "默认", "主要作用", "适用场景", "自动/视觉验证", "状态", "限制/代价"]];
header(methods.getRange("A3:H3"));
const methodRows = [
  ["Fisheye / Focus+Context", "局部细节", "开启", "鼠标邻域内部放大并保留全局上下文", "精读邻近节点", "倍率、恢复截图", "通过", "大树持续更新有少量渲染成本"],
  ["Subtree Collapse / Expand", "结构裁剪", "展开", "折叠分支并显示隐藏数量和两层摘要", "局部编辑与总览", "可见节点、重建时间", "通过", "新连接仍归属折叠节点"],
  ["Compact Mode", "密度", "关闭", "缩小卡片并保留短标题和类型颜色", "中大型树总览", "卡片面积、截图", "通过", "参数转移到 Inspector"],
  ["Active Path Highlight", "运行调试", "开启", "突出 Root 到当前叶节点的执行链", "运行诊断", "路径正确性、截图", "通过", "依赖游戏运行"],
  ["Non-active Branch Dimming", "运行调试", "关闭", "降低非当前路径分支透明度", "大树 Live Debug", "覆盖率、首帧/稳态", "通过", "需搭配活动路径"],
  ["Multi-column Layout", "布局", "关闭", "宽扇出分支分列并保持执行顺序", "大量同级子节点", "无重叠、顺序测试", "通过", "布局宽度增加"],
  ["Overview + Detail Minimap", "导航", "开启", "显示全部节点、视口与运行状态", "跨区域导航", "覆盖率、开关/稳态", "通过", "占用固定 230x150 区域"],
  ["Semantic Zoom", "信息层级", "关闭", "低缩放隐藏次要字段，不改变节点几何", "多尺度浏览", "信息字段、截图", "通过", "需要学习两个阈值"],
  ["Path Summary View", "导航", "开启", "显示可点击的运行路径摘要", "快速定位当前链", "按钮跳转、截图", "通过", "路径很长时横向占用"],
  ["Decorator Condition Badges", "语义编码", "开启", "在节点卡片显示条件、冷却和限制摘要", "不打开 Inspector 阅读逻辑", "文本与布局测试", "通过", "多个 Decorator 增加卡高"],
  ["Search + Highlight", "定位", "开启", "搜索标题、类型、描述、方法和参数", "已知目标定位", "363/364 降噪、截图", "通过", "未知名称时帮助有限"],
  ["Orthogonal Edges", "连线", "关闭", "使用直角折线降低连接歧义", "层次关系阅读", "连接路径截图", "通过", "弯折增加线段"],
  ["Edge Bundling", "连线", "关闭", "同父同向连接共享主干", "宽分支降噪", "连接路径截图", "通过", "密集处可能降低单线辨识"],
  ["Stable Incremental Layout", "布局", "关闭", "自动排列尽量保持已有节点位置", "持续编辑大树", "位置稳定测试", "通过", "不能消除所有重叠冲突"],
  ["Breadcrumb Navigation", "导航", "开启", "显示选中节点祖先路径并跳转", "深层节点定位", "点击导航测试", "通过", "与路径摘要信息相近"],
  ["Failure Reason Annotation", "运行调试", "开启", "标注 FAILURE 节点和具体失败原因", "运行诊断", "失败用例、截图", "通过", "依赖 Actor 返回信息"],
  ["Shape / Icon Type Encoding", "语义编码", "开启", "使用形状与图标补充类型颜色", "低缩放与灰度阅读", "灰度、低缩放截图", "通过", "占用少量标题栏空间"],
  ["Accessibility / Colorblind Palette", "无障碍", "关闭", "切换色盲安全配色并提供键盘搜索导航", "色觉差异与键盘操作", "配色、Ctrl+F/F3 测试", "通过", "与默认配色视觉风格不同"],
  ["Single Connection Rendering", "连线", "开启", "每条关系只显示一条自定义连线", "减少重复线与连接歧义", "命中、断开、撤销与截图", "通过", "拖拽时临时显示原生连接层"],
];
methods.getRange("A4:H22").values = methodRows;
body(methods.getRange("A4:H22"), { size: 9 });
methods.getRange("G4:G22").format = { fill: "#DDF3E5", font: { bold: true, color: GREEN }, horizontalAlignment: "center", borders: { preset: "all", style: "thin", color: GRID } };
methods.getRange("A:A").format.columnWidth = 31;
methods.getRange("B:C").format.columnWidth = 14;
methods.getRange("D:D").format.columnWidth = 46;
methods.getRange("E:E").format.columnWidth = 25;
methods.getRange("F:F").format.columnWidth = 28;
methods.getRange("G:G").format.columnWidth = 11;
methods.getRange("H:H").format.columnWidth = 34;
methods.getRange("A4:H22").format.rowHeight = 48;
methods.freezePanes.freezeRows(3);

// 364 节点对比。所有实测值从“原始数据”页用 SUMIFS 读取。
title(comparison, "364 节点显示方法量化对比（公式驱动）", "K");
comparison.getRange("A3:K3").values = [["方法", "可见比例", "卡片面积", "信息字段", "降噪率", "局部倍率", "重建(ms)", "结构简化", "信息/导航", "性能", "自动综合分"]];
header(comparison.getRange("A3:K3"));
const comparedMethods = ["Baseline", "Compact Cards", "Semantic Zoom", "Search Highlight", "Subtree Focus", "Subtree Collapse", "Fisheye", "Minimap", "Fit to View"];
comparison.getRange("A4:A12").values = comparedMethods.map((name) => [name]);
for (let row = 4; row <= 12; row += 1) {
  comparison.getRange(`B${row}`).formulas = [[`=SUMIFS('原始数据'!$D$4:$D$${displayLastRow},'原始数据'!$A$4:$A$${displayLastRow},364,'原始数据'!$B$4:$B$${displayLastRow},$A${row})`]];
  comparison.getRange(`C${row}`).formulas = [[`=SUMIFS('原始数据'!$E$4:$E$${displayLastRow},'原始数据'!$A$4:$A$${displayLastRow},364,'原始数据'!$B$4:$B$${displayLastRow},$A${row})`]];
  comparison.getRange(`D${row}`).formulas = [[`=SUMIFS('原始数据'!$F$4:$F$${displayLastRow},'原始数据'!$A$4:$A$${displayLastRow},364,'原始数据'!$B$4:$B$${displayLastRow},$A${row})`]];
  comparison.getRange(`E${row}`).formulas = [[`=SUMIFS('原始数据'!$G$4:$G$${displayLastRow},'原始数据'!$A$4:$A$${displayLastRow},364,'原始数据'!$B$4:$B$${displayLastRow},$A${row})/364`]];
  comparison.getRange(`F${row}`).formulas = [[`=SUMIFS('原始数据'!$H$4:$H$${displayLastRow},'原始数据'!$A$4:$A$${displayLastRow},364,'原始数据'!$B$4:$B$${displayLastRow},$A${row})`]];
  comparison.getRange(`G${row}`).formulas = [[`=SUMIFS('原始数据'!$I$4:$I$${displayLastRow},'原始数据'!$A$4:$A$${displayLastRow},364,'原始数据'!$B$4:$B$${displayLastRow},$A${row})`]];
  comparison.getRange(`H${row}`).formulas = [[`=1-B${row}`]];
  comparison.getRange(`I${row}`).formulas = [[`=MAX(1-D${row}/6,E${row},MAX(0,F${row}-1))`]];
  comparison.getRange(`J${row}`).formulas = [[`=MAX(0,1-MIN(G${row},1000)/1000)`]];
  comparison.getRange(`K${row}`).formulas = [[`=H${row}*'评价说明'!$F$4+I${row}*'评价说明'!$F$5+J${row}*'评价说明'!$F$6`]];
}
body(comparison.getRange("A4:K12"), { size: 9, horizontalAlignment: "center" });
comparison.getRange("B4:B12").format.numberFormat = "0.0%";
comparison.getRange("C4:C12").format.numberFormat = "#,##0";
comparison.getRange("D4:D12").format.numberFormat = "0.0";
comparison.getRange("E4:E12").format.numberFormat = "0.0%";
comparison.getRange("F4:F12").format.numberFormat = "0.00x";
comparison.getRange("G4:G12").format.numberFormat = "0.000";
comparison.getRange("H4:K12").format.numberFormat = "0.0%";
comparison.getRange("A:A").format.columnWidth = 25;
comparison.getRange("B:K").format.columnWidth = 14;
note(comparison, "A15:K17", "自动综合分只比较可由程序测量的几何、信息/导航和性能指标，不代表最终人的可读性。Minimap、Fit 和 Fisheye 的价值无法由节点减少率完整表达；正式结论必须补充参与者实验。", LIGHT_GOLD, MUTED);

const chart = comparison.charts.add("bar", comparison.getRange("A3:A12"));
chart.setData(comparison.getRange("A3:A12"));
chart.delete?.();
// Chart data helper avoids formulas being treated as categories by some renderers.
comparison.getRange("M3:N12").values = [["方法", "自动综合分"], ...comparedMethods.map((name) => [name, null])];
for (let row = 4; row <= 12; row += 1) comparison.getRange(`N${row}`).formulas = [[`=K${row}`]];
const scoreChart = comparison.charts.add("bar", comparison.getRange("M3:N12"));
scoreChart.title = "自动综合分（不含人工可用性）";
scoreChart.hasLegend = false;
scoreChart.yAxis = { numberFormatCode: "0%", min: 0, max: 1 };
scoreChart.setPosition("M2", "T17");

// 总览引用验收与量化页。
title(overview, "可视化行为树插件：完整验收与显示优化评价", "H");
overview.getRange("A4:B4").values = [["验收指标", "结果"]];
header(overview.getRange("A4:B4"));
overview.getRange("A5:A10").values = [["自动化断言"], ["运行时/资源"], ["编辑器 GUI"], ["基础游戏"], ["复杂竞技场"], ["真实 GPU 视觉"]];
overview.getRange("B5").formulas = [["='功能验收'!C11"]];
overview.getRange("B6:B10").formulas = [["='功能验收'!C4"], ["='功能验收'!C5"], ["='功能验收'!C6"], ["='功能验收'!C7"], ["='功能验收'!C8"]];
body(overview.getRange("A5:B10"));
overview.getRange("B5:B10").format.numberFormat = "0";

overview.getRange("D4:E4").values = [["研究指标", "结果"]];
header(overview.getRange("D4:E4"));
overview.getRange("D5:D10").values = [["基准树规模"], ["原始数据行"], ["显示开关"], ["真实截图"], ["Godot 版本"], ["报告日期"]];
overview.getRange("E5:E10").values = [["31 / 121 / 364"], [displayRows.length], [19], ["17 核心 + 4 实验"], ["4.6 stable"], ["2026-08-09"]];
body(overview.getRange("D5:E10"));

section(overview, "A12:H12", "364 节点关键结果");
overview.getRange("A14:B14").values = [["指标", "实测"]];
header(overview.getRange("A14:B14"));
overview.getRange("A15:A22").values = [["Compact 卡片面积降幅"], ["Semantic 信息字段降幅"], ["Search 降噪比例"], ["Subtree Focus 可见节点降幅"], ["Subtree Collapse 可见节点降幅"], ["Fisheye 局部倍率"], ["Branch Dimming 淡化比例"], ["Enhanced Minimap 覆盖率"]];
overview.getRange("B15").formulas = [["=1-'对比评分'!C5/'对比评分'!C4"]];
overview.getRange("B16").formulas = [["=1-'对比评分'!D6/'对比评分'!D4"]];
overview.getRange("B17").formulas = [["='对比评分'!E7"]];
overview.getRange("B18").formulas = [["='对比评分'!H8"]];
overview.getRange("B19").formulas = [["='对比评分'!H9"]];
overview.getRange("B20").formulas = [["='对比评分'!F10"]];
overview.getRange("B21").formulas = [["='原始数据'!N6"]];
overview.getRange("B22").formulas = [["='原始数据'!M14"]];
body(overview.getRange("A15:B22"));
overview.getRange("B15:B19").format.numberFormat = "0.0%";
overview.getRange("B20").format.numberFormat = "0.00x";
overview.getRange("B21:B22").format.numberFormat = "0.0%";
note(overview, "D14:H18", "结论：插件已形成“可视化建模、资源保存、运行执行、编辑器 Live Debug、复杂场景验证”的完整闭环。Compact、Focus 和 Collapse 显著降低几何复杂度；Search、Fisheye 与 Minimap 解决不同的定位和细节任务。", LIGHT_TEAL, INK);
note(overview, "D20:H23", "解释边界：面积、可见节点和信息字段变化不等于人类可读性已经提升。协议、固定树、Live Debug 快照和 270 行独立工作簿已完成；正式论文结论仍需 8–15 名参与者真实完成实验。", LIGHT_GOLD, MUTED);
overview.getRange("A:A").format.columnWidth = 31;
overview.getRange("B:B").format.columnWidth = 18;
overview.getRange("C:C").format.columnWidth = 4;
overview.getRange("D:D").format.columnWidth = 25;
overview.getRange("E:E").format.columnWidth = 20;
overview.getRange("F:H").format.columnWidth = 18;

// 用户实验页：只提供模板，不填造结果。
title(study, "用户实验快速记录模板（待采集）", "L");
study.getRange("A3:L3").values = [["参与者", "经验等级", "树规模", "显示方法", "任务", "完成时间(s)", "错误次数", "缩放/平移次数", "成功", "可读性(1-7)", "认知负担(1-7)", "备注"]];
header(study.getRange("A3:L3"));
const participants = Array.from({ length: 15 }, (_, index) => `P${String(index + 1).padStart(2, "0")}`);
const studyRows = [];
for (const participant of participants) {
  for (const task of ["定位指定 Action", "识别当前活动链", "编辑 Decorator 条件"]) {
    studyRows.push([participant, null, null, null, task, null, null, null, null, null, null, null]);
  }
}
study.getRange("A4:L48").values = studyRows;
body(study.getRange("A4:L48"), { size: 9, verticalAlignment: "center" });
study.getRange("B4:B48").dataValidation = { rule: { type: "list", values: ["Novice", "Intermediate", "Expert"] } };
study.getRange("C4:C48").dataValidation = { rule: { type: "list", values: [31, 121, 364] } };
study.getRange("D4:D48").dataValidation = { rule: { type: "list", values: ["Baseline", "Compact", "Collapse", "Fisheye", "Search", "Minimap"] } };
study.getRange("I4:I48").dataValidation = { rule: { type: "list", values: ["Yes", "No"] } };
study.getRange("J4:K48").dataValidation = { rule: { type: "whole", operator: "between", formula1: 1, formula2: 7 } };
study.getRange("A:A").format.columnWidth = 11;
study.getRange("B:D").format.columnWidth = 17;
study.getRange("E:E").format.columnWidth = 26;
study.getRange("F:K").format.columnWidth = 16;
study.getRange("L:L").format.columnWidth = 28;
study.freezePanes.freezeRows(3);
note(study, "A51:L53", "完整受控实验请使用 behavior_tree_human_comparison_study.xlsx：含 15 名参与者、6 种平衡方法顺序、3 种任务顺序、270 次试验计划、公式汇总和预先冻结的排除规则。当前没有参与者数据。", LIGHT_RED, RED);

// 评价说明与可审计权重。
title(guidance, "评价协议、权重与解释边界", "F");
guidance.getRange("A3:C3").values = [["自动指标", "定义", "正确解释"]];
header(guidance.getRange("A3:C3"));
guidance.getRange("A4:C9").values = [
  ["可见比例", "可见 GraphNode / 总节点数", "越低越能降低结构复杂度"],
  ["卡片总面积", "所有可见节点最小卡片面积之和", "越低表示几何密度越高"],
  ["信息字段", "标题、类型、描述、参数、Decorator、运行状态", "按任务权衡，不是越少越好"],
  ["降噪率", "被弱化的非目标节点 / 总节点数", "搜索或运行调试中越高越好"],
  ["局部倍率", "鼠标焦点节点内部放大系数", "Fisheye 只反映细节增益"],
  ["刷新时间", "操作到下一布局帧的本机时间", "越低越好，但不可跨机器直接比较"],
];
body(guidance.getRange("A4:C9"));
guidance.getRange("E3:F3").values = [["综合分权重", "权重"]];
header(guidance.getRange("E3:F3"));
guidance.getRange("E4:F6").values = [["结构简化", 0.35], ["信息/导航", 0.45], ["性能", 0.20]];
body(guidance.getRange("E4:F6"));
guidance.getRange("F4:F6").format.numberFormat = "0%";
guidance.getRange("A:A").format.columnWidth = 22;
guidance.getRange("B:B").format.columnWidth = 46;
guidance.getRange("C:C").format.columnWidth = 48;
guidance.getRange("D:D").format.columnWidth = 4;
guidance.getRange("E:E").format.columnWidth = 20;
guidance.getRange("F:F").format.columnWidth = 14;
section(guidance, "A12:F12", "推荐用户任务");
guidance.getRange("A13:F17").merge(true);
guidance.getRange("A13:A17").values = [["1. 在 364 节点树中找到指定 Action，并报告其父级执行顺序。"], ["2. 找到并修改指定 Blackboard Decorator 的 value。"], ["3. 运行游戏后指出当前执行叶节点和完整活动链。"], ["4. 在不丢失上下文的情况下比较两个远距离分支。"], ["5. 恢复全树并解释折叠摘要中隐藏的两层节点。"]];
guidance.getRange("A13:F17").format = { fill: LIGHT, font: { name: "Microsoft YaHei", size: 10, color: INK }, wrapText: true };
note(guidance, "A20:F22", "人工实验尚未实施。当前自动综合分只用于比较程序可测结果，不代表最终可读性、认知负担或学习成本。", LIGHT_RED, RED);

workbook.recalculate();
await fs.mkdir(OUTPUT_DIR, { recursive: true });
await fs.mkdir(QA_DIR, { recursive: true });

const formulaErrors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "final formula error scan",
});
console.log(formulaErrors.ndjson);

for (const [index, sheet] of workbook.worksheets.items.entries()) {
  const preview = await workbook.render({ sheetName: sheet.name, autoCrop: "all", scale: 1, format: "png" });
  const safeName = `${String(index + 1).padStart(2, "0")}_${sheet.name.replace(/[<>:\"/\\|?*]+/g, "_")}`;
  await fs.writeFile(path.join(QA_DIR, `${safeName}.png`), new Uint8Array(await preview.arrayBuffer()));
}

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(OUTPUT);
console.log(`Saved ${OUTPUT}`);
