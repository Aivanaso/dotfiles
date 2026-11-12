#!/usr/bin/env python3
"""Genera los fotogramas PNG del tema Plymouth «puerta-enana».
Renders every PNG frame of the «puerta-enana» Plymouth theme.

Uso / Usage:
    python3 generate_frames.py [OUT_DIR]      (por defecto: junto a este fichero)

La escena es una puerta enana de piedra de noche. Cada grupo de grabados se
dibuja dos veces: apagado (surco oscuro, dentro de base.png) y encendido (capa
plateada con resplandor, un PNG recortado por grupo). El script del tema las
funde con opacidad creciente segun el progreso del arranque.
The scene is a dwarven stone gate at night. Every engraving group is drawn
twice: unlit (a dark groove baked into base.png) and lit (a silver glow layer,
one cropped PNG per group) which the theme script fades in as boot progresses.

Reproducible: no reloj, no azar sin semilla, PNG sin metadatos; dos ejecuciones
producen ficheros identicos byte a byte. Needs Pillow and pycairo, plus the
'Noto Sans Runic' font file (the runes are baked into the frames, so the theme
needs no font at boot time).

Tras generar, comprueba que la tabla de capas de puerta-enana.script coincide
con los recortes producidos y falla si no (el script se edita a mano).
"""

import math
import random
import sys
from collections import OrderedDict
from pathlib import Path

import cairo
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageOps

THEME_DIR = Path(__file__).resolve().parent
SCRIPT_FILE = THEME_DIR / "puerta-enana.script"

# --------------------------------------------------------------------------
# Constantes de la escena / Scene constants
# --------------------------------------------------------------------------
W, H = 1000, 960
CX = 500
BG = (5, 8, 14)  # debe coincidir con Window.SetBackground*Color del script
SILVER = (205, 220, 245)
SILVER_CORE = (240, 246, 255)
HALO_BLUE = (110, 150, 235)
GROOVE = (7, 9, 15)
GROOVE_EDGE = (96, 110, 142)

FLOOR_Y = 830
ARCH_SPRING_Y = 520
ARCH_OFFSET = 100  # los dos centros del arco apuntado estan a +-100 de CX
ARCH_R0 = 200  # radio del hueco de la puerta
RUNE_CENTER = (CX, 440)
RUNE_RADIUS = 262
RUNE_SIZE = 30
COLUMN_TOP = 400
COLUMN_HALF_WIDTH = 30
COLUMN_CENTER_X = 292

RUNIC_FONT_PATH = Path("/usr/share/fonts/truetype/noto/NotoSansRunic-Regular.ttf")

# --------------------------------------------------------------------------
# Inscripcion / Inscription: «bienvenido a tu reino» -> Elder Futhark historico
# --------------------------------------------------------------------------
INSCRIPTION = "bienvenido a tu reino"
WORD_SEPARATOR = "᛫"  # ᛫ interpunct

ELDER_FUTHARK_24 = "ᚠᚢᚦᚨᚱᚲᚷᚹᚺᚾᛁᛃᛇᛈᛉᛊᛏᛒᛖᛗᛚᛜᛞᛟ"

# Spanish letter -> Elder Futhark rune (phonetic; v takes wunjo, the closest
# bilabial the futhark has, c/k/q share kaunan).
TRANSLITERATION = {
    "a": "ᚨ", "b": "ᛒ", "c": "ᚲ", "d": "ᛞ", "e": "ᛖ", "f": "ᚠ", "g": "ᚷ",
    "h": "ᚺ", "i": "ᛁ", "j": "ᛃ", "k": "ᚲ", "l": "ᛚ", "m": "ᛗ", "n": "ᚾ",
    "o": "ᛟ", "p": "ᛈ", "q": "ᚲ", "r": "ᚱ", "s": "ᛊ", "t": "ᛏ", "u": "ᚢ",
    "v": "ᚹ", "w": "ᚹ", "z": "ᛉ",
}


def transliterate(text):
    """Return the list of runes for `text`; word gaps become interpuncts."""
    runes = []
    for word in text.split():
        if runes:
            runes.append(WORD_SEPARATOR)
        for letter in word:
            runes.append(TRANSLITERATION[letter])
    return runes


# --------------------------------------------------------------------------
# Utilidades de dibujo / Drawing helpers
# --------------------------------------------------------------------------
def new_mask_canvas():
    surface = cairo.ImageSurface(cairo.FORMAT_A8, W, H)
    ctx = cairo.Context(surface)
    ctx.set_antialias(cairo.ANTIALIAS_BEST)
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    ctx.set_line_join(cairo.LINE_JOIN_ROUND)
    ctx.set_source_rgba(0, 0, 0, 1)
    return surface, ctx


def mask_from_surface(surface):
    surface.flush()
    return Image.frombuffer(
        "L", (W, H), bytes(surface.get_data()), "raw", "L", surface.get_stride(), 1
    )


def draw_mask(draw_fn):
    """Run draw_fn(ctx) on a fresh alpha canvas and return it as a PIL 'L' mask."""
    surface, ctx = new_mask_canvas()
    draw_fn(ctx)
    return mask_from_surface(surface)


def solid(color, mask):
    layer = Image.new("RGBA", mask.size, color + (0,))
    layer.putalpha(mask)
    return layer


def scaled(mask, factor):
    return mask.point(lambda v: min(255, int(v * factor)))


def polar(center, radius, angle):
    return (center[0] + radius * math.cos(angle), center[1] + radius * math.sin(angle))


def smoothstep(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)


# --------------------------------------------------------------------------
# Geometria / Geometry
# --------------------------------------------------------------------------
def ogive_radius(grow):
    return ARCH_R0 + grow


def ogive_path(ctx, grow, down_to=None, close=False):
    """Pointed (equilateral) arch; grow>0 offsets the curve outward.

    down_to=y extends both jambs straight down to that y; close=True also
    joins them (a filled arch + jambs).
    """
    radius = ogive_radius(grow)
    half = math.acos(ARCH_OFFSET / radius)
    left_spring = CX + ARCH_OFFSET - radius
    right_spring = CX - ARCH_OFFSET + radius
    ctx.new_sub_path()
    if down_to is not None:
        ctx.move_to(left_spring, down_to)
    ctx.line_to(left_spring, ARCH_SPRING_Y)
    ctx.arc(CX + ARCH_OFFSET, ARCH_SPRING_Y, radius, math.pi, math.pi + half)
    ctx.arc(CX - ARCH_OFFSET, ARCH_SPRING_Y, radius, -half, 0)
    if down_to is not None:
        ctx.line_to(right_spring, down_to)
    if close:
        ctx.close_path()


def leaf_path(ctx, side, inset):
    """One door leaf: half of the doorway ogive, inset from the opening."""
    radius = ARCH_R0 - inset
    half = math.acos(ARCH_OFFSET / radius)
    seam = 4 + inset * 0.3
    ctx.new_sub_path()
    if side < 0:
        spring = CX + ARCH_OFFSET - radius
        ctx.move_to(spring, FLOOR_Y - inset)
        ctx.line_to(spring, ARCH_SPRING_Y)
        ctx.arc(CX + ARCH_OFFSET, ARCH_SPRING_Y, radius, math.pi, math.pi + half)
        ctx.line_to(CX - seam, FLOOR_Y - inset)
    else:
        spring = CX - ARCH_OFFSET + radius
        ctx.move_to(spring, FLOOR_Y - inset)
        ctx.line_to(spring, ARCH_SPRING_Y)
        ctx.arc_negative(CX - ARCH_OFFSET, ARCH_SPRING_Y, radius, 0, -half)
        ctx.line_to(CX + seam, FLOOR_Y - inset)
    ctx.close_path()


def star_path(ctx, cx, cy, radius, points=8, inner=0.42, rotation=-math.pi / 2):
    ctx.new_sub_path()
    for i in range(points * 2):
        r = radius if i % 2 == 0 else radius * inner
        x, y = polar((cx, cy), r, rotation + i * math.pi / points)
        (ctx.move_to if i == 0 else ctx.line_to)(x, y)
    ctx.close_path()


def facade_silhouette():
    """Stepped crown following a circle around the rune arc, then straight down."""
    left, right, step, radius = 182, 818, 40, 322
    points = [(left, FLOOR_Y)]
    x = left
    while x < right:
        near = min(abs(x - CX), abs(x + step - CX))
        top = RUNE_CENTER[1] - math.sqrt(max(radius**2 - near**2, 0))
        top = max(top, 120)
        points += [(x, top), (x + step, top)]
        x += step
    points.append((right, FLOOR_Y))
    return points


# --------------------------------------------------------------------------
# Grupos de grabados / Engraving groups (cada uno: ctx -> trazos en blanco)
# --------------------------------------------------------------------------
def engrave_star(ctx, cx, cy, radius):
    ctx.set_line_width(2.0)
    star_path(ctx, cx, cy, radius)
    ctx.stroke()
    ctx.arc(cx, cy, max(radius * 0.18, 1.6), 0, 2 * math.pi)
    ctx.fill()


STAR_CLUSTERS = {
    "left": [(402, 318, 20), (354, 404, 12), (322, 350, 7)],
    "right": [(598, 322, 17), (648, 396, 13), (682, 346, 8)],
}


def draw_stars(side):
    def draw(ctx):
        stars = STAR_CLUSTERS[side]
        for cx, cy, radius in stars:
            engrave_star(ctx, cx, cy, radius)
        ctx.set_line_width(1.4)
        ctx.set_dash([5, 6])
        ctx.move_to(stars[0][0], stars[0][1])
        for cx, cy, _ in stars[1:]:
            ctx.line_to(cx, cy)
        ctx.stroke()
        ctx.set_dash([])

    return draw


def draw_column(side):
    sign = -1 if side == "left" else 1
    cx = CX + sign * (CX - COLUMN_CENTER_X)
    half = COLUMN_HALF_WIDTH

    def draw(ctx):
        ctx.set_line_width(2.2)
        # capitel y base: filetes y dientes / capital and base: fillets and teeth
        for y0, y1 in ((COLUMN_TOP, COLUMN_TOP + 32), (FLOOR_Y - 32, FLOOR_Y)):
            ctx.rectangle(cx - half - 12, y0, 2 * (half + 12), y1 - y0)
            ctx.stroke()
            ctx.move_to(cx - half - 12, (y0 + y1) / 2)
            ctx.line_to(cx + half + 12, (y0 + y1) / 2)
            ctx.stroke()
            for i in range(7):
                tx = cx - half - 12 + 6 + i * ((2 * (half + 12) - 12) / 6)
                ctx.move_to(tx - 4, y0 + 4)
                ctx.line_to(tx, (y0 + y1) / 2 - 3)
                ctx.line_to(tx + 4, y0 + 4)
                ctx.stroke()
        # fuste: cadena de anillos entrelazados / shaft: chain of interlocked rings
        top, bottom = COLUMN_TOP + 52, FLOOR_Y - 52
        ctx.rectangle(cx - half + 4, top - 8, 2 * half - 8, bottom - top + 16)
        ctx.stroke()
        spacing = 36
        for k in range(int((bottom - top - 20) / spacing) + 1):
            ring_y = top + 18 + k * spacing
            ctx.arc(cx, ring_y, 17, 0, 2 * math.pi)
            ctx.stroke()
            ctx.arc(cx, ring_y + spacing / 2, 2.6, 0, 2 * math.pi)
            ctx.fill()

    return draw


def draw_arch_inner(ctx):
    ctx.set_line_width(2.6)
    for grow in (0, 16):
        ogive_path(ctx, grow, down_to=FLOOR_Y)
        ctx.stroke()
    # dovelas interiores / inner voussoir ticks
    ctx.set_line_width(1.8)
    for side in (-1, 1):
        arc_centre = (CX + ARCH_OFFSET if side < 0 else CX - ARCH_OFFSET, ARCH_SPRING_Y)
        half = math.acos(ARCH_OFFSET / ARCH_R0)
        for i in range(1, 7):
            if side < 0:
                angle = math.pi + half * i / 7
            else:
                angle = -half * (1 - i / 7)
            ax, ay = polar(arc_centre, ARCH_R0, angle)
            bx, by = polar(arc_centre, ARCH_R0 + 16, angle)
            ctx.move_to(ax, ay)
            ctx.line_to(bx, by)
            ctx.stroke()


def draw_arch_outer(ctx):
    ctx.set_line_width(2.6)
    for grow in (34, 54):
        ogive_path(ctx, grow, down_to=FLOOR_Y)
        ctx.stroke()
    ctx.set_line_width(1.8)
    for side in (-1, 1):
        arc_centre = (CX + ARCH_OFFSET if side < 0 else CX - ARCH_OFFSET, ARCH_SPRING_Y)
        radius_in, radius_out = ARCH_R0 + 34, ARCH_R0 + 54
        half = math.acos(ARCH_OFFSET / radius_in)
        for i in range(1, 8):
            if side < 0:
                angle = math.pi + half * i / 8
            else:
                angle = -half * (1 - i / 8)
            ax, ay = polar(arc_centre, radius_in, angle)
            bx, by = polar(arc_centre, radius_out, angle)
            ctx.move_to(ax, ay)
            ctx.line_to(bx, by)
            ctx.stroke()
    # clave: cuadrado girado dentro de un circulo, sobre el apice / keystone medallion
    medallion = (CX, 248)
    ctx.set_line_width(2.4)
    ctx.arc(medallion[0], medallion[1], 26, 0, 2 * math.pi)
    ctx.stroke()
    ctx.new_sub_path()
    for i in range(4):
        x, y = polar(medallion, 18, math.pi / 4 + i * math.pi / 2)
        (ctx.move_to if i == 0 else ctx.line_to)(x, y)
    ctx.close_path()
    ctx.stroke()
    ctx.arc(medallion[0], medallion[1], 3, 0, 2 * math.pi)
    ctx.fill()


def ring_angles():
    """Angular span of the inscription, from the glyph advances (see rune_layout)."""
    layout, _ = rune_layout()
    return layout[0][1], layout[-1][1]


def draw_rings(ctx):
    start, end = ring_angles()
    margin = math.radians(7)
    ctx.set_line_width(2.4)
    for radius in (RUNE_RADIUS - 26, RUNE_RADIUS + 26):
        ctx.new_sub_path()
        ctx.arc(RUNE_CENTER[0], RUNE_CENTER[1], radius, start - margin, end + margin)
        ctx.stroke()
    ctx.set_line_width(2.0)
    for angle in (start - margin, end + margin):
        ax, ay = polar(RUNE_CENTER, RUNE_RADIUS - 26, angle)
        bx, by = polar(RUNE_CENTER, RUNE_RADIUS + 26, angle)
        ctx.move_to(ax, ay)
        ctx.line_to(bx, by)
        ctx.stroke()


def draw_door_leaf(side):
    sign = -1 if side == "left" else 1

    def draw(ctx):
        ctx.set_line_width(2.4)
        leaf_path(ctx, sign, 10)
        ctx.stroke()
        ctx.set_line_width(1.8)
        leaf_path(ctx, sign, 26)
        ctx.stroke()
        # cenefa de rombos a lo largo de la hoja / lozenge chain down the leaf
        cx = CX + sign * 52
        for y in range(600, FLOOR_Y - 40, 46):
            ctx.new_sub_path()
            ctx.move_to(cx, y - 17)
            ctx.line_to(cx + 15, y)
            ctx.line_to(cx, y + 17)
            ctx.line_to(cx - 15, y)
            ctx.close_path()
            ctx.stroke()
            ctx.arc(cx, y, 2.2, 0, 2 * math.pi)
            ctx.fill()
        # remaches / studs along the seam
        for y in range(560, FLOOR_Y - 30, 36):
            ctx.arc(CX + sign * 22, y, 2.4, 0, 2 * math.pi)
            ctx.fill()

    return draw


SIGIL_CENTER = (CX, 676)


def draw_sigil(ctx):
    """Ring + rotated lattice + dots on the seam: deliberately not a star."""
    cx, cy = SIGIL_CENTER
    ctx.set_line_width(2.6)
    ctx.arc(cx, cy, 36, 0, 2 * math.pi)
    ctx.stroke()
    ctx.arc(cx, cy, 25, 0, 2 * math.pi)
    ctx.stroke()
    ctx.set_line_width(2.0)
    for rot in (0, math.pi / 4):
        ctx.new_sub_path()
        for i in range(4):
            x, y = polar((cx, cy), 17, rot + i * math.pi / 2)
            (ctx.move_to if i == 0 else ctx.line_to)(x, y)
        ctx.close_path()
        ctx.stroke()
    for i in range(12):
        x, y = polar((cx, cy), 30.5, i * math.pi / 6)
        ctx.arc(x, y, 1.8, 0, 2 * math.pi)
        ctx.fill()
    ctx.set_line_width(2.2)
    ctx.move_to(cx, cy + 36)
    ctx.line_to(cx, cy + 62)
    ctx.stroke()
    ctx.arc(cx, cy + 68, 5, 0, 2 * math.pi)
    ctx.stroke()


def draw_steps(ctx):
    ctx.set_line_width(2.2)
    for y, half in ((FLOOR_Y + 15, 345), (FLOOR_Y + 30, 372)):
        ctx.move_to(CX - half, y)
        ctx.line_to(CX + half, y)
        ctx.stroke()
        for i in range(-int(half / 46), int(half / 46) + 1):
            x = CX + i * 46
            ctx.move_to(x - 6, y - 10)
            ctx.line_to(x, y - 3)
            ctx.line_to(x + 6, y - 10)
            ctx.stroke()
    ctx.move_to(CX - 345, FLOOR_Y + 15)
    ctx.line_to(CX - 345, FLOOR_Y)
    ctx.move_to(CX + 345, FLOOR_Y + 15)
    ctx.line_to(CX + 345, FLOOR_Y)
    ctx.stroke()


# --------------------------------------------------------------------------
# Runas / Runes
# --------------------------------------------------------------------------
def load_runic_font(size):
    if not RUNIC_FONT_PATH.is_file():
        sys.exit(f"error: runic font not found: {RUNIC_FONT_PATH} (package fonts-noto-core)")
    return ImageFont.truetype(str(RUNIC_FONT_PATH), size)


def glyph_tile(font, char):
    tile = Image.new("L", (96, 96), 0)
    ImageDraw.Draw(tile).text((48, 48), char, fill=255, font=font, anchor="mm")
    return tile


def assert_font_covers(runes):
    """A missing glyph renders as .notdef; make sure no rune looks like it."""
    font = load_runic_font(64)
    notdef = glyph_tile(font, "͸").tobytes()
    for char in set(runes):
        tile = glyph_tile(font, char)
        if tile.tobytes() == notdef or tile.getbbox() is None:
            sys.exit(f"error: {char!r} (U+{ord(char):04X}) has no glyph in {RUNIC_FONT_PATH.name}")


def rune_layout():
    """[(rune, angle)] centred on the top of the arc, plus the font used for metrics."""
    runes = transliterate(INSCRIPTION)
    allowed = set(ELDER_FUTHARK_24) | {WORD_SEPARATOR}
    assert set(runes) <= allowed, "inscription uses a codepoint outside Elder Futhark"
    assert_font_covers(runes)
    font = load_runic_font(64)
    ratio = RUNE_SIZE / 64.0
    widths = [font.getlength(r) * ratio * (0.9 if r == WORD_SEPARATOR else 1.0) + 8 for r in runes]
    total = sum(widths)
    angle = -math.pi / 2 - total / RUNE_RADIUS / 2
    layout = []
    for rune, width in zip(runes, widths):
        angle += width / RUNE_RADIUS / 2
        layout.append((rune, angle))
        angle += width / RUNE_RADIUS / 2
    return layout, font


def draw_runes(subset):
    """subset: 'left' or 'right' half of the inscription (lit in two steps)."""

    def draw(ctx):
        layout, font = rune_layout()
        half = len(layout) // 2
        chosen = layout[:half] if subset == "left" else layout[half:]
        ratio = RUNE_SIZE / 64.0
        for rune, angle in chosen:
            tile = glyph_tile(font, rune)
            data = bytearray(tile.tobytes())
            glyph = cairo.ImageSurface.create_for_data(data, cairo.FORMAT_A8, 96, 96, 96)
            x, y = polar(RUNE_CENTER, RUNE_RADIUS, angle)
            ctx.save()
            ctx.translate(x, y)
            ctx.rotate(angle + math.pi / 2)
            ctx.scale(ratio, ratio)
            ctx.mask_surface(glyph, -48, -48)
            ctx.restore()

    return draw


# --------------------------------------------------------------------------
# Piedra / Stone
# --------------------------------------------------------------------------
def noise_layer(rng, blur):
    raw = Image.frombytes("L", (W, H), rng.randbytes(W * H))
    return ImageOps.autocontrast(raw.filter(ImageFilter.GaussianBlur(blur)))


def stone_texture(base, seed, contrast):
    rng = random.Random(seed)
    fine = noise_layer(rng, 1.0)
    mid = noise_layer(rng, 5.0)
    large = noise_layer(rng, 24.0)
    mixed = Image.blend(Image.blend(fine, mid, 0.55), large, 0.45)
    mixed = ImageOps.autocontrast(mixed)
    channels = []
    for value in base:
        channels.append(
            mixed.point(lambda v, c=value: max(0, min(255, int(c * (1 - contrast + 2 * contrast * v / 255)))))
        )
    return Image.merge("RGB", channels)


def ridge_points():
    rng = random.Random(7)
    anchors = [
        (-20, 640), (80, 560), (150, 470), (230, 380), (300, 300), (360, 215),
        (410, 150), (455, 95), (500, 62), (548, 100), (600, 150), (660, 210),
        (720, 280), (790, 350), (860, 430), (930, 500), (1020, 590),
    ]
    points = []
    for (x0, y0), (x1, y1) in zip(anchors, anchors[1:]):
        steps = 9
        for s in range(steps):
            t = s / steps
            jitter = rng.uniform(-15, 15)
            points.append((x0 + (x1 - x0) * t + rng.uniform(-3, 3), y0 + (y1 - y0) * t + jitter))
    points.append(anchors[-1])
    return points


def polygon_mask(points):
    def draw(ctx):
        ctx.move_to(*points[0])
        for point in points[1:]:
            ctx.line_to(*point)
        ctx.close_path()
        ctx.fill()

    return draw_mask(draw)


def masonry_mask():
    def draw(ctx):
        ctx.set_line_width(1.3)
        course = 46
        for row, y in enumerate(range(250, FLOOR_Y, course)):
            ctx.move_to(170, y)
            ctx.line_to(830, y)
            ctx.stroke()
            offset = 0 if row % 2 == 0 else 55
            for x in range(190 + offset, 830, 110):
                ctx.move_to(x, y)
                ctx.line_to(x, min(y + course, FLOOR_Y))
                ctx.stroke()

    return draw_mask(draw)


def carve(canvas, mask):
    """Paint an engraved groove: dark core plus a faint lower-right lip."""
    lip = ImageChops.subtract(ImageChops.offset(mask, 1, 2), mask)
    canvas.alpha_composite(solid(GROOVE_EDGE, scaled(lip, 0.45)))
    canvas.alpha_composite(solid(GROOVE, scaled(mask, 0.92)))


def glow_layer(mask):
    """Lit engraving: white-silver core, silver bloom, blue halo."""
    tight = scaled(mask.filter(ImageFilter.GaussianBlur(2.2)), 2.4)
    bloom = scaled(mask.filter(ImageFilter.GaussianBlur(7)), 5.0)
    halo = scaled(mask.filter(ImageFilter.GaussianBlur(18)), 5.5)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    layer.alpha_composite(solid(HALO_BLUE, scaled(halo, 0.55)))
    layer.alpha_composite(solid(SILVER, scaled(bloom, 0.75)))
    layer.alpha_composite(solid(SILVER, tight))
    layer.alpha_composite(solid(SILVER_CORE, scaled(mask, 1.0)))
    cleaned = layer.getchannel("A").point(lambda v: 0 if v < 3 else v)
    layer.putalpha(cleaned)
    return layer


def moon_mask():
    center, radius = (176, 168), 44

    def draw(ctx):
        ctx.arc(center[0], center[1], radius, 0, 2 * math.pi)
        ctx.fill()

    full = draw_mask(draw)
    bite = draw_mask(lambda ctx: (ctx.arc(center[0] + 24, center[1] - 8, radius * 0.9, 0, 2 * math.pi), ctx.fill()))
    return ImageChops.subtract(full, bite)


def background_stars(sky_mask):
    rng = random.Random(11)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for _ in range(140):
        x, y = rng.randrange(W), rng.randrange(H)
        if sky_mask.getpixel((x, y)) < 128:
            continue
        brightness = rng.choice((70, 90, 110, 140, 180))
        draw.point((x, y), fill=(200, 215, 245, brightness))
        if brightness >= 140:
            draw.point((x + 1, y), fill=(200, 215, 245, brightness // 2))
    return layer


def vignette_mask():
    mask = Image.new("L", (W, H), 0)
    pixels = mask.load()
    for y in range(H):
        for x in range(W):
            d = math.hypot((x - CX) / 610.0, (y - 480) / 560.0)
            edge = min(x, W - 1 - x, y, H - 1 - y)
            # el borde del lienzo termina siempre en el color de fondo exacto
            fade = max(smoothstep(0.72, 1.0, d), 1 - smoothstep(0, 70, edge))
            pixels[x, y] = int(255 * fade)
    return mask


def build_plate(canvas):
    """Message tablet below the steps: dark stone, legible against light text."""
    x0, y0, x1, y1 = 270, 866, 730, 944
    plate = draw_mask(
        lambda ctx: (
            ctx.move_to(x0 + 14, y0), ctx.line_to(x1 - 14, y0), ctx.line_to(x1, y0 + 14),
            ctx.line_to(x1, y1 - 14), ctx.line_to(x1 - 14, y1), ctx.line_to(x0 + 14, y1),
            ctx.line_to(x0, y1 - 14), ctx.line_to(x0, y0 + 14), ctx.close_path(), ctx.fill(),
        )
    )
    texture = stone_texture((16, 19, 29), 41, 0.18).convert("RGBA")
    canvas.paste(texture, (0, 0), scaled(plate, 1.0))
    rim = draw_mask(
        lambda ctx: (
            ctx.set_line_width(2.0),
            ctx.move_to(x0 + 14, y0), ctx.line_to(x1 - 14, y0), ctx.line_to(x1, y0 + 14),
            ctx.line_to(x1, y1 - 14), ctx.line_to(x1 - 14, y1), ctx.line_to(x0 + 14, y1),
            ctx.line_to(x0, y1 - 14), ctx.line_to(x0, y0 + 14), ctx.close_path(), ctx.stroke(),
        )
    )
    canvas.alpha_composite(solid((92, 106, 138), scaled(rim, 0.8)))


# --------------------------------------------------------------------------
# Ensamblado / Assembly
# --------------------------------------------------------------------------
def engraving_groups():
    """Lighting order: the theme script lights these one after another."""
    return OrderedDict(
        [
            ("glow-01", draw_stars("left")),
            ("glow-02", draw_stars("right")),
            ("glow-03", draw_column("left")),
            ("glow-04", draw_column("right")),
            ("glow-05", draw_arch_inner),
            ("glow-06", draw_arch_outer),
            ("glow-07", draw_rings),
            ("glow-08", draw_runes("left")),
            ("glow-09", draw_runes("right")),
            ("glow-10", draw_door_leaf("left")),
            ("glow-11", draw_door_leaf("right")),
            ("glow-12", draw_sigil),
            ("glow-13", draw_steps),
        ]
    )


def render_base(group_masks):
    ridge = ridge_points()
    mountain = polygon_mask(ridge + [(W + 20, H + 20), (-20, H + 20)])
    sky = ImageChops.invert(mountain)

    canvas = Image.new("RGBA", (W, H), BG + (255,))
    gradient = Image.new("RGB", (W, H))
    top, bottom = (9, 14, 30), (16, 24, 46)
    ImageDraw.Draw(gradient).rectangle((0, 0, W, H), fill=top)
    for y in range(H):
        t = y / (H - 1)
        ImageDraw.Draw(gradient).line(
            [(0, y), (W, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom))
        )
    canvas.paste(gradient, (0, 0))
    canvas.alpha_composite(background_stars(sky))

    canvas.paste(stone_texture((27, 33, 48), 3, 0.34), (0, 0), mountain)

    facade = polygon_mask(facade_silhouette())
    canvas.paste(stone_texture((47, 54, 72), 5, 0.22), (0, 0), facade)
    seams = ImageChops.multiply(masonry_mask(), facade)
    carve(canvas, scaled(seams, 0.55))

    opening = draw_mask(lambda ctx: (ogive_path(ctx, 0, down_to=FLOOR_Y, close=True), ctx.fill()))
    recess = Image.new("RGB", (W, H), (9, 12, 21))
    canvas.paste(recess, (0, 0), opening)
    leaves = Image.new("L", (W, H), 0)
    for side in (-1, 1):
        leaves = ImageChops.lighter(leaves, draw_mask(lambda ctx, s=side: (leaf_path(ctx, s, 8), ctx.fill())))
    canvas.paste(stone_texture((34, 40, 58), 9, 0.20), (0, 0), leaves)

    for mask in group_masks.values():
        carve(canvas, mask)

    # peldanos de piedra / stone steps under the doorway
    for y, half, tone in ((FLOOR_Y, 360, (40, 46, 64)), (FLOOR_Y + 15, 388, (33, 38, 54))):
        step = draw_mask(lambda ctx, y=y, half=half: (ctx.rectangle(CX - half, y, 2 * half, 15), ctx.fill()))
        canvas.paste(Image.new("RGB", (W, H), tone), (0, 0), step)

    fade = vignette_mask()
    canvas.paste(Image.new("RGB", (W, H), BG), (0, 0), fade)
    build_plate(canvas)
    return canvas.convert("RGB")


def render_halo():
    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surface)
    gradient = cairo.RadialGradient(CX, 560, 20, CX, 560, 330)
    r, g, b = (c / 255 for c in HALO_BLUE)
    gradient.add_color_stop_rgba(0.0, r, g, b, 0.34)
    gradient.add_color_stop_rgba(0.55, r, g, b, 0.12)
    gradient.add_color_stop_rgba(1.0, r, g, b, 0.0)
    ctx.set_source(gradient)
    ctx.paint()
    surface.flush()
    return Image.frombuffer("RGBA", (W, H), bytes(surface.get_data()), "raw", "BGRa", surface.get_stride(), 1)


def render_twinkle(size, arm):
    """Small four-ray glint with a soft halo, drawn on its own tiny canvas."""
    side = size
    surface = cairo.ImageSurface(cairo.FORMAT_A8, side, side)
    ctx = cairo.Context(surface)
    ctx.set_antialias(cairo.ANTIALIAS_BEST)
    ctx.set_source_rgba(0, 0, 0, 1)
    c = side / 2
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    ctx.set_line_width(1.6)
    ctx.move_to(c - arm, c)
    ctx.line_to(c + arm, c)
    ctx.move_to(c, c - arm)
    ctx.line_to(c, c + arm)
    ctx.stroke()
    ctx.arc(c, c, 1.8, 0, 2 * math.pi)
    ctx.fill()
    surface.flush()
    mask = Image.frombuffer("L", (side, side), bytes(surface.get_data()), "raw", "L", surface.get_stride(), 1)
    layer = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    halo = scaled(mask.filter(ImageFilter.GaussianBlur(3.0)), 2.2)
    layer.alpha_composite(solid(HALO_BLUE, halo))
    layer.alpha_composite(solid(SILVER_CORE, mask))
    return layer


def render_entry():
    """Password slot: recessed stone slab with a silver rim (works without any font)."""
    width, height = 360, 40
    base = stone_texture_small((14, 17, 27), 77, (width, height))
    ImageDraw.Draw(base).rounded_rectangle((0, 0, width - 1, height - 1), radius=7, outline=(120, 138, 176), width=2)
    ImageDraw.Draw(base).rounded_rectangle((4, 4, width - 5, height - 5), radius=4, outline=(40, 48, 70), width=1)
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1), radius=7, fill=255)
    base.putalpha(mask)
    return base


def stone_texture_small(base, seed, size):
    rng = random.Random(seed)
    noise = Image.frombytes("L", size, rng.randbytes(size[0] * size[1])).filter(ImageFilter.GaussianBlur(1.2))
    noise = ImageOps.autocontrast(noise)
    channels = [noise.point(lambda v, c=c: int(c * (0.85 + 0.3 * v / 255))) for c in base]
    return Image.merge("RGB", channels).convert("RGBA")


def render_bullet():
    """Password bullet: a small silver lozenge."""
    size = 16
    scale = 4
    big = Image.new("L", (size * scale, size * scale), 0)
    c = size * scale / 2
    ImageDraw.Draw(big).polygon([(c, 4 * scale), (c + 5 * scale, c), (c, size * scale - 4 * scale), (c - 5 * scale, c)], fill=255)
    mask = big.resize((size, size), Image.LANCZOS)
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    layer.alpha_composite(solid(HALO_BLUE, scaled(mask.filter(ImageFilter.GaussianBlur(1.6)), 1.6)))
    layer.alpha_composite(solid(SILVER_CORE, mask))
    return layer


def crop_to_content(image):
    box = image.getchannel("A").getbbox()
    if box is None:
        sys.exit("error: empty layer")
    return image.crop(box), (box[0], box[1])


def render_layers():
    """Return OrderedDict name -> (PIL image, (x, y) offset on the scene)."""
    groups = engraving_groups()
    masks = OrderedDict((name, draw_mask(fn)) for name, fn in groups.items())
    layers = OrderedDict()
    layers["base"] = (render_base(masks), (0, 0))
    layers["halo"] = (render_halo(), (0, 0))
    layers["moon"] = crop_to_content(glow_layer(moon_mask()))
    for name, mask in masks.items():
        layers[name] = crop_to_content(glow_layer(mask))
    layers["twinkle-1"] = (render_twinkle(21, 8), (0, 0))
    layers["twinkle-2"] = (render_twinkle(27, 11), (0, 0))
    layers["twinkle-3"] = (render_twinkle(33, 14), (0, 0))
    layers["entry"] = (render_entry(), (0, 0))
    layers["bullet"] = (render_bullet(), (0, 0))
    layers["halo"] = crop_to_content(layers["halo"][0])
    return layers


def script_layer_table(layers):
    """Lines the hand-written script must contain, one per cropped layer."""
    lines = []
    for name, (image, (x, y)) in layers.items():
        if name in ("base", "entry", "bullet") or name.startswith("twinkle"):
            continue
        lines.append(f'AddLayer("{name}", {x}, {y});')
    return lines


def check_script_table(layers):
    if not SCRIPT_FILE.is_file():
        print(f"note: {SCRIPT_FILE.name} not found, layer table not checked")
        return True
    text = SCRIPT_FILE.read_text(encoding="utf-8")
    missing = [line for line in script_layer_table(layers) if line not in text]
    if missing:
        print(f"error: {SCRIPT_FILE.name} layer table is out of date; it must contain:")
        print("\n".join(script_layer_table(layers)))
        return False
    return True


def write_png(image, path):
    image.save(path, "PNG", optimize=False, compress_level=9)


def main(argv):
    out_dir = Path(argv[1]) if len(argv) > 1 else THEME_DIR
    out_dir.mkdir(parents=True, exist_ok=True)
    layers = render_layers()
    for name, (image, _) in layers.items():
        write_png(image, out_dir / f"{name}.png")
    print(f"wrote {len(layers)} frames to {out_dir}")
    if not check_script_table(layers):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
