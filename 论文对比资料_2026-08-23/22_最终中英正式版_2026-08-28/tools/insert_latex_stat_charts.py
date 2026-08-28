from __future__ import annotations

import re
from pathlib import Path


VERSION_DIR = Path(__file__).resolve().parents[1]
ZH_MAIN_TEX = VERSION_DIR / "latex_output" / ".build" / "zh" / "main.tex"
EN_MAIN_TEX = VERSION_DIR / "latex_output" / ".build" / "en" / "main.tex"


TREE = [
    ("Adaptive 面积减少", "百分比", [("31", 33.46), ("61", 33.58), ("121", 46.07), ("241", 57.93), ("364", 54.67)]),
    ("Related 全亮候选减少", "百分比", [("31", 35.41), ("61", 57.91), ("121", 68.74), ("241", 71.38), ("364", 59.10)]),
    ("Fisheye 宽度增幅", "百分比", [("31", 37.04), ("61", 54.23), ("121", 114.94), ("241", 226.33), ("364", 300.43)]),
    ("Smart 平均移动节点", "卡片数", [("31", 2.67), ("61", 1.67), ("121", 1.67), ("241", 3.00), ("364", 3.00)]),
    ("Smart 平均总移动距离", "px", [("31", 441.15), ("61", 284.06), ("121", 284.06), ("241", 435.11), ("364", 435.11)]),
    ("Overlay 自然遮挡边比例", "比例", [("31", 0.1052), ("61", 0.1869), ("121", 0.1918), ("241", 0.0218), ("364", 0.3677)]),
]

SCREEN = [
    ("Adaptive 面积减少", "百分比", [("15.94in", 57.14), ("26.96in", 42.61), ("31.55in", 35.67)]),
    ("Related 全亮候选减少", "百分比", [("15.94in", 54.01), ("26.96in", 59.61), ("31.55in", 61.90)]),
    ("Fisheye 宽度增幅", "百分比", [("15.94in", 258.98), ("26.96in", 104.90), ("31.55in", 75.90)]),
    ("Smart 平均移动节点", "卡片数", [("15.94in", 2.40), ("26.96in", 2.40), ("31.55in", 2.40)]),
    ("Smart 平均总移动距离", "px", [("15.94in", 375.90), ("26.96in", 375.90), ("31.55in", 375.90)]),
    ("Overlay 自然遮挡边比例", "比例", [("15.94in", 0.1682), ("26.96in", 0.1735), ("31.55in", 0.1825)]),
]

TREE_EN = [
    ("Adaptive area reduction", "percent", [("31", 33.46), ("61", 33.58), ("121", 46.07), ("241", 57.93), ("364", 54.67)]),
    ("Related full-bright candidates reduced", "percent", [("31", 35.41), ("61", 57.91), ("121", 68.74), ("241", 71.38), ("364", 59.10)]),
    ("Fisheye width increase", "percent", [("31", 37.04), ("61", 54.23), ("121", 114.94), ("241", 226.33), ("364", 300.43)]),
    ("Smart average moved nodes", "cards", [("31", 2.67), ("61", 1.67), ("121", 1.67), ("241", 3.00), ("364", 3.00)]),
    ("Smart average total movement", "px", [("31", 441.15), ("61", 284.06), ("121", 284.06), ("241", 435.11), ("364", 435.11)]),
    ("Overlay natural occluded edge ratio", "ratio", [("31", 0.1052), ("61", 0.1869), ("121", 0.1918), ("241", 0.0218), ("364", 0.3677)]),
]

SCREEN_EN = [
    ("Adaptive area reduction", "percent", [("15.94in", 57.14), ("26.96in", 42.61), ("31.55in", 35.67)]),
    ("Related full-bright candidates reduced", "percent", [("15.94in", 54.01), ("26.96in", 59.61), ("31.55in", 61.90)]),
    ("Fisheye width increase", "percent", [("15.94in", 258.98), ("26.96in", 104.90), ("31.55in", 75.90)]),
    ("Smart average moved nodes", "cards", [("15.94in", 2.40), ("26.96in", 2.40), ("31.55in", 2.40)]),
    ("Smart average total movement", "px", [("15.94in", 375.90), ("26.96in", 375.90), ("31.55in", 375.90)]),
    ("Overlay natural occluded edge ratio", "ratio", [("15.94in", 0.1682), ("26.96in", 0.1735), ("31.55in", 0.1825)]),
]


def esc(text: str) -> str:
    return text.replace("&", r"\&").replace("%", r"\%").replace("_", r"\_")


def panel(title: str, ylabel: str, points: list[tuple[str, float]]) -> str:
    max_value = max(value for _, value in points) or 1.0
    rows = []
    for label, value in points:
        fraction = max(0.018, 0.20 * value / max_value)
        if ylabel in {"百分比", "percent"}:
            shown = f"{value:.1f}\\%"
        elif ylabel == "px":
            shown = f"{value:.1f}px"
        elif ylabel in {"比例", "ratio"}:
            shown = f"{value:.3f}"
        else:
            shown = f"{value:.2f}"
        rows.append(
            rf"{esc(label)} & \textcolor{{blue!70!black}}{{\rule{{{fraction:.4f}\textwidth}}{{1.1ex}}}} & {shown} \\"
        )
    return "\n".join([
        r"\begin{minipage}[t]{0.46\textwidth}",
        r"\centering",
        rf"\textbf{{{esc(title)}}}\\[-0.2em]",
        r"\begin{tabular}{@{}r l r@{}}",
        "\n".join(rows),
        r"\end{tabular}",
        r"\end{minipage}",
    ])


def figure_block(caption: str, label: str, data: list[tuple[str, str, list[tuple[str, float]]]]) -> str:
    rows = []
    for i in range(0, len(data), 2):
        left = panel(*data[i])
        right = panel(*data[i + 1])
        rows.append(left + "\n&\n" + right)
    return "\n".join([
        r"\begin{figure}[htbp]",
        r"\centering",
        r"\begin{tabular}{cc}",
        (r" \\[1.2em]" + "\n").join(rows),
        r"\end{tabular}",
        rf"\caption{{{esc(caption)}}}",
        rf"\label{{{label}}}",
        r"\end{figure}",
        "",
    ])


def insert_after_table(tex: str, caption: str, block: str) -> str:
    marker = rf"\caption{{{caption}}}"
    start = tex.find(marker)
    if start < 0:
        raise ValueError(f"Could not find table caption {caption}")
    end = tex.find(r"\end{longtable}", start)
    if end < 0:
        raise ValueError(f"Could not find end of table {caption}")
    end += len(r"\end{longtable}")
    return tex[:end] + "\n\n" + block + tex[end:]


def main() -> None:
    jobs = [
        (
            ZH_MAIN_TEX,
            "五种行为树规模下的主要显示变化",
            "三种物理尺寸配置下的主要显示变化",
            "显示优化功能随树规模变化的效果",
            "显示优化功能随屏幕尺寸配置变化的效果",
            TREE,
            SCREEN,
        ),
        (
            EN_MAIN_TEX,
            "Main display changes under five behaviour tree sizes",
            "Main display changes under three physical screen size configurations",
            "Effect of display optimisation functions across tree sizes",
            "Effect of display optimisation functions across screen size configurations",
            TREE_EN,
            SCREEN_EN,
        ),
    ]
    for main_tex, tree_caption, screen_caption, tree_figure_caption, screen_figure_caption, tree_data, screen_data in jobs:
        if not main_tex.exists():
            continue
        tex = main_tex.read_text(encoding="utf-8")
        tex = tex.replace("\\usepackage{pgfplots}\n", "")
        tex = tex.replace("\\pgfplotsset{compat=1.18}\n", "")
        tex = insert_after_table(tex, tree_caption, figure_block(tree_figure_caption, "fig:display-size-metrics", tree_data))
        tex = insert_after_table(tex, screen_caption, figure_block(screen_figure_caption, "fig:display-screen-metrics", screen_data))
        main_tex.write_text(tex, encoding="utf-8", newline="\n")
        print(main_tex)


if __name__ == "__main__":
    main()
