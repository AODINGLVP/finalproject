#!/usr/bin/env python3
"""Render the English architecture diagram used by the supervisor DOCX."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "thesis_draft" / "english" / "figures" / "architecture_en.png"
FONT_REGULAR = Path("C:/Windows/Fonts/segoeui.ttf")
FONT_BOLD = Path("C:/Windows/Fonts/segoeuib.ttf")


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    if not path.is_file():
        raise FileNotFoundError(path)
    return ImageFont.truetype(str(path), size)


def centred_text(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    lines: list[tuple[str, ImageFont.FreeTypeFont, str]],
    *,
    gap: int = 12,
) -> None:
    heights = []
    for text, text_font, _ in lines:
        bounds = draw.textbbox((0, 0), text, font=text_font)
        heights.append(bounds[3] - bounds[1])
    total_height = sum(heights) + gap * (len(lines) - 1)
    y = box[1] + (box[3] - box[1] - total_height) / 2
    for (text, text_font, colour), height in zip(lines, heights, strict=True):
        bounds = draw.textbbox((0, 0), text, font=text_font)
        width = bounds[2] - bounds[0]
        x = box[0] + (box[2] - box[0] - width) / 2
        draw.text((x, y), text, font=text_font, fill=colour)
        y += height + gap


def arrow(
    draw: ImageDraw.ImageDraw,
    start: tuple[int, int],
    end: tuple[int, int],
    *,
    colour: str = "#718096",
    width: int = 6,
) -> None:
    draw.line((start, end), fill=colour, width=width)
    x1, y1 = start
    x2, y2 = end
    head = 17
    if x2 > x1:
        points = [(x2, y2), (x2 - head, y2 - 12), (x2 - head, y2 + 12)]
    elif x2 < x1:
        points = [(x2, y2), (x2 + head, y2 - 12), (x2 + head, y2 + 12)]
    elif y2 > y1:
        points = [(x2, y2), (x2 - 12, y2 - head), (x2 + 12, y2 - head)]
    else:
        points = [(x2, y2), (x2 - 12, y2 + head), (x2 + 12, y2 + head)]
    draw.polygon(points, fill=colour)


def render() -> None:
    canvas = Image.new("RGB", (1800, 900), "white")
    draw = ImageDraw.Draw(canvas)
    title_font = font(FONT_BOLD, 48)
    box_title = font(FONT_BOLD, 28)
    box_body = font(FONT_REGULAR, 21)
    footer_font = font(FONT_REGULAR, 21)

    title = "Plugin Architecture and Data Flow"
    title_bounds = draw.textbbox((0, 0), title, font=title_font)
    draw.text(((1800 - (title_bounds[2] - title_bounds[0])) / 2, 38), title, font=title_font, fill="#17324D")

    editor = (70, 182, 430, 370)
    resource = (525, 182, 885, 370)
    runner = (980, 182, 1340, 370)
    actor = (1450, 182, 1730, 370)
    debug = (525, 542, 885, 730)
    game = (980, 542, 1340, 730)

    boxes = [
        (editor, "#2F75B5", [
            ("Godot Editor Plugin", box_title, "#2F75B5"),
            ("Node creation, dragging", box_body, "#1F2937"),
            ("and connection", box_body, "#1F2937"),
            ("Layout and display optimisation", box_body, "#1F2937"),
        ]),
        (resource, "#159C9C", [
            ("BTTreeResource", box_title, "#159C9C"),
            ("Tree structure and node resources", box_body, "#1F2937"),
            ("Validation, saving and duplication", box_body, "#1F2937"),
        ]),
        (runner, "#D9981E", [
            ("BehaviorTreeRunner", box_title, "#D9981E"),
            ("State machine and node memory", box_body, "#1F2937"),
            ("Blackboard and Decorators", box_body, "#1F2937"),
        ]),
        (actor, "#2F855A", [
            ("Actor / NPC", box_title, "#2F855A"),
            ("Action and Condition", box_body, "#1F2937"),
            ("method calls", box_body, "#1F2937"),
        ]),
        (debug, "#D04B4B", [
            ("Live Debug Bridge", box_title, "#D04B4B"),
            ("Atomic JSON snapshots", box_body, "#1F2937"),
            ("Active path and failure reasons", box_body, "#1F2937"),
        ]),
        (game, "#17324D", [
            ("Playable Test Game", box_title, "#17324D"),
            ("Patrol, chase and attack", box_body, "#1F2937"),
            ("Search, retreat and healing", box_body, "#1F2937"),
        ]),
    ]
    for box, outline, lines in boxes:
        draw.rounded_rectangle(box, radius=24, fill="#F5F8FA", outline=outline, width=4)
        centred_text(draw, box, lines)

    arrow(draw, (430, 276), (525, 276))
    arrow(draw, (885, 276), (980, 276))
    arrow(draw, (1340, 276), (1450, 276))
    arrow(draw, (1160, 370), (1160, 542))
    arrow(draw, (980, 636), (885, 636))
    arrow(draw, (705, 542), (705, 370))

    footer = (
        "The editor provides visual authoring; the Runner applies runtime semantics; "
        "Live Debug returns runtime state to the editor."
    )
    bounds = draw.textbbox((0, 0), footer, font=footer_font)
    draw.text(((1800 - (bounds[2] - bounds[0])) / 2, 826), footer, font=footer_font, fill="#64748B")

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(OUTPUT, format="PNG", optimize=True)
    print(f"ARCHITECTURE_EN_OK={OUTPUT}")


if __name__ == "__main__":
    render()
