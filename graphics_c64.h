#pragma once

#include <cstdint>

// A tiny, dependency-free C64-inspired graphics renderer.
//
// Memory layout (fixed base address in VM memory):
// - Screen is 40x25 cells, each cell is 8x8 pixels => 320x200
// - For each cell:
//     8 bytes: bitmap rows, MSB is left-most pixel
//              bit=1 => foreground, bit=0 => background
//     1 byte : color nibble byte: high nibble = foreground (0..15)
//                                low  nibble = background (0..15)
// - Total bytes: 40*25*(8+1) = 9000
//
// Output backend for now: binary PPM (P6) file.
// This keeps the feature portable and testable without external libs.

struct GraphicsC64
{
    static constexpr uint16_t kGfxBase = 0x8000;
    static constexpr int kCellsW = 40;
    static constexpr int kCellsH = 25;
    static constexpr int kCellPx = 8;
    static constexpr int kWidth = kCellsW * kCellPx;   // 320
    static constexpr int kHeight = kCellsH * kCellPx;  // 200
    static constexpr int kBytesPerCell = 9;
    static constexpr int kTotalBytes = kCellsW * kCellsH * kBytesPerCell; // 9000
};

// Draws the screen described by gfx_mem (must point to the first byte at base 0x8000)
// into a PPM file.
void graphics_c64_draw_ppm(const uint8_t* gfx_mem, const char* out_path);
