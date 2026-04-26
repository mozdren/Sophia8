#pragma once

#include <cstddef>
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

    // Sophia8 text console buffer, separate from the graphics framebuffer.
    static constexpr uint16_t kTextStateBase = 0x09BC;
    static constexpr uint16_t kTextBase = 0x09C0;
    static constexpr int kTextCols = 80;
    static constexpr int kTextRows = 25;
    static constexpr int kTextCellW = 4;
    static constexpr int kTextCellH = 8;
    static constexpr int kTextBytes = kTextCols * kTextRows;
    static constexpr uint16_t kTextCharsetBase = 0xD5CA;
    static constexpr int kTextAsciiFirst = 0x20;
    static constexpr int kTextAsciiCount = 0x7F - 0x20;
    static constexpr int kTextCharsetBytes = kTextAsciiCount * kTextCellH;
};

// Draws the screen described by gfx_mem (must point to the first byte at base 0x8000)
// into a PPM file.
void graphics_c64_draw_ppm(const uint8_t* gfx_mem,
                           const char* out_path,
                           const uint8_t* text_mem = nullptr,
                           const uint8_t* charset_mem = nullptr,
                           const uint8_t* text_state = nullptr);

// Renders the screen described by gfx_mem into an RGB888 buffer.
// If text_mem/charset_mem/text_state are provided, the text console is
// composited into a temporary framebuffer copy before RGB conversion.
// rgb_out must contain at least GraphicsC64::kWidth * GraphicsC64::kHeight * 3 bytes.
void graphics_c64_render_rgb(const uint8_t* gfx_mem,
                             uint8_t* rgb_out,
                             size_t rgb_out_size,
                             const uint8_t* text_mem = nullptr,
                             const uint8_t* charset_mem = nullptr,
                             const uint8_t* text_state = nullptr);
