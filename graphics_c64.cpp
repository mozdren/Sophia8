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

static inline void set_px(uint8_t* rgb_out, const int x, const int y, const RGB px)
{
    const size_t idx = static_cast<size_t>((y * GraphicsC64::kWidth + x) * 3);
    rgb_out[idx + 0] = px.r;
    rgb_out[idx + 1] = px.g;
    rgb_out[idx + 2] = px.b;
}

static void render_text_into_framebuffer(uint8_t* gfx_frame,
                                         const uint8_t* text_mem,
                                         const uint8_t* charset_mem,
                                         const uint8_t* text_state)
{
    if (!gfx_frame || !text_mem || !charset_mem || !text_state) return;

    const uint8_t text_enabled = text_state[0];
    if (!text_enabled) return;

    const uint8_t cursor_x = text_state[1];
    const uint8_t cursor_y = text_state[2];
    const bool cursor_visible = text_state[3] != 0;

    for (int cy = 0; cy < GraphicsC64::kTextRows; cy++)
    {
        for (int cx = 0; cx < GraphicsC64::kTextCols; cx++)
        {
            const uint8_t ch = text_mem[static_cast<size_t>(cy * GraphicsC64::kTextCols + cx)];
            const int gfx_cell_x = cx / 2;
            const int gfx_cell_y = cy;
            const size_t cell_index = static_cast<size_t>(gfx_cell_y * GraphicsC64::kCellsW + gfx_cell_x);
            uint8_t* cell = gfx_frame + cell_index * GraphicsC64::kBytesPerCell;
            const bool is_cursor = cursor_visible &&
                                   cx == static_cast<int>(cursor_x) &&
                                   cy == static_cast<int>(cursor_y);

            const bool left_half = (cx % 2) == 0;
            const uint8_t shift_base = left_half ? 4u : 0u;

            if (!is_cursor && (ch < GraphicsC64::kTextAsciiFirst || ch >= 0x7F))
            {
                continue;
            }

            // Text is painted into the framebuffer copy using a visible
            // foreground color while preserving the existing background nibble.
            cell[8] = static_cast<uint8_t>((cell[8] & 0x0F) | 0x10);

            const uint8_t* glyph = nullptr;
            if (ch >= GraphicsC64::kTextAsciiFirst && ch < 0x7F)
            {
                glyph = charset_mem + static_cast<size_t>((ch - GraphicsC64::kTextAsciiFirst) * GraphicsC64::kTextCellH);
            }
            for (int row = 0; row < GraphicsC64::kTextCellH; row++)
            {
                uint8_t bits = is_cursor ? 0x0F : 0x00;
                if (glyph) bits = static_cast<uint8_t>(glyph[row] & 0x0F);
                if (is_cursor) bits = 0x0F;
                for (int col = 0; col < GraphicsC64::kTextCellW; col++)
                {
                    if ((bits & (0x08u >> col)) == 0) continue;
                    const uint8_t bit = static_cast<uint8_t>(0x80u >> (left_half ? col : (4 + col)));
                    cell[row] |= bit;
                }
            }
        }
    }
}

void graphics_c64_render_rgb(const uint8_t* gfx_mem,
                             uint8_t* rgb_out,
                             const size_t rgb_out_size,
                             const uint8_t* text_mem,
                             const uint8_t* charset_mem,
                             const uint8_t* text_state)
{
    const size_t need = static_cast<size_t>(GraphicsC64::kWidth * GraphicsC64::kHeight * 3);
    if (!gfx_mem || !rgb_out || rgb_out_size < need) return;

    std::vector<uint8_t> frame;
    frame.assign(gfx_mem, gfx_mem + GraphicsC64::kTotalBytes);
    render_text_into_framebuffer(frame.data(), text_mem, charset_mem, text_state);

    const uint8_t* p = frame.data();
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
                    const RGB px = on ? fg_rgb : bg_rgb;
                    set_px(rgb_out, x, y, px);
                }
            }
        }
    }

}

void graphics_c64_draw_ppm(const uint8_t* gfx_mem,
                           const char* out_path,
                           const uint8_t* text_mem,
                           const uint8_t* charset_mem,
                           const uint8_t* text_state)
{
    if (!gfx_mem || !out_path) return;

    std::vector<uint8_t> rgb;
    rgb.resize(static_cast<size_t>(GraphicsC64::kWidth * GraphicsC64::kHeight * 3));
    graphics_c64_render_rgb(gfx_mem, rgb.data(), rgb.size(), text_mem, charset_mem, text_state);

    FILE* f = std::fopen(out_path, "wb");
    if (!f) return;

    std::fprintf(f, "P6\n%d %d\n255\n", GraphicsC64::kWidth, GraphicsC64::kHeight);
    (void)std::fwrite(rgb.data(), 1, rgb.size(), f);
    std::fclose(f);
}
