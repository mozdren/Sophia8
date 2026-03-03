#include "graphics_c64.h"

#include <cstdio>
#include <vector>

struct RGB { uint8_t r,g,b; };

// Commonly used C64 palette approximations (16 colors).
// These are not meant to be perfect, but are stable and deterministic.
static constexpr RGB kC64Palette[16] = {
    { 0x00, 0x00, 0x00 }, // 0 black
    { 0xFF, 0xFF, 0xFF }, // 1 white
    { 0x88, 0x00, 0x00 }, // 2 red
    { 0xAA, 0xFF, 0xEE }, // 3 cyan
    { 0xCC, 0x44, 0xCC }, // 4 purple
    { 0x00, 0xCC, 0x55 }, // 5 green
    { 0x00, 0x00, 0xAA }, // 6 blue
    { 0xEE, 0xEE, 0x77 }, // 7 yellow
    { 0xDD, 0x88, 0x55 }, // 8 orange
    { 0x66, 0x44, 0x00 }, // 9 brown
    { 0xFF, 0x77, 0x77 }, // A light red
    { 0x33, 0x33, 0x33 }, // B dark grey
    { 0x77, 0x77, 0x77 }, // C grey
    { 0xAA, 0xFF, 0x66 }, // D light green
    { 0x00, 0x88, 0xFF }, // E light blue
    { 0xBB, 0xBB, 0xBB }, // F light grey
};

void graphics_c64_draw_ppm(const uint8_t* gfx_mem, const char* out_path)
{
    if (!gfx_mem || !out_path) return;

    std::vector<uint8_t> rgb;
    rgb.resize(static_cast<size_t>(GraphicsC64::kWidth * GraphicsC64::kHeight * 3));

    // Render cell-by-cell
    const uint8_t* p = gfx_mem;
    for (int cy = 0; cy < GraphicsC64::kCellsH; cy++)
    {
        for (int cx = 0; cx < GraphicsC64::kCellsW; cx++)
        {
            const uint8_t* bitmap = p;           // 8 bytes
            const uint8_t color = p[8];          // 1 byte
            p += GraphicsC64::kBytesPerCell;

            const uint8_t fg = (color >> 4) & 0x0F;
            const uint8_t bg = (color >> 0) & 0x0F;
            const RGB fg_rgb = kC64Palette[fg];
            const RGB bg_rgb = kC64Palette[bg];

            for (int row = 0; row < 8; row++)
            {
                const uint8_t bits = bitmap[row];
                const int y = cy * 8 + row;
                for (int col = 0; col < 8; col++)
                {
                    const bool on = (bits & (0x80u >> col)) != 0;
                    const int x = cx * 8 + col;
                    const size_t idx = static_cast<size_t>((y * GraphicsC64::kWidth + x) * 3);
                    const RGB px = on ? fg_rgb : bg_rgb;
                    rgb[idx + 0] = px.r;
                    rgb[idx + 1] = px.g;
                    rgb[idx + 2] = px.b;
                }
            }
        }
    }

    FILE* f = std::fopen(out_path, "wb");
    if (!f) return;

    std::fprintf(f, "P6\n%d %d\n255\n", GraphicsC64::kWidth, GraphicsC64::kHeight);
    (void)std::fwrite(rgb.data(), 1, rgb.size(), f);
    std::fclose(f);
}
