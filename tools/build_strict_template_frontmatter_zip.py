from __future__ import annotations

import pathlib
import re
import shutil
import zipfile


BASE = pathlib.Path(r"E:/course pdf/project/finalproject")
SOURCE_DIR = BASE / "论文对比资料_2026-08-23" / "26_模板格式修正版_2026-08-31"
OUT_BASE = BASE / "论文对比资料_2026-08-23" / "27_完全模板前置页版_2026-08-31"


def next_output_dir() -> pathlib.Path:
    out = OUT_BASE
    index = 2
    while out.exists():
        out = pathlib.Path(str(OUT_BASE) + f"_{index}")
        index += 1
    return out


def frontchapter_body(text: str, name: str) -> str:
    pattern = re.compile(r"\\frontchapter\{" + re.escape(name) + r"\}(.*?)(?=\\frontchapter\{|\\mainmatter|$)", re.S)
    match = pattern.search(text)
    if not match:
        return ""
    return match.group(1).strip()


def main() -> None:
    out = next_output_dir()
    shutil.copytree(SOURCE_DIR, out)

    old_frontmatter = (SOURCE_DIR / "frontmatter.tex").read_text(encoding="utf-8")
    acknowledgement = frontchapter_body(old_frontmatter, "Acknowledgements")
    abstract = frontchapter_body(old_frontmatter, "Abstract")

    strict_frontmatter = r"""% This sets the page numbers to be printed in lowercase roman numerals, starts
% the page numbering from i, and prohibits any numbering of sectional divisions.
\frontmatter

% Uncomment a command to generate the title page. The only difference is the
% crest artwork used. The default is the official crest provided to me by the
% university brand officer; however, I happen to think it's the least visually
% appealing option... Variations 1 and 2 are both solid choices; 1 is probably
% the more "sedate" option (it appears on the top of the Warwick Arts Centre
% Building) while 2 is more "fun" feeling. I happened to find monochrome
% versions of the official crest and variation 1, with "mono" suffix on names.
% Variation 3 is interesting, as it is an image of the crest as it appeared on
% the original letters patent granting the University its arms. It is a
% modified version of a file from the Wikimedia Commons:
% https://commons.wikimedia.org/wiki/File:University_of_Warwick_Coat_of_Arms.jpg
% \titlepage % uses crests/official
% \titlepage[crests/officialmono]
% \titlepage[crests/variation1]
% \titlepage[crests/variation1mono]
% \titlepage[crests/variation2]
\titlepage[crests/variation3]

% Generate table of contents.
\tableofcontents
% Uncomment this to generate list of figures.
\clearforchapter\listoffigures
% Uncomment this to generate list of tables.
% \clearforchapter\listoftables


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\frontchapter{Declaration}
This thesis is submitted to the University of Warwick in support of my application for the degree of \thequalification. It has been composed by myself and has not been submitted in any previous application for any degree.
% if parts previously used uncomment and edit the following
% (apart from the background material in sections XXX which was previously submitted for YYY degree).
The work presented (including data generated and data analysis) was carried out by the author.
% if there are exceptions uncomment and edit the following
% except in the cases outlined below:
% List of data provided and/or analysis carried out by collaborators.



% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

"""
    if acknowledgement:
        strict_frontmatter += "\\frontchapter{Acknowledgments}\n" + acknowledgement + "\n\n"
    else:
        strict_frontmatter += "\\frontchapter{Acknowledgments}\nAcknowledge the people who have supported you\n\n"

    strict_frontmatter += "% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n\n"
    strict_frontmatter += "\\frontchapter{Abstract}\n" + abstract + "\n\n"
    strict_frontmatter += r"""%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This prints the list of abbreviations, which are declared in abbreviations.tex
% This uses the acro package, and note that by default abbreviations will only
% be printed in the list if they are actually used in text.
%\printacronyms
"""

    (out / "frontmatter.tex").write_text(strict_frontmatter, encoding="utf-8")

    readme = (out / "README_template_format_fix.md").read_text(encoding="utf-8")
    readme += "\n\nStrict front matter update: this version restores the template title-page crest selection, declaration wording, and list-of-tables switch while keeping the dissertation acknowledgement and abstract text.\n"
    (out / "README_template_format_fix.md").write_text(readme, encoding="utf-8")

    zip_path = out.with_suffix(".zip")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as archive:
        for file_path in out.rglob("*"):
            archive.write(file_path, file_path.relative_to(out))

    print(out)
    print(zip_path)


if __name__ == "__main__":
    main()
