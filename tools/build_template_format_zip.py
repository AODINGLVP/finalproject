from __future__ import annotations

import json
import pathlib
import re
import shutil
import zipfile


BASE = pathlib.Path(r"E:/course pdf/project/finalproject")
WORK = sorted(BASE.glob("tmp_template_format_fix_*"), key=lambda p: p.stat().st_mtime, reverse=True)[0]
PAPER = WORK / "paper"
TEMPLATE = WORK / "template"
OUT_BASE = BASE / "论文对比资料_2026-08-23" / "26_模板格式修正版_2026-08-31"


def next_output_dir() -> pathlib.Path:
    out = OUT_BASE
    index = 2
    while out.exists():
        out = pathlib.Path(str(OUT_BASE) + f"_{index}")
        index += 1
    return out


def main() -> None:
    out = next_output_dir()
    shutil.copytree(TEMPLATE, out)

    main_text = (PAPER / "main.tex").read_text(encoding="utf-8")

    meta: dict[str, str] = {}
    for key in ["title", "author", "date", "qualification", "department", "studentnumber"]:
        match = re.search(r"\\" + key + r"\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}", main_text)
        meta[key] = match.group(1) if match else ""

    fronts: dict[str, str] = {}
    front_matches = list(re.finditer(r"\\frontchapter\{([^}]*)\}", main_text))
    chapter_match = re.search(r"^\\chapter\{", main_text, re.M)
    front_end = chapter_match.start() if chapter_match else len(main_text)
    for index, match in enumerate(front_matches):
        start = match.end()
        end = front_matches[index + 1].start() if index + 1 < len(front_matches) else front_end
        fronts[match.group(1)] = main_text[start:end].strip()

    markers = list(re.finditer(r"^\\chapter\{([^}]*)\}|^\\chapter\*\{References\}", main_text, re.M))
    chapters: list[tuple[str, str]] = []
    refs = ""
    for index, match in enumerate(markers):
        title = match.group(1) if match.group(1) is not None else "References"
        start = match.start()
        end = markers[index + 1].start() if index + 1 < len(markers) else main_text.find(r"\end{document}", start)
        block = main_text[start:end].strip()
        if title == "References":
            refs = block
        else:
            chapters.append((title, block))

    extra_packages = r"""
% Additional packages used by this dissertation content
\usepackage{booktabs}
\usepackage{longtable}
\usepackage{array}
\usepackage{graphicx}
\usepackage{enumitem}
\setsecnumdepth{subsubsection}
\settocdepth{subsubsection}
\sloppy
""".strip()

    uwthesis = r"""% Template for University of Warwick Thesis
% Created by Samuel A. Maloney in 2023/2024
% Inspired by template from M Hadley and S Royle in Overleaf Gallery

% Check the "Presentation of thesis" information here:
% https://warwick.ac.uk/services/dc/submission/gtehdr/

% This file has been adapted to contain the current dissertation text while
% preserving the supplied Games Engineering dissertation template structure.

\RequirePackage[l2tabu,orthodox]{nag}
\documentclass[11pt,a4paper,oneside,extrafontsizes]{memoir}
\usepackage[margin=4cm]{uwthesis}
\usepackage[backend=biber,style=nature,doi=true]{biblatex}
\usepackage{silence}
\WarningFilter{nameref}{The definition of \label has changed!}
\usepackage{multirow}
\usepackage[hidelinks]{hyperref}
\usepackage[nameinlink,noabbrev]{cleveref}

""" + extra_packages + r"""

\addbibresource{references.bib}

\DeclareSourcemap{
    \maps[datatype=bibtex]{
        \map{
            \step[fieldsource=doi,final]
            \step[fieldset=issn,null]
            \step[fieldset=isbn,null]
            \step[fieldset=url,null]
        }
        \map{
            \step[fieldsource=doi, match=\regexp{\{\\_\}}, replace=\regexp{_}]
        }
    }
}
\setcounter{biburlnumpenalty}{9000}

"""

    for key in ["title", "author", "date", "qualification", "department", "studentnumber"]:
        uwthesis += f"\\{key}{{{meta[key]}}}\n"

    uwthesis += r"""

\input{abbreviations}

\begin{document}

\input{frontmatter}

\mainmatter

\input{chapters/introduction}
\input{chapters/literaturereview}
\input{chapters/methodology}
\input{chapters/method}
\input{chapters/results}
\input{chapters/discussion}
\input{chapters/conclusion}
\input{chapters/references}

\end{document}
"""

    (out / "uwthesis.tex").write_text(uwthesis, encoding="utf-8")

    frontmatter = r"""% This sets the page numbers to be printed in lowercase roman numerals, starts
% the page numbering from i, and prohibits any numbering of sectional divisions.
\frontmatter

% Generate the title page.
\titlepage[crests/officialmono]

\tableofcontents
\clearforchapter\listoffigures
\clearforchapter\listoftables

"""
    for name in ["Acknowledgements", "Declaration", "Abstract"]:
        if name in fronts:
            frontmatter += f"\\frontchapter{{{name}}}\n\n{fronts[name]}\n\n"
    (out / "frontmatter.tex").write_text(frontmatter, encoding="utf-8")

    (out / "abbreviations.tex").write_text("% Abbreviations can be declared here if needed.\n", encoding="utf-8")

    name_map = {
        "Introduction": "introduction.tex",
        "Literature review": "literaturereview.tex",
        "Research method": "methodology.tex",
        "System design and implementation": "method.tex",
        "Experimental results": "results.tex",
        "Discussion": "discussion.tex",
        "Conclusion": "conclusion.tex",
    }
    chapter_dir = out / "chapters"
    for title, block in chapters:
        file_name = name_map.get(title, re.sub(r"[^A-Za-z0-9]+", "_", title).strip("_").lower() + ".tex")
        (chapter_dir / file_name).write_text(block + "\n", encoding="utf-8")
    (chapter_dir / "references.tex").write_text(refs + "\n", encoding="utf-8")

    figure_dir = out / "figures"
    figure_dir.mkdir(exist_ok=True)
    for source in (PAPER / "figures").glob("*"):
        if source.is_file():
            shutil.copy2(source, figure_dir / source.name)

    (out / "main.tex").write_text(
        "% Convenience wrapper for Overleaf. The template root file is uwthesis.tex.\n\\input{uwthesis.tex}\n",
        encoding="utf-8",
    )

    readme = """# Template-format corrected package

Content source: `D:/download document/chrome下载/A_Godot_based_Visual_Behaviour_Tree_Plugin_and_Display_Optimisation.zip`

Template source: `D:/download document/chrome下载/Games_Engineering_Dissertation_Template (3).zip`

Main template root: `uwthesis.tex`

Convenience wrapper: `main.tex`

This package keeps the current dissertation text and figures, but reorganises the project to match the supplied Games Engineering dissertation template structure: front matter in `frontmatter.tex`, chapters in `chapters/`, references in `chapters/references.tex`, template assets in `crests/`, and template fonts in `texmf/`.

The manual reference list from the current dissertation is preserved. It has not been converted into BibTeX entries in order to avoid changing citation content.
"""
    (out / "README_template_format_fix.md").write_text(readme, encoding="utf-8")

    zip_path = out.with_suffix(".zip")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as archive:
        for file_path in out.rglob("*"):
            archive.write(file_path, file_path.relative_to(out))

    result = {
        "output_dir": str(out),
        "zip_path": str(zip_path),
        "chapters": [title for title, _ in chapters],
        "frontchapters": list(fronts.keys()),
        "file_count": len([p for p in out.rglob("*") if p.is_file()]),
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
