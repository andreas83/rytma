#!/usr/bin/env python3
"""Generate the Rytma app icon for every platform.

Concept: a classic wind-up metronome whose swinging pendulum is a lightning
bolt — rhythm (metronome) + energy (the bolt). Brand purple gradient
backdrop, amber energy bolt, cyan rhythm pulses.

Pure-Pillow, no binary source asset: the art is drawn procedurally at high
resolution and downscaled (supersampled) for crisp anti-aliasing. Re-run to
regenerate all platform icons:

    python3 tool/generate_icon.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Palette (matches lib/ui/theme.dart RytmaColors).
PURPLE_HI = (158, 116, 255)   # vivid top-left
PURPLE_LO = (38, 14, 78)      # deep bottom-right
GLOW = (190, 160, 255)
WHITE = (245, 242, 255)
AMBER = (255, 193, 7)         # RytmaColors.poly-ish (energy bolt)
AMBER_HI = (255, 224, 130)
CYAN = (64, 196, 255)         # RytmaColors.weak (rhythm pulses)
INK = (22, 18, 40)


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def background(n):
    """Diagonal purple gradient + soft radial glow, built small and upscaled."""
    s = 256
    base = Image.new("RGB", (s, s))
    px = base.load()
    cx, cy = 0.5 * s, 0.42 * s
    rmax = 0.7 * s
    for y in range(s):
        for x in range(s):
            t = (x + y) / (2 * s)
            r, g, b = lerp(PURPLE_HI, PURPLE_LO, t)
            # radial glow toward the centre
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / rmax
            k = max(0.0, 1.0 - d) ** 2 * 0.45
            r = round(r + (GLOW[0] - r) * k)
            g = round(g + (GLOW[1] - g) * k)
            b = round(b + (GLOW[2] - b) * k)
            px[x, y] = (r, g, b)
    return base.resize((n, n), Image.LANCZOS).convert("RGBA")


def poly(draw, pts, n, fill):
    draw.polygon([(x * n, y * n) for (x, y) in pts], fill=fill)


def draw_art(img, n):
    """Draw the metronome + bolt onto a supersampled RGBA canvas of side n."""
    d = ImageDraw.Draw(img)
    cx = 0.5

    # --- rhythm pulses: faint concentric arcs radiating from the top tip ---
    arc = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ad = ImageDraw.Draw(arc)
    px, py = 0.55 * n, 0.24 * n
    for i, rad in enumerate((0.15, 0.215, 0.28)):
        bbox = [px - rad * n, py - rad * n, px + rad * n, py + rad * n]
        ad.arc(bbox, start=292, end=350, fill=CYAN + (225 - i * 45,),
               width=int(0.015 * n))
    img.alpha_composite(arc)

    # --- soft drop shadow under the metronome body ---
    body = [
        (cx - 0.110, 0.300), (cx + 0.110, 0.300),
        (cx + 0.205, 0.715), (cx - 0.205, 0.715),
    ]
    shadow = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    poly(sd, [(x, y + 0.018) for (x, y) in body], n, (0, 0, 0, 130))
    shadow = shadow.filter(ImageFilter.GaussianBlur(0.02 * n))
    img.alpha_composite(shadow)

    # --- base plinth (rounded) ---
    bw, bh = 0.30, 0.058
    bx0, by0 = (cx - bw / 2) * n, 0.705 * n
    d.rounded_rectangle([bx0, by0, (cx + bw / 2) * n, by0 + bh * n],
                        radius=0.02 * n, fill=INK + (255,))

    # --- metronome body (white trapezoid) ---
    poly(d, body, n, WHITE + (255,))
    # subtle vertical shading on the body for depth
    shade = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    sh = ImageDraw.Draw(shade)
    poly(sh, [(cx + 0.010, 0.300), (cx + 0.110, 0.300),
              (cx + 0.205, 0.715), (cx + 0.060, 0.715)], n, (60, 40, 110, 38))
    img.alpha_composite(shade)
    # centre scale slot
    d.line([(cx * n, 0.345 * n), (cx * n, 0.66 * n)],
           fill=(120, 110, 150, 120), width=int(0.006 * n))

    # --- the lightning-bolt pendulum (the "Power") ---
    # local bolt polygon in a 0..1 box, pointing up, then mapped onto the body.
    box_x0, box_y0, box_w, box_h = cx - 0.100, 0.205, 0.225, 0.475
    bolt_local = [
        (0.66, 0.00),  # top tip
        (0.28, 0.52),
        (0.50, 0.52),
        (0.30, 1.00),  # bottom tip
        (0.78, 0.42),
        (0.52, 0.42),
    ]
    bolt = [(box_x0 + x * box_w, box_y0 + y * box_h) for (x, y) in bolt_local]

    glow = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.polygon([(x * n, y * n) for (x, y) in bolt], fill=AMBER + (255,))
    glow = glow.filter(ImageFilter.GaussianBlur(0.02 * n))
    img.alpha_composite(glow)
    poly(d, bolt, n, AMBER + (255,))
    # highlight edge on the bolt
    poly(d, [bolt_local and (box_x0 + 0.66 * box_w, box_y0 + 0.00),
             (box_x0 + 0.30 * box_w, box_y0 + 0.50 * box_h),
             (box_x0 + 0.40 * box_w, box_y0 + 0.50 * box_h)], n,
         AMBER_HI + (220,))

    # --- pivot at the bolt base ---
    pvx, pvy = cx * n, 0.66 * n
    d.ellipse([pvx - 0.028 * n, pvy - 0.028 * n, pvx + 0.028 * n, pvy + 0.028 * n],
              fill=INK + (255,))
    d.ellipse([pvx - 0.013 * n, pvy - 0.013 * n, pvx + 0.013 * n, pvy + 0.013 * n],
              fill=AMBER + (255,))


def make_master(size=2048, ss=2):
    n = size * ss
    img = background(n)
    draw_art(img, n)
    return img.resize((size, size), Image.LANCZOS)


def save(img, path, rgb=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out = img
    if rgb:
        bg = Image.new("RGB", img.size, PURPLE_LO)
        bg.paste(img, mask=img.split()[3])
        out = bg
    out.save(path)
    print("wrote", os.path.relpath(path, ROOT), img.size)


def main():
    master = make_master()

    # master preview
    save(master, os.path.join(ROOT, "tool", "icon_preview.png"))

    # Android legacy mipmaps
    android = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for d, px in android.items():
        save(master.resize((px, px), Image.LANCZOS),
             os.path.join(ROOT, "android/app/src/main/res", f"mipmap-{d}",
                          "ic_launcher.png"))

    # iOS appiconset (flattened to RGB, no alpha)
    ios_dir = os.path.join(ROOT, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
    ios = {
        "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60, "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120, "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180, "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152, "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for name, px in ios.items():
        save(master.resize((px, px), Image.LANCZOS),
             os.path.join(ios_dir, name), rgb=True)

    # Web icons + favicon (maskable use the same full-bleed art — content sits
    # well inside the safe zone).
    web = os.path.join(ROOT, "web")
    save(master.resize((192, 192), Image.LANCZOS), os.path.join(web, "icons/Icon-192.png"))
    save(master.resize((512, 512), Image.LANCZOS), os.path.join(web, "icons/Icon-512.png"))
    save(master.resize((192, 192), Image.LANCZOS), os.path.join(web, "icons/Icon-maskable-192.png"))
    save(master.resize((512, 512), Image.LANCZOS), os.path.join(web, "icons/Icon-maskable-512.png"))
    save(master.resize((64, 64), Image.LANCZOS), os.path.join(web, "favicon.png"))


if __name__ == "__main__":
    main()
