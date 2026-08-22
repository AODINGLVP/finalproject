import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const ROOT = process.cwd();
const OUTPUT_DIR = path.join(ROOT, "research", "display_optimization");
const OUTPUT = path.join(OUTPUT_DIR, "behavior_tree_human_comparison_study.xlsx");
const QA_DIR = path.join(OUTPUT_DIR, "human_study_workbook_qa");
const FIXTURE_PATH = path.join(ROOT, "testgame", "testgame", "tests", "fixtures", "human_study_241_targets.json");
const STUDY = JSON.parse(await fs.readFile(FIXTURE_PATH, "utf8"));

const NAVY = "#17324D";
const TEAL = "#177E78";
const GOLD = "#D99B2B";
const RED = "#C94A4A";
const LIGHT = "#F3F7FA";
const LIGHT_TEAL = "#E8F5F3";
const LIGHT_GOLD = "#FFF5DC";
const LIGHT_RED = "#FDECEC";
const WHITE = "#FFFFFF";
const INK = "#23303D";
const MUTED = "#617181";
const GRID = "#D7E0E7";

const METHODS = STUDY.methods;
const TASKS = STUDY.tasks;
const METHOD_ORDERS = STUDY.method_orders;
const TASK_ORDERS = STUDY.task_orders;
const TRACE_TARGETS = STUDY.trace_targets;
const DECORATOR_TARGETS = STUDY.decorator_targets;
const PARTICIPANT_COUNT = STUDY.participants;
const TRIAL_COUNT = PARTICIPANT_COUNT * METHODS.length * TASKS.length;
const FIRST_DATA_ROW = 4;
const LAST_DATA_ROW = FIRST_DATA_ROW + TRIAL_COUNT - 1;

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

const participants = Array.from({ length: PARTICIPANT_COUNT }, (_, index) => ({
  index,
  id: `P${String(index + 1).padStart(2, "0")}`,
  methodOrder: index % METHOD_ORDERS.length,
  taskOrder: index % TASK_ORDERS.length,
  targetOffset: index % METHODS.length,
}));

const trialRows = [];
let trialNumber = 1;
for (const participant of participants) {
  const taskOrder = TASK_ORDERS[participant.taskOrder];
  const methodOrder = METHOD_ORDERS[participant.methodOrder];
  for (let block = 0; block < taskOrder.length; block += 1) {
    const task = taskOrder[block];
    for (let methodPosition = 0; methodPosition < methodOrder.length; methodPosition += 1) {
      const method = methodOrder[methodPosition];
      const methodIndex = METHODS.indexOf(method);
      const targetIndex = (methodIndex + participant.index) % METHODS.length;
      const target = task === "Edit Decorator" ? DECORATOR_TARGETS[targetIndex] : TRACE_TARGETS[targetIndex];
      const context = task === "Edit Decorator"
        ? `Owner #${target.owner_id} ${target.owner_title}; ${target.mode}; ${target.start_duration} -> ${target.target_duration}`
        : `Path ${target.path_ids.join(" > ")}`;
      const criterion = task === "Locate Action"
        ? `Select #${target.id} ${target.title}`
        : task === "Trace Active Path"
          ? `Report ${target.path_titles.join(" > ")}`
          : `Set Decorator #${target.id} Duration to ${target.target_duration}; no other change`;
      trialRows.push([
        `T${String(trialNumber).padStart(3, "0")}`,
        participant.id,
        `M${participant.methodOrder + 1}`,
        `T${participant.taskOrder + 1}`,
        participant.targetOffset + 1,
        block + 1,
        methodPosition + 1,
        task,
        method,
        STUDY.resource_nodes,
        target.key,
        target.id,
        target.title,
        context,
        criterion,
      ]);
      trialNumber += 1;
    }
  }
}

const workbook = Workbook.create();
workbook.comments.setSelf({ displayName: "Researcher" });
const instructions = workbook.worksheets.add("Instructions");
const participantSheet = workbook.worksheets.add("Participants");
const counterbalance = workbook.worksheets.add("Counterbalance");
const trialPlan = workbook.worksheets.add("Trial Plan");
const raw = workbook.worksheets.add("Raw Data");
const summary = workbook.worksheets.add("Summary");
const exclusions = workbook.worksheets.add("Exclusion Rules");
for (const sheet of workbook.worksheets.items) configureSheet(sheet);

title(instructions, "241 节点可玩行为树开发者可用性实验", "J");
note(instructions, "A3:J5", `状态：待采集。工作簿预生成 ${PARTICIPANT_COUNT} 名参与者 × 18 次正式试验 = ${TRIAL_COUNT} 行，但没有填入任何真人观测。GPU 耗时和几何面积不能代替可用性结论。`, LIGHT_RED, RED);
section(instructions, "A7:J7", "固定实验材料");
instructions.getRange("A8:B15").values = [
  ["正式树", STUDY.formal_tree],
  ["规模", `${STUDY.resource_nodes} 个资源节点；${STUDY.rendered_cards} 张卡片；39 个附加 Decorator`],
  ["练习树", STUDY.practice_tree],
  ["开发任务", "Locate Action / Trace Active Path / Edit Decorator"],
  ["显示条件", METHODS.join(" / ")],
  ["目标来源", "res://tests/fixtures/human_study_241_targets.json"],
  ["Godot / 视口", "Godot 4.6 stable；English；1600×900；同一设备设置"],
  ["Live Debug", "prepare_human_study_live_debug.gd -- --duration=1800 --target=<key>"],
];
body(instructions.getRange("A8:B15"));
instructions.getRange("A8:A15").format = { fill: LIGHT_TEAL, font: { bold: true, color: TEAL }, borders: { preset: "all", style: "thin", color: GRID } };
section(instructions, "A17:J17", "执行流程");
instructions.getRange("A18:J26").merge(true);
instructions.getRange("A18:A26").values = [
  ["1. 完成知情说明和参与者信息；用 121 节点树完成三次不计分练习。"],
  ["2. 严格按 Trial Plan 的 Task、Method 和 Target 执行，不自行替换目标。"],
  ["3. 每次先 Show All、清空 Search、清除选择、恢复固定 Zoom/Pan，再只开启当前方法。"],
  ["4. Trace 任务用 Target Key 刷新对应 Live Debug；确认 ArenaEnemy / RUNNING / Depth 7。"],
  ["5. 从说“开始”计时，到成功、放弃或 180 秒停止；失败和超时必须保留。"],
  ["6. 当场在 Raw Data 黄色列录入时间、错误、Zoom、Pan、成功和两项评分。"],
  ["7. Edit 后恢复起始 Duration 并重新加载，确认没有保存其他修改。"],
  ["8. 只有崩溃、快照过期、错误初态或研究者错误可排除；记录原因并重排。"],
  ["9. 严格分析使用 analyze_human_study_results.py；Summary 页只作采集进度快速检查。"],
];
instructions.getRange("A18:J26").format = { fill: LIGHT, font: { name: "Microsoft YaHei", size: 10, color: INK }, wrapText: true };
instructions.getRange("A:A").format.columnWidth = 24;
instructions.getRange("B:B").format.columnWidth = 86;
instructions.getRange("C:J").format.columnWidth = 12;

title(participantSheet, "参与者与平衡分组", "I");
participantSheet.getRange("A3:I3").values = [["Participant", "Method Order", "Task Order", "Target Offset", "Experience", "Godot Years", "BT Experience", "Consent", "Notes"]];
header(participantSheet.getRange("A3:I3"));
participantSheet.getRange(`A4:D${PARTICIPANT_COUNT + 3}`).values = participants.map((p) => [p.id, `M${p.methodOrder + 1}`, `T${p.taskOrder + 1}`, p.targetOffset + 1]);
body(participantSheet.getRange(`A4:I${PARTICIPANT_COUNT + 3}`));
participantSheet.getRange(`E4:I${PARTICIPANT_COUNT + 3}`).format.fill = LIGHT_GOLD;
participantSheet.getRange(`E4:E${PARTICIPANT_COUNT + 3}`).dataValidation = { rule: { type: "list", values: ["Novice", "Intermediate", "Expert"] } };
participantSheet.getRange(`F4:F${PARTICIPANT_COUNT + 3}`).dataValidation = { rule: { type: "decimal", operator: "between", formula1: 0, formula2: 50 } };
participantSheet.getRange(`G4:G${PARTICIPANT_COUNT + 3}`).dataValidation = { rule: { type: "list", values: ["None", "Basic", "Experienced"] } };
participantSheet.getRange(`H4:H${PARTICIPANT_COUNT + 3}`).dataValidation = { rule: { type: "list", values: ["Yes", "No", "Withdrawn"] } };
participantSheet.getRange("A:D").format.columnWidth = 15;
participantSheet.getRange("E:H").format.columnWidth = 18;
participantSheet.getRange("I:I").format.columnWidth = 36;
participantSheet.freezePanes.freezeRows(3);

title(counterbalance, "方法、任务与目标平衡", "H");
counterbalance.getRange("A3:G3").values = [["Method Order", "1", "2", "3", "4", "5", "6"]];
header(counterbalance.getRange("A3:G3"));
counterbalance.getRange("A4:G9").values = METHOD_ORDERS.map((order, index) => [`M${index + 1}`, ...order]);
body(counterbalance.getRange("A4:G9"), { horizontalAlignment: "center" });
counterbalance.getRange("A12:D12").values = [["Task Order", "Block 1", "Block 2", "Block 3"]];
header(counterbalance.getRange("A12:D12"));
counterbalance.getRange("A13:D15").values = TASK_ORDERS.map((order, index) => [`T${index + 1}`, ...order]);
body(counterbalance.getRange("A13:D15"), { horizontalAlignment: "center" });
counterbalance.getRange("A18:D18").values = [["Participant", "Method Order", "Task Order", "Target Offset"]];
header(counterbalance.getRange("A18:D18"));
counterbalance.getRange(`A19:D${PARTICIPANT_COUNT + 18}`).values = participants.map((p) => [p.id, `M${p.methodOrder + 1}`, `T${p.taskOrder + 1}`, p.targetOffset + 1]);
body(counterbalance.getRange(`A19:D${PARTICIPANT_COUNT + 18}`), { horizontalAlignment: "center" });
note(counterbalance, `A${PARTICIPANT_COUNT + 21}:H${PARTICIPANT_COUNT + 23}`, "12 人中每个方法顺序使用两次、每个任务顺序使用四次；目标按 (method index + participant index) mod 6 分配，因此每个方法×目标组合恰好出现两次。", LIGHT_TEAL, TEAL);
counterbalance.getRange("A:A").format.columnWidth = 18;
counterbalance.getRange("B:G").format.columnWidth = 22;

title(trialPlan, `预生成正式试验计划（${TRIAL_COUNT} 次）`, "O");
trialPlan.getRange("A3:O3").values = [["Trial ID", "Participant", "Method Order", "Task Order", "Target Offset", "Block", "Position", "Task", "Method", "Tree Size", "Target Key", "Target ID", "Target Title", "Context", "Success Criterion"]];
header(trialPlan.getRange("A3:O3"));
trialPlan.getRange(`A4:O${LAST_DATA_ROW}`).values = trialRows;
body(trialPlan.getRange(`A4:O${LAST_DATA_ROW}`), { size: 9 });
trialPlan.getRange(`E4:G${LAST_DATA_ROW}`).format.numberFormat = "0";
trialPlan.getRange(`J4:L${LAST_DATA_ROW}`).format.numberFormat = "0";
trialPlan.getRange("A:G").format.columnWidth = 13;
trialPlan.getRange("H:I").format.columnWidth = 22;
trialPlan.getRange("J:L").format.columnWidth = 13;
trialPlan.getRange("M:M").format.columnWidth = 28;
trialPlan.getRange("N:O").format.columnWidth = 64;
trialPlan.freezePanes.freezeRows(3);

title(raw, "人工实验原始数据（待采集）", "T");
raw.getRange("A3:T3").values = [["Trial ID", "Participant", "Task", "Method", "Target Key", "Target ID", "Target Title", "Time (s)", "Errors", "Zoom", "Pan", "Success", "Readability 1-7", "Cognitive Load 1-7", "Excluded", "Exclusion Reason", "Observer", "Timestamp", "Participant Comment", "Researcher Notes"]];
header(raw.getRange("A3:T3"));
for (let row = FIRST_DATA_ROW; row <= LAST_DATA_ROW; row += 1) {
  raw.getRange(`A${row}:G${row}`).formulas = [[
    `='Trial Plan'!A${row}`,
    `='Trial Plan'!B${row}`,
    `='Trial Plan'!H${row}`,
    `='Trial Plan'!I${row}`,
    `='Trial Plan'!K${row}`,
    `='Trial Plan'!L${row}`,
    `='Trial Plan'!M${row}`,
  ]];
}
body(raw.getRange(`A4:T${LAST_DATA_ROW}`), { size: 9 });
raw.getRange(`H4:T${LAST_DATA_ROW}`).format.fill = LIGHT_GOLD;
raw.getRange(`H4:H${LAST_DATA_ROW}`).dataValidation = { rule: { type: "decimal", operator: "between", formula1: 0, formula2: 180 } };
raw.getRange(`I4:K${LAST_DATA_ROW}`).dataValidation = { rule: { type: "whole", operator: "between", formula1: 0, formula2: 999 } };
raw.getRange(`L4:L${LAST_DATA_ROW}`).dataValidation = { rule: { type: "list", values: ["Yes", "No"] } };
raw.getRange(`M4:N${LAST_DATA_ROW}`).dataValidation = { rule: { type: "whole", operator: "between", formula1: 1, formula2: 7 } };
raw.getRange(`O4:O${LAST_DATA_ROW}`).dataValidation = { rule: { type: "list", values: ["No", "Yes"] } };
raw.getRange(`P4:P${LAST_DATA_ROW}`).dataValidation = { rule: { type: "list", values: ["", "Editor Crash", "Stale Live Debug", "Wrong Initial State", "Researcher Error", "Participant Withdrawal", "Other"] } };
raw.getRange("A:G").format.columnWidth = 19;
raw.getRange("H:O").format.columnWidth = 15;
raw.getRange("P:P").format.columnWidth = 24;
raw.getRange("Q:R").format.columnWidth = 18;
raw.getRange("S:T").format.columnWidth = 36;
raw.getRange(`H4:H${LAST_DATA_ROW}`).format.numberFormat = "0.0";
raw.getRange(`I4:K${LAST_DATA_ROW}`).format.numberFormat = "0";
raw.getRange(`M4:N${LAST_DATA_ROW}`).format.numberFormat = "0";
raw.freezePanes.freezeRows(3);

title(summary, "方法 × 任务采集进度（公式驱动）", "J");
note(summary, "A3:J5", "状态：待采集。这里只提供均值用于现场完整性检查；论文统计必须运行分析脚本，报告 Median [Q1, Q3]、Friedman、校正配对检验和效应量。", LIGHT_RED, RED);
summary.getRange("A7:J7").values = [["Method", "Task", "Valid N", "Success Rate", "Mean Time (s)", "Mean Errors", "Mean Nav", "Readability", "Cognitive Load", "Status"]];
header(summary.getRange("A7:J7"));
const summaryRows = [];
for (const method of METHODS) for (const task of TASKS) summaryRows.push([method, task]);
summary.getRange("A8:B25").values = summaryRows;
for (let row = 8; row <= 25; row += 1) {
  const criteria = `'Raw Data'!$D$4:$D$${LAST_DATA_ROW},$A${row},'Raw Data'!$C$4:$C$${LAST_DATA_ROW},$B${row},'Raw Data'!$O$4:$O$${LAST_DATA_ROW},"No",'Raw Data'!$H$4:$H$${LAST_DATA_ROW},">=0"`;
  summary.getRange(`C${row}`).formulas = [[`=COUNTIFS(${criteria})`]];
  summary.getRange(`D${row}`).formulas = [[`=IF(C${row}=0,"",COUNTIFS(${criteria},'Raw Data'!$L$4:$L$${LAST_DATA_ROW},"Yes")/C${row})`]];
  summary.getRange(`E${row}`).formulas = [[`=IF(C${row}=0,"",SUMIFS('Raw Data'!$H$4:$H$${LAST_DATA_ROW},${criteria})/C${row})`]];
  summary.getRange(`F${row}`).formulas = [[`=IF(C${row}=0,"",SUMIFS('Raw Data'!$I$4:$I$${LAST_DATA_ROW},${criteria})/C${row})`]];
  summary.getRange(`G${row}`).formulas = [[`=IF(C${row}=0,"",(SUMIFS('Raw Data'!$J$4:$J$${LAST_DATA_ROW},${criteria})+SUMIFS('Raw Data'!$K$4:$K$${LAST_DATA_ROW},${criteria}))/C${row})`]];
  summary.getRange(`H${row}`).formulas = [[`=IF(C${row}=0,"",SUMIFS('Raw Data'!$M$4:$M$${LAST_DATA_ROW},${criteria})/C${row})`]];
  summary.getRange(`I${row}`).formulas = [[`=IF(C${row}=0,"",SUMIFS('Raw Data'!$N$4:$N$${LAST_DATA_ROW},${criteria})/C${row})`]];
  summary.getRange(`J${row}`).formulas = [[`=IF(C${row}=0,"待采集","有数据")`]];
}
body(summary.getRange("A8:J25"), { size: 9 });
summary.getRange("C8:C25").format.numberFormat = "0";
summary.getRange("D8:D25").format.numberFormat = "0.0%";
summary.getRange("E8:I25").format.numberFormat = "0.00";
summary.getRange("J8:J25").format = { fill: LIGHT_GOLD, font: { bold: true, color: GOLD }, horizontalAlignment: "center", borders: { preset: "all", style: "thin", color: GRID } };
section(summary, "A28:J28", "论文分析规则");
summary.getRange("A29:J35").merge(true);
summary.getRange("A29:A35").values = [
  ["1. 主时间分析保留失败和 180 秒超时；另报告仅成功试验的敏感性分析。"],
  ["2. 每种方法按任务报告 N、成功率、Median [Q1, Q3]、错误、导航和评分。"],
  ["3. 每个任务先做 Friedman；显著后才做优化与 Baseline 的 Wilcoxon 配对。"],
  ["4. 五个配对使用 Holm 校正，并报告效应量；成功率用 Cochran Q / McNemar。"],
  ["5. 可读性越高越好；认知负担越低越好，不能未经反向编码直接相加。"],
  ["6. 自动几何证据与真人任务证据分开陈述，GPU 耗时不证明开发者更方便。"],
  ["7. 未采集真人数据时只报告实验装置已验证，绝不生成参与者结果。"],
];
summary.getRange("A29:J35").format = { fill: LIGHT, font: { name: "Microsoft YaHei", size: 10, color: INK }, wrapText: true };
summary.getRange("A:B").format.columnWidth = 24;
summary.getRange("C:J").format.columnWidth = 17;
summary.freezePanes.freezeRows(7);

title(exclusions, "预先冻结的排除与计分规则", "F");
exclusions.getRange("A3:F3").values = [["Level", "Condition", "Exclude?", "Raw Data Handling", "Reason Code", "Notes"]];
header(exclusions.getRange("A3:F3"));
exclusions.getRange("A4:F12").values = [
  ["Trial", "Editor or native crash", "Yes", "Mark Excluded=Yes; reschedule", "Editor Crash", "Not a participant-performance failure"],
  ["Trial", "Live Debug snapshot older than 2 seconds", "Yes", "Mark Excluded=Yes; refresh and reschedule", "Stale Live Debug", "Verify ArenaEnemy / RUNNING / Depth 7"],
  ["Trial", "Wrong tree, target, zoom, pan, or switch state", "Yes", "Mark Excluded=Yes; reset and reschedule", "Wrong Initial State", "Document the incorrect state"],
  ["Trial", "Researcher gives hint or starts timer incorrectly", "Yes", "Mark Excluded=Yes; reschedule", "Researcher Error", "Do not silently overwrite"],
  ["Trial", "Participant reaches 180 seconds", "No", "Time=180; Success=No", "", "Normal outcome, not an outlier"],
  ["Trial", "Participant chooses wrong node/path/value", "No", "Increment Errors; retain time", "", "Normal task error"],
  ["Trial", "Participant gives up", "No", "Success=No; retain actual time", "", "Record reason in comment"],
  ["Participant", "Withdraws consent or never consented", "Yes", "Mark affected rows excluded", "Participant Withdrawal", "Store anonymous ID only"],
  ["Participant", "Device/project failure affects more than 3 trials", "Yes", "Exclude after documented review", "Other", "Apply before inferential analysis"],
];
body(exclusions.getRange("A4:F12"), { size: 9 });
note(exclusions, "A15:F18", "排除规则必须在查看方法差异前冻结。正常失败、错误、放弃和超时不能为了改善结果而删除。主结果保留失败和封顶时间，另可报告仅成功试验的敏感性分析。", LIGHT_RED, RED);
exclusions.getRange("A:A").format.columnWidth = 16;
exclusions.getRange("B:B").format.columnWidth = 48;
exclusions.getRange("C:C").format.columnWidth = 13;
exclusions.getRange("D:D").format.columnWidth = 42;
exclusions.getRange("E:E").format.columnWidth = 25;
exclusions.getRange("F:F").format.columnWidth = 40;

workbook.recalculate();
await fs.mkdir(OUTPUT_DIR, { recursive: true });
await fs.mkdir(QA_DIR, { recursive: true });

const keyRanges = [
  ["Participants", `A3:I${PARTICIPANT_COUNT + 3}`],
  ["Counterbalance", `A3:G${PARTICIPANT_COUNT + 18}`],
  ["Trial Plan", "A3:O12"],
  ["Raw Data", "A3:T12"],
  ["Summary", "A7:J25"],
];
for (const [sheetName, range] of keyRanges) {
  const inspected = await workbook.inspect({ kind: "table", range: `${sheetName}!${range}`, include: "values,formulas", tableMaxRows: 40, tableMaxCols: 24 });
  console.log(inspected.ndjson);
}

const formulaErrors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "241-node human study formula error scan",
});
console.log(formulaErrors.ndjson);

for (const [index, sheet] of workbook.worksheets.items.entries()) {
  const preview = await workbook.render({ sheetName: sheet.name, autoCrop: "all", scale: 1, format: "png" });
  const safeName = `${String(index + 1).padStart(2, "0")}_${sheet.name.replace(/[<>:"/\\|?*]+/g, "_")}`;
  await fs.writeFile(path.join(QA_DIR, `${safeName}.png`), new Uint8Array(await preview.arrayBuffer()));
}

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(OUTPUT);
console.log(`Saved ${OUTPUT}`);
