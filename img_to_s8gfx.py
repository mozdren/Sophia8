#!/usr/bin/env python3
"""
Sophia8 C64-like image converter (colorful by default).

Output format at .org 0x8000:
- 40x25 cells (320x200 pixels)
- per cell: 8 bitmap bytes + 1 color byte (FG hi nibble, BG lo nibble)
- 9000 bytes total

Algorithm (standard C64 2-color-per-cell practice):
1) Resize image to 320x200
2) Quantize every pixel to the 16-color palette WITH Floyd–Steinberg dithering (default)
3) For each 8x8 cell, choose the best ordered FG/BG pair (16x16) minimizing palette error
4) Emit 1bpp bitmap: bit=1 => FG, bit=0 => BG

Dependency: Pillow (pip install pillow)
"""

from __future__ import annotations
import argparse
from typing import List, Tuple
from PIL import Image

# IMPORTANT: Must match your VM palette in graphics_c64.cpp exactly.
C64_PALETTE: List[Tuple[int, int, int]] = [
    (0x00, 0x00, 0x00), (0xFF, 0xFF, 0xFF), (0x88, 0x00, 0x00), (0xAA, 0xFF, 0xEE),
    (0xCC, 0x44, 0xCC), (0x00, 0xCC, 0x55), (0x00, 0x00, 0xAA), (0xEE, 0xEE, 0x77),
    (0xDD, 0x88, 0x55), (0x66, 0x44, 0x00), (0xFF, 0x77, 0x77), (0x33, 0x33, 0x33),
    (0x77, 0x77, 0x77), (0xAA, 0xFF, 0x66), (0x00, 0x88, 0xFF), (0xBB, 0xBB, 0xBB),
]

# --- sRGB -> Lab (D65), for perceptual nearest-color matching ---
def _srgb_to_linear(u: float) -> float:
    return u / 12.92 if u <= 0.04045 else ((u + 0.055) / 1.055) ** 2.4

def _rgb_to_xyz(r: int, g: int, b: int) -> Tuple[float, float, float]:
    R = _srgb_to_linear(r / 255.0)
    G = _srgb_to_linear(g / 255.0)
    B = _srgb_to_linear(b / 255.0)
    X = 0.4124564 * R + 0.3575761 * G + 0.1804375 * B
    Y = 0.2126729 * R + 0.7151522 * G + 0.0721750 * B
    Z = 0.0193339 * R + 0.1191920 * G + 0.9503041 * B
    return (X, Y, Z)

def _f_lab(t: float) -> float:
    delta = 6.0 / 29.0
    return t ** (1 / 3) if t > delta**3 else (t / (3 * delta * delta) + 4.0 / 29.0)

def _rgb_to_lab(r: int, g: int, b: int) -> Tuple[float, float, float]:
    X, Y, Z = _rgb_to_xyz(r, g, b)
    Xn, Yn, Zn = 0.95047, 1.0, 1.08883
    fx = _f_lab(X / Xn)
    fy = _f_lab(Y / Yn)
    fz = _f_lab(Z / Zn)
    L = 116.0 * fy - 16.0
    a = 500.0 * (fx - fy)
    bb = 200.0 * (fy - fz)
    return (L, a, bb)

def _lab_dist2(p, c) -> float:
    d0 = p[0] - c[0]
    d1 = p[1] - c[1]
    d2 = p[2] - c[2]
    return d0*d0 + d1*d1 + d2*d2

PAL_LAB = [_rgb_to_lab(r, g, b) for (r, g, b) in C64_PALETTE]

def nearest_palette_index(r: int, g: int, b: int) -> int:
    lab = _rgb_to_lab(r, g, b)
    best_i = 0
    best_d = 1e30
    for i, c in enumerate(PAL_LAB):
        d = _lab_dist2(lab, c)
        if d < best_d:
            best_d = d
            best_i = i
    return best_i

def clamp255(x: float) -> int:
    if x < 0: return 0
    if x > 255: return 255
    return int(x + 0.5)

def quantize_dither_fs(img: Image.Image) -> List[int]:
    """Return palette indices for each pixel (row-major), using Floyd–Steinberg dithering."""
    w, h = img.size
    pix = img.load()

    # Error buffers
    err = [[[0.0, 0.0, 0.0] for _ in range(w)] for _ in range(h)]
    idx = [0] * (w * h)

    for y in range(h):
        for x in range(w):
            r, g, b = pix[x, y]
            r2 = clamp255(r + err[y][x][0])
            g2 = clamp255(g + err[y][x][1])
            b2 = clamp255(b + err[y][x][2])

            pi = nearest_palette_index(r2, g2, b2)
            pr, pg, pb = C64_PALETTE[pi]
            idx[y * w + x] = pi

            # quantization error
            er = r2 - pr
            eg = g2 - pg
            eb = b2 - pb

            def add(dx, dy, factor):
                xx = x + dx
                yy = y + dy
                if 0 <= xx < w and 0 <= yy < h:
                    err[yy][xx][0] += er * factor
                    err[yy][xx][1] += eg * factor
                    err[yy][xx][2] += eb * factor

            # Floyd–Steinberg weights
            add(+1, 0, 7/16)
            add(-1, +1, 3/16)
            add(0, +1, 5/16)
            add(+1, +1, 1/16)

    return idx

def best_fg_bg_for_cell(cell_idx: List[int]) -> Tuple[int, int]:
    """Choose ordered (fg,bg) minimizing Lab error to either fg or bg for each pixel."""
    px_lab = [PAL_LAB[i] for i in cell_idx]

    best_fg, best_bg = 0, 0
    best_err = 1e30
    for fg in range(16):
        fg_lab = PAL_LAB[fg]
        for bg in range(16):
            bg_lab = PAL_LAB[bg]
            err = 0.0
            for p in px_lab:
                dfg = _lab_dist2(p, fg_lab)
                dbg = _lab_dist2(p, bg_lab)
                err += dfg if dfg <= dbg else dbg
            if err < best_err:
                best_err = err
                best_fg, best_bg = fg, bg
    return best_fg, best_bg

def encode_to_gfx(img: Image.Image) -> bytearray:
    # Colorful default: Lanczos resize + FS dithering to force palette usage
    img = img.convert("RGB").resize((320, 200), Image.LANCZOS)

    idx_all = quantize_dither_fs(img)
    out = bytearray()

    for cy in range(25):
        for cx in range(40):
            cell = []
            x0 = cx * 8
            y0 = cy * 8
            for y in range(8):
                row = (y0 + y) * 320
                for x in range(8):
                    cell.append(idx_all[row + (x0 + x)])

            fg, bg = best_fg_bg_for_cell(cell)

            fg_lab = PAL_LAB[fg]
            bg_lab = PAL_LAB[bg]

            # bitmap rows
            for y in range(8):
                b = 0
                for x in range(8):
                    p = PAL_LAB[cell[y * 8 + x]]
                    dfg = _lab_dist2(p, fg_lab)
                    dbg = _lab_dist2(p, bg_lab)
                    if dfg <= dbg:
                        b |= (1 << (7 - x))
                out.append(b)

            out.append(((fg & 0x0F) << 4) | (bg & 0x0F))

    if len(out) != 9000:
        raise RuntimeError(f"Produced {len(out)} bytes, expected 9000")
    return out

def write_s8(path: str, gfx: bytes, out_bin: str | None):
    def hb(x: int) -> str:
        return f"0x{x:02X}"

    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("; Auto-generated by img_to_s8gfx.py (colorful defaults)\n\n")
        f.write(".org 0x0200\n")
        f.write("START:\n")
        f.write("    HALT\n\n")
        f.write(".org 0x8000\n")
        f.write("GFX_DATA:\n")

        per_line = 36
        for i in range(0, len(gfx), per_line):
            chunk = gfx[i:i + per_line]
            f.write("    .byte " + ", ".join(hb(b) for b in chunk) + "\n")

        if out_bin:
            f.write("\n; Suggested commands:\n")
            f.write(f";   s8asm {path} -o {out_bin}\n")
            f.write(f";   sophia8 {out_bin} --gfx --gfx-out frame.ppm\n")

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("input_image")
    ap.add_argument("output_s8")
    ap.add_argument("--out-bin-name", default=None)
    args = ap.parse_args()

    img = Image.open(args.input_image)
    gfx = encode_to_gfx(img)
    write_s8(args.output_s8, gfx, args.out_bin_name)

    print(f"Wrote {args.output_s8} with 9000 bytes at .org 0x8000")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())