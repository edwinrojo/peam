#!/usr/bin/env python3
"""Rebuild launcher PNGs from the supplied PEAM logo."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
# Field color sampled from the logo background.
PURPLE = (128, 101, 249, 255)


def main() -> None:
    source = Image.open(ROOT / "app_icon_source.png").convert("RGBA")
    flat = Image.new("RGBA", source.size, PURPLE)
    flat.alpha_composite(source)
    flat.save(ROOT / "app_icon.png")
    source.save(ROOT / "app_icon_foreground.png")
    print("Wrote app_icon.png and app_icon_foreground.png")


if __name__ == "__main__":
    main()
