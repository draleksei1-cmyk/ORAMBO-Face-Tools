from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "src" / "orambo_face_tools" / "icons"
OUT.mkdir(parents=True, exist_ok=True)

BLUE = (47, 111, 237, 255)
INK = (36, 42, 54, 255)
LIGHT = (47, 111, 237, 52)


def canvas(size):
    scale = 4
    image = Image.new("RGBA", (size * scale, size * scale), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image), scale


def line(draw, points, fill, width, scale):
    draw.line([(round(x * scale), round(y * scale)) for x, y in points], fill=fill, width=width * scale, joint="curve")


def dot(draw, x, y, radius, fill, scale):
    box = [(x - radius) * scale, (y - radius) * scale, (x + radius) * scale, (y + radius) * scale]
    draw.ellipse(box, fill=fill)


def save(image, name, size):
    image.resize((size, size), Image.Resampling.LANCZOS).save(OUT / f"{name}_{size}.png")


def break_icon(size):
    image, draw, s = canvas(size)
    k = size / 24
    line(draw, [(3*k, 17*k), (9*k, 11*k)], INK, 2, s)
    line(draw, [(11*k, 9*k), (16*k, 4*k)], BLUE, 2, s)
    line(draw, [(14*k, 17*k), (21*k, 10*k)], INK, 2, s)
    for x, y in [(3,17), (9,11), (11,9), (16,4), (14,17), (21,10)]:
        dot(draw, x*k, y*k, 1.45*k, BLUE if (x, y) in [(9,11), (11,9)] else INK, s)
    return image


def flatten_icon(size):
    image, draw, s = canvas(size)
    k = size / 24
    line(draw, [(3*k, 19*k), (21*k, 19*k)], BLUE, 2, s)
    line(draw, [(4*k, 8*k), (10*k, 5*k), (16*k, 10*k), (21*k, 6*k)], INK, 2, s)
    for x, y in [(4,8), (10,5), (16,10), (21,6)]:
        dot(draw, x*k, y*k, 1.35*k, INK, s)
        line(draw, [(x*k, (y+2)*k), (x*k, 16*k)], BLUE, 1, s)
        line(draw, [((x-1.4)*k, 14.6*k), (x*k, 16*k), ((x+1.4)*k, 14.6*k)], BLUE, 1, s)
    return image


def face_icon(size):
    image, draw, s = canvas(size)
    k = size / 24
    polygon = [(4*k, 18*k), (6*k, 6*k), (18*k, 4*k), (20*k, 17*k)]
    draw.polygon([(x*s, y*s) for x, y in polygon], fill=LIGHT)
    line(draw, polygon + [polygon[0]], INK, 2, s)
    for x, y in [(4,18), (6,6), (18,4), (20,17)]:
        dot(draw, x*k, y*k, 1.35*k, BLUE, s)
    return image


for size in (16, 24):
    save(break_icon(size), "break_segments", size)
    save(flatten_icon(size), "flatten_edges", size)
    save(face_icon(size), "make_faces", size)

sheet = Image.new("RGBA", (360, 128), (245, 247, 250, 255))
for index, name in enumerate(("break_segments", "flatten_edges", "make_faces")):
    icon = Image.open(OUT / f"{name}_24.png").resize((96, 96), Image.Resampling.NEAREST)
    sheet.alpha_composite(icon, (16 + index * 120, 16))
sheet.save(ROOT / "tmp" / "icons_contact_sheet.png")
