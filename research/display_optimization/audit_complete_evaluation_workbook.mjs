import fs from "node:fs/promises";
import path from "node:path";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const workbookPath = "research/display_optimization/behavior_tree_complete_validation_and_display_evaluation.xlsx";
const outputDir = "research/display_optimization/complete_evaluation_qa_before";

const input = await FileBlob.load(workbookPath);
const workbook = await SpreadsheetFile.importXlsx(input);
await fs.mkdir(outputDir, { recursive: true });

const sheets = await workbook.inspect({ kind: "sheet", include: "id,name" });
console.log(sheets.ndjson);

for (const [index, sheet] of workbook.worksheets.items.entries()) {
  const used = sheet.getUsedRange();
  const region = used
    ? await workbook.inspect({
        kind: "region",
        sheetId: sheet.name,
        range: used.address,
        maxChars: 3500,
      })
    : null;
  console.log(`--- ${sheet.name} ${used?.address ?? "empty"} ---`);
  if (region) console.log(region.ndjson);

  const preview = await workbook.render({
    sheetName: sheet.name,
    autoCrop: "all",
    scale: 1,
    format: "png",
  });
  const safeName = `${String(index + 1).padStart(2, "0")}_${sheet.name.replace(/[<>:\"/\\|?*]+/g, "_")}`;
  await fs.writeFile(path.join(outputDir, `${safeName}.png`), new Uint8Array(await preview.arrayBuffer()));
}

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "final formula error scan",
});
console.log(errors.ndjson);
