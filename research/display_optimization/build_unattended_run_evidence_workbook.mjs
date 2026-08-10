import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const ROOT = path.resolve(".");
const CSV_PATH = path.join(ROOT, "testgame/testgame/test_results/runtime_profile.csv");
const OUTPUT = path.join(ROOT, "research/display_optimization/behavior_tree_unattended_run_evidence.xlsx");
const QA_DIR = path.join(ROOT, "research/display_optimization/unattended_run_workbook_qa");

const csvText = await fs.readFile(CSV_PATH, "utf8");
const lines = csvText.trim().split(/\r?\n/);
const rows = lines.slice(1).map((line) => line.split(",").map((value, index) => index === 2 ? value === "true" : Number(value)));
const workbook = Workbook.create();
const overview = workbook.worksheets.add("Overview");
const tasks = workbook.worksheets.add("Task Validation");
const runtime = workbook.worksheets.add("Runtime Raw Data");
const summary = workbook.worksheets.add("Runtime Summary");
const switches = workbook.worksheets.add("Display Switches");
const visuals = workbook.worksheets.add("Visual Evidence");
const reproduce = workbook.worksheets.add("Reproduce");

const NAVY = "#16324F", BLUE = "#2E75B6", TEAL = "#0F766E", GREEN = "#18864B", GOLD = "#D99A16";
const LIGHT = "#F4F7FA", GRID = "#D9E2EC", RED = "#B42318", INK = "#172B3A", MUTED = "#52606D";
const title = (sheet, text, end) => {
  sheet.getRange(`A1:${end}1`).merge();
  sheet.getRange("A1").values = [[text]];
  sheet.getRange(`A1:${end}1`).format = { fill: NAVY, font: { bold: true, color: "#FFFFFF", size: 16 }, rowHeight: 30, verticalAlignment: "center" };
};
const header = (range) => range.format = { fill: BLUE, font: { bold: true, color: "#FFFFFF" }, horizontalAlignment: "center", verticalAlignment: "center", wrapText: true, borders: { preset: "all", style: "thin", color: GRID } };
const body = (range) => range.format = { font: { color: INK, size: 9 }, verticalAlignment: "center", wrapText: true, borders: { preset: "inside", style: "thin", color: GRID } };
const note = (sheet, address, text, fill = "#FFF7DC", color = MUTED) => {
  sheet.getRange(address).merge();
  sheet.getRange(address.split(":")[0]).values = [[text]];
  sheet.getRange(address).format = { fill, font: { color, italic: true, size: 9 }, wrapText: true, verticalAlignment: "center" };
};

for (const sheet of workbook.worksheets.items) sheet.showGridLines = false;

title(overview, "Behavior Tree Project: Reproducible Evidence", "H");
overview.getRange("A3:B3").values = [["Verified area", "Result"]]; header(overview.getRange("A3:B3"));
overview.getRange("A4:B10").values = [
  ["Runtime/resource regression", "153 / 153"], ["Editor GUI regression", "185 / 185"],
  ["Core GPU visual regression", "70 / 70"], ["Runtime profile assertions", "511 / 511"],
  ["Runtime raw observations", rows.length], ["Display switches", 19], ["Human participant data", "Not collected"]
]; body(overview.getRange("A4:B10"));
overview.getRange("D3:E3").values = [["Environment", "Value"]]; header(overview.getRange("D3:E3"));
overview.getRange("D4:E9").values = [["Date", "2026-08-09"], ["Godot", "4.6 stable"], ["OS", "Windows"], ["GPU visual", "NVIDIA OpenGL 3.3 compatibility"], ["Viewport", "1600 x 900"], ["Runtime statistic", "Median of 7 samples"]]; body(overview.getRange("D4:E9"));
overview.getRange("A12:H12").merge(); overview.getRange("A12").values = [["Key measured outcomes"]]; overview.getRange("A12:H12").format = { fill: TEAL, font: { bold: true, color: "#FFFFFF" } };
overview.getRange("A14:D14").values = [["Tree nodes", "NPCs", "Median cache gain", "Interpretation"]]; header(overview.getRange("A14:D14"));
overview.getRange("A15:D17").values = [[31, "1 / 10 / 50", "15.98% - 26.46%", "Safe exact validation; positive gain"], [121, "1 / 10 / 50", "52.61% - 56.02%", "Stable medium-tree benefit"], [364, "1 / 10 / 50", "76.65% - 78.00%", "Large-tree lookup bottleneck reduced"]]; body(overview.getRange("A15:D17"));
note(overview, "A20:H23", "Scope boundary: automated geometry, rendering and timing evidence does not prove human readability. The prepared 270-trial workbook remains empty until 8-15 real participants complete the study. Exact per-Tick topology validation trades some small-tree speed for safe same-size mutation invalidation. Timings describe this machine and workload, not a universal guarantee.");
overview.getRange("A:A").format.columnWidth = 32; overview.getRange("B:B").format.columnWidth = 20; overview.getRange("C:C").format.columnWidth = 18; overview.getRange("D:D").format.columnWidth = 30; overview.getRange("E:H").format.columnWidth = 18;

title(tasks, "Independent Task Completion Gates", "F");
tasks.getRange("A3:F3").values = [["Task", "Implemented", "Focused test", "Regression", "GPU visual", "Evidence"]]; header(tasks.getRange("A3:F3"));
tasks.getRange("A4:F12").values = [
  ["Blackboard Schema Editor", "Yes", "19 new GUI assertions", "153 runtime + prior GUI", "Schema panel screenshot", "Typed CRUD, validation, history, persistence"],
  ["Shape/Icon Type Encoding", "Yes", "3 new GUI assertions", "171 GUI", "Color + grayscale", "Low-detail identity and safe disable"],
  ["Accessibility", "Yes", "5 new GUI assertions", "176 GUI", "215 blue / 283 orange sampled pixels", "Palette, Ctrl+F, F3, tooltips"],
  ["Single Connection Rendering", "Yes", "6 new GUI assertions", "182 GUI", "Single-line screenshot", "Hit test, disconnect, undo/redo, fallback"],
  ["Runtime Cache Experiment", "Yes", "511 assertions", "153 semantic regression", "N/A", "Exact signature and same-size invalidation"],
  ["Reproducible Evidence", "Yes", "Formula/error audit", "447 core regression", "21 indexed screenshots", "Workbook, commands, logs and raw CSV"],
  ["Blackboard Reference Assistance", "Yes", "6 runtime + 3 GUI", "153 runtime / 185 GUI", "Schema key picker", "Typed picker, strict references, unused keys"],
  ["Safe Cache Invalidation", "Yes", "4 same-size cases", "511 profile / 153 semantics", "N/A", "Reorder, parent, Decorator owner, instance"],
  ["Distributable Package", "Yes", "53 package checks", "3 project startups", "N/A", "ZIP boundary, MIT, hashes, clean install"]
]; body(tasks.getRange("A4:F12")); tasks.getRange("B4:B12").format = { fill: "#DDF3E5", font: { bold: true, color: GREEN }, horizontalAlignment: "center" };
for (const [col,width] of [["A",30],["B",13],["C",24],["D",22],["E",25],["F",42]]) tasks.getRange(`${col}:${col}`).format.columnWidth = width;

title(runtime, "Runtime Profile Raw Observations", "I");
runtime.getRange("A3:I3").values = [["Tree nodes", "NPC count", "Cache enabled", "Sample", "Ticks/runner", "Total ticks", "Elapsed ms", "Mean tick us", "Status"]]; header(runtime.getRange("A3:I3"));
runtime.getRange(`A4:I${rows.length + 3}`).values = rows; body(runtime.getRange(`A4:I${rows.length + 3}`));
runtime.getRange(`A4:F${rows.length + 3}`).format.numberFormat = "#,##0"; runtime.getRange(`G4:H${rows.length + 3}`).format.numberFormat = "0.0000";
runtime.freezePanes.freezeRows(3); for (const c of "ABCDEFGHI") runtime.getRange(`${c}:${c}`).format.columnWidth = c === "C" ? 16 : 14;

title(summary, "Runtime Cache Comparison (Formula Driven)", "H");
summary.getRange("A3:H3").values = [["Tree nodes", "NPCs", "Uncached median us", "Cached median us", "Gain us", "Gain %", "All SUCCESS", "Samples"]]; header(summary.getRange("A3:H3"));
let outRow = 4;
for (const tree of [31,121,364]) for (const npc of [1,10,50]) {
  summary.getRange(`A${outRow}:B${outRow}`).values = [[tree,npc]];
  const uncached = rows.filter(r => r[0]===tree && r[1]===npc && r[2]===false).map(r=>r[7]).sort((a,b)=>a-b)[3];
  const cached = rows.filter(r => r[0]===tree && r[1]===npc && r[2]===true).map(r=>r[7]).sort((a,b)=>a-b)[3];
  summary.getRange(`C${outRow}:D${outRow}`).values = [[uncached,cached]];
  summary.getRange(`E${outRow}`).formulas = [[`=C${outRow}-D${outRow}`]];
  summary.getRange(`F${outRow}`).formulas = [[`=E${outRow}/C${outRow}`]];
  summary.getRange(`G${outRow}`).formulas = [[`=COUNTIFS('Runtime Raw Data'!$A$4:$A$129,A${outRow},'Runtime Raw Data'!$B$4:$B$129,B${outRow},'Runtime Raw Data'!$I$4:$I$129,1)=14`]];
  summary.getRange(`H${outRow}`).formulas = [[`=COUNTIFS('Runtime Raw Data'!$A$4:$A$129,A${outRow},'Runtime Raw Data'!$B$4:$B$129,B${outRow})`]];
  outRow++;
}
body(summary.getRange("A4:H12")); summary.getRange("C4:E12").format.numberFormat = "0.000"; summary.getRange("F4:F12").format.numberFormat = "0.00%"; summary.getRange("A:H").format.columnWidth = 18;
note(summary, "A15:H17", "Medians in columns C-D are imported from the deterministic benchmark run; derived gain and quality-control columns are workbook formulas. Every scenario uses seven cached and seven uncached samples after warmup.");

title(switches, "Independent Display Feature Switches", "E");
switches.getRange("A3:E3").values = [["Key", "UI label", "Default", "Safe disable", "Purpose"]]; header(switches.getRange("A3:E3"));
const featureRows = [
  ["fisheye","Fisheye / Focus+Context",true,"Resets transform","Pointer focus"], ["subtree_collapse","Subtree Collapse / Expand",true,"Restores descendants","Structural reduction"], ["compact","Compact Mode",false,"Restores cards","Density"], ["type_encoding","Shape / Icon Type Encoding",false,"Hides icons","Grayscale identity"], ["accessibility","Accessibility / Colorblind Palette",false,"Restores palette","Color/keyboard access"], ["single_connection","Single Connection Rendering",true,"Restores native line","Remove helper edge"], ["active_path","Active Path Highlight",true,"Clears highlight","Runtime trace"], ["branch_dimming","Non-active Branch Dimming",false,"Restores alpha","Runtime focus"], ["multi_column","Multi-column Layout",false,"One-row layout","Wide fan-out"], ["enhanced_minimap","Enhanced Minimap",true,"Standard minimap off","Overview+detail"], ["semantic_zoom","Semantic Zoom",false,"Full detail","Information density"], ["path_summary","Path Summary View",true,"Clears row","Runtime navigation"], ["decorator_badges","Decorator Badges",true,"Hides badges","Condition visibility"], ["search","Search + Highlight",true,"Clears query/dimming","Target location"], ["orthogonal_edges","Orthogonal Edges",false,"Bezier route","Connection clarity"], ["edge_bundling","Edge Bundling",false,"Bezier route","Connection density"], ["stable_layout","Stable Incremental Layout",false,"Normal arrange","Mental map"], ["breadcrumb","Breadcrumb Navigation",true,"Clears row","Hierarchy navigation"], ["failure_reason","Failure Reason Annotation",true,"Clears badges","Runtime diagnosis"]
];
switches.getRange("A4:E22").values = featureRows; body(switches.getRange("A4:E22")); switches.freezePanes.freezeRows(3); switches.getRange("A:A").format.columnWidth=25; switches.getRange("B:B").format.columnWidth=34; switches.getRange("C:D").format.columnWidth=18; switches.getRange("E:E").format.columnWidth=28;

title(visuals, "Fixed GPU Visual Evidence Index", "E");
visuals.getRange("A3:E3").values = [["File", "Case", "Viewport", "Automated gate", "Manual observation"]]; header(visuals.getRange("A3:E3"));
const visualFiles = ["01_baseline.png","01b_type_encoding.png","01c_type_encoding_grayscale.png","01d_accessible_palette.png","01e_single_connections.png","02_compact.png","03_fisheye.png","04_fisheye_disabled.png","05_collapsed.png","06_search.png","07_runtime_failure.png","07b_live_blackboard.png","07c_schema_editor.png","07d_schema_key_picker.png","08_orthogonal_edges.png","09_bundled_edges.png","10_complex_tree.png"];
visuals.getRange("A4:E20").values = visualFiles.map((file) => [file, file.replace(/\.png$/,""), "1600 x 900", "Image valid + case assertions", file.includes("single") ? "No faint native helper line" : file.includes("schema") ? "Schema controls do not overlap" : "Layout and reset inspected"]); body(visuals.getRange("A4:E20")); visuals.getRange("A:A").format.columnWidth=38; visuals.getRange("B:B").format.columnWidth=32; visuals.getRange("C:D").format.columnWidth=23; visuals.getRange("E:E").format.columnWidth=38;

title(reproduce, "Reproduction Commands and Evidence Paths", "D");
reproduce.getRange("A3:D3").values = [["Purpose", "Command / path", "Expected", "Failure gate"]]; header(reproduce.getRange("A3:D3"));
const commands = [
  ["Runtime semantics", "Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path testgame/testgame --script res://tests/run_behavior_tree_tests.gd", "153/153", "Nonzero, FAIL, ERROR, SCRIPT ERROR, leak/crash"],
  ["Editor GUI", "... --script res://tests/run_editor_view_tests.gd", "185/185", "Same strict gate"],
  ["GPU visual", "... --rendering-method gl_compatibility --script res://tests/run_visual_regression_tests.gd", "70/70", "Same gate + manual image inspection"],
  ["Runtime profile", "... --headless --script res://tests/run_runtime_profile.gd", "511/511", "Every cached median must beat uncached"],
  ["Raw timing data", "testgame/testgame/test_results/runtime_profile.csv", "126 observations", "No missing scenario/sample"],
  ["Visual output", "testgame/testgame/test_results/visual/", "17 PNG", "1600x900 and visually legible"],
  ["Human study", "research/display_optimization/behavior_tree_human_comparison_study.xlsx", "270 planned trials", "Do not fabricate participant data"],
  ["Package", "tools/package_behavior_tree_plugin.ps1", "53/53", "ZIP boundary, SHA-256, clean Godot install"]
];
reproduce.getRange("A4:D11").values = commands; body(reproduce.getRange("A4:D11")); reproduce.getRange("A:A").format.columnWidth=25; reproduce.getRange("B:B").format.columnWidth=88; reproduce.getRange("C:C").format.columnWidth=24; reproduce.getRange("D:D").format.columnWidth=42; reproduce.getRange("A4:D11").format.rowHeight=42;

await fs.mkdir(QA_DIR, { recursive: true });
const errors = await workbook.inspect({ kind: "match", searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A", options: { useRegex: true, maxResults: 100 }, summary: "formula error scan" });
console.log(errors.ndjson);
for (const [index, sheet] of workbook.worksheets.items.entries()) {
  const image = await workbook.render({ sheetName: sheet.name, autoCrop: "all", scale: 1, format: "png" });
  await fs.writeFile(path.join(QA_DIR, `${String(index+1).padStart(2,"0")}_${sheet.name.replaceAll(" ","_")}.png`), new Uint8Array(await image.arrayBuffer()));
}
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(OUTPUT);
console.log(`Saved ${OUTPUT}`);
