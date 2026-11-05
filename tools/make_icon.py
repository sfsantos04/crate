#!/usr/bin/env python3
"""Gera o AppIcon do Sonda: dois nós ligados por uma curva (P2P), gradiente ciano
sobre azul profundo. Desenha em 4096 e reduz para 1024 (antialiasing real)."""
import json
import os
from PIL import Image, ImageDraw, ImageFilter

SS = 2048          # supersample
OUT = 1024
BASE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Assets", "Assets.xcassets")
ICONSET = os.path.join(BASE, "AppIcon.appiconset")
ACCENT = os.path.join(BASE, "AccentColor.colorset")


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def radial_background(size):
    """Fundo: radial do centro claro para as bordas escuras, desenhado em anéis
    (rápido, sem numpy)."""
    inner = (24, 63, 122)
    outer = (7, 15, 31)
    img = Image.new("RGB", (size, size), outer)
    draw = ImageDraw.Draw(img)
    cx = cy = size / 2
    maxd = int((2 ** 0.5) * size / 2)
    for r in range(maxd, 0, -1):
        t = (r / maxd) ** 1.15
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=lerp(inner, outer, min(1.0, t)))
    return img


def gradient_stroke(size, points, widths, color_a=(91, 231, 255), color_b=(255, 255, 255)):
    """Traço limpo: máscara de uma passada só + gradiente vertical aplicado por cima."""
    mask = Image.new("L", (size, size), 0)
    brush = ImageDraw.Draw(mask)
    radius = widths / 2
    for (x, y) in points:
        brush.ellipse([x - radius, y - radius, x + radius, y + radius], fill=255)

    gradient = Image.new("RGBA", (size, size))
    draw = ImageDraw.Draw(gradient)
    for y in range(size):
        draw.line([(0, y), (size, y)], fill=lerp(color_a, color_b, y / size) + (255,))

    stroke = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    stroke.paste(gradient, (0, 0), mask)
    return stroke, mask


def bezier(p0, p1, p2, p3, n=400):
    pts = []
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * p1[0] + 3 * (1 - t) * t ** 2 * p2[0] + t ** 3 * p3[0]
        y = (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * p1[1] + 3 * (1 - t) * t ** 2 * p2[1] + t ** 3 * p3[1]
        pts.append((x, y))
    return pts


def glow(size, points, width):
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.line(points, fill=(91, 231, 255, 90), width=width, joint="curve")
    return layer.filter(__import__("PIL.ImageFilter", fromlist=["GaussianBlur"]).GaussianBlur(width * 0.35))


def main():
    size = SS
    bg = radial_background(size)
    canvas = bg.convert("RGBA")

    # curva em S ligando dois nós, ocupando o centro do ícone
    curve = bezier((size * 0.26, size * 0.72), (size * 0.34, size * 0.38),
                   (size * 0.66, size * 0.62), (size * 0.74, size * 0.28))
    stroke, mask = gradient_stroke(size, curve, int(size * 0.075))

    halo = mask.filter(ImageFilter.GaussianBlur(size * 0.028))
    glow_layer = Image.new("RGBA", (size, size), (91, 231, 255, 0))
    glow_layer.putalpha(halo.point(lambda v: int(v * 0.55)))
    canvas.alpha_composite(glow_layer)
    canvas.alpha_composite(stroke)

    draw = ImageDraw.Draw(canvas)
    for (cx, cy) in ((size * 0.26, size * 0.72), (size * 0.74, size * 0.28)):
        r = size * 0.105
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, 255))
        draw.ellipse([cx - r * 0.46, cy - r * 0.46, cx + r * 0.46, cy + r * 0.46],
                     fill=(16, 43, 92, 255))

    icon = canvas.convert("RGB").resize((OUT, OUT), Image.LANCZOS)
    os.makedirs(ICONSET, exist_ok=True)
    icon.save(os.path.join(ICONSET, "AppIcon-1024.png"), "PNG", optimize=True)

    contents = {
        "images": [{
            "filename": "AppIcon-1024.png",
            "idiom": "universal",
            "platform": "ios",
            "size": "1024x1024",
        }],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(ICONSET, "Contents.json"), "w", encoding="utf-8") as fh:
        json.dump(contents, fh, indent=2)

    os.makedirs(ACCENT, exist_ok=True)
    accent = {
        "colors": [{
            "idiom": "universal",
            "color": {"color-space": "srgb", "components": {
                "alpha": "1.000", "blue": "1.000", "green": "0.906", "red": "0.357"}},
        }],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(ACCENT, "Contents.json"), "w", encoding="utf-8") as fh:
        json.dump(accent, fh, indent=2)

    with open(os.path.join(BASE, "Contents.json"), "w", encoding="utf-8") as fh:
        json.dump({"info": {"author": "xcode", "version": 1}}, fh, indent=2)

    print("ícone:", os.path.join(ICONSET, "AppIcon-1024.png"),
          os.path.getsize(os.path.join(ICONSET, "AppIcon-1024.png")), "bytes")


if __name__ == "__main__":
    main()
