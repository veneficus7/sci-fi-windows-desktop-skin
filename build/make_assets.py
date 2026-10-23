"""Builds every asset of the Arrakis desktop.

    python make_assets.py source.jpg ../Arrakis/@Resources [alien_source.jpg]

Writes wallpapers (dawn/day/dusk/night, clear and storm), hotspot boxes, buttons, scan
thumbnails, moons, the sandworm ripple, the eye glow and the UI sounds. With an Alien
source it also writes the Nostromo wallpapers and scans.
"""
import math
import sys
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SCREEN = (1920, 1200)
SS = 4

BOX, INSET, PAD = 101, 11, 10
FRAME = (244, 252, 255)
GLOW = (120, 225, 245)

# Planet / clock geometry (keep in sync with Sky.lua and Focus.ini)
PLANET = (975, 368, 305)
RING_HOUR, RING_MIN = 215, 268
EYES = (963.5, 357.5)
WORM_SIGN = (200, 905)

PHASES = ("dawn", "day", "dusk", "night")


# ---------------------------------------------------------------- helpers

def fill_crop(im):
    s = max(SCREEN[0] / im.width, SCREEN[1] / im.height)
    big = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    x0, y0 = (big.width - SCREEN[0]) // 2, (big.height - SCREEN[1]) // 2
    return big.crop((x0, y0, x0 + SCREEN[0], y0 + SCREEN[1]))


def to_f(im):
    return np.asarray(im.convert("RGB")).astype(np.float32) / 255.0


def to_im(a):
    return Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")


def disc_mask(shape, cx, cy, r, feather):
    yy, xx = np.mgrid[0:shape[0], 0:shape[1]]
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    return np.clip((r - d) / feather + 0.5, 0, 1)[..., None]


def vignette(shape, strength):
    yy, xx = np.mgrid[0:shape[0], 0:shape[1]]
    nx, ny = xx / shape[1] - 0.5, yy / shape[0] - 0.5
    return (1 - strength * (nx ** 2 + ny ** 2) * 2.2)[..., None]


def vgrad(shape, top, bottom):
    t = np.linspace(0, 1, shape[0])[:, None, None]
    return top + (bottom - top) * t


def lum(a):
    return (0.3 * a[..., 0] + 0.59 * a[..., 1] + 0.11 * a[..., 2])[..., None]


def desat(a, k):
    return a * (1 - k) + lum(a) * k


def overlay_rgba(base_im, layer):
    out = base_im.convert("RGBA")
    out.alpha_composite(layer)
    return out.convert("RGB")


# ---------------------------------------------------------------- wallpapers

def grade(base, phase):
    a = to_f(base)
    sh = a.shape
    planet = disc_mask(sh, PLANET[0], PLANET[1], PLANET[2], 30)
    # only the cyan iris pixels, not the face around them
    eyes = disc_mask(sh, EYES[0], EYES[1], 20, 6) * np.clip((a[..., 2:3] - a[..., 0:1] - 0.05) * 6, 0, 1)
    if phase == "day":
        a = desat(a * 1.05 + 0.03, 0.08)
        a = a * 0.94 + vgrad(sh, np.array([1.0, 0.93, 0.82]), np.array([1.0, 0.9, 0.8])) * 0.06
    elif phase == "dawn":
        a = a * np.array([1.0, 0.86, 0.9]) * 0.92 + np.array([0.06, 0.045, 0.055])
        a = a * 0.88 + vgrad(sh, np.array([1.0, 0.72, 0.74]), np.array([0.6, 0.4, 0.35])) * 0.12
        a = a ** 1.05
    elif phase == "dusk":
        g = a * np.array([1.0, 0.6, 0.52]) * 0.8
        g = g * (1 - 0.22 * vgrad(sh, np.array([1.0]), np.array([0.0])))
        g = g * vignette(sh, 0.28)
        a = g * (1 - planet * 0.6) + a * 0.85 * planet * 0.6
    elif phase == "night":
        L = lum(a) ** 1.15
        dark, light = np.array([0.02, 0.035, 0.08]), np.array([0.55, 0.68, 0.9])
        col = (dark + (light - dark) * L) * 0.82
        col = col * (1 - planet * 0.8) + (a * 0.62) * planet * 0.8
        rng = np.random.default_rng(7)
        n = 1400
        sx, sy = rng.integers(0, sh[1], n), rng.integers(0, 640, n)
        stars = np.zeros(sh[:2], np.float32)
        stars[sy, sx] = rng.uniform(0.25, 1.0, n) ** 2
        stars = np.asarray(Image.fromarray((stars * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))).astype(np.float32) / 255 * 2.2
        sky = np.clip(1 - planet[..., 0] * 1.2, 0, 1) * np.clip((640 - np.arange(sh[0]))[:, None] / 240, 0, 1)
        col = col + (stars * sky)[..., None] * np.array([0.85, 0.9, 1.0])
        col = col * vignette(sh, 0.3)
        a = col * (1 - eyes) + np.clip(a * 1.35, 0, 1) * eyes   # the eyes keep glowing at night
    return to_im(a)


RING_COLORS = {"dawn": (255, 236, 232, 70), "day": (255, 246, 232, 72), "dusk": (255, 220, 200, 62), "night": (200, 220, 255, 84)}


def add_rings(im, phase):
    W, H = SCREEN
    s = 2
    layer = Image.new("RGBA", (W * s, H * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    col = RING_COLORS[phase]
    cx, cy = PLANET[0] * s, PLANET[1] * s
    r = RING_MIN * s
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=col, width=s)
    for i in range(60):            # minute ticks, longer every five
        a = i / 60 * 2 * math.pi
        l1, l2 = (RING_MIN - (7 if i % 5 == 0 else 3)) * s, (RING_MIN + (7 if i % 5 == 0 else 3)) * s
        w = s * (2 if i % 15 == 0 else 1)
        d.line([(cx + l1 * math.sin(a), cy - l1 * math.cos(a)), (cx + l2 * math.sin(a), cy - l2 * math.cos(a))], fill=col, width=w)
    r = RING_HOUR * s
    for i in range(120):           # dotted hour orbit
        a = i / 120 * 2 * math.pi
        x, y = cx + r * math.sin(a), cy - r * math.cos(a)
        d.ellipse([x - s, y - s, x + s, y + s], fill=col[:3] + (int(col[3] * 0.9),))
    layer = layer.resize((W, H), Image.LANCZOS)
    return overlay_rgba(im, layer)


def add_worm_sign(im):
    W, H = SCREEN
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x, y = WORM_SIGN
    for i, (rx, ry) in enumerate(((34, 9), (52, 14), (72, 20))):
        a = 70 - i * 18
        d.arc([x - rx, y - ry, x + rx, y + ry], 190, 350, fill=(255, 235, 200, a), width=2)
        d.arc([x - rx, y - ry + 3, x + rx, y + ry + 3], 190, 350, fill=(60, 20, 0, a), width=2)
    d.line([(x - 80, y + 4), (x - 260, y + 18)], fill=(60, 20, 0, 40), width=3)
    layer = layer.filter(ImageFilter.GaussianBlur(1.2))
    return overlay_rgba(im, layer)


HAZE = {"dawn": (0.78, 0.55, 0.5), "day": (0.8, 0.56, 0.32), "dusk": (0.55, 0.24, 0.14), "night": (0.22, 0.26, 0.34)}


def storm(im, phase):
    a = to_f(im.filter(ImageFilter.GaussianBlur(1.3)))
    sh = a.shape
    rng = np.random.default_rng(11)
    small = rng.random((sh[0] // 8, sh[1] // 8)).astype(np.float32)
    n = Image.fromarray((small * 255).astype(np.uint8)).resize((sh[1], sh[0]), Image.BICUBIC)
    n = np.asarray(n.filter(ImageFilter.BoxBlur(3))).astype(np.float32) / 255
    k = 90                          # horizontal wind streaks
    c = np.cumsum(np.pad(n, ((0, 0), (k, 0)), mode="edge"), axis=1)
    streak = (c[:, k:] - c[:, :-k]) / k
    streak = (streak - streak.min()) / (streak.max() - streak.min())
    h = (0.20 + 0.20 * streak + 0.08 * vgrad(sh, np.array([0.0]), np.array([1.0]))[..., 0])[..., None]
    a = a * (1 - h) + np.array(HAZE[phase]) * h
    return to_im(a)


def make_wallpapers(src, out):
    base = fill_crop(Image.open(src).convert("RGB"))
    base = add_worm_sign(base)
    for phase in PHASES:
        clear = add_rings(grade(base, phase), phase)
        clear.save(out / f"arrakis_{phase}.png", optimize=True)
        storm(clear, phase).save(out / f"arrakis_{phase}_storm.png", optimize=True)
    return base


def make_nostromo(src, out):
    base = fill_crop(Image.open(src).convert("RGB"))
    # paint out the poster's red title (on pure black); the live title replaces it
    a = to_f(base)
    red = (a[..., 0] > 0.3) & (a[..., 0] > a[..., 1] * 2) & (a[..., 0] > a[..., 2] * 2)
    red[:900] = False
    mask = Image.fromarray((red * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(2))
    m = np.asarray(mask).astype(np.float32)[..., None] / 255
    base = to_im(a * (1 - m))
    base.save(out / "nostromo_day.png", optimize=True)
    a = to_f(base)
    L = lum(a) ** 1.1           # night: red emergency lighting
    col = np.array([0.03, 0.0, 0.0]) + (np.array([0.95, 0.24, 0.18]) - np.array([0.03, 0.0, 0.0])) * L
    to_im(col * vignette(a.shape, 0.35)).save(out / "nostromo_night.png", optimize=True)
    return base


# ---------------------------------------------------------------- UI images

def box_image(hover=False, hidden=False):
    size = BOX + 2 * PAD
    S = size * SS
    o0, o1 = PAD * SS, (PAD + BOX - 1) * SS
    i0, i1 = (PAD + INSET) * SS, (PAD + BOX - 1 - INSET) * SS
    shade = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(shade)
    k = 1.35 if hover else 1.0
    if not hidden:
        d.polygon([(o0, o0), (o1, o0), (i1, i0), (i0, i0)], fill=(20, 6, 0, int(78 * k)))
        d.polygon([(o0, o1), (o1, o1), (i1, i1), (i0, i1)], fill=(20, 6, 0, int(58 * k)))
        d.polygon([(o0, o0), (i0, i0), (i0, i1), (o0, o1)], fill=(20, 6, 0, int(66 * k)))
        d.polygon([(o1, o0), (i1, i0), (i1, i1), (o1, o1)], fill=(20, 6, 0, int(66 * k)))
        d.rectangle([i0, i0, i1, i1], fill=(10, 4, 0, 34 if not hover else 0))
    lines = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(lines)
    w = int((1.9 if hover else 1.5) * SS)
    d.rectangle([o0, o0, o1, o1], outline=FRAME + (255,), width=w)
    d.rectangle([i0, i0, i1, i1], outline=FRAME + (255,), width=w)
    for a, b in (((o0, o0), (i0, i0)), ((o1, o0), (i1, i0)), ((o0, o1), (i0, i1)), ((o1, o1), (i1, i1))):
        d.line([a, b], fill=FRAME + (255,), width=w)
    glow = Image.new("RGBA", (S, S), GLOW + (0,))
    blur = lines.split()[3].filter(ImageFilter.GaussianBlur((4.5 if hover else 3.2) * SS))
    glow.putalpha(blur.point(lambda v: min(255, int(v * (2.6 if hover else 1.9)))))
    out = Image.alpha_composite(Image.alpha_composite(shade, glow), lines)
    return out.resize((size, size), Image.LANCZOS)


def with_glow(shape_fn, size, hover, color=GLOW, radius=3.0, gain=1.0):
    S = (size[0] * SS, size[1] * SS)
    layer = Image.new("RGBA", S, (0, 0, 0, 0))
    shape_fn(ImageDraw.Draw(layer), hover)
    glow = Image.new("RGBA", S, color + (0,))
    blur = layer.split()[3].filter(ImageFilter.GaussianBlur((radius * 1.5 if hover else radius) * SS))
    glow.putalpha(blur.point(lambda v: min(255, int(v * (gain * 1.6 if hover else gain)))))
    return Image.alpha_composite(glow, layer).resize(size, Image.LANCZOS)


def button_image(hover=False):
    def draw(d, hov):
        fill = (255, 252, 246, 250) if hov else (250, 242, 230, 235)
        d.rounded_rectangle([10 * SS, 10 * SS, 92 * SS - 1, 31 * SS - 1], radius=2 * SS, fill=fill)
    return with_glow(draw, (102, 41), hover)


def ring_image(hover=False):
    def draw(d, hov):
        col = (255, 252, 246, 255) if hov else (250, 242, 230, 255)
        d.ellipse([10 * SS, 10 * SS, 32 * SS - 1, 32 * SS - 1], outline=col, width=int(2 * SS))
    return with_glow(draw, (42, 42), hover)


def moon_image(radius, size):
    c = size / 2

    def draw(d, _):
        r = radius * SS
        cx = cy = c * SS
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(246, 238, 222, 255))
        # terminator shading and a couple of craters
        d.ellipse([cx - r * 0.35, cy - r, cx + r * 1.6, cy + r], fill=(206, 196, 182, 120))
        for ox, oy, cr in ((-0.35, -0.2, 0.22), (0.15, 0.35, 0.16)):
            d.ellipse([cx + (ox - cr) * r, cy + (oy - cr) * r, cx + (ox + cr) * r, cy + (oy + cr) * r], fill=(190, 180, 168, 160))
    return with_glow(draw, (size, size), False, color=(255, 236, 200), radius=radius * 0.55, gain=1.4)


def worm_image(direction):
    W, H = 240, 64
    S = (W * SS, H * SS)
    layer = Image.new("RGBA", S, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # dark trough behind, bright crest on top, spray at the head
    d.ellipse([20 * SS, 30 * SS, 220 * SS, 50 * SS], fill=(55, 18, 0, 90))
    d.ellipse([30 * SS, 22 * SS, 210 * SS, 40 * SS], fill=(255, 226, 180, 70))
    d.ellipse([60 * SS, 25 * SS, 180 * SS, 33 * SS], fill=(255, 240, 210, 70))
    rng = np.random.default_rng(3)
    for _ in range(70):
        x = rng.normal(26, 10) * SS
        y = rng.normal(28, 7) * SS
        r = rng.uniform(0.6, 1.6) * SS
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 230, 190, int(rng.uniform(60, 160))))
    out = layer.filter(ImageFilter.GaussianBlur(2.2 * SS)).resize((W, H), Image.LANCZOS)
    return out if direction == "l" else out.transpose(Image.FLIP_LEFT_RIGHT)


def eye_glow():
    W, H = 120, 60
    S = (W * SS, H * SS)
    layer = Image.new("RGBA", S, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for ex in (-10.5, 10.5):
        x, y = (W / 2 + ex) * SS, (H / 2) * SS
        d.ellipse([x - 5 * SS, y - 4 * SS, x + 5 * SS, y + 4 * SS], fill=(150, 235, 255, 255))
    core = layer.filter(ImageFilter.GaussianBlur(3 * SS))
    halo = Image.new("RGBA", S, (90, 200, 255, 0))
    halo.putalpha(layer.split()[3].filter(ImageFilter.GaussianBlur(11 * SS)).point(lambda v: int(v * 0.8)))
    return Image.alpha_composite(halo, core).resize((W, H), Image.LANCZOS)


def scan_image(wp, crop, tint_dark=(4, 22, 30), tint_light=(160, 238, 248)):
    n = BOX - 2 * INSET - 2
    c = wp.crop(crop).resize((n, n), Image.LANCZOS).convert("L")
    a = np.asarray(c).astype(float) / 255.0
    a = np.clip((a - a.min()) / max(1e-6, a.max() - a.min()), 0, 1) ** 0.9
    dark, light = np.array(tint_dark, float), np.array(tint_light, float)
    rgb = dark + (light - dark) * a[..., None]
    rgb[1::2] *= 0.62
    yy, xx = np.mgrid[0:n, 0:n] / (n - 1) - 0.5
    rgb *= (1 - 0.55 * (xx ** 2 + yy ** 2))[..., None]
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")


# ---------------------------------------------------------------- sounds

RATE = 44100


def write_wav(path, samples):
    s = np.clip(samples, -1, 1)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((s * 32767).astype(np.int16).tobytes())


def env(n, attack, decay):
    t = np.arange(n) / RATE
    return np.minimum(1, t / attack) * np.exp(-t / decay)


def make_sounds(out):
    rng = np.random.default_rng(5)
    t = lambda sec: np.arange(int(RATE * sec)) / RATE
    x = t(0.09)
    hover = (np.sin(2 * np.pi * 110 * x) * 0.7 + np.sin(2 * np.pi * 220 * x) * 0.2) * env(len(x), 0.004, 0.03) * 0.16
    hover += np.convolve(rng.normal(0, 1, len(x)), np.ones(20) / 20, "same") * env(len(x), 0.002, 0.02) * 0.05
    x = t(0.5)
    f = 92 * np.exp(-x * 2.2) + 48
    click = np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(len(x), 0.002, 0.12) * 0.42
    click[:200] += rng.normal(0, 0.25, 200) * np.linspace(1, 0, 200)
    x = t(0.3)
    f = 330 * (1 + x / 0.3)
    opn = np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(len(x), 0.01, 0.09) * 0.14
    x = t(1.4)
    disc = np.zeros_like(x)
    for i, fr in enumerate((523.25, 659.25, 783.99, 1046.5)):
        d0 = int(i * 0.11 * RATE)
        seg = x[: len(x) - d0]
        disc[d0:] += np.sin(2 * np.pi * fr * seg) * env(len(seg), 0.005, 0.35) * 0.09
    disc += np.concatenate([np.zeros(int(0.18 * RATE)), disc[: -int(0.18 * RATE)]]) * 0.35
    x = t(2.6)
    chime = np.zeros_like(x)
    for fr, a, dec in ((440, 0.22, 0.9), (880 * 1.003, 0.12, 0.6), (1320 * 0.995, 0.07, 0.4), (1760, 0.04, 0.3)):
        chime += np.sin(2 * np.pi * fr * x) * a * env(len(x), 0.003, dec)
    on, off = out / "1", out / "0"   # folder name = the Sounds setting
    on.mkdir(parents=True, exist_ok=True)
    off.mkdir(parents=True, exist_ok=True)
    for name, s in (("hover", hover), ("click", click), ("open", opn), ("discover", disc), ("chime", chime)):
        write_wav(on / f"{name}.wav", s)
        write_wav(off / f"{name}.wav", np.zeros(int(RATE * 0.02)))


# ---------------------------------------------------------------- main

def main():
    src = sys.argv[1]
    res = Path(sys.argv[2])
    alien = sys.argv[3] if len(sys.argv) > 3 else None
    img = res / "Images"
    wpdir = img / "Wallpapers"
    wpdir.mkdir(parents=True, exist_ok=True)

    base = make_wallpapers(src, wpdir)
    box_image().save(img / "box_idle.png")
    box_image(hover=True).save(img / "box_hover.png")
    box_image(hover=True, hidden=True).save(img / "box_hidden.png")
    button_image().save(img / "button_idle.png")
    button_image(hover=True).save(img / "button_hover.png")
    ring_image().save(img / "ring_idle.png")
    ring_image(hover=True).save(img / "ring_hover.png")
    moon_image(9, 44).save(img / "moon_hour.png")
    moon_image(5.5, 32).save(img / "moon_min.png")
    worm_image("l").save(img / "worm_l.png")
    worm_image("r").save(img / "worm_r.png")
    eye_glow().save(img / "eyes_glow.png")
    for i, crop in {1: (880, 290, 1045, 455), 2: (1040, 110, 1240, 310), 3: (260, 930, 520, 1190)}.items():
        scan_image(base, crop).save(img / f"scan{i}.png")
    if alien:
        nb = make_nostromo(alien, wpdir)
        for i, crop in {1: (540, 330, 760, 550), 2: (1240, 440, 1460, 660), 3: (840, 320, 1100, 580)}.items():
            scan_image(nb, crop).save(img / f"nostromo_scan{i}.png")
    make_sounds(res / "Sounds")
    print("ok")


if __name__ == "__main__":
    main()
