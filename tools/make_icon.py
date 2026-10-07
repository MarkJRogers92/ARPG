"""Draws the app icon (assets/icon/icon.png): a soul flame over a night sky,
with dawn breaking at the horizon. Run from the project root:

    python3 tools/make_icon.py
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 1024
M = 100  # macOS icons leave a margin around the rounded square
OUT = "assets/icon/icon.png"


def lerp(a, b, t):
    return a + (b - a) * t


def main():
    y, x = np.mgrid[0:S, 0:S].astype(float)
    t = (y - M) / (S - 2 * M)
    top = np.array([0.06, 0.05, 0.16])
    mid = np.array([0.22, 0.09, 0.30])
    low = np.array([0.95, 0.52, 0.30])
    sky = np.where(t[..., None] < 0.62, lerp(top, mid, np.clip(t / 0.62, 0, 1)[..., None]),
                   lerp(mid, low, np.clip((t - 0.62) / 0.38, 0, 1)[..., None] ** 1.6))
    # The sun's glow just under the horizon.
    d = np.hypot(x - S / 2, y - (S - M + 60)) / S
    sky += np.array([1.0, 0.75, 0.4]) * np.exp(-d * 5.0)[..., None] * 0.55
    img = Image.fromarray((np.clip(sky, 0, 1) * 255).astype(np.uint8), "RGB").convert("RGBA")

    draw = ImageDraw.Draw(img)
    rng = np.random.default_rng(3)
    for _ in range(40):
        sx, sy = rng.uniform(M + 40, S - M - 40), rng.uniform(M + 40, S * 0.5)
        r = rng.uniform(1.5, 4.0)
        draw.ellipse([sx - r, sy - r, sx + r, sy + r], fill=(255, 245, 220, int(rng.uniform(120, 230))))
    # A crescent moon, top right.
    mx, my, mr = S - M - 190, M + 170, 70
    moon = Image.new("RGBA", (S, S))
    md = ImageDraw.Draw(moon)
    md.ellipse([mx - mr, my - mr, mx + mr, my + mr], fill=(235, 238, 255, 255))
    md.ellipse([mx - mr + 38, my - mr - 18, mx + mr + 38, my + mr - 18], fill=(0, 0, 0, 0))
    img.alpha_composite(moon)

    # Graves along the horizon, in silhouette.
    ground = Image.new("RGBA", (S, S))
    gd = ImageDraw.Draw(ground)
    hy = S - M - 150
    gd.polygon([(0, hy + 30), (S * 0.3, hy), (S * 0.7, hy + 10), (S, hy - 10), (S, S), (0, S)], fill=(18, 10, 24, 255))
    for gx, w, h in [(190, 60, 95), (300, 44, 70), (720, 58, 105), (830, 40, 66)]:
        gd.rounded_rectangle([gx - w / 2, hy - h, gx + w / 2, hy + 20], radius=w / 2, fill=(18, 10, 24, 255))
    img.alpha_composite(ground)

    # The soul: a cyan flame with hollow eyes, glowing.
    flame = Image.new("RGBA", (S, S))
    fd = ImageDraw.Draw(flame)
    cx, cy = S / 2, S * 0.47
    def bez(p0, p1, p2, p3, n=40):
        out = []
        for k in range(n):
            u = k / (n - 1)
            out.append(tuple((1 - u) ** 3 * np.array(p0) + 3 * (1 - u) ** 2 * u * np.array(p1)
                    + 3 * (1 - u) * u ** 2 * np.array(p2) + u ** 3 * np.array(p3)))
        return out

    base = cy + 150
    pts = []
    # Round bottom.
    for k in range(41):
        a = np.pi * k / 40
        pts.append((cx + 165 * np.cos(a), base - 40 + 120 * np.sin(a) * 0.9))
    pts.reverse()  # left to right along the bottom
    pts = pts[::-1]
    # Left side up to a small tongue, then to the main tip, down to a right tongue.
    pts += bez((cx - 165, base - 40), (cx - 190, base - 200), (cx - 120, base - 260), (cx - 110, base - 330))
    pts += bez((cx - 110, base - 330), (cx - 80, base - 270), (cx - 60, base - 280), (cx - 40, base - 320))
    pts += bez((cx - 40, base - 320), (cx - 20, base - 420), (cx + 40, base - 470), (cx + 30, base - 560))
    pts += bez((cx + 30, base - 560), (cx + 120, base - 470), (cx + 110, base - 380), (cx + 90, base - 330))
    pts += bez((cx + 90, base - 330), (cx + 115, base - 350), (cx + 140, base - 380), (cx + 150, base - 420))
    pts += bez((cx + 150, base - 420), (cx + 200, base - 300), (cx + 200, base - 160), (cx + 165, base - 40))
    k = 0.74  # scale the flame about its base
    pts = [(cx + (px - cx) * k, base + 30 + (py - base) * k) for px, py in pts]
    fd.polygon(pts, fill=(120, 230, 255, 255))
    glow = flame.filter(ImageFilter.GaussianBlur(60))
    img.alpha_composite(glow)
    img.alpha_composite(glow)
    inner = flame.filter(ImageFilter.GaussianBlur(6))
    img.alpha_composite(inner)
    core = Image.new("RGBA", (S, S))
    cd = ImageDraw.Draw(core)
    cd.ellipse([cx - 82, cy + 75, cx + 82, cy + 255], fill=(230, 252, 255, 230))
    img.alpha_composite(core.filter(ImageFilter.GaussianBlur(30)))
    eyes = ImageDraw.Draw(img)
    for ex in (cx - 42, cx + 42):
        eyes.ellipse([ex - 21, cy + 130, ex + 21, cy + 184], fill=(20, 12, 40, 255))

    # Cut to the rounded square.
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([M, M, S - M, S - M], radius=185, fill=255)
    out = Image.new("RGBA", (S, S))
    out.paste(img, (0, 0), mask)
    out.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
