"""Compare the editable body of two dissertation DOCX files."""

from __future__ import annotations

import argparse
import difflib
from pathlib import Path

from docx import Document
from docx.document import Document as DocumentObject
from docx.oxml.table import CT_Tbl
from docx.oxml.text.paragraph import CT_P
from docx.table import Table
from docx.text.paragraph import Paragraph


def iter_blocks(document: DocumentObject):
    for child in document.element.body.iterchildren():
        if isinstance(child, CT_P):
            yield Paragraph(child, document)
        elif isinstance(child, CT_Tbl):
            yield Table(child, document)


def body_records(path: Path) -> list[str]:
    records: list[str] = []
    started = False
    for block in iter_blocks(Document(path)):
        if isinstance(block, Paragraph):
            text = " ".join(block.text.split())
            if not started:
                if text == "致谢":
                    started = True
                else:
                    continue
            if text:
                records.append(f"P[{block.style.name}] {text}")
        elif started:
            rows = [
                " | ".join(" ".join(cell.text.split()) for cell in row.cells)
                for row in block.rows
            ]
            records.append("T " + " || ".join(rows))
    return records


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("baseline", type=Path)
    parser.add_argument("edited", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    baseline = body_records(args.baseline)
    edited = body_records(args.edited)
    diff = list(
        difflib.unified_diff(
            baseline,
            edited,
            fromfile=str(args.baseline),
            tofile=str(args.edited),
            lineterm="",
            n=2,
        )
    )
    args.output.write_text("\n".join(diff) + "\n", encoding="utf-8")
    print(f"baseline_records={len(baseline)}")
    print(f"edited_records={len(edited)}")
    print(f"diff_lines={len(diff)}")


if __name__ == "__main__":
    main()
