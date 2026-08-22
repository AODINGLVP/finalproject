import fs from "node:fs/promises";
import path from "node:path";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const inputPath = "research/display_optimization/behavior_tree_human_comparison_study.xlsx";
const outputDir = "research/display_optimization/human_study_workbook_audit";
const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(inputPath));
await fs.mkdir(outputDir, { recursive: true });

const sheets = await workbook.inspect({ kind: "sheet", include: "id,name" });
console.log(sheets.ndjson);

for (const range of ["Trial Plan!A216:O219", "Raw Data!A216:T219"]) {
  const tail = await workbook.inspect({ kind: "table", range, include: "values,formulas", tableMaxRows: 10, tableMaxCols: 20 });
  console.log(tail.ndjson);
}

for (const [index, sheet] of workbook.worksheets.items.entries()) {
  const used = sheet.getUsedRange();
  console.log(`--- ${sheet.name} ${used?.address ?? "empty"} ---`);
  if (used) {
    const region = await workbook.inspect({ kind: "region", sheetId: sheet.name, range: used.address, maxChars: 2500 });
    console.log(region.ndjson);
  }
  const preview = await workbook.render({ sheetName: sheet.name, autoCrop: "all", scale: 1, format: "png" });
  const safeName = `${String(index + 1).padStart(2, "0")}_${sheet.name.replace(/[<>:\"/\\|?*]+/g, "_")}`;
  await fs.writeFile(path.join(outputDir, `${safeName}.png`), new Uint8Array(await preview.arrayBuffer()));
}

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "human study imported formula error scan",
});
console.log(errors.ndjson);

// In-memory samples prove that the empty template formulas calculate real observations correctly.
const raw = workbook.worksheets.getItem("Raw Data");
raw.getRange("H4:O5").values = [
  [30, 1, 2, 1, "Yes", 6, 2, "No"],
  [60, 3, 4, 2, "No", 4, 5, "No"],
];
workbook.recalculate();
const sampleSummary = await workbook.inspect({ kind: "table", range: "Summary!A8:J8", include: "values,formulas", tableMaxRows: 2, tableMaxCols: 12 });
console.log(sampleSummary.ndjson);
