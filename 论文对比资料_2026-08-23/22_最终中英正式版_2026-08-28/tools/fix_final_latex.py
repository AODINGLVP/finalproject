from __future__ import annotations

import re
import shutil
from pathlib import Path


VERSION_DIR = Path(__file__).resolve().parents[1]
ZH_TEX = VERSION_DIR / "latex_output" / ".build" / "zh" / "main.tex"
EN_TEX = VERSION_DIR / "latex_output" / ".build" / "en" / "main.tex"


ZH_TABLE_CAPTIONS = [
    ("实验使用的行为树规模和主要游戏行为", "tab:experiment-tree-sizes"),
    ("三种屏幕尺寸及对应的编辑区域", "tab:screen-configs"),
    ("显示优化功能的实验方法和比较内容", "tab:display-experiment-methods"),
    ("显示优化功能的主要指标与判断标准", "tab:display-metrics-criteria"),
    ("当前运行节点的主要语义", "tab:runtime-node-semantics"),
    ("当前版本的插件功能和游戏验证结果", "tab:function-game-validation"),
    ("显示优化功能开启前后的主要结果", "tab:display-main-results"),
    ("五种行为树规模下的主要显示变化", "tab:tree-size-results"),
    ("三种物理尺寸配置下的主要显示变化", "tab:screen-size-results"),
    ("结构化开发者评价结果", "tab:developer-evaluation"),
]

ZH_FIGURE_CAPTIONS = [
    ("插件、资源、执行系统、调试桥和测试游戏之间的关系", "fig:system-architecture"),
    ("当前版本在 241 节点真实行为树上显示 Live Debug", "fig:live-debug"),
    ("五种规模行为树分别控制可玩场景中的五名敌人", "fig:test-game"),
    ("智能拖拽重排关闭与开启：同一拖动位置下消除卡片遮挡", "fig:smart-drag-before-after"),
    ("自适应缩放细节关闭与开启：相同概览缩放下减少卡片面积和字段", "fig:adaptive-before-after"),
    ("可读连线覆盖关闭与开启：相同路线透过卡片背景但避开文字", "fig:overlay-before-after"),
    ("相关节点聚焦关闭与开启：选中节点及其关系分支保持突出", "fig:related-before-after"),
    ("鱼眼聚焦关闭与开启：概览中恢复目标尺寸并淡化远处节点", "fig:fisheye-before-after"),
]

EN_TABLE_CAPTIONS = [
    ("Behaviour tree sizes and main game behaviours used in the experiment", "tab:experiment-tree-sizes"),
    ("Three screen sizes and their corresponding editing areas", "tab:screen-configs"),
    ("Experimental method and comparison content for the display optimisation functions", "tab:display-experiment-methods"),
    ("Main metrics and success criteria for the display optimisation functions", "tab:display-metrics-criteria"),
    ("Main semantics of the current execution nodes", "tab:runtime-node-semantics"),
    ("Plugin function and playable game validation results for the current version", "tab:function-game-validation"),
    ("Main results before and after enabling the display optimisation functions", "tab:display-main-results"),
    ("Main display changes under five behaviour tree sizes", "tab:tree-size-results"),
    ("Main display changes under three physical screen size configurations", "tab:screen-size-results"),
    ("Structured developer evaluation results", "tab:developer-evaluation"),
]

EN_FIGURE_CAPTIONS = [
    ("Relationship between the plugin, resources, execution system, debug bridge and test game", "fig:system-architecture"),
    ("Live Debug shown on the current 241-node real behaviour tree", "fig:live-debug"),
    ("Five behaviour tree sizes controlling five enemies in the playable scene", "fig:test-game"),
    ("Smart Drag Reflow disabled and enabled: removing card overlap at the same drag position", "fig:smart-drag-before-after"),
    ("Adaptive Zoom Detail disabled and enabled: reducing card area and fields at the same overview zoom", "fig:adaptive-before-after"),
    ("Readable Edge Overlay disabled and enabled: the same route passes through card background while avoiding text", "fig:overlay-before-after"),
    ("Related Node Focus disabled and enabled: selected nodes and their related branches remain prominent", "fig:related-before-after"),
    ("Fisheye Focus disabled and enabled: restoring target size in the overview and dimming distant nodes", "fig:fisheye-before-after"),
]


def replace_table_captions(tex: str, captions: list[tuple[str, str]]) -> str:
    iterator = iter(captions)

    def repl(_: re.Match[str]) -> str:
        caption, label = next(iterator)
        return rf"\caption{{{caption}}}\label{{{label}}}\\"

    return re.sub(r"\\caption\{[^{}]*\}\\label\{tab:auto-\d+\}\\\\", repl, tex, count=len(captions))


def replace_figure_captions(tex: str, captions: list[tuple[str, str]]) -> str:
    iterator = iter(captions)

    def repl(_: re.Match[str]) -> str:
        caption, label = next(iterator)
        return rf"\caption{{{caption}}}" + "\n" + rf"\label{{{label}}}"

    return re.sub(r"\\caption\{[^{}]*\}\s*\\label\{fig:auto-\d+\}", repl, tex, count=len(captions))


def clean_auto_caption_lines(tex: str) -> str:
    # Remove the visible caption paragraphs that were copied from Word after the real LaTeX captions.
    tex = re.sub(r"(?m)^\d+图\s+[45]\.\d+.*\n", "", tex)
    tex = re.sub(r"(?m)^\d+表\s+[345]\.\d+.*\n", "", tex)
    return tex


def configure_chinese_fonts(tex: str, build_dir: Path) -> str:
    local_fonts = build_dir / "local_fonts"
    local_fonts.mkdir(parents=True, exist_ok=True)
    for source in [
        Path(r"C:\Windows\Fonts\msyh.ttc"),
        Path(r"C:\Windows\Fonts\msyhbd.ttc"),
        Path(r"C:\Windows\Fonts\simkai.ttf"),
    ]:
        if source.exists():
            shutil.copy2(source, local_fonts / source.name)
    fonts_conf = build_dir / "fonts.conf"
    fonts_conf.write_text(
        "\n".join(
            [
                '<?xml version="1.0"?>',
                '<!DOCTYPE fontconfig SYSTEM "fonts.dtd">',
                "<fontconfig>",
                f"  <dir>{local_fonts.as_posix()}</dir>",
                f"  <cachedir>{(build_dir / 'fontcache').as_posix()}</cachedir>",
                "  <config></config>",
                "</fontconfig>",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    return tex.replace(
        r"\usepackage[UTF8,fontset=windows]{ctex}",
        "\n".join(
            [
                r"\usepackage[UTF8,fontset=none]{ctex}",
                r"\setCJKmainfont{msyh.ttc}[Path=local_fonts/]",
                r"\setCJKsansfont{msyhbd.ttc}[Path=local_fonts/]",
                r"\setCJKmonofont{simkai.ttf}[Path=local_fonts/]",
            ]
        ),
    )


def fix_one(path: Path, *, chinese: bool) -> None:
    if not path.exists():
        return
    tex = path.read_text(encoding="utf-8")
    if chinese:
        tex = configure_chinese_fonts(tex, path.parent)
        tex = replace_table_captions(tex, ZH_TABLE_CAPTIONS)
        tex = replace_figure_captions(tex, ZH_FIGURE_CAPTIONS)
    else:
        tex = replace_table_captions(tex, EN_TABLE_CAPTIONS)
        tex = replace_figure_captions(tex, EN_FIGURE_CAPTIONS)
    tex = clean_auto_caption_lines(tex)
    tex = tex.replace(r"\small", "").replace(r"\footnotesize", "").replace(r"\scriptsize", "")
    path.write_text(tex, encoding="utf-8", newline="\n")
    print(path)


def main() -> None:
    fix_one(ZH_TEX, chinese=True)
    fix_one(EN_TEX, chinese=False)


if __name__ == "__main__":
    main()
