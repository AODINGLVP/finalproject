from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
DATA = (
    REPO
    / "research"
    / "display_optimization"
    / "five_feature_evaluation"
    / "data"
    / "2026-08-26_current_five_features_a87d7ac"
)
OUT_ZH = HERE / "figures" / "zh"
OUT_EN = HERE / "figures" / "en"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def font_path(chinese: bool, bold: bool = False) -> Path:
    candidates = (
        [Path("C:/Windows/Fonts/msyhbd.ttc"), Path("C:/Windows/Fonts/msyh.ttc")]
        if chinese
        else [Path("C:/Windows/Fonts/arialbd.ttf") if bold else Path("C:/Windows/Fonts/arial.ttf")]
    )
    candidates += [Path("C:/Windows/Fonts/arial.ttf")]
    return next(path for path in candidates if path.exists())


def copy_static_figures() -> list[Path]:
    OUT_ZH.mkdir(parents=True, exist_ok=True)
    OUT_EN.mkdir(parents=True, exist_ok=True)
    architecture = REPO / "thesis_draft" / "chinese" / "figures" / "architecture.png"
    live_debug = (
        REPO
        / "testgame"
        / "testgame"
        / "test_results"
        / "supervisor_game_evidence"
        / "02_tactician_241_live_debug.png"
    )
    game = REPO / "testgame" / "testgame" / "test_results" / "arena_multiscale_five_enemies.png"
    shutil.copy2(architecture, OUT_ZH / "figure_4_1_architecture.png")
    for output in (OUT_ZH, OUT_EN):
        shutil.copy2(live_debug, output / "figure_4_2_live_debug.png")
        shutil.copy2(game, output / "figure_4_3_five_enemy_game.png")
    return [architecture, live_debug, game]


def compose_pair(off_path: Path, on_path: Path, output: Path, language: str) -> None:
    off = Image.open(off_path).convert("RGB")
    on = Image.open(on_path).convert("RGB")
    panel_width = 1180
    max_panel_height = 720

    def fit(image: Image.Image) -> Image.Image:
        scale = min(panel_width / image.width, max_panel_height / image.height)
        return image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)

    off = fit(off)
    on = fit(on)
    body_height = max(off.height, on.height)
    header_height = 86
    canvas = Image.new("RGB", (panel_width * 2 + 3, header_height + body_height), "white")
    canvas.paste(off, ((panel_width - off.width) // 2, header_height))
    canvas.paste(on, (panel_width + 3 + (panel_width - on.width) // 2, header_height))
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((panel_width, 0, panel_width + 2, canvas.height), fill=(196, 55, 55))
    chinese = language == "zh"
    font = ImageFont.truetype(str(font_path(chinese, bold=True)), 38)
    labels = ("关闭（基线）", "开启") if chinese else ("Off (baseline)", "On")
    for index, label in enumerate(labels):
        left = 0 if index == 0 else panel_width + 3
        box = draw.textbbox((0, 0), label, font=font)
        text_width = box[2] - box[0]
        draw.text((left + (panel_width - text_width) / 2, 20), label, fill=(26, 43, 60), font=font)
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, optimize=True)


def build_comparisons() -> list[Path]:
    formal = DATA / "evidence"
    supplemental = DATA / "supplemental_overlay_task1" / "evidence"
    mappings = [
        ("auto_spacing", formal, "figure_5_1_smart_drag_comparison.png"),
        ("semantic_zoom", formal, "figure_5_2_adaptive_comparison.png"),
        ("translucent_cards", supplemental, "figure_5_3_overlay_comparison.png"),
        ("breadcrumb", formal, "figure_5_4_related_comparison.png"),
        ("fisheye", formal, "figure_5_5_fisheye_comparison.png"),
    ]
    inputs: list[Path] = []
    for key, folder, filename in mappings:
        off_path = folder / f"{key}_off.png"
        on_path = folder / f"{key}_on.png"
        inputs.extend([off_path, on_path])
        compose_pair(off_path, on_path, OUT_ZH / filename, "zh")
        compose_pair(off_path, on_path, OUT_EN / filename, "en")
    return inputs


def build_architecture_en() -> None:
    canvas = Image.new("RGB", (1920, 1080), "white")
    draw = ImageDraw.Draw(canvas)
    title_font = ImageFont.truetype(str(font_path(False, bold=True)), 52)
    box_title_font = ImageFont.truetype(str(font_path(False, bold=True)), 27)
    body_font = ImageFont.truetype(str(font_path(False)), 21)
    note_font = ImageFont.truetype(str(font_path(False)), 21)

    def centred_text(x: int, y: int, width: int, text: str, font: ImageFont.FreeTypeFont, fill: str) -> None:
        box = draw.multiline_textbbox((0, 0), text, font=font, align="center", spacing=10)
        text_width = box[2] - box[0]
        draw.multiline_text((x + (width - text_width) / 2, y), text, font=font, fill=fill, align="center", spacing=10)

    title_box = draw.textbbox((0, 0), "Plugin Architecture and Data Flow", font=title_font)
    draw.text(((1920 - (title_box[2] - title_box[0])) / 2, 55), "Plugin Architecture and Data Flow", font=title_font, fill="#18324b")
    boxes = {
        "editor": (70, 300, 400, 220, "Godot Editor Plugin", "Create, drag and connect nodes\nLayout and display features", "#2f73b8"),
        "resource": (555, 300, 400, 220, "BTTreeResource", "Tree structure and node resources\nValidation, save and copy", "#179a9a"),
        "runner": (1040, 300, 400, 220, "BehaviorTreeRunner", "Execution state and node memory\nBlackboard and Decorators", "#d79521"),
        "actor": (1525, 300, 325, 220, "Actor / NPC", "Action and Condition\nmethod calls", "#2e8659"),
        "debug": (555, 660, 400, 220, "Live Debug Bridge", "Atomic JSON snapshots\nActive path and failure reasons", "#d24b4b"),
        "game": (1040, 660, 400, 220, "Playable Test Game", "Patrol, chase and attack\nSearch, retreat and heal", "#18324b"),
    }
    for x, y, width, height, title, body, colour in boxes.values():
        draw.rounded_rectangle((x, y, x + width, y + height), radius=24, fill="#f5f8fb", outline=colour, width=4)
        centred_text(x, y + 48, width, title, box_title_font, colour)
        centred_text(x, y + 118, width, body, body_font, "#22303c")

    def arrow(start: tuple[int, int], end: tuple[int, int]) -> None:
        colour = "#78879c"
        draw.line((start, end), fill=colour, width=7)
        x2, y2 = end
        if abs(end[0] - start[0]) >= abs(end[1] - start[1]):
            direction = 1 if end[0] > start[0] else -1
            draw.polygon([(x2, y2), (x2 - 22 * direction, y2 - 14), (x2 - 22 * direction, y2 + 14)], fill=colour)
        else:
            direction = 1 if end[1] > start[1] else -1
            draw.polygon([(x2, y2), (x2 - 14, y2 - 22 * direction), (x2 + 14, y2 - 22 * direction)], fill=colour)

    arrow((470, 410), (555, 410))
    arrow((955, 410), (1040, 410))
    arrow((1440, 410), (1525, 410))
    arrow((1240, 520), (1240, 660))
    arrow((1040, 770), (955, 770))
    arrow((755, 660), (755, 520))
    note = "The editor visualises the resource; the runner executes it; Live Debug returns runtime state to the editor."
    note_box = draw.textbbox((0, 0), note, font=note_font)
    draw.text(((1920 - (note_box[2] - note_box[0])) / 2, 980), note, font=note_font, fill="#607086")
    canvas.save(OUT_EN / "figure_4_1_architecture.png", optimize=True)


def build_effect_chart(output: Path, language: str, x_labels: list[str], values: dict[str, list[float]], screen: bool) -> None:
    chinese = language == "zh"
    colours = ["#2775b6", "#31936f", "#d89021"]
    zh_titles = ["自适应：卡片面积减少", "相关聚焦：全亮候选减少", "鱼眼：目标宽度组均值增幅"]
    en_titles = ["Adaptive: card-area reduction", "Related Focus: full-bright candidate reduction", "Fisheye: group-mean target-width gain"]
    titles = zh_titles if chinese else en_titles
    keys = ["adaptive", "related", "fisheye"]
    canvas = Image.new("RGB", (2400, 830), "white")
    draw = ImageDraw.Draw(canvas)
    title_font = ImageFont.truetype(str(font_path(chinese, bold=True)), 30)
    label_font = ImageFont.truetype(str(font_path(chinese)), 24)
    value_font = ImageFont.truetype(str(font_path(False)), 23)
    note_font = ImageFont.truetype(str(font_path(chinese)), 21)
    panel_width = 760
    panel_gap = 40
    panel_top = 80
    chart_top = 170
    chart_bottom = 690
    for panel_index, (key, title, colour) in enumerate(zip(keys, titles, colours)):
        panel_left = 20 + panel_index * (panel_width + panel_gap)
        title_box = draw.textbbox((0, 0), title, font=title_font)
        draw.text((panel_left + (panel_width - (title_box[2] - title_box[0])) / 2, panel_top), title, font=title_font, fill="#203040")
        axis_left = panel_left + 75
        axis_right = panel_left + panel_width - 25
        draw.line((axis_left, chart_top, axis_left, chart_bottom), fill="#596773", width=3)
        draw.line((axis_left, chart_bottom, axis_right, chart_bottom), fill="#596773", width=3)
        maximum = max(values[key]) * 1.22 + 3
        for grid_index in range(5):
            y = chart_bottom - (chart_bottom - chart_top) * grid_index / 4
            grid_value = maximum * grid_index / 4
            draw.line((axis_left, y, axis_right, y), fill="#d9dee3", width=1)
            grid_text = f"{grid_value:.0f}"
            box = draw.textbbox((0, 0), grid_text, font=value_font)
            draw.text((axis_left - (box[2] - box[0]) - 10, y - 12), grid_text, font=value_font, fill="#596773")
        slot_width = (axis_right - axis_left) / len(x_labels)
        bar_width = slot_width * 0.58
        for index, (x_label, number) in enumerate(zip(x_labels, values[key])):
            centre = axis_left + slot_width * (index + 0.5)
            height = (chart_bottom - chart_top) * number / maximum
            draw.rounded_rectangle((centre - bar_width / 2, chart_bottom - height, centre + bar_width / 2, chart_bottom), radius=5, fill=colour)
            value_text = f"{number:.2f}"
            value_box = draw.textbbox((0, 0), value_text, font=value_font)
            draw.text((centre - (value_box[2] - value_box[0]) / 2, chart_bottom - height - 34), value_text, font=value_font, fill="#263442")
            label_box = draw.textbbox((0, 0), x_label, font=label_font)
            draw.text((centre - (label_box[2] - label_box[0]) / 2, chart_bottom + 15), x_label, font=label_font, fill="#263442")
        unit = "变化（%）" if chinese else "Change (%)"
        draw.text((panel_left + 8, chart_top - 55), unit, font=label_font, fill="#596773")
    note = (
        "三个子图使用各自指标；鱼眼为开启/关闭组平均宽度的比率。"
        if chinese
        else "Each panel uses its own metric; fisheye reports the ratio of the on/off group-mean widths."
    )
    note_box = draw.textbbox((0, 0), note, font=note_font)
    draw.text(((2400 - (note_box[2] - note_box[0])) / 2, 785), note, font=note_font, fill="#52606d")
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, optimize=True)


def build_charts() -> None:
    tree_labels = ["31", "61", "121", "241", "364"]
    tree_values = {
        "adaptive": [33.46, 33.58, 46.07, 57.93, 54.67],
        "related": [34.40, 55.63, 68.95, 73.43, 59.10],
        "fisheye": [19.19, 25.40, 54.91, 143.44, 188.73],
    }
    screen_zh = ["15.94 英寸", "26.96 英寸", "31.55 英寸"]
    screen_en = ["15.94 in", "26.96 in", "31.55 in"]
    screen_values = {
        "adaptive": [57.14, 42.61, 35.67],
        "related": [52.83, 60.46, 61.61],
        "fisheye": [142.24, 47.67, 32.72],
    }
    build_effect_chart(OUT_ZH / "figure_5_6_effect_by_tree.png", "zh", tree_labels, tree_values, False)
    build_effect_chart(OUT_EN / "figure_5_6_effect_by_tree.png", "en", tree_labels, tree_values, False)
    build_effect_chart(OUT_ZH / "figure_5_7_effect_by_screen.png", "zh", screen_zh, screen_values, True)
    build_effect_chart(OUT_EN / "figure_5_7_effect_by_screen.png", "en", screen_en, screen_values, True)


def main() -> None:
    inputs = copy_static_figures()
    inputs.extend(build_comparisons())
    build_architecture_en()
    build_charts()
    outputs = sorted([*OUT_ZH.glob("*.png"), *OUT_EN.glob("*.png")])
    manifest = {
        "purpose": "Paper figures for the current five Display features",
        "formal_data_commit": "a87d7acc49165e66966039a66ad596c57e710c44",
        "inputs": {str(path.relative_to(REPO)): sha256(path) for path in sorted(set(inputs))},
        "outputs": {str(path.relative_to(HERE)): sha256(path) for path in outputs},
        "notes": [
            "Five comparisons use identical off/on source states; overlay uses the documented supplemental task-1 evidence pair.",
            "All quantitative conclusions remain based on the formal 450-observation dataset.",
            "Fisheye chart percentages are ratios of group-mean on/off target widths, not means of per-pair percentages.",
        ],
    }
    (HERE / "figures" / "MANIFEST.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Generated {len(outputs)} figures in {HERE / 'figures'}")


if __name__ == "__main__":
    main()
