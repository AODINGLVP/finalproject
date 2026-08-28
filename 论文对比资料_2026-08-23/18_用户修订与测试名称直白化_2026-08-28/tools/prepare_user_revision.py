"""Promote the user's edited DOCX chapters 1-3 into a canonical Markdown source.

The user-edited DOCX is authoritative for the front matter and chapters 1-3.
Chapter 4 onward remains identical to the previously generated version.  This
script deliberately never reads text from a PDF and never overwrites the user
checkpoint DOCX.
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

from docx import Document
from docx.document import Document as DocumentObject
from docx.oxml.table import CT_Tbl
from docx.oxml.text.paragraph import CT_P
from docx.table import Table
from docx.text.paragraph import Paragraph


VERSION_DIR = Path(__file__).resolve().parent.parent
ROOT = VERSION_DIR.parent.parent
PREVIOUS_DIR = ROOT / "论文对比资料_2026-08-23" / "15_移除技术文档引用_34篇_2026-08-28"
INPUT_DOCX = VERSION_DIR / "source" / "用户修改原稿_前三章_2026-08-28.docx"
PREVIOUS_MARKDOWN = PREVIOUS_DIR / "source" / "论文内容_中文.md"
OUTPUT_MARKDOWN = VERSION_DIR / "source" / "论文内容_中文.md"
OUTPUT_MANIFEST = VERSION_DIR / "source" / "用户修订提取记录.json"


LIST_ITEMS = {
    "该功能主要帮助完成什么操作；",
    "开启后是否更容易查看或编辑行为树；",
    "使用过程中出现了什么问题；",
    "该功能更适合哪种行为树规模；",
    "该功能更适合哪种屏幕尺寸；",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def iter_blocks(document: DocumentObject):
    for child in document.element.body.iterchildren():
        if isinstance(child, CT_P):
            yield Paragraph(child, document)
        elif isinstance(child, CT_Tbl):
            yield Table(child, document)


def clean_text(text: str, changes: list[str]) -> str:
    value = " ".join(text.split())
    replacements = {
        "传统行为树辑器": "传统行为树编辑器",
        "在Godot编辑器中": "在 Godot 编辑器中",
    }
    for old, new in replacements.items():
        if old in value:
            value = value.replace(old, new)
            changes.append(f"{old} -> {new}")

    old_strategy = (
        "本研究先确认 Godot 4.6 行为树插件能够正常编辑和运行，再测试大型行为树的五项显示功能。"
        "研究重点为这些显示优化功能在不同的情况下能够展示出多大的效果，他们更加适合什么情况。"
    )
    if value == old_strategy:
        value = (
            "本研究先确认 Godot 4.6 行为树插件能够正常编辑和运行，再测试大型行为树的五项显示功能。"
            "研究重点是这些显示优化功能在不同情况下能够产生多大的效果，以及它们更适合哪些情况。"
        )
        changes.append("理顺3.1研究重点句并将“他们”改为“它们”")

    if value.startswith("项目工作分为平台建设与研究评估。") and value.endswith("；"):
        value = value[:-1] + "。"
        changes.append("将1.4平台建设段末分号改为句号")

    if value.startswith("在测试显示功能之前，必须先确认行为树本身能够正确运行"):
        marker = "Sequence 可以记住当前执行位置"
        if marker in value and "在本项目的实现中，Sequence" not in value:
            value = value.replace(marker, "在本项目的实现中，Sequence 可以记住当前执行位置", 1)
            changes.append("明确2.1节点运行规则描述的是本项目实现")

    return value


def table_to_markdown(table: Table) -> str:
    rows: list[list[str]] = []
    for row in table.rows:
        values = []
        for cell in row.cells:
            value = " ".join(cell.text.split()).replace("|", "\\|")
            values.append(value)
        rows.append(values)
    if not rows or not rows[0]:
        raise ValueError("Encountered an empty table in the edited DOCX")
    lines = ["| " + " | ".join(rows[0]) + " |"]
    lines.append("| " + " | ".join("---" for _ in rows[0]) + " |")
    for row in rows[1:]:
        lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines)


def normalise_caption(text: str) -> str:
    match = re.match(r"表\s*(\d+\.\d+)\s*(.*)", text.strip())
    if not match:
        raise ValueError(f"Unrecognised table caption: {text!r}")
    return f"表 {match.group(1)}　{match.group(2).strip()}"


def normalise_numbered_heading(text: str) -> str:
    chapter = re.match(r"^(第\d+章)\s*(.*)$", text)
    if chapter:
        return f"{chapter.group(1)}　{chapter.group(2).strip()}"
    section = re.match(r"^(\d+(?:\.\d+)+)\s*(.*)$", text)
    if section:
        return f"{section.group(1)}　{section.group(2).strip()}"
    return text


def make_doi_links_clickable(markdown: str) -> str:
    """Turn plain DOI URLs into Markdown links without swallowing sentence punctuation."""

    def replace(match: re.Match[str]) -> str:
        token = match.group(0)
        trailing = ""
        while token.endswith((".", ",", ";")):
            trailing = token[-1] + trailing
            token = token[:-1]
        return f"[{token}]({token}){trailing}"

    return re.sub(r"(?<!\]\()https://doi\.org/\S+", replace, markdown)


def extract_front_and_first_three(document: DocumentObject, changes: list[str]) -> tuple[str, int]:
    blocks: list[str] = []
    list_buffer: list[str] = []
    pending_caption: str | None = None
    started = False
    table_count = 0
    skipped_duplicate = False

    def flush_list() -> None:
        nonlocal list_buffer
        if list_buffer:
            blocks.append("\n".join(f"- {item}" for item in list_buffer))
            list_buffer = []

    for block in iter_blocks(document):
        if isinstance(block, Paragraph):
            raw = " ".join(block.text.split())
            if not started:
                if raw == "致谢":
                    started = True
                else:
                    continue
            if raw.startswith("第4章"):
                flush_list()
                break
            if not raw:
                continue
            if raw == "。":
                changes.append("删除2.2末尾单独的句号段落")
                continue
            if raw == "实验使用可玩游戏中的五棵真实行为树，节点数量分别为31、61、121、241和364。它们代表从小型行为树到大型行为树的不同规模。":
                skipped_duplicate = True
                changes.append("合并3.2重复的实验对象介绍")
                continue

            text = clean_text(raw, changes)
            if text == "实验使用当前可玩游戏中的五棵真实行为树，节点数量分别为31、61、121、241和364。它们代表不同规模和复杂程度的行为树。" and skipped_duplicate:
                text = "实验使用当前可玩游戏中的五棵真实行为树，节点数量分别为31、61、121、241和364。它们代表从小型到大型的不同规模和复杂程度。"

            if re.match(r"表\s*3\.\d+", text):
                flush_list()
                pending_caption = normalise_caption(text)
                continue

            if text in LIST_ITEMS:
                list_buffer.append(text)
                continue
            flush_list()

            if block.style.name in {"Front Matter Heading", "Heading 1"}:
                blocks.append(f"# {normalise_numbered_heading(text)}")
            elif re.match(r"^\d+\.\d+\.\d+\s+", text):
                blocks.append(f"### {normalise_numbered_heading(text)}")
            elif re.match(r"^\d+\.\d+\s+", text):
                blocks.append(f"## {normalise_numbered_heading(text)}")
            else:
                blocks.append(text)
        else:
            flush_list()
            table_count += 1
            blocks.append(table_to_markdown(block))
            if pending_caption is None:
                raise ValueError(f"Table {table_count} has no preceding caption")
            blocks.append(pending_caption)
            pending_caption = None

    flush_list()
    if pending_caption is not None:
        raise ValueError(f"Caption was not followed by a table: {pending_caption}")
    if table_count != 4:
        raise AssertionError(f"Expected four edited Chapter 3 tables, found {table_count}")
    return "\n\n".join(blocks).strip() + "\n", table_count


def build_markdown() -> dict:
    if not INPUT_DOCX.is_file():
        raise FileNotFoundError(INPUT_DOCX)
    if not PREVIOUS_MARKDOWN.is_file():
        raise FileNotFoundError(PREVIOUS_MARKDOWN)

    previous = PREVIOUS_MARKDOWN.read_text(encoding="utf-8")
    metadata, remainder = previous.split("# 致谢", 1)
    del remainder
    metadata = re.sub(
        r"(?m)^version:.*$",
        "version: 执行系统术语统一版 2026-08-28",
        metadata,
    ).rstrip()
    suffix_marker = "# 第4章　系统设计与实现"
    if suffix_marker not in previous:
        raise AssertionError("Previous Markdown has no Chapter 4 marker")
    suffix = suffix_marker + previous.split(suffix_marker, 1)[1]
    suffix = suffix.replace("pp. 73–84", "pp. 73–83")

    changes: list[str] = []
    document = Document(INPUT_DOCX)
    first_part, edited_tables = extract_front_and_first_three(document, changes)
    combined = metadata + "\n\n" + first_part + "\n" + suffix.strip() + "\n"
    terminology_replacements = {
        "系统由编辑器插件、资源模型、运行时、调试桥和测试游戏五部分组成。":
            "系统由编辑器插件、资源模型、执行系统、调试桥和测试游戏五部分组成。",
        "运行时读取同一资源并把 Tick 结果传递给游戏 Actor。":
            "执行系统读取同一资源并把 Tick 结果传递给游戏 Actor。",
        "插件、资源、运行时、调试桥和测试游戏之间的关系":
            "插件、资源、执行系统、调试桥和测试游戏之间的关系",
        "## 4.3　运行时与节点语义": "## 4.3　执行系统与节点语义",
        "运行时每次 Tick 返回": "执行系统每次 Tick 返回",
        "运行时使用树资源": "执行系统使用树资源",
        "Related Focus 与运行时活动路径": "Related Focus 与执行系统的活动路径",
        "资源与运行时、编辑器": "资源与执行系统、编辑器",
        "| 资源与运行时 |": "| 资源与执行系统 |",
        "树资源、编辑器和运行时可以一起工作": "树资源、编辑器和执行系统可以一起工作",
    }
    for old, new in terminology_replacements.items():
        combined = combined.replace(old, new)
    combined = make_doi_links_clickable(combined)

    required = [
        "# 第1章　引言",
        "# 第2章　文献综述",
        "# 第3章　研究方法",
        "## 3.5　数据处理与判断标准",
        "# 第4章　系统设计与实现",
        "# 参考文献",
    ]
    missing = [item for item in required if item not in combined]
    if missing:
        raise AssertionError(f"Generated Markdown is missing required content: {missing}")
    doi_targets = re.findall(r"\]\((https://doi\.org/[^)]+)\)", combined)
    if len(doi_targets) != 34 or len(set(doi_targets)) != 34:
        raise AssertionError("The rebuilt source must contain exactly 34 unique DOI links")
    if "pp. 73–84" in combined or "pp. 73–83" not in combined:
        raise AssertionError("Sarkar and Brown page correction was not applied")
    if "\n。\n" in combined:
        raise AssertionError("The stray punctuation paragraph remains")
    if "运行时" in combined:
        raise AssertionError("The deprecated term 运行时 remains in the dissertation source")

    OUTPUT_MARKDOWN.write_text(combined, encoding="utf-8", newline="\n")
    manifest = {
        "authoritative_input": str(INPUT_DOCX),
        "authoritative_input_sha256": sha256(INPUT_DOCX),
        "preserved_suffix_source": str(PREVIOUS_MARKDOWN),
        "preserved_suffix_source_sha256": sha256(PREVIOUS_MARKDOWN),
        "output_markdown": str(OUTPUT_MARKDOWN),
        "output_markdown_sha256": sha256(OUTPUT_MARKDOWN),
        "edited_chapter_3_tables": edited_tables,
        "reference_count": 34,
        "non_structural_corrections": changes + [
            "Sarkar and Brown (1994) pages 73–84 -> 73–83",
            "运行时 terminology -> 执行系统",
        ],
    }
    OUTPUT_MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


if __name__ == "__main__":
    result = build_markdown()
    print(json.dumps(result, ensure_ascii=False, indent=2))
