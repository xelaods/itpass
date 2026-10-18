#!/usr/bin/env python3
"""アプリアイコン（1024px）とロゴ画像を作る。 python3 tools/make_icon.py"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "ITPass" / "Resources" / "Assets.xcassets"
S = 4  # スーパーサンプリング
N = 1024 * S

TOP = (92, 99, 245)
BOTTOM = (124, 72, 232)
ACCENT = (88, 86, 236)
GREEN = (40, 190, 110)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def make():
    grad = Image.new("RGB", (1, 256))
    for y in range(256):
        grad.putpixel((0, y), lerp(TOP, BOTTOM, y / 255))
    img = grad.resize((N, N), Image.BICUBIC)
    # 柔らかい光
    glow = Image.new("L", (N, N), 0)
    ImageDraw.Draw(glow).ellipse((-N * 0.4, -N * 0.6, N * 1.4, N * 0.45), fill=55)
    glow = glow.filter(ImageFilter.GaussianBlur(N * 0.08))
    img = Image.composite(Image.new("RGB", (N, N), (255, 255, 255)), img, glow)

    # 受験票のようなカード
    card = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    w, h = 560 * S, 680 * S
    x0, y0 = (N - w) // 2, (N - h) // 2 + 10 * S
    d.rounded_rectangle((x0, y0, x0 + w, y0 + h), radius=70 * S, fill=(255, 255, 255, 255))
    # 写真枠と文字の線
    d.rounded_rectangle((x0 + 70 * S, y0 + 80 * S, x0 + 220 * S, y0 + 250 * S), radius=24 * S, fill=(226, 228, 252, 255))
    for i, ln in enumerate([230, 170, 200]):
        yy = y0 + (100 + i * 55) * S
        d.rounded_rectangle((x0 + 260 * S, yy, x0 + (260 + ln) * S, yy + 26 * S), radius=13 * S, fill=(214, 217, 246, 255))
    # 合格のチェック
    cx, cy = N // 2, y0 + 470 * S
    r = 150 * S
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=GREEN + (255,))
    lw = 46 * S
    pts = [(cx - 72 * S, cy + 2 * S), (cx - 18 * S, cy + 56 * S), (cx + 80 * S, cy - 58 * S)]
    d.line(pts, fill=(255, 255, 255, 255), width=lw, joint="curve")
    for p in (pts[0], pts[-1]):
        d.ellipse((p[0] - lw / 2, p[1] - lw / 2, p[0] + lw / 2, p[1] + lw / 2), fill=(255, 255, 255, 255))

    card = card.rotate(-7, resample=Image.BICUBIC, center=(N / 2, N / 2))
    shadow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    shadow.paste((20, 10, 80, 110), (0, 0), card.split()[3])
    shadow = shadow.filter(ImageFilter.GaussianBlur(28 * S))
    base = img.convert("RGBA")
    base.alpha_composite(shadow, (0, 26 * S))
    base.alpha_composite(card)
    return base.convert("RGB").resize((1024, 1024), Image.LANCZOS)


def main():
    icon = make()
    (ASSETS / "AppIcon.appiconset").mkdir(parents=True, exist_ok=True)
    icon.save(ASSETS / "AppIcon.appiconset" / "AppIcon.png")
    (ASSETS / "Logo.imageset").mkdir(parents=True, exist_ok=True)
    icon.resize((512, 512), Image.LANCZOS).save(ASSETS / "Logo.imageset" / "Logo.png")
    print("ok")


if __name__ == "__main__":
    main()
