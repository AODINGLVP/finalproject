from __future__ import annotations

import re
import os
from io import BytesIO
from pathlib import Path

from docx import Document
from docx.document import Document as DocumentObject
from docx.oxml.ns import qn
from docx.oxml.table import CT_Tbl
from docx.oxml.text.paragraph import CT_P
from docx.table import Table
from docx.text.paragraph import Paragraph
from PIL import Image


VERSION_DIR = Path(__file__).resolve().parents[1]
INPUT_DOCX = VERSION_DIR / "output" / "行为树论文_中文_最终版_2026-08-28.docx"
OLD_SOURCE = VERSION_DIR / "source" / "论文内容_中文_上一版参考.md"
OUTPUT_MD = VERSION_DIR / "source" / "论文内容_中文_来自用户DOCX.md"
FIG_DIR = VERSION_DIR / "figures" / "extracted"


def iter_blocks(document: DocumentObject):
    for child in document.element.body.iterchildren():
        if isinstance(child, CT_P):
            yield Paragraph(child, document)
        elif isinstance(child, CT_Tbl):
            yield Table(child, document)


def paragraph_images(paragraph: Paragraph) -> list[Image.Image]:
    images: list[Image.Image] = []
    for blip in paragraph._p.xpath(".//a:blip"):
        rid = blip.get(qn("r:embed"))
        if not rid:
            continue
        part = paragraph.part.related_parts[rid]
        image = Image.open(BytesIO(part.blob)).convert("RGB")
        images.append(image)
    return images


def compose_images(images: list[Image.Image]) -> Image.Image:
    if len(images) == 1:
        return images[0]
    gap = 20
    width = sum(image.width for image in images) + gap * (len(images) - 1)
    height = max(image.height for image in images)
    canvas = Image.new("RGB", (width, height), "white")
    x = 0
    for image in images:
        y = (height - image.height) // 2
        canvas.paste(image, (x, y))
        x += image.width + gap
    return canvas


def table_to_markdown(table: Table) -> str:
    rows: list[list[str]] = []
    for row in table.rows:
        rows.append([" ".join(cell.text.split()).replace("|", "\\|") for cell in row.cells])
    if not rows:
        return ""
    lines = ["| " + " | ".join(rows[0]) + " |"]
    lines.append("| " + " | ".join("---" for _ in rows[0]) + " |")
    for row in rows[1:]:
        lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines)


def is_heading(style: str, text: str) -> int | None:
    if text in {"致谢", "声明", "摘要", "缩略语", "参考文献"}:
        return 1
    if re.match(r"^第\d+章", text):
        return 1
    if re.match(r"^\d+\.\d+\.\d+\s", text) or re.match(r"^\d+\.\d+\.\d+　", text):
        return 3
    if re.match(r"^\d+\.\d+\s", text) or re.match(r"^\d+\.\d+　", text):
        return 2
    if style == "Heading 1" and text:
        return 1
    return None


def main() -> None:
    FIG_DIR.mkdir(parents=True, exist_ok=True)
    old = OLD_SOURCE.read_text(encoding="utf-8")
    metadata = old.split("# 致谢", 1)[0].strip()
    metadata = re.sub(r"(?m)^version:.*$", "version: 最终版 2026-08-28", metadata)

    doc = Document(str(INPUT_DOCX))
    blocks = list(iter_blocks(doc))
    output: list[str] = [metadata]
    started = False
    skip_next_figure_caption = False
    pending_table_caption: str | None = None
    image_count = 0

    for idx, block in enumerate(blocks):
        if isinstance(block, Paragraph):
            raw = " ".join(block.text.split())
            if not started:
                if raw == "致谢":
                    started = True
                else:
                    continue
            images = paragraph_images(block)
            if images:
                caption = ""
                for next_block in blocks[idx + 1 : idx + 4]:
                    if isinstance(next_block, Paragraph):
                        text = " ".join(next_block.text.split())
                        if text.startswith("图 "):
                            caption = text
                            break
                image_count += 1
                safe = caption.replace("图 ", "figure_").split("　", 1)[0].replace(".", "_").replace(" ", "_")
                if not safe:
                    safe = f"figure_{image_count}"
                path = FIG_DIR / f"{safe}.png"
                compose_images(images).save(path)
                rel = os.path.relpath(path, OUTPUT_MD.parent).replace("\\", "/")
                output.append(f"![{caption}]({rel})")
                skip_next_figure_caption = True
                continue
            if skip_next_figure_caption and raw.startswith("图 "):
                skip_next_figure_caption = False
                continue
            skip_next_figure_caption = False
            if not raw:
                continue
            if raw.startswith("7表 5.2"):
                continue
            if raw.startswith("表 "):
                pending_table_caption = raw
                continue
            level = is_heading(block.style.name, raw)
            if level:
                output.append("#" * level + " " + raw)
            elif block.style.name == "List Bullet":
                output.append(f"- {raw}")
            else:
                output.append(raw)
        else:
            output.append(table_to_markdown(block))
            if pending_table_caption:
                output.append(pending_table_caption)
                pending_table_caption = None

    OUTPUT_MD.write_text("\n\n".join(part for part in output if part).strip() + "\n", encoding="utf-8")
    print(OUTPUT_MD)
    print(f"EXTRACTED_IMAGES={image_count}")


if __name__ == "__main__":
    main()
