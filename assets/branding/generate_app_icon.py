#!/usr/bin/env python3
"""Generate PEAM launcher PNGs: fingerprint + attendance check."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
PURPLE = (123, 97, 255, 255)
WHITE = (255, 255, 255, 255)
MINT = (216, 243, 232, 255)
MINT_DEEP = (47, 158, 122, 255)


def _round_line(
    draw: ImageDraw.ImageDraw,
    p1: tuple[float, float],
    p2: tuple[float, float],
    width: int,
    color: tuple[int, int, int, int],
) -> None:
    draw.line([p1, p2], fill=color, width=width)
    r = width / 2
    for x, y in (p1, p2):
        draw.ellipse((x - r, y - r, x + r, y + r), fill=color)


def _horseshoe(
    draw: ImageDraw.ImageDraw,
    left: float,
    top: float,
    width: float,
    height: float,
    stroke: int,
    color: tuple[int, int, int, int],
    right_leg: float | None = None,
) -> None:
    """U-shape with a rounded top and vertical legs (fingerprint ridge)."""
    right_leg = height if right_leg is None else right_leg
    right = left + width
    radius = width / 2
    # Upper semicircle: left → top → right
    draw.arc((left, top, right, top + width), start=180, end=0, fill=color, width=stroke)
    leg_top = top + radius
    _round_line(draw, (left, leg_top), (left, top + height), stroke, color)
    _round_line(draw, (right, leg_top), (right, top + right_leg), stroke, color)


def _draw_fingerprint(draw: ImageDraw.ImageDraw, cx: float, cy: float, size: float) -> None:
    stroke = max(10, int(size * 0.09))
    # Nested U ridges, taller than wide, inner ridge shorter on one side.
    ridges = [
        (0.16, 0.06, 0.68, 0.86, 0.86),
        (0.28, 0.18, 0.44, 0.78, 0.70),
        (0.40, 0.30, 0.20, 0.64, 0.52),
    ]
    for l, t, w, h, rh in ridges:
        _horseshoe(
            draw,
            cx - size / 2 + l * size,
            cy - size / 2 + t * size,
            w * size,
            h * size,
            stroke,
            WHITE,
            right_leg=rh * size,
        )
    # Inner core hook
    core_l = cx - size * 0.06
    core_t = cy - size * 0.02
    core_w = size * 0.14
    draw.arc(
        (core_l, core_t, core_l + core_w, core_t + core_w * 1.35),
        start=40,
        end=250,
        fill=WHITE,
        width=stroke,
    )


def _draw_check(draw: ImageDraw.ImageDraw, cx: int, cy: int, radius: int) -> None:
    draw.ellipse(
        (cx - radius, cy - radius, cx + radius, cy + radius),
        fill=MINT,
    )
    w = max(10, radius // 5)
    p1 = (cx - radius * 0.40, cy + radius * 0.04)
    p2 = (cx - radius * 0.06, cy + radius * 0.40)
    p3 = (cx + radius * 0.44, cy - radius * 0.32)
    draw.line([p1, p2, p3], fill=MINT_DEEP, width=w)
    r = w / 2
    for x, y in (p1, p2, p3):
        draw.ellipse((x - r, y - r, x + r, y + r), fill=MINT_DEEP)


def make_full(canvas: int = 2048) -> Image.Image:
    img = Image.new("RGBA", (canvas, canvas), PURPLE)
    draw = ImageDraw.Draw(img)
    _draw_fingerprint(draw, canvas * 0.46, canvas * 0.46, canvas * 0.70)
    _draw_check(draw, int(canvas * 0.74), int(canvas * 0.74), int(canvas * 0.16))
    return img.resize((1024, 1024), Image.Resampling.LANCZOS)


def make_foreground(canvas: int = 2048) -> Image.Image:
    img = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    _draw_fingerprint(draw, canvas * 0.46, canvas * 0.44, canvas * 0.60)
    _draw_check(draw, int(canvas * 0.70), int(canvas * 0.70), int(canvas * 0.14))
    return img.resize((1024, 1024), Image.Resampling.LANCZOS)


def main() -> None:
    make_full().save(ROOT / "app_icon.png")
    make_foreground().save(ROOT / "app_icon_foreground.png")
    print("Wrote app_icon.png and app_icon_foreground.png")


if __name__ == "__main__":
    main()
