import argparse
from pathlib import Path

import pypdfium2 as pdfium
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent
RENDER = ROOT / "report_render"
PDF = RENDER / "Godot_Behavior_Tree_Plugin_Complete_Report.pdf"
FONT = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 28)

parser = argparse.ArgumentParser()
parser.add_argument("--output-dir", type=Path, default=RENDER)
args = parser.parse_args()
output_dir = args.output_dir.resolve()
output_dir.mkdir(parents=True, exist_ok=True)

pdf = pdfium.PdfDocument(PDF)
page_paths = []
for index in range(len(pdf)):
    page = pdf[index]
    image = page.render(scale=1.6).to_pil().convert("RGB")
    path = output_dir / f"page-{index + 1:02d}.png"
    image.save(path)
    page_paths.append(path)

thumb_width = 330
thumbs = []
for path in page_paths:
    image = Image.open(path).convert("RGB")
    ratio = thumb_width / image.width
    thumbs.append(image.resize((thumb_width, int(image.height * ratio)), Image.Resampling.LANCZOS))

columns = 4
label_height = 42
gap = 24
cell_height = max(image.height for image in thumbs) + label_height
rows = (len(thumbs) + columns - 1) // columns
contact = Image.new("RGB", (columns * thumb_width + (columns + 1) * gap,
                            rows * cell_height + (rows + 1) * gap), "#DDE3E8")
draw = ImageDraw.Draw(contact)
for index, image in enumerate(thumbs):
    col = index % columns
    row = index // columns
    x = gap + col * (thumb_width + gap)
    y = gap + row * (cell_height + gap)
    contact.paste(image, (x, y + label_height))
    draw.text((x + thumb_width / 2, y + label_height / 2), f"第 {index + 1} 页",
              font=FONT, fill="#17324D", anchor="mm")
contact_path = output_dir / "contact_sheet.png"
contact.save(contact_path)
print(f"pages={len(page_paths)} contact={contact_path}")
