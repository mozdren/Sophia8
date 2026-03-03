#!/usr/bin/env python3
"""
ppm_to_png.py

Convert PPM (P6 or P3) to PNG.

Usage:
  python ppm_to_png.py input.ppm output.png
"""

import sys
from PIL import Image

def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: python ppm_to_png.py input.ppm output.png")
        return 2

    in_path = sys.argv[1]
    out_path = sys.argv[2]

    img = Image.open(in_path)   # Pillow supports PPM (P3/P6)
    img.save(out_path, format="PNG")
    print(f"Converted {in_path} -> {out_path}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())