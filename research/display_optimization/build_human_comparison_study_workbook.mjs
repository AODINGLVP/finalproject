import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const ROOT = process.cwd();
const OUTPUT_DIR = path.join(ROOT, "research", "display_optimization");
const OUTPUT = path.join(OUTPUT_DIR, "behavior_tree_human_comparison_study.xlsx");
const QA_DIR = path.join(OUTPUT_DIR, "human_study_workbook_qa");

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

const METHODS = ["Baseline", "Compact", "Collapse", "Fisheye", "Search", "Minimap"];
const TASKS = ["Locate Action", "Trace Active Path", "Edit Decorator"];
const TASK_ORDERS = [
  ["Locate Action", "Trace Active Path", "Edit Decorator"],
  ["Trace Active Path", "Edit Decorator", "Locate Action"],
  ["Edit Decorator", "Locate Action", "Trace Active Path"],
];
const METHOD_ORDERS = METHODS.map((_, offset) => METHODS.map((__, index) => METHODS[(index + offset) % METHODS.length]));

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

function section(sheet, address, text) {
  const range = sheet.getRange(address);
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

const participants = Array.from({ length: 15 }, (_, index) => {
  const id = `P${String(index + 1).padStart(2, "0")}`;
  return {
    id,
    methodOrder: index % METHOD_ORDERS.length,
    taskOrder: index % TASK_ORDERS.length,
  };
});

const trialRows = [];
let trialNumber = 1;
for (const participant of participants) {
  const taskOrder = TASK_ORDERS[participant.taskOrder];
  const methodOrder = METHOD_ORDERS[participant.methodOrder];
  for (let block = 0; block < taskOrder.length; block += 1) {
    for (let methodPosition = 0; methodPosition < methodOrder.length; methodPosition += 1) {
      trialRows.push([
        `T${String(trialNumber).padStart(3, "0")}`,
        participant.id,
        `M${participant.methodOrder + 1}`,
        `T${participant.taskOrder + 1}`,
        block + 1,
        methodPosition + 1,
        taskOrder[block],
        methodOrder[methodPosition],
        364,
        taskOrder[block] === "Locate Action" ? "Select node #363" : taskOrder[block] === "Trace Active Path" ? "Report IDs 1>2>5>14>41>122>363" : "Change Decorator #364 value true to false",
      ]);
      trialNumber += 1;
    }
  }
}

const workbook = Workbook.create();
workbook.comments.setSelf({ displayName: "User" });
const instructions = workbook.worksheets.add("Instructions");
const participantSheet = workbook.worksheets.add("Participants");
const counterbalance = workbook.worksheets.add("Counterbalance");
const trialPlan = workbook.worksheets.add("Trial Plan");
const raw = workbook.worksheets.add("Raw Data");
const summary = workbook.worksheets.add("Summary");
const exclusions = workbook.worksheets.add("Exclusion Rules");
for (const sheet of workbook.worksheets.items) configureSheet(sheet);

title(instructions, "行为树显示优化人工对比实验", "H");
note(instructions, "A3:H5", "状态：待采集。此工作簿已准备 15 名参与者 × 18 次正式试验 = 270 行，但没有填入任何参与者观测数据，不得据此声称可读性或认知负担已改善。", LIGHT_RED, RED);
section(instructions, "A7:H7", "固定实验材料");
instructions.getRange("A8:B14").values = [
  ["Godot / 视口", "Godot 4.6 stable；English；1600×900；统一系统缩放"],
  ["正式树", "res://behavior_trees/human_study_tree_364.tres"],
  ["练习树", "res://behavior_trees/human_study_tree_121.tres"],
  ["Action 目标", "#363 STUDY_TARGET_ACTION"],
  ["Decorator 目标", "#364 STUDY_TARGET_DECORATOR；value true → false"],
  ["固定运行链", "1 > 2 > 5 > 14 > 41 > 122 > 363"],
  ["Live Debug", "prepare_human_study_live_debug.gd -- --duration=1800"],
];
body(instructions.getRange("A8:B14"));
instructions.getRange("A8:A14").format = { fill: LIGHT_TEAL, font: { bold: true, color: TEAL }, borders: { preset: "all", style: "thin", color: GRID } };
section(instructions, "A16:H16", "执行流程");
instructions.getRange("A17:H24").merge(true);
instructions.getRange("A17:A24").values = [
  ["1. 先完成知情说明、参与者信息和三次 121 节点练习；练习不录入正式数据。"],
  ["2. 根据 Participants 页分配的方法序列和任务区组顺序。"],
  ["3. 每次试验前执行 Show All、Fit、清空 Search，并只开启当前方法。"],
  ["4. 从说“开始”计时，到成功、主动放弃或 180 秒上限停止。"],
  ["5. 失败和超时保留；只有设备、快照或初始状态故障才能标记试验级排除。"],
  ["6. 立即在 Raw Data 黄色输入列录入时间、错误、导航、成功和两项评分。"],
  ["7. Edit Decorator 后恢复 true 并重新载入；Trace 前确认 StudyNPC / RUNNING / Depth 7。"],
  ["8. Summary 仅汇总 Excluded=No 且有时间的数据；待采集时保持空白。"],
];
instructions.getRange("A17:H24").format = { fill: LIGHT, font: { name: "Microsoft YaHei", size: 10, color: INK }, wrapText: true };
instructions.getRange("A:A").format.columnWidth = 22;
instructions.getRange("B:B").format.columnWidth = 72;
instructions.getRange("C:H").format.columnWidth = 14;

title(participantSheet, "参与者与分组", "H");
participantSheet.getRange("A3:H3").values = [["Participant", "Method Order", "Task Order", "Experience", "Godot Years", "BT Experience", "Consent", "Notes"]];
header(participantSheet.getRange("A3:H3"));
participantSheet.getRange("A4:C18").values = participants.map((p) => [p.id, `M${p.methodOrder + 1}`, `T${p.taskOrder + 1}`]);
body(participantSheet.getRange("A4:H18"));
participantSheet.getRange("D4:H18").format.fill = LIGHT_GOLD;
participantSheet.getRange("D4:D18").dataValidation = { rule: { type: "list", values: ["Novice", "Intermediate", "Expert"] } };
participantSheet.getRange("E4:E18").dataValidation = { rule: { type: "decimal", operator: "between", formula1: 0, formula2: 50 } };
participantSheet.getRange("F4:F18").dataValidation = { rule: { type: "list", values: ["None", "Basic", "Experienced"] } };
participantSheet.getRange("G4:G18").dataValidation = { rule: { type: "list", values: ["Yes", "No", "Withdrawn"] } };
participantSheet.getRange("A:C").format.columnWidth = 15;
participantSheet.getRange("D:G").format.columnWidth = 18;
participantSheet.getRange("H:H").format.columnWidth = 36;
participantSheet.freezePanes.freezeRows(3);

title(counterbalance, "方法与任务顺序平衡", "H");
counterbalance.getRange("A3:G3").values = [["Method Order", "1", "2", "3", "4", "5", "6"]];
header(counterbalance.getRange("A3:G3"));
counterbalance.getRange("A4:G9").values = METHOD_ORDERS.map((order, index) => [`M${index + 1}`, ...order]);
body(counterbalance.getRange("A4:G9"), { horizontalAlignment: "center" });
counterbalance.getRange("A12:D12").values = [["Task Order", "Block 1", "Block 2", "Block 3"]];
header(counterbalance.getRange("A12:D12"));
counterbalance.getRange("A13:D15").values = TASK_ORDERS.map((order, index) => [`T${index + 1}`, ...order]);
body(counterbalance.getRange("A13:D15"), { horizontalAlignment: "center" });
note(counterbalance, "A18:H20", "方法使用循环 Latin-square 顺序并按参与者编号轮换；任务区组使用三种循环顺序。每名参与者完成 6 方法 × 3 任务，方法比较为被试内设计。", LIGHT_TEAL, TEAL);
counterbalance.getRange("A:A").format.columnWidth = 18;
counterbalance.getRange("B:G").format.columnWidth = 22;
counterbalance.getRange("H:H").format.columnWidth = 4;

title(trialPlan, "预生成正式试验计划（270 次）", "J");
trialPlan.getRange("A3:J3").values = [["Trial ID", "Participant", "Method Order", "Task Order", "Block", "Position", "Task", "Method", "Tree Size", "Success Criterion"]];
header(trialPlan.getRange("A3:J3"));
trialPlan.getRange("A4:J273").values = trialRows;
body(trialPlan.getRange("A4:J273"), { size: 9 });
trialPlan.getRange("E4:F273").format.numberFormat = "0";
trialPlan.getRange("I4:I273").format.numberFormat = "0";
trialPlan.getRange("A:F").format.columnWidth = 14;
trialPlan.getRange("G:H").format.columnWidth = 23;
trialPlan.getRange("I:I").format.columnWidth = 12;
trialPlan.getRange("J:J").format.columnWidth = 48;
trialPlan.freezePanes.freezeRows(3);

title(raw, "人工实验原始数据（待采集）", "Q");
raw.getRange("A3:Q3").values = [["Trial ID", "Participant", "Task", "Method", "Time (s)", "Errors", "Zoom", "Pan", "Success", "Readability 1-7", "Cognitive Load 1-7", "Excluded", "Exclusion Reason", "Observer", "Timestamp", "Participant Comment", "Researcher Notes"]];
header(raw.getRange("A3:Q3"));
for (let row = 4; row <= 273; row += 1) {
  const planRow = row;
  raw.getRange(`A${row}:D${row}`).formulas = [[
    `='Trial Plan'!A${planRow}`,
    `='Trial Plan'!B${planRow}`,
    `='Trial Plan'!G${planRow}`,
    `='Trial Plan'!H${planRow}`,
  ]];
}
body(raw.getRange("A4:Q273"), { size: 9 });
raw.getRange("E4:Q273").format.fill = LIGHT_GOLD;
raw.getRange("E4:E273").dataValidation = { rule: { type: "decimal", operator: "between", formula1: 0, formula2: 180 } };
raw.getRange("F4:H273").dataValidation = { rule: { type: "whole", operator: "between", formula1: 0, formula2: 999 } };
raw.getRange("I4:I273").dataValidation = { rule: { type: "list", values: ["Yes", "No"] } };
raw.getRange("J4:K273").dataValidation = { rule: { type: "whole", operator: "between", formula1: 1, formula2: 7 } };
raw.getRange("L4:L273").dataValidation = { rule: { type: "list", values: ["No", "Yes"] } };
raw.getRange("M4:M273").dataValidation = { rule: { type: "list", values: ["", "Editor Crash", "Stale Live Debug", "Wrong Initial State", "Researcher Error", "Participant Withdrawal", "Other"] } };
raw.getRange("A:D").format.columnWidth = 20;
raw.getRange("E:L").format.columnWidth = 15;
raw.getRange("M:M").format.columnWidth = 24;
raw.getRange("N:O").format.columnWidth = 18;
raw.getRange("P:Q").format.columnWidth = 36;
raw.getRange("E4:E273").format.numberFormat = "0.0";
raw.getRange("F4:H273").format.numberFormat = "0";
raw.getRange("J4:K273").format.numberFormat = "0";
raw.freezePanes.freezeRows(3);

title(summary, "方法 × 任务结果汇总（公式驱动）", "J");
note(summary, "A3:J5", "状态：待采集。只有 Raw Data 中 Time 有值且 Excluded=No 的试验进入汇总。失败与 180 秒超时保留在主分析中；当前空白不是 0。", LIGHT_RED, RED);
summary.getRange("A7:J7").values = [["Method", "Task", "Valid N", "Success Rate", "Mean Time (s)", "Mean Errors", "Mean Nav", "Readability", "Cognitive Load", "Status"]];
header(summary.getRange("A7:J7"));
const summaryRows = [];
for (const method of METHODS) for (const task of TASKS) summaryRows.push([method, task]);
summary.getRange("A8:B25").values = summaryRows;
for (let row = 8; row <= 25; row += 1) {
  const criteria = `'Raw Data'!$D$4:$D$273,$A${row},'Raw Data'!$C$4:$C$273,$B${row},'Raw Data'!$L$4:$L$273,"No",'Raw Data'!$E$4:$E$273,">=0"`;
  summary.getRange(`C${row}`).formulas = [[`=COUNTIFS(${criteria})`]];
  summary.getRange(`D${row}`).formulas = [[`=IF(C${row}=0,"",COUNTIFS(${criteria},'Raw Data'!$I$4:$I$273,"Yes")/C${row})`]];
  summary.getRange(`E${row}`).formulas = [[`=IF(C${row}=0,"",SUMIFS('Raw Data'!$E$4:$E$273,${criteria})/C${row})`]];
  summary.getRange(`F${row}`).formulas = [[`=IF(C${row}=0,"",SUMIFS('Raw Data'!$F$4:$F$273,${criteria})/C${row})`]];
  summary.getRange(`G${row}`).formulas = [[`=IF(C${row}=0,"",(SUMIFS('Raw Data'!$G$4:$G$273,${criteria})+SUMIFS('Raw Data'!$H$4:$H$273,${criteria}))/C${row})`]];
  summary.getRange(`H${row}`).formulas = [[`=IF(C${row}=0,"",SUMIFS('Raw Data'!$J$4:$J$273,${criteria})/C${row})`]];
  summary.getRange(`I${row}`).formulas = [[`=IF(C${row}=0,"",SUMIFS('Raw Data'!$K$4:$K$273,${criteria})/C${row})`]];
  summary.getRange(`J${row}`).formulas = [[`=IF(C${row}=0,"待采集","有数据")`]];
}
body(summary.getRange("A8:J25"), { size: 9 });
summary.getRange("C8:C25").format.numberFormat = "0";
summary.getRange("D8:D25").format.numberFormat = "0.0%";
summary.getRange("E8:I25").format.numberFormat = "0.00";
summary.getRange("J8:J25").format = { fill: LIGHT_GOLD, font: { bold: true, color: GOLD }, horizontalAlignment: "center", borders: { preset: "all", style: "thin", color: GRID } };
section(summary, "A28:J28", "建议分析输出");
summary.getRange("A29:J34").merge(true);
summary.getRange("A29:A34").values = [
  ["1. 同时报告全部有效试验的 180 秒封顶时间与仅成功试验时间。"],
  ["2. 每种方法按任务报告 N、成功率、时间中位数/均值、错误、导航和 1–7 评分。"],
  ["3. 被试内数据优先用重复测量方法；小样本或偏态时使用 Friedman 检验。"],
  ["4. 显著后配对比较需多重校正，并报告效应量与置信区间。"],
  ["5. 可读性越高越好；认知负担越低越好，两者不可未经反向编码直接相加。"],
  ["6. 自动几何结果与人工任务结果分开陈述，不用面积降低替代可用性证据。"],
];
summary.getRange("A29:J34").format = { fill: LIGHT, font: { name: "Microsoft YaHei", size: 10, color: INK }, wrapText: true };
summary.getRange("A:B").format.columnWidth = 24;
summary.getRange("C:J").format.columnWidth = 17;
summary.freezePanes.freezeRows(7);

title(exclusions, "预先冻结的排除与计分规则", "F");
exclusions.getRange("A3:F3").values = [["Level", "Condition", "Exclude?", "Raw Data Handling", "Reason Code", "Notes"]];
header(exclusions.getRange("A3:F3"));
exclusions.getRange("A4:F12").values = [
  ["Trial", "Editor or native crash", "Yes", "Mark Excluded=Yes; reschedule", "Editor Crash", "Not a participant-performance failure"],
  ["Trial", "Live Debug snapshot older than 2 seconds", "Yes", "Mark Excluded=Yes; refresh and reschedule", "Stale Live Debug", "Verify StudyNPC / RUNNING / Depth 7"],
  ["Trial", "Wrong tree, zoom, pan, switch, or target state", "Yes", "Mark Excluded=Yes; reset and reschedule", "Wrong Initial State", "Document the incorrect state"],
  ["Trial", "Researcher gives hint or starts timer incorrectly", "Yes", "Mark Excluded=Yes; reschedule", "Researcher Error", "Do not silently overwrite"],
  ["Trial", "Participant reaches 180 seconds", "No", "Time=180; Success=No", "", "Normal outcome, not an outlier"],
  ["Trial", "Participant chooses wrong node/path/value", "No", "Increment Errors; retain time", "", "Normal task error"],
  ["Trial", "Participant gives up", "No", "Success=No; retain actual time", "", "Record reason in comment"],
  ["Participant", "Withdraws consent or leaves study", "Yes", "Mark remaining rows excluded", "Participant Withdrawal", "Keep only data allowed by consent"],
  ["Participant", "Device/project failure affects more than 3 trials", "Yes", "Exclude participant after documented review", "Other", "Apply before inferential analysis"],
];
body(exclusions.getRange("A4:F12"), { size: 9 });
note(exclusions, "A15:F18", "排除规则必须在查看方法差异前冻结。正常失败、错误、放弃和超时不能为了改善结果而删除。主结果保留失败和封顶时间，另可报告仅成功试验的敏感性分析。", LIGHT_RED, RED);
exclusions.getRange("A:A").format.columnWidth = 16;
exclusions.getRange("B:B").format.columnWidth = 46;
exclusions.getRange("C:C").format.columnWidth = 13;
exclusions.getRange("D:D").format.columnWidth = 42;
exclusions.getRange("E:E").format.columnWidth = 25;
exclusions.getRange("F:F").format.columnWidth = 38;

workbook.recalculate();
await fs.mkdir(OUTPUT_DIR, { recursive: true });
await fs.mkdir(QA_DIR, { recursive: true });

const keyRanges = [
  ["Participants", "A3:H18"],
  ["Counterbalance", "A3:G15"],
  ["Trial Plan", "A3:J12"],
  ["Raw Data", "A3:Q12"],
  ["Summary", "A7:J25"],
];
for (const [sheetName, range] of keyRanges) {
  const inspected = await workbook.inspect({ kind: "table", range: `${sheetName}!${range}`, include: "values,formulas", tableMaxRows: 30, tableMaxCols: 20 });
  console.log(inspected.ndjson);
}

const formulaErrors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "human study formula error scan",
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
