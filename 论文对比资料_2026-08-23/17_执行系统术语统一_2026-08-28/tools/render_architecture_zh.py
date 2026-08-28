"""Render the Chinese architecture figure with dissertation terminology."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


VERSION_DIR = Path(__file__).resolve().parent.parent
OUTPUT = VERSION_DIR / "figures" / "zh" / "figure_4_1_architecture.png"
FONT_REGULAR = Path("C:/Windows/Fonts/msyh.ttc")
FONT_BOLD = Path("C:/Windows/Fonts/msyhbd.ttc")


def render() -> None:
    regular = lambda size: ImageFont.truetype(str(FONT_REGULAR), size)
    bold = lambda size: ImageFont.truetype(str(FONT_BOLD), size)
    image = Image.new("RGB", (1800, 900), "white")
    draw = ImageDraw.Draw(image)

    draw.text((900, 58), "插件总体架构与数据流", font=bold(44), fill="#18324B", anchor="mm")
    boxes = [
        (70, 180, 360, 190, "Godot 编辑器插件", "节点创建、拖拽、连接\n布局与显示优化", "#2F73B8"),
        (525, 180, 360, 190, "BTTreeResource", "树结构、节点资源\n校验、保存与复制", "#179A9A"),
        (980, 180, 360, 190, "执行系统", "状态机、节点记忆\n黑板与 Decorator", "#D79521"),
        (1450, 180, 280, 190, "Actor / NPC", "Action 与 Condition\n方法调用", "#2E8659"),
        (525, 540, 360, 190, "Live Debug Bridge", "原子 JSON 快照\n活动路径与失败原因", "#D24B4B"),
        (980, 540, 360, 190, "测试游戏", "巡逻、追击、攻击\n搜索、撤退、治疗", "#18324B"),
    ]
    for x, y, width, height, title, detail, colour in boxes:
        draw.rounded_rectangle(
            (x, y, x + width, y + height),
            radius=24,
            fill="#F7FAFC",
            outline=colour,
            width=4,
        )
        draw.text((x + width / 2, y + 56), title, font=bold(28), fill=colour, anchor="mm")
        for line_index, line in enumerate(detail.splitlines()):
            draw.text(
                (x + width / 2, y + 118 + line_index * 35),
                line,
                font=regular(21),
                fill="#22303C",
                anchor="mm",
            )

    arrows = [
        ((430, 275), (525, 275)),
        ((885, 275), (980, 275)),
        ((1340, 275), (1450, 275)),
        ((1160, 370), (1160, 540)),
        ((980, 635), (885, 635)),
        ((705, 540), (705, 370)),
    ]
    for start, end in arrows:
        draw.line((start, end), fill="#718096", width=5)
        end_x, end_y = end
        start_x, start_y = start
        if end_x != start_x:
            direction = 1 if end_x > start_x else -1
            draw.polygon(
                [
                    (end_x, end_y),
                    (end_x - 18 * direction, end_y - 11),
                    (end_x - 18 * direction, end_y + 11),
                ],
                fill="#718096",
            )
        else:
            direction = 1 if end_y > start_y else -1
            draw.polygon(
                [
                    (end_x, end_y),
                    (end_x - 11, end_y - 18 * direction),
                    (end_x + 11, end_y - 18 * direction),
                ],
                fill="#718096",
            )

    draw.text(
        (900, 835),
        "编辑器负责可视化建模，执行系统负责节点判断与动作调用，Live Debug 将执行状态回传到编辑器。",
        font=regular(22),
        fill="#607086",
        anchor="mm",
    )
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT, optimize=True)


if __name__ == "__main__":
    render()
